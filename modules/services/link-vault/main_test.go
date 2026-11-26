package main

import (
	"bytes"
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func openTestStore(t *testing.T) *Store {
	t.Helper()
	store, err := OpenStore(filepath.Join(t.TempDir(), "links.sqlite"))
	if err != nil {
		t.Fatalf("OpenStore: %v", err)
	}
	t.Cleanup(func() { _ = store.Close() })
	return store
}

func TestStoreSearchStatesStatsAndMarkdown(t *testing.T) {
	store := openTestStore(t)
	ctx := context.Background()
	link, created, err := store.UpsertLink(ctx, LinkInput{
		URL:         "https://example.com/articles/nixos-notes#top",
		Title:       "NixOS operations notes",
		Description: "Fleet rebuild notes and module patterns",
		Tags:        []string{"NixOS", "fleet", "nixos"},
		Collection:  "infrastructure",
	})
	if err != nil {
		t.Fatalf("UpsertLink: %v", err)
	}
	if !created {
		t.Fatal("first insert was not reported created")
	}
	if link.CanonicalURL != "https://example.com/articles/nixos-notes" {
		t.Fatalf("canonical URL did not strip the fragment: %q", link.CanonicalURL)
	}
	_, createdAgain, err := store.UpsertLink(ctx, LinkInput{URL: "https://example.com/articles/nixos-notes", State: "read", Tags: []string{"fleet"}})
	if err != nil {
		t.Fatalf("second UpsertLink: %v", err)
	}
	if createdAgain {
		t.Fatal("canonical duplicate was reported created")
	}
	hits, err := store.ListLinks(ctx, ListOptions{Query: "nixos"})
	if err != nil {
		t.Fatalf("ListLinks search: %v", err)
	}
	if len(hits) != 1 {
		t.Fatalf("FTS hits = %d, want 1", len(hits))
	}
	if err := store.UpdateLinkState(ctx, link.ID, "archived"); err != nil {
		t.Fatalf("UpdateLinkState: %v", err)
	}
	stats, err := store.Stats(ctx)
	if err != nil {
		t.Fatalf("Stats: %v", err)
	}
	if stats["bookmarks"] != 1 || stats["archived"] != 1 || stats["collections"] != 1 || stats["tags"] != 1 {
		t.Fatalf("unexpected stats: %#v", stats)
	}
	markdown, err := store.ExportMarkdown(ctx)
	if err != nil {
		t.Fatalf("ExportMarkdown: %v", err)
	}
	if !strings.Contains(markdown, "NixOS operations notes") || !strings.Contains(markdown, "state: `archived`") {
		t.Fatalf("markdown export missing link or state:\n%s", markdown)
	}
}

func TestHTTPExtraction(t *testing.T) {
	page := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/html")
		_, _ = w.Write([]byte(`<html><head><title>Research Notes</title><meta name="description" content="A durable note"><meta property="og:site_name" content="Example Research"></head><body><script>bad()</script><h1>Systems reading</h1><p>Useful archive text.</p></body></html>`))
	}))
	defer page.Close()

	extractor := newExtractor(providerConfig{})
	result, err := extractor.extract(context.Background(), page.URL, "http")
	if err != nil {
		t.Fatalf("extract http: %v", err)
	}
	if result.Title != "Research Notes" || result.Description != "A durable note" || result.SiteName != "Example Research" {
		t.Fatalf("unexpected extraction metadata: %#v", result)
	}
	if !strings.Contains(result.Content, "Useful archive text") || strings.Contains(result.Content, "bad()") {
		t.Fatalf("unexpected extracted content: %q", result.Content)
	}
}

func TestFirecrawlExtractionWithMockProvider(t *testing.T) {
	provider := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/scrape" {
			t.Errorf("path = %q, want /scrape", r.URL.Path)
		}
		if got := r.Header.Get("Authorization"); got != "Bearer test-key" {
			t.Errorf("Authorization = %q", got)
		}
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`{"data":{"markdown":"# Provider content\n\nExtracted body.","metadata":{"title":"Provider title","description":"Provider description","siteName":"Mock Site"}}}`))
	}))
	defer provider.Close()

	extractor := newExtractor(providerConfig{FirecrawlKey: "test-key", FirecrawlBase: provider.URL})
	result, err := extractor.extract(context.Background(), "https://example.com/page", "firecrawl")
	if err != nil {
		t.Fatalf("extract firecrawl: %v", err)
	}
	if result.Provider != "firecrawl" || result.Title != "Provider title" || !strings.Contains(result.Content, "Extracted body") {
		t.Fatalf("unexpected provider extraction: %#v", result)
	}
}

func newTestApplication(t *testing.T) (*server, *httptest.Server) {
	t.Helper()
	store := openTestStore(t)
	app := &server{store: store, extractor: newExtractor(providerConfig{}), started: time.Now().UTC()}
	httpServer := httptest.NewServer(app.routes())
	t.Cleanup(httpServer.Close)
	return app, httpServer
}

func TestAPIArchiveExtractSearchStateAndExports(t *testing.T) {
	page := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_, _ = w.Write([]byte(`<html><head><title>API Page</title><meta name="description" content="API extracted description"></head><body><p>API archive body with kubernetes notes.</p></body></html>`))
	}))
	defer page.Close()
	_, apiServer := newTestApplication(t)

	payload := map[string]any{
		"url":        page.URL + "/article?a=1#fragment",
		"title":      "API Page Override",
		"collection": "research",
		"tags":       []string{"kubernetes", "platform"},
		"extract":    true,
		"provider":   "http",
	}
	raw, _ := json.Marshal(payload)
	res, err := http.Post(apiServer.URL+"/api/links", "application/json", bytes.NewReader(raw))
	if err != nil {
		t.Fatalf("POST /api/links: %v", err)
	}
	if res.StatusCode != http.StatusCreated {
		t.Fatalf("POST /api/links status = %s", res.Status)
	}
	var created struct {
		Created bool `json:"created"`
		Link    Link `json:"link"`
	}
	if err := json.NewDecoder(res.Body).Decode(&created); err != nil {
		t.Fatalf("decode created: %v", err)
	}
	res.Body.Close()
	if !created.Created || created.Link.ExtractionStatus != "ok" || !strings.Contains(created.Link.Content, "kubernetes notes") {
		t.Fatalf("unexpected create response: %#v", created)
	}

	res, err = http.Get(apiServer.URL + "/api/links?q=kubernetes")
	if err != nil {
		t.Fatalf("GET /api/links: %v", err)
	}
	var list struct {
		Links []Link `json:"links"`
	}
	if err := json.NewDecoder(res.Body).Decode(&list); err != nil {
		t.Fatalf("decode list: %v", err)
	}
	res.Body.Close()
	if len(list.Links) != 1 || list.Links[0].CollectionName != "research" {
		t.Fatalf("unexpected search response: %#v", list.Links)
	}

	res, err = http.Post(apiServer.URL+"/api/links/1/state", "application/json", strings.NewReader(`{"state":"read"}`))
	if err != nil {
		t.Fatalf("POST state: %v", err)
	}
	if res.StatusCode != http.StatusOK {
		t.Fatalf("POST state status = %s", res.Status)
	}
	res.Body.Close()

	res, err = http.Get(apiServer.URL + "/api/stats")
	if err != nil {
		t.Fatalf("GET stats: %v", err)
	}
	var stats struct {
		Bookmarks   int64 `json:"bookmarks"`
		Read        int64 `json:"read"`
		Collections int64 `json:"collections"`
	}
	if err := json.NewDecoder(res.Body).Decode(&stats); err != nil {
		t.Fatalf("decode stats: %v", err)
	}
	res.Body.Close()
	if stats.Bookmarks != 1 || stats.Read != 1 || stats.Collections != 1 {
		t.Fatalf("unexpected stats response: %#v", stats)
	}

	for path, want := range map[string]string{
		"/api/export.json": "API Page",
		"/api/export.md":   "state: `read`",
		"/":                "Link vault",
	} {
		res, err = http.Get(apiServer.URL + path)
		if err != nil {
			t.Fatalf("GET %s: %v", path, err)
		}
		body, readErr := io.ReadAll(res.Body)
		res.Body.Close()
		if readErr != nil || res.StatusCode != http.StatusOK || !strings.Contains(string(body), want) {
			t.Fatalf("GET %s status=%s body missing %q", path, res.Status, want)
		}
	}
}

func TestTavilyAndContextExtractionWithMockProviders(t *testing.T) {
	tavily := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/extract" {
			t.Errorf("tavily path = %q, want /extract", r.URL.Path)
		}
		var body map[string]any
		if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
			t.Errorf("tavily body: %v", err)
		}
		if got := r.Header.Get("Authorization"); got != "Bearer tavily-key" {
			t.Errorf("tavily Authorization = %q", got)
		}
		if _, exists := body["api_key"]; exists {
			t.Errorf("tavily key appeared in the request body")
		}
		_, _ = w.Write([]byte(`{"results":[{"title":"Tavily title","raw_content":"Tavily extracted body"}]}`))
	}))
	defer tavily.Close()
	contextAPI := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/web/scrape/markdown" {
			t.Errorf("context path = %q", r.URL.Path)
		}
		if got := r.Header.Get("Authorization"); got != "Bearer context-key" {
			t.Errorf("context Authorization = %q", got)
		}
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`{"data":{"title":"Context title","markdown":"Context extracted body"}}`))
	}))
	defer contextAPI.Close()

	extractor := newExtractor(providerConfig{
		TavilyKey:   "tavily-key",
		TavilyBase:  tavily.URL,
		ContextKey:  "context-key",
		ContextBase: contextAPI.URL,
	})
	tavilyResult, err := extractor.extract(context.Background(), "https://example.com/tavily", "tavily")
	if err != nil {
		t.Fatalf("tavily extract: %v", err)
	}
	contextResult, err := extractor.extract(context.Background(), "https://example.com/context", "context")
	if err != nil {
		t.Fatalf("context extract: %v", err)
	}
	if tavilyResult.Title != "Tavily title" || !strings.Contains(tavilyResult.Content, "Tavily extracted") {
		t.Fatalf("unexpected tavily result: %#v", tavilyResult)
	}
	if contextResult.Title != "Context title" || !strings.Contains(contextResult.Content, "Context extracted") {
		t.Fatalf("unexpected context result: %#v", contextResult)
	}
}
