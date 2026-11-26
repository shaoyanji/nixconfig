package main

import (
	"bytes"
	"context"
	"encoding/json"
	"encoding/xml"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"regexp"
	"strings"
	"sync"
	"time"
)

var defaultSources = []string{"rss", "json-feeds", "web-search", "scrape-urls"}

type providerConfig struct {
	FirecrawlKey  string
	TavilyKey     string
	ContextKey    string
	FirecrawlBase string
	TavilyBase    string
	ContextBase   string
	SearchQueries []string
	RSSFeeds      []string
	JSONFeeds     []string
	ScrapeURLs    []string
	Enrich        bool
	MaxEnrich     int
	AllowKeyless  bool
}

type ingester struct {
	store  *Store
	client *http.Client
	cfg    providerConfig

	mu      sync.Mutex
	running bool
	started time.Time
	last    string
}

type ingestSummary struct {
	Running bool      `json:"running"`
	Started time.Time `json:"started,omitempty"`
	Message string    `json:"message"`
}

func newIngester(store *Store, cfg providerConfig) *ingester {
	if cfg.FirecrawlBase == "" {
		cfg.FirecrawlBase = "https://api.firecrawl.dev/v2"
	}
	if cfg.TavilyBase == "" {
		cfg.TavilyBase = "https://api.tavily.com"
	}
	if cfg.ContextBase == "" {
		cfg.ContextBase = "https://api.context.dev/v1"
	}
	if cfg.MaxEnrich <= 0 {
		cfg.MaxEnrich = 4
	}
	if len(cfg.SearchQueries) == 0 {
		cfg.SearchQueries = []string{"laptop deal discount coupon", "ssd sale discount price", "headphones deal Europe"}
	}
	if len(cfg.RSSFeeds) == 0 {
		cfg.RSSFeeds = []string{"https://feeds.feedburner.com/SlickdealsnetFP", "https://feeds.feedburner.com/DealNews"}
	}
	return &ingester{store: store, cfg: cfg, client: &http.Client{Timeout: 45 * time.Second}}
}

func (s *ingester) status() ingestSummary {
	s.mu.Lock()
	defer s.mu.Unlock()
	return ingestSummary{Running: s.running, Started: s.started, Message: s.last}
}

func (s *ingester) startAsync(ctx context.Context, sources []string) (bool, ingestSummary) {
	s.mu.Lock()
	if s.running {
		status := ingestSummary{Running: true, Started: s.started, Message: s.last}
		s.mu.Unlock()
		return false, status
	}
	s.running = true
	s.started = time.Now().UTC()
	s.last = "ingestion queued"
	s.mu.Unlock()
	go s.run(ctx, sources)
	return true, s.status()
}

func (s *ingester) progress(message string) {
	s.mu.Lock()
	s.last = message
	s.mu.Unlock()
}

func (s *ingester) finishStatus(message string) {
	s.mu.Lock()
	s.running = false
	s.last = message
	s.mu.Unlock()
}

func (s *ingester) run(ctx context.Context, sources []string) {
	if len(sources) == 0 {
		sources = defaultSources
	}
	totalFetched, totalInserted, totalUpdated := 0, 0, 0
	failures := []string{}
	for _, source := range sources {
		source = strings.TrimSpace(strings.ToLower(source))
		if source == "" {
			continue
		}
		s.progress("ingesting " + source)
		runID, err := s.store.BeginRun(ctx, source)
		if err != nil {
			failures = append(failures, source+": run record: "+err.Error())
			continue
		}
		result, err := s.ingestSource(ctx, source)
		fetched, inserted, updated := 0, 0, 0
		if err == nil {
			fetched = len(result.Deals)
			for _, input := range result.Deals {
				_, created, upsertErr := s.store.UpsertDeal(ctx, input)
				if upsertErr != nil {
					result.Warnings = append(result.Warnings, "upsert: "+upsertErr.Error())
					continue
				}
				if created {
					inserted++
				} else {
					updated++
				}
			}
			if len(result.Warnings) > 0 {
				err = errors.New(strings.Join(result.Warnings, "; "))
			}
		}
		status := "ok"
		errText := ""
		if err != nil {
			errText = err.Error()
			if fetched > 0 || len(result.Warnings) > 0 {
				status = "ok_with_warnings"
			} else {
				status = "error"
				failures = append(failures, source+": "+err.Error())
			}
		}
		_ = s.store.FinishRun(ctx, runID, source, status, fetched, inserted, updated, errText)
		totalFetched += fetched
		totalInserted += inserted
		totalUpdated += updated
	}
	expired, _ := s.store.MarkExpiredDeals(ctx)
	message := fmt.Sprintf("fetched %d, inserted %d, updated %d, expired %d", totalFetched, totalInserted, totalUpdated, expired)
	if len(failures) > 0 {
		message += "; " + strings.Join(failures, " | ")
	}
	s.finishStatus(message)
}

func (s *ingester) ingestSource(ctx context.Context, source string) (ingestResult, error) {
	switch source {
	case "rss":
		return s.ingestRSS(ctx)
	case "json-feeds":
		return s.ingestJSONFeeds(ctx)
	case "web-search":
		return s.ingestWebSearch(ctx)
	case "scrape-urls":
		return s.ingestScrapeURLs(ctx)
	default:
		return ingestResult{}, fmt.Errorf("unknown source %q", source)
	}
}

func (s *ingester) fetch(ctx context.Context, rawurl string) ([]byte, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, rawurl, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("User-Agent", "private-deals/0.1 (+https://delphi.cloudforest-kardashev.ts.net:8465)")
	req.Header.Set("Accept", "application/rss+xml, application/atom+xml, application/xml, application/json, text/html;q=0.8, */*;q=0.5")
	res, err := s.client.Do(req)
	if err != nil {
		return nil, err
	}
	defer res.Body.Close()
	if res.StatusCode < 200 || res.StatusCode > 299 {
		return nil, fmt.Errorf("%s: HTTP %s", rawurl, res.Status)
	}
	return io.ReadAll(io.LimitReader(res.Body, 8<<20))
}

type feedItem struct {
	Title       string
	Link        string
	Description string
	Published   string
	Categories  []string
}

type rssDocument struct {
	Channel struct {
		Items []struct {
			Title       string   `xml:"title"`
			Link        string   `xml:"link"`
			PubDate     string   `xml:"pubDate"`
			Description string   `xml:"description"`
			Categories  []string `xml:"category"`
		} `xml:"item"`
	} `xml:"channel"`
}

type atomDocument struct {
	Entries []struct {
		Title string `xml:"title"`
		Links []struct {
			Href string `xml:"href,attr"`
			Rel  string `xml:"rel,attr"`
		} `xml:"link"`
		Summary    string `xml:"summary"`
		Content    string `xml:"content"`
		Published  string `xml:"published"`
		Updated    string `xml:"updated"`
		Categories []struct {
			Term string `xml:"term,attr"`
		} `xml:"category"`
	} `xml:"entry"`
}

func parseFeed(raw []byte) ([]feedItem, error) {
	var rss rssDocument
	if err := xml.Unmarshal(raw, &rss); err == nil && len(rss.Channel.Items) > 0 {
		items := make([]feedItem, 0, len(rss.Channel.Items))
		for _, item := range rss.Channel.Items {
			items = append(items, feedItem{Title: item.Title, Link: item.Link, Description: item.Description, Published: item.PubDate, Categories: item.Categories})
		}
		return items, nil
	}
	var atom atomDocument
	if err := xml.Unmarshal(raw, &atom); err == nil && len(atom.Entries) > 0 {
		items := make([]feedItem, 0, len(atom.Entries))
		for _, entry := range atom.Entries {
			link := ""
			for _, candidate := range entry.Links {
				if link == "" || candidate.Rel == "alternate" {
					link = candidate.Href
				}
			}
			description := entry.Summary
			if description == "" {
				description = entry.Content
			}
			published := entry.Published
			if published == "" {
				published = entry.Updated
			}
			categories := []string{}
			for _, category := range entry.Categories {
				categories = append(categories, category.Term)
			}
			items = append(items, feedItem{Title: entry.Title, Link: link, Description: description, Published: published, Categories: categories})
		}
		return items, nil
	}
	return nil, errors.New("no RSS items or Atom entries found")
}

func dealFromFeed(item feedItem, source string) dealInput {
	text := item.Title + " " + item.Description
	price, list, discount := extractPricing(text)
	merchant := merchantFromURL(item.Link)
	return dealInput{
		URL: item.Link, Source: source, Merchant: merchant, Title: cleanText(item.Title), Description: item.Description,
		Category: inferCategory(text), Price: price, ListPrice: list, DiscountPct: &discount, Tags: append([]string{"rss"}, item.Categories...),
	}
}

func (s *ingester) ingestRSS(ctx context.Context) (ingestResult, error) {
	out := ingestResult{}
	if len(s.cfg.RSSFeeds) == 0 {
		out.Warnings = append(out.Warnings, "no RSS feeds configured")
		return out, nil
	}
	for _, feedURL := range s.cfg.RSSFeeds {
		raw, err := s.fetch(ctx, feedURL)
		if err != nil {
			out.Warnings = append(out.Warnings, feedURL+": "+err.Error())
			continue
		}
		items, err := parseFeed(raw)
		if err != nil {
			out.Warnings = append(out.Warnings, feedURL+": "+err.Error())
			continue
		}
		for _, item := range items {
			if deallike(item.Title + " " + item.Description) {
				out.Deals = append(out.Deals, dealFromFeed(item, "rss"))
			}
		}
	}
	return out, nil
}

func deallike(text string) bool {
	lower := strings.ToLower(text)
	if priceTokenRE.MatchString(text) || percentRE.MatchString(text) {
		return true
	}
	for _, word := range []string{"deal", "sale", "discount", "coupon", "price drop", "rabatt", "angebot", "save "} {
		if strings.Contains(lower, word) {
			return true
		}
	}
	return false
}

func (s *ingester) ingestJSONFeeds(ctx context.Context) (ingestResult, error) {
	out := ingestResult{}
	if len(s.cfg.JSONFeeds) == 0 {
		out.Warnings = append(out.Warnings, "no JSON feeds configured")
		return out, nil
	}
	for _, feedURL := range s.cfg.JSONFeeds {
		raw, err := s.fetch(ctx, feedURL)
		if err != nil {
			out.Warnings = append(out.Warnings, feedURL+": "+err.Error())
			continue
		}
		var payload any
		if err := json.Unmarshal(raw, &payload); err != nil {
			out.Warnings = append(out.Warnings, feedURL+": "+err.Error())
			continue
		}
		rows := findObjectRows(payload)
		for _, row := range rows {
			if deal, ok := dealFromMap(row); ok {
				out.Deals = append(out.Deals, deal)
			}
		}
	}
	return out, nil
}

func findObjectRows(v any) []map[string]any {
	switch value := v.(type) {
	case []any:
		rows := []map[string]any{}
		for _, child := range value {
			if row, ok := child.(map[string]any); ok {
				rows = append(rows, row)
			}
		}
		return rows
	case map[string]any:
		for _, key := range []string{"deals", "items", "results", "products", "data"} {
			if rows := findObjectRows(value[key]); len(rows) > 0 {
				return rows
			}
		}
	}
	return nil
}

func stringField(row map[string]any, keys ...string) string {
	for _, key := range keys {
		if value, ok := row[key].(string); ok && strings.TrimSpace(value) != "" {
			return value
		}
	}
	return ""
}

func floatField(row map[string]any, keys ...string) *float64 {
	for _, key := range keys {
		switch value := row[key].(type) {
		case float64:
			return &value
		case string:
			if parsed, ok := parseAmount(value); ok {
				return &parsed
			}
		}
	}
	return nil
}

func tagsField(row map[string]any) []string {
	switch value := row["tags"].(type) {
	case []any:
		out := []string{}
		for _, item := range value {
			if text, ok := item.(string); ok {
				out = append(out, text)
			}
		}
		return out
	case string:
		return strings.Split(value, ",")
	}
	return nil
}

func dealFromMap(row map[string]any) (dealInput, bool) {
	title := stringField(row, "title", "name", "deal", "product")
	if title == "" {
		return dealInput{}, false
	}
	description := stringField(row, "description", "content", "summary", "text")
	price := floatField(row, "price", "current_price", "sale_price", "deal_price")
	list := floatField(row, "list_price", "regular_price", "original_price", "was_price")
	discount := floatField(row, "discount_pct", "discount", "percent_off")
	if price == nil {
		parsedPrice, parsedList, parsedDiscount := extractPricing(title + " " + description)
		price = parsedPrice
		if list == nil {
			list = parsedList
		}
		if discount == nil && parsedDiscount > 0 {
			discount = &parsedDiscount
		}
	}
	url := stringField(row, "url", "link", "deal_url", "product_url")
	return dealInput{
		URL: url, Source: firstNonEmpty(stringField(row, "source"), "json-feed"), Merchant: stringField(row, "merchant", "store", "shop"),
		Title: title, Description: description, Category: stringField(row, "category"), Currency: stringField(row, "currency"),
		Price: price, ListPrice: list, DiscountPct: discount, CouponCode: stringField(row, "coupon", "coupon_code", "code"),
		ExpiresAt: stringField(row, "expires_at", "expiry", "ends_at"), Tags: append([]string{"json"}, tagsField(row)...),
	}, true
}

func firstNonEmpty(values ...string) string {
	for _, value := range values {
		if strings.TrimSpace(value) != "" {
			return value
		}
	}
	return ""
}

func (s *ingester) ingestWebSearch(ctx context.Context) (ingestResult, error) {
	out := ingestResult{}
	if s.cfg.TavilyKey == "" && s.cfg.ContextKey == "" {
		out.Warnings = append(out.Warnings, "web-search skipped: TAVILY_API_KEY and CONTEXT_API_KEY are not configured")
		return out, nil
	}
	for _, query := range s.cfg.SearchQueries {
		if s.cfg.TavilyKey != "" {
			deals, err := s.tavilySearch(ctx, query)
			if err != nil {
				out.Warnings = append(out.Warnings, "tavily: "+err.Error())
			} else {
				out.Deals = append(out.Deals, deals...)
			}
		}
		if s.cfg.ContextKey != "" {
			deals, err := s.contextSearch(ctx, query)
			if err != nil {
				out.Warnings = append(out.Warnings, "context: "+err.Error())
			} else {
				out.Deals = append(out.Deals, deals...)
			}
		}
	}
	return out, nil
}

func (s *ingester) postJSON(ctx context.Context, endpoint, token string, body any, out any) error {
	payload, err := json.Marshal(body)
	if err != nil {
		return err
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, endpoint, bytes.NewReader(payload))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json")
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	res, err := s.client.Do(req)
	if err != nil {
		return err
	}
	defer res.Body.Close()
	raw, err := io.ReadAll(io.LimitReader(res.Body, 8<<20))
	if err != nil {
		return err
	}
	if res.StatusCode < 200 || res.StatusCode > 299 {
		return fmt.Errorf("%s: HTTP %s: %s", endpoint, res.Status, strings.TrimSpace(string(raw[:minInt(len(raw), 240)])))
	}
	return json.Unmarshal(raw, out)
}

func minInt(a, b int) int {
	if a < b {
		return a
	}
	return b
}

func searchDeal(source, title, rawurl, content string) (dealInput, bool) {
	if !deallike(title + " " + content) {
		return dealInput{}, false
	}
	price, list, discount := extractPricing(title + " " + content)
	return dealInput{
		URL: rawurl, Source: source, Merchant: merchantFromURL(rawurl), Title: cleanSearchResultTitle(title), Description: content,
		Category: inferCategory(title + " " + content), Price: price, ListPrice: list, DiscountPct: &discount, Tags: []string{"search", source},
	}, true
}

var trailingSiteRE = regexp.MustCompile(`\s+[|–—-]\s+[^|–—-]{2,60}$`)

func cleanSearchResultTitle(title string) string {
	title = cleanText(title)
	if trailingSiteRE.MatchString(title) {
		title = trailingSiteRE.ReplaceAllString(title, "")
	}
	return strings.Trim(title, " -–—|")
}

func (s *ingester) tavilySearch(ctx context.Context, query string) ([]dealInput, error) {
	var response struct {
		Results []struct {
			Title   string  `json:"title"`
			URL     string  `json:"url"`
			Content string  `json:"content"`
			Score   float64 `json:"score"`
		} `json:"results"`
	}
	body := map[string]any{"query": query, "max_results": 8, "search_depth": "basic", "include_answer": false}
	if err := s.postJSON(ctx, strings.TrimRight(s.cfg.TavilyBase, "/")+"/search", s.cfg.TavilyKey, body, &response); err != nil {
		return nil, err
	}
	out := []dealInput{}
	for _, result := range response.Results {
		if deal, ok := searchDeal("tavily-search", result.Title, result.URL, result.Content); ok {
			deal.Score = &result.Score
			out = append(out, deal)
		}
	}
	return out, nil
}

func (s *ingester) contextSearch(ctx context.Context, query string) ([]dealInput, error) {
	var response struct {
		Results []struct {
			Title       string `json:"title"`
			URL         string `json:"url"`
			Description string `json:"description"`
			Content     string `json:"content"`
		} `json:"results"`
	}
	body := map[string]any{"query": query, "numResults": 8, "freshness": "last_month"}
	if err := s.postJSON(ctx, strings.TrimRight(s.cfg.ContextBase, "/")+"/web/search", s.cfg.ContextKey, body, &response); err != nil {
		return nil, err
	}
	out := []dealInput{}
	for _, result := range response.Results {
		text := result.Description
		if result.Content != "" {
			text = result.Content
		}
		if deal, ok := searchDeal("context-search", result.Title, result.URL, text); ok {
			out = append(out, deal)
		}
	}
	return out, nil
}

func (s *ingester) ingestScrapeURLs(ctx context.Context) (ingestResult, error) {
	out := ingestResult{}
	if len(s.cfg.ScrapeURLs) == 0 {
		out.Warnings = append(out.Warnings, "no scrape URLs configured")
		return out, nil
	}
	for _, rawurl := range s.cfg.ScrapeURLs {
		text, err := s.scrapeText(ctx, rawurl)
		if err != nil {
			out.Warnings = append(out.Warnings, rawurl+": "+err.Error())
			continue
		}
		title := firstMarkdownHeading(text)
		if title == "" {
			title = merchantFromURL(rawurl) + " deal"
		}
		price, list, discount := extractPricing(text)
		out.Deals = append(out.Deals, dealInput{
			URL: rawurl, Source: "scrape-url", Merchant: merchantFromURL(rawurl), Title: title, Description: text,
			Category: inferCategory(text), Price: price, ListPrice: list, DiscountPct: &discount, Tags: []string{"scrape"},
		})
	}
	return out, nil
}

func firstMarkdownHeading(text string) string {
	for _, line := range strings.Split(text, "\n") {
		line = strings.TrimSpace(strings.TrimPrefix(line, "#"))
		if line != "" && len(line) < 180 {
			return cleanText(line)
		}
	}
	return ""
}

func (s *ingester) scrapeText(ctx context.Context, rawurl string) (string, error) {
	if s.cfg.TavilyKey != "" {
		if text, err := s.tavilyExtract(ctx, rawurl); err == nil && len(text) > 80 {
			return text, nil
		}
	}
	if s.cfg.FirecrawlKey != "" || s.cfg.AllowKeyless {
		if text, err := s.firecrawlScrape(ctx, rawurl); err == nil && len(text) > 80 {
			return text, nil
		}
	}
	if s.cfg.ContextKey != "" {
		if text, err := s.contextScrape(ctx, rawurl); err == nil && len(text) > 80 {
			return text, nil
		}
	}
	return "", errors.New("no scrape provider returned content")
}

func (s *ingester) tavilyExtract(ctx context.Context, rawurl string) (string, error) {
	var response struct {
		Results []struct {
			RawContent string `json:"raw_content"`
		} `json:"results"`
	}
	body := map[string]any{"urls": []string{rawurl}, "extract_depth": "basic", "format": "markdown"}
	if err := s.postJSON(ctx, strings.TrimRight(s.cfg.TavilyBase, "/")+"/extract", s.cfg.TavilyKey, body, &response); err != nil {
		return "", err
	}
	if len(response.Results) == 0 {
		return "", errors.New("tavily extract returned no results")
	}
	return response.Results[0].RawContent, nil
}

func (s *ingester) firecrawlScrape(ctx context.Context, rawurl string) (string, error) {
	var response struct {
		Success bool `json:"success"`
		Data    struct {
			Markdown string `json:"markdown"`
		} `json:"data"`
	}
	body := map[string]any{"url": rawurl, "formats": []string{"markdown"}, "onlyMainContent": true}
	if err := s.postJSON(ctx, strings.TrimRight(s.cfg.FirecrawlBase, "/")+"/scrape", s.cfg.FirecrawlKey, body, &response); err != nil {
		return "", err
	}
	if !response.Success || response.Data.Markdown == "" {
		return "", errors.New("firecrawl returned no markdown")
	}
	return response.Data.Markdown, nil
}

func (s *ingester) contextScrape(ctx context.Context, rawurl string) (string, error) {
	endpoint := strings.TrimRight(s.cfg.ContextBase, "/") + "/web/scrape/markdown?url=" + url.QueryEscape(rawurl)
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, endpoint, nil)
	if err != nil {
		return "", err
	}
	req.Header.Set("Accept", "application/json, text/markdown")
	req.Header.Set("Authorization", "Bearer "+s.cfg.ContextKey)
	res, err := s.client.Do(req)
	if err != nil {
		return "", err
	}
	defer res.Body.Close()
	raw, err := io.ReadAll(io.LimitReader(res.Body, 8<<20))
	if err != nil {
		return "", err
	}
	if res.StatusCode < 200 || res.StatusCode > 299 {
		return "", fmt.Errorf("context scrape: HTTP %s", res.Status)
	}
	contentType := res.Header.Get("Content-Type")
	if strings.Contains(contentType, "markdown") || strings.Contains(contentType, "text/plain") {
		return string(raw), nil
	}
	var payload any
	if err := json.Unmarshal(raw, &payload); err != nil {
		return "", err
	}
	if text := findTextKey(payload, "markdown", "content", "text"); text != "" {
		return text, nil
	}
	return "", errors.New("context scrape returned no markdown")
}

func findTextKey(v any, keys ...string) string {
	switch value := v.(type) {
	case map[string]any:
		for _, key := range keys {
			if text, ok := value[key].(string); ok && text != "" {
				return text
			}
		}
		for _, child := range value {
			if text := findTextKey(child, keys...); text != "" {
				return text
			}
		}
	case []any:
		for _, child := range value {
			if text := findTextKey(child, keys...); text != "" {
				return text
			}
		}
	}
	return ""
}
