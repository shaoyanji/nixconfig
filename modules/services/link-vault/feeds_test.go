package main

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestParseRSSAndAtomFeeds(t *testing.T) {
	rss := []byte(`<?xml version="1.0"?><rss version="2.0"><channel><title>Research Feed</title><item><title>RSS item</title><link>https://example.com/rss-one</link><description>&lt;p&gt;RSS summary&lt;/p&gt;</description><content:encoded>&lt;p&gt;RSS full content&lt;/p&gt;</content:encoded><guid>rss-one</guid></item></channel></rss>`)
	parsed, err := parseFeed(rss)
	if err != nil {
		t.Fatalf("parse RSS: %v", err)
	}
	if parsed.Title != "Research Feed" || len(parsed.Items) != 1 || parsed.Items[0].URL != "https://example.com/rss-one" || parsed.Items[0].GUID != "rss-one" || !strings.Contains(parsed.Items[0].Content, "RSS full content") {
		t.Fatalf("unexpected RSS parse: %#v", parsed)
	}

	atom := []byte(`<?xml version="1.0"?><feed xmlns="http://www.w3.org/2005/Atom"><title>Atom Feed</title><entry><title>Atom item</title><link rel="alternate" href="https://example.com/atom-one"/><id>atom-one</id><summary>Atom summary</summary></entry></feed>`)
	parsed, err = parseFeed(atom)
	if err != nil {
		t.Fatalf("parse Atom: %v", err)
	}
	if parsed.Title != "Atom Feed" || len(parsed.Items) != 1 || parsed.Items[0].URL != "https://example.com/atom-one" || parsed.Items[0].GUID != "atom-one" {
		t.Fatalf("unexpected Atom parse: %#v", parsed)
	}
}

func postTestJSON(t *testing.T, url string, payload any) *http.Response {
	t.Helper()
	raw, err := json.Marshal(payload)
	if err != nil {
		t.Fatalf("marshal payload: %v", err)
	}
	res, err := http.Post(url, "application/json", bytes.NewReader(raw))
	if err != nil {
		t.Fatalf("POST %s: %v", url, err)
	}
	return res
}

func TestAPIFeedsPollDedupesCapturedLinks(t *testing.T) {
	var feedBody string
	feedServer := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/rss+xml")
		_, _ = w.Write([]byte(feedBody))
	}))
	defer feedServer.Close()
	itemURL := feedServer.URL + "/articles/feed-item"
	feedBody = `<?xml version="1.0"?><rss version="2.0"><channel><title>Mock Research</title><item><title>Feed captured research</title><link>` + itemURL + `</link><description>Feed captured summary</description><guid>stable-item-one</guid></item><item><title>Second captured item</title><link>` + feedServer.URL + `/articles/second</link><description>Second summary</description><guid>stable-item-two</guid></item></channel></rss>`

	_, apiServer := newTestApplication(t)
	res := postTestJSON(t, apiServer.URL+"/api/feeds", map[string]any{
		"url":        feedServer.URL + "/feed.xml",
		"title":      "Research watch",
		"collection": "watched",
		"tags":       []string{"research", "feed"},
	})
	if res.StatusCode != http.StatusCreated {
		t.Fatalf("POST /api/feeds status = %s", res.Status)
	}
	var createdFeed struct {
		Feed    Feed `json:"feed"`
		Created bool `json:"created"`
	}
	if err := json.NewDecoder(res.Body).Decode(&createdFeed); err != nil {
		t.Fatalf("decode feed create: %v", err)
	}
	res.Body.Close()
	if !createdFeed.Created || createdFeed.Feed.ID == 0 || createdFeed.Feed.Collection != "watched" {
		t.Fatalf("unexpected feed create: %#v", createdFeed)
	}

	res = postTestJSON(t, apiServer.URL+"/api/feeds/poll", map[string]any{})
	if res.StatusCode != http.StatusOK {
		t.Fatalf("first poll status = %s", res.Status)
	}
	var firstPoll struct {
		Polled  int `json:"polled"`
		Created int `json:"created"`
		Skipped int `json:"skipped"`
		Failed  int `json:"failed"`
	}
	if err := json.NewDecoder(res.Body).Decode(&firstPoll); err != nil {
		t.Fatalf("decode first poll: %v", err)
	}
	res.Body.Close()
	if firstPoll.Polled != 1 || firstPoll.Created != 2 || firstPoll.Skipped != 0 || firstPoll.Failed != 0 {
		t.Fatalf("unexpected first poll: %#v", firstPoll)
	}

	res = postTestJSON(t, apiServer.URL+"/api/feeds/poll", map[string]any{"id": createdFeed.Feed.ID})
	if res.StatusCode != http.StatusOK {
		t.Fatalf("second poll status = %s", res.Status)
	}
	var secondPoll struct {
		Created int `json:"created"`
		Skipped int `json:"skipped"`
		Failed  int `json:"failed"`
	}
	if err := json.NewDecoder(res.Body).Decode(&secondPoll); err != nil {
		t.Fatalf("decode second poll: %v", err)
	}
	res.Body.Close()
	if secondPoll.Created != 0 || secondPoll.Skipped != 2 || secondPoll.Failed != 0 {
		t.Fatalf("unexpected dedupe poll: %#v", secondPoll)
	}

	res, err := http.Get(apiServer.URL + "/api/links?tag=feed")
	if err != nil {
		t.Fatalf("GET captured links: %v", err)
	}
	var list struct {
		Links []Link `json:"links"`
	}
	if err := json.NewDecoder(res.Body).Decode(&list); err != nil {
		t.Fatalf("decode links: %v", err)
	}
	res.Body.Close()
	if len(list.Links) != 2 {
		t.Fatalf("captured links = %d, want 2: %#v", len(list.Links), list.Links)
	}
	for _, link := range list.Links {
		if link.Source != "feed" || link.CollectionName != "watched" {
			t.Fatalf("unexpected captured link: %#v", link)
		}
	}

	res, err = http.Get(apiServer.URL + "/api/feeds")
	if err != nil {
		t.Fatalf("GET feeds: %v", err)
	}
	var feeds struct {
		Feeds []Feed `json:"feeds"`
	}
	if err := json.NewDecoder(res.Body).Decode(&feeds); err != nil {
		t.Fatalf("decode feeds: %v", err)
	}
	res.Body.Close()
	if len(feeds.Feeds) != 1 || feeds.Feeds[0].LastItemCount != 2 || feeds.Feeds[0].LastError != "" || feeds.Feeds[0].LastSuccessAt == "" {
		t.Fatalf("unexpected feed state: %#v", feeds.Feeds)
	}

	req, err := http.NewRequest(http.MethodDelete, apiServer.URL+"/api/feeds/1", nil)
	if err != nil {
		t.Fatalf("delete request: %v", err)
	}
	res, err = http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("DELETE feed: %v", err)
	}
	if res.StatusCode != http.StatusOK {
		t.Fatalf("DELETE feed status = %s", res.Status)
	}
	res.Body.Close()
}

func TestAnalyticsEndpoint(t *testing.T) {
	app, apiServer := newTestApplication(t)
	store := app.store
	background := context.Background()
	for _, row := range []LinkInput{
		{URL: "https://example.com/one", Title: "One", Tags: []string{"nixos", "fleet"}, Collection: "infrastructure", State: "read"},
		{URL: "https://example.com/two", Title: "Two", Tags: []string{"nixos"}, Collection: "infrastructure", State: "unread"},
		{URL: "https://other.net/three", Title: "Three", Tags: []string{"ai"}, State: "unread"},
	} {
		link, _, err := store.UpsertLink(background, row)
		if err != nil {
			t.Fatalf("upsert %s: %v", row.URL, err)
		}
		if row.Title == "One" {
			if err := store.UpdateExtraction(background, link.ID, ExtractionResult{Title: row.Title, Content: "extracted", Provider: "http"}, "ok", ""); err != nil {
				t.Fatalf("UpdateExtraction: %v", err)
			}
		}
	}
	res, err := http.Get(apiServer.URL + "/api/analytics")
	if err != nil {
		t.Fatalf("GET analytics: %v", err)
	}
	if res.StatusCode != http.StatusOK {
		t.Fatalf("analytics status = %s", res.Status)
	}
	var analytics analyticsResponse
	if err := json.NewDecoder(res.Body).Decode(&analytics); err != nil {
		t.Fatalf("decode analytics: %v", err)
	}
	res.Body.Close()
	if analytics.States.Total != 3 || analytics.States.Read != 1 || analytics.States.Unread != 2 || analytics.States.ReadPercent <= 0 {
		t.Fatalf("unexpected state analytics: %#v", analytics.States)
	}
	if len(analytics.TopDomains) == 0 || analytics.TopDomains[0].Name != "example.com" || analytics.TopDomains[0].Count != 2 {
		t.Fatalf("unexpected domain analytics: %#v", analytics.TopDomains)
	}
	if len(analytics.TopTags) == 0 || analytics.TopTags[0].Name != "nixos" || analytics.TopTags[0].Count != 2 {
		t.Fatalf("unexpected tag analytics: %#v", analytics.TopTags)
	}
	if len(analytics.Collections) == 0 || analytics.Collections[0].Name != "infrastructure" || analytics.Collections[0].Count != 2 || analytics.Collections[0].Read != 1 {
		t.Fatalf("unexpected collection analytics: %#v", analytics.Collections)
	}
	if len(analytics.ExtractionProviders) != 1 || analytics.ExtractionProviders[0].Name != "http" || analytics.ExtractionProviders[0].Count != 1 {
		t.Fatalf("unexpected provider analytics: %#v", analytics.ExtractionProviders)
	}
	if !strings.Contains(analytics.GeneratedAt, "T") {
		t.Fatalf("generated_at missing: %#v", analytics.GeneratedAt)
	}
}
