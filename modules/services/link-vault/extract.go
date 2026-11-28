package main

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"html"
	"io"
	"log"
	"net/http"
	"net/url"
	"regexp"
	"strings"
	"time"

	"nixconfig.local/fetchcache"
)

type providerConfig struct {
	FirecrawlKey  string
	TavilyKey     string
	ContextKey    string
	FirecrawlBase string
	TavilyBase    string
	ContextBase   string
}

type ExtractionResult struct {
	Title       string `json:"title"`
	Description string `json:"description"`
	Content     string `json:"content"`
	Excerpt     string `json:"excerpt"`
	SiteName    string `json:"site_name"`
	Provider    string `json:"provider"`
}

type extractor struct {
	cfg    providerConfig
	client *http.Client
}

func newExtractor(cfg providerConfig, cacheDirs ...string) *extractor {
	if cfg.FirecrawlBase == "" {
		cfg.FirecrawlBase = "https://api.firecrawl.dev/v2"
	}
	if cfg.TavilyBase == "" {
		cfg.TavilyBase = "https://api.tavily.com"
	}
	if cfg.ContextBase == "" {
		cfg.ContextBase = "https://api.context.dev/v1"
	}
	cacheDir := ""
	if len(cacheDirs) > 0 {
		cacheDir = cacheDirs[0]
	}
	return &extractor{cfg: cfg, client: &http.Client{Timeout: 20 * time.Second, Transport: fetchcache.New(cacheDir, 8<<20, nil, log.Printf)}}
}

func (e *extractor) providers() map[string]bool {
	return map[string]bool{
		"http":      true,
		"firecrawl": e.cfg.FirecrawlKey != "",
		"tavily":    e.cfg.TavilyKey != "",
		"context":   e.cfg.ContextKey != "",
	}
}

func (e *extractor) extract(ctx context.Context, rawurl, provider string) (ExtractionResult, error) {
	if _, err := canonicalURL(rawurl); err != nil {
		return ExtractionResult{}, err
	}
	provider = strings.ToLower(strings.TrimSpace(provider))
	if provider == "" || provider == "auto" {
		errorsSeen := []string{}
		for _, candidate := range []string{"firecrawl", "tavily", "context", "http"} {
			if candidate != "http" && !e.providers()[candidate] {
				continue
			}
			result, err := e.extractOne(ctx, rawurl, candidate)
			if err == nil && (result.Content != "" || result.Title != "") {
				return result, nil
			}
			if err != nil {
				errorsSeen = append(errorsSeen, candidate+": "+err.Error())
			}
		}
		if len(errorsSeen) > 0 {
			return ExtractionResult{}, errors.New(strings.Join(errorsSeen, "; "))
		}
		return ExtractionResult{}, fmt.Errorf("no extractor produced content")
	}
	return e.extractOne(ctx, rawurl, provider)
}

func (e *extractor) extractOne(ctx context.Context, rawurl, provider string) (ExtractionResult, error) {
	switch provider {
	case "http", "direct":
		return e.extractHTTP(ctx, rawurl)
	case "firecrawl":
		if e.cfg.FirecrawlKey == "" {
			return ExtractionResult{}, fmt.Errorf("firecrawl credentials are not configured")
		}
		return e.extractFirecrawl(ctx, rawurl)
	case "tavily":
		if e.cfg.TavilyKey == "" {
			return ExtractionResult{}, fmt.Errorf("tavily credentials are not configured")
		}
		return e.extractTavily(ctx, rawurl)
	case "context":
		if e.cfg.ContextKey == "" {
			return ExtractionResult{}, fmt.Errorf("context credentials are not configured")
		}
		return e.extractContext(ctx, rawurl)
	default:
		return ExtractionResult{}, fmt.Errorf("provider must be auto, http, firecrawl, tavily or context")
	}
}

func limitBody(body io.Reader) ([]byte, error) {
	return io.ReadAll(io.LimitReader(body, 8<<20))
}

func (e *extractor) extractHTTP(ctx context.Context, rawurl string) (ExtractionResult, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, rawurl, nil)
	if err != nil {
		return ExtractionResult{}, err
	}
	req.Header.Set("User-Agent", "link-vault/0.1 (+https://delphi.cloudforest-kardashev.ts.net:8468)")
	req.Header.Set("Accept", "text/html,application/xhtml+xml,text/plain;q=0.8,*/*;q=0.5")
	res, err := e.client.Do(req)
	if err != nil {
		return ExtractionResult{}, err
	}
	defer res.Body.Close()
	if res.StatusCode < 200 || res.StatusCode > 299 {
		return ExtractionResult{}, fmt.Errorf("HTTP %s", res.Status)
	}
	raw, err := limitBody(res.Body)
	if err != nil {
		return ExtractionResult{}, err
	}
	result := parseHTMLContent(string(raw), rawurl)
	result.Provider = "http"
	return result, nil
}

var (
	titleRE       = regexp.MustCompile(`(?is)<title[^>]*>(.*?)</title>`)
	scriptRE      = regexp.MustCompile(`(?is)<script[^>]*>.*?</script>|<style[^>]*>.*?</style>|<noscript[^>]*>.*?</noscript>|<svg[^>]*>.*?</svg>|<template[^>]*>.*?</template>`)
	commentRE     = regexp.MustCompile(`(?is)<!--.*?-->`)
	tagRE         = regexp.MustCompile(`(?is)<[^>]+>`)
	metaDescRE    = regexp.MustCompile(`(?is)<meta[^>]+name=["']description["'][^>]+content=["']([^"']*)["']`)
	metaDescAltRE = regexp.MustCompile(`(?is)<meta[^>]+content=["']([^"']*)["'][^>]+name=["']description["']`)
	metaSiteRE    = regexp.MustCompile(`(?is)<meta[^>]+property=["']og:site_name["'][^>]+content=["']([^"']*)["']`)
)

func parseHTMLContent(raw, rawurl string) ExtractionResult {
	title := ""
	if match := titleRE.FindStringSubmatch(raw); len(match) == 2 {
		title = cleanSpace(html.UnescapeString(match[1]))
	}
	description := firstRegex(raw, metaDescRE, metaDescAltRE)
	siteName := firstRegex(raw, metaSiteRE)
	if siteName == "" {
		if u, err := url.Parse(rawurl); err == nil {
			siteName = u.Hostname()
		}
	}
	withoutBlocks := scriptRE.ReplaceAllString(raw, " ")
	withoutBlocks = commentRE.ReplaceAllString(withoutBlocks, " ")
	text := html.UnescapeString(tagRE.ReplaceAllString(withoutBlocks, " "))
	content := cleanSpace(text)
	runes := []rune(content)
	if len(runes) > 200000 {
		content = string(runes[:200000])
	}
	return ExtractionResult{
		Title:       title,
		Description: cleanSpace(html.UnescapeString(description)),
		Content:     content,
		Excerpt:     excerptOf(firstNonEmptyString(description, content), 280),
		SiteName:    cleanSpace(html.UnescapeString(siteName)),
	}
}

func firstRegex(raw string, expressions ...*regexp.Regexp) string {
	for _, expression := range expressions {
		if match := expression.FindStringSubmatch(raw); len(match) == 2 {
			return strings.TrimSpace(match[1])
		}
	}
	return ""
}

func postJSON(ctx context.Context, client *http.Client, endpoint string, payload any, bearer string) (map[string]any, error) {
	raw, err := json.Marshal(payload)
	if err != nil {
		return nil, err
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, endpoint, bytes.NewReader(raw))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json")
	if bearer != "" {
		req.Header.Set("Authorization", "Bearer "+bearer)
	}
	res, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer res.Body.Close()
	body, err := limitBody(res.Body)
	if err != nil {
		return nil, err
	}
	if res.StatusCode < 200 || res.StatusCode > 299 {
		return nil, fmt.Errorf("HTTP %s", res.Status)
	}
	var decoded map[string]any
	if err := json.Unmarshal(body, &decoded); err != nil {
		return nil, fmt.Errorf("provider response is not JSON: %w", err)
	}
	return decoded, nil
}

func stringAt(value any, path ...string) string {
	current := value
	for _, key := range path {
		object, ok := current.(map[string]any)
		if !ok {
			return ""
		}
		current = object[key]
	}
	text, _ := current.(string)
	return strings.TrimSpace(text)
}

func finishProviderResult(result ExtractionResult, provider, rawurl string) ExtractionResult {
	if result.SiteName == "" {
		if u, err := url.Parse(rawurl); err == nil {
			result.SiteName = u.Hostname()
		}
	}
	if result.Excerpt == "" {
		result.Excerpt = excerptOf(firstNonEmptyString(result.Description, result.Content), 280)
	}
	result.Provider = provider
	return result
}

func (e *extractor) extractFirecrawl(ctx context.Context, rawurl string) (ExtractionResult, error) {
	decoded, err := postJSON(ctx, e.client, strings.TrimRight(e.cfg.FirecrawlBase, "/")+"/scrape", map[string]any{
		"url":             rawurl,
		"formats":         []string{"markdown"},
		"onlyMainContent": true,
	}, e.cfg.FirecrawlKey)
	if err != nil {
		return ExtractionResult{}, err
	}
	result := ExtractionResult{
		Title:       firstNonEmptyString(stringAt(decoded, "data", "metadata", "title"), stringAt(decoded, "metadata", "title")),
		Description: firstNonEmptyString(stringAt(decoded, "data", "metadata", "description"), stringAt(decoded, "metadata", "description")),
		Content:     firstNonEmptyString(stringAt(decoded, "data", "markdown"), stringAt(decoded, "markdown"), stringAt(decoded, "data", "content"), stringAt(decoded, "content")),
		SiteName:    firstNonEmptyString(stringAt(decoded, "data", "metadata", "siteName"), stringAt(decoded, "metadata", "siteName")),
	}
	if result.Content == "" && result.Title == "" {
		return ExtractionResult{}, errors.New("firecrawl returned no markdown")
	}
	return finishProviderResult(result, "firecrawl", rawurl), nil
}

func (e *extractor) extractTavily(ctx context.Context, rawurl string) (ExtractionResult, error) {
	decoded, err := postJSON(ctx, e.client, strings.TrimRight(e.cfg.TavilyBase, "/")+"/extract", map[string]any{
		"urls":          []string{rawurl},
		"extract_depth": "basic",
		"format":        "markdown",
	}, e.cfg.TavilyKey)
	if err != nil {
		return ExtractionResult{}, err
	}
	var first map[string]any
	if rows, ok := decoded["results"].([]any); ok && len(rows) > 0 {
		first, _ = rows[0].(map[string]any)
	}
	result := ExtractionResult{
		Title:       firstNonEmptyString(stringAt(first, "title"), stringAt(decoded, "title")),
		Description: firstNonEmptyString(stringAt(first, "description"), stringAt(decoded, "description")),
		Content:     firstNonEmptyString(stringAt(first, "raw_content"), stringAt(first, "content"), stringAt(decoded, "raw_content"), stringAt(decoded, "content")),
	}
	if result.Content == "" {
		return ExtractionResult{}, errors.New("tavily extract returned no content")
	}
	return finishProviderResult(result, "tavily", rawurl), nil
}

func findStringKey(value any, keys ...string) string {
	switch typed := value.(type) {
	case map[string]any:
		for _, key := range keys {
			if text, ok := typed[key].(string); ok && strings.TrimSpace(text) != "" {
				return strings.TrimSpace(text)
			}
		}
		for _, nested := range typed {
			if text := findStringKey(nested, keys...); text != "" {
				return text
			}
		}
	case []any:
		for _, nested := range typed {
			if text := findStringKey(nested, keys...); text != "" {
				return text
			}
		}
	}
	return ""
}

func (e *extractor) extractContext(ctx context.Context, rawurl string) (ExtractionResult, error) {
	endpoint := strings.TrimRight(e.cfg.ContextBase, "/") + "/web/scrape/markdown?url=" + url.QueryEscape(rawurl)
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, endpoint, nil)
	if err != nil {
		return ExtractionResult{}, err
	}
	req.Header.Set("Accept", "application/json, text/markdown")
	req.Header.Set("Authorization", "Bearer "+e.cfg.ContextKey)
	res, err := e.client.Do(req)
	if err != nil {
		return ExtractionResult{}, err
	}
	defer res.Body.Close()
	raw, err := limitBody(res.Body)
	if err != nil {
		return ExtractionResult{}, err
	}
	if res.StatusCode < 200 || res.StatusCode > 299 {
		return ExtractionResult{}, fmt.Errorf("HTTP %s", res.Status)
	}
	result := ExtractionResult{}
	contentType := res.Header.Get("Content-Type")
	if strings.Contains(contentType, "markdown") || strings.Contains(contentType, "text/plain") {
		result.Content = strings.TrimSpace(string(raw))
	} else {
		var payload any
		if err := json.Unmarshal(raw, &payload); err != nil {
			return ExtractionResult{}, err
		}
		result.Title = findStringKey(payload, "title")
		result.Description = findStringKey(payload, "description")
		result.Content = findStringKey(payload, "markdown", "content", "text")
	}
	if result.Content == "" {
		return ExtractionResult{}, errors.New("context scrape returned no markdown")
	}
	return finishProviderResult(result, "context", rawurl), nil
}
