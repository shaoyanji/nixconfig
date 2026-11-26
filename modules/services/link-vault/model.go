package main

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"net/url"
	"regexp"
	"sort"
	"strings"
	"time"
)

var whitespaceRE = regexp.MustCompile(`\s+`)

type Link struct {
	ID               int64     `json:"id"`
	URL              string    `json:"url"`
	CanonicalURL     string    `json:"canonical_url"`
	Title            string    `json:"title"`
	Description      string    `json:"description"`
	Content          string    `json:"content,omitempty"`
	Excerpt          string    `json:"excerpt"`
	SiteName         string    `json:"site_name"`
	Source           string    `json:"source"`
	State            string    `json:"state"`
	Tags             []string  `json:"tags"`
	CollectionID     int64     `json:"collection_id,omitempty"`
	CollectionName   string    `json:"collection_name,omitempty"`
	ExtractionStatus string    `json:"extraction_status"`
	ExtractionError  string    `json:"extraction_error,omitempty"`
	ExtractedAt      string    `json:"extracted_at,omitempty"`
	CreatedAt        time.Time `json:"created_at"`
	UpdatedAt        time.Time `json:"updated_at"`
}

type LinkInput struct {
	URL         string   `json:"url"`
	Title       string   `json:"title"`
	Description string   `json:"description"`
	Content     string   `json:"content"`
	Excerpt     string   `json:"excerpt"`
	SiteName    string   `json:"site_name"`
	Source      string   `json:"source"`
	State       string   `json:"state"`
	Tags        []string `json:"tags"`
	Collection  string   `json:"collection"`
	Extract     bool     `json:"extract"`
	Provider    string   `json:"provider"`
}

type Collection struct {
	ID          int64     `json:"id"`
	Name        string    `json:"name"`
	Description string    `json:"description"`
	Links       int64     `json:"links"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
}

func cleanSpace(raw string) string {
	return strings.TrimSpace(whitespaceRE.ReplaceAllString(raw, " "))
}

func normalizeState(raw string) (string, error) {
	state := strings.ToLower(strings.TrimSpace(raw))
	if state == "" {
		state = "unread"
	}
	switch state {
	case "unread", "read", "archived":
		return state, nil
	default:
		return "", fmt.Errorf("state must be unread, read or archived")
	}
}

func normalizeTags(tags []string) []string {
	seen := map[string]bool{}
	out := []string{}
	for _, tag := range tags {
		for _, part := range strings.Split(tag, ",") {
			part = strings.ToLower(cleanSpace(strings.TrimPrefix(part, "#")))
			if part != "" && !seen[part] {
				seen[part] = true
				out = append(out, part)
			}
		}
	}
	sort.Strings(out)
	return out
}

func tagsJSON(tags []string) string {
	raw, _ := json.Marshal(normalizeTags(tags))
	return string(raw)
}

func parseTags(raw string) []string {
	var tags []string
	if json.Unmarshal([]byte(raw), &tags) != nil {
		return []string{}
	}
	return normalizeTags(tags)
}

func canonicalURL(rawurl string) (string, error) {
	rawurl = strings.TrimSpace(rawurl)
	if rawurl == "" {
		return "", fmt.Errorf("url is required")
	}
	u, err := url.Parse(rawurl)
	if err != nil {
		return "", fmt.Errorf("invalid url: %w", err)
	}
	if u.Scheme != "http" && u.Scheme != "https" {
		return "", fmt.Errorf("url must use http or https")
	}
	if u.Hostname() == "" {
		return "", fmt.Errorf("url host is required")
	}
	u.Scheme = strings.ToLower(u.Scheme)
	u.Host = strings.ToLower(u.Host)
	u.Fragment = ""
	return u.String(), nil
}

func fingerprintURL(canonical string) string {
	sum := sha256.Sum256([]byte(canonical))
	return hex.EncodeToString(sum[:])
}

func excerptOf(content string, limit int) string {
	content = cleanSpace(content)
	if limit <= 0 {
		limit = 280
	}
	runes := []rune(content)
	if len(runes) <= limit {
		return content
	}
	return strings.TrimSpace(string(runes[:limit])) + "…"
}

func validateInput(input *LinkInput) error {
	canonical, err := canonicalURL(input.URL)
	if err != nil {
		return err
	}
	input.URL = canonical
	if input.Source = strings.ToLower(cleanSpace(input.Source)); input.Source == "" {
		input.Source = "manual"
	}
	if input.State, err = normalizeState(input.State); err != nil {
		return err
	}
	input.Tags = normalizeTags(input.Tags)
	input.Title = cleanSpace(input.Title)
	input.Description = cleanSpace(input.Description)
	input.SiteName = cleanSpace(input.SiteName)
	input.Collection = cleanSpace(input.Collection)
	return nil
}
