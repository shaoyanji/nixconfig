package main

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"net/url"
	"strings"
	"testing"
)

func tempStore(t *testing.T) *server {
	t.Helper()
	db, err := openStore(t.TempDir() + "/deals.db")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { db.Close() })
	return &server{db: db}
}

func post(t *testing.T, srv *server, path, body string) *httptest.ResponseRecorder {
	t.Helper()
	req := httptest.NewRequest("POST", path, strings.NewReader(body))
	rec := httptest.NewRecorder()
	srv.mux().ServeHTTP(rec, req)
	return rec
}

func get(t *testing.T, srv *server, path string) *httptest.ResponseRecorder {
	t.Helper()
	req := httptest.NewRequest("GET", path, nil)
	rec := httptest.NewRecorder()
	srv.mux().ServeHTTP(rec, req)
	return rec
}

func TestAddSearchFTS(t *testing.T) {
	srv := tempStore(t)
	rec := post(t, srv, "/api/deals", `{"title":"ThinkPad T14 Gen 3 refurbished","url":"https://example.test/t14","price_cents":54900,"notes":"16GB RAM, good battery"}`)
	if rec.Code != 200 {
		t.Fatalf("add: %d %s", rec.Code, rec.Body)
	}
	var added struct {
		ID  int64 `json:"id"`
		New bool  `json:"new"`
	}
	json.Unmarshal(rec.Body.Bytes(), &added)
	if !added.New {
		t.Fatal("first insert must be new")
	}

	rec = get(t, srv, "/api/deals?q=thinkpad")
	if rec.Code != 200 {
		t.Fatalf("search: %d %s", rec.Code, rec.Body)
	}
	var res struct {
		Count int `json:"count"`
	}
	json.Unmarshal(rec.Body.Bytes(), &res)
	if res.Count != 1 {
		t.Fatalf("fts search thinkpad: got %d, want 1", res.Count)
	}

	// FTS must hit notes too, and a query with punctuation must not break MATCH.
	rec = get(t, srv, "/api/deals?q="+url.QueryEscape("battery,"))
	json.Unmarshal(rec.Body.Bytes(), &res)
	if res.Count != 1 {
		t.Fatalf("fts notes search: got %d, want 1", res.Count)
	}

	rec = get(t, srv, "/api/deals?q=nothinghere")
	json.Unmarshal(rec.Body.Bytes(), &res)
	if res.Count != 0 {
		t.Fatalf("miss search: got %d, want 0", res.Count)
	}
}

func TestUpsertPriceHistory(t *testing.T) {
	srv := tempStore(t)
	post(t, srv, "/api/deals", `{"title":"SSD 2TB","url":"https://example.test/ssd","price_cents":9999}`)
	post(t, srv, "/api/deals", `{"title":"SSD 2TB","url":"https://example.test/ssd","price_cents":8999}`)
	post(t, srv, "/api/deals", `{"title":"SSD 2TB","url":"https://example.test/ssd","price_cents":8999}`)

	rec := get(t, srv, "/api/deals/1")
	var res struct {
		Deal Deal `json:"deal"`
		Hist []struct {
			PriceCents int64 `json:"price_cents"`
		} `json:"price_history"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &res); err != nil {
		t.Fatal(err)
	}
	if res.Deal.PriceCents != 8999 {
		t.Fatalf("price after upsert: got %d, want 8999", res.Deal.PriceCents)
	}
	if len(res.Hist) != 2 {
		t.Fatalf("price history rows: got %d, want 2 (no row for an unchanged price)", len(res.Hist))
	}
}

func TestWatchlistRoundtrip(t *testing.T) {
	srv := tempStore(t)
	rec := post(t, srv, "/api/watchlists", `{"name":"thinkpads","query":"thinkpad t14"}`)
	if rec.Code != 200 {
		t.Fatalf("add watchlist: %d %s", rec.Code, rec.Body)
	}
	rec = get(t, srv, "/api/watchlists")
	var res struct {
		Watchlists []Watchlist `json:"watchlists"`
	}
	json.Unmarshal(rec.Body.Bytes(), &res)
	if len(res.Watchlists) != 1 || res.Watchlists[0].Name != "thinkpads" {
		t.Fatalf("watchlist roundtrip: %+v", res.Watchlists)
	}
}

func TestFeedIngest(t *testing.T) {
	feed := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte(`<?xml version="1.0"?><rss version="2.0"><channel>
			<item><title>NAS 4 bay for €149,99</title><link>https://example.test/nas</link><description>uses 4 slots</description><pubDate>x</pubDate></item>
			<item><title>no price here</title><link>https://example.test/np</link><description>d</description></item>
		</channel></rss>`))
	}))
	defer feed.Close()

	srv := tempStore(t)
	post(t, srv, "/api/feeds", `{"url":"`+feed.URL+`"}`)
	rec := post(t, srv, "/api/ingest", ``)
	if rec.Code != 200 {
		t.Fatalf("ingest: %d %s", rec.Code, rec.Body)
	}
	var res struct {
		Ingested map[string]int `json:"ingested"`
		Failed   map[string]string `json:"failed"`
	}
	json.Unmarshal(rec.Body.Bytes(), &res)
	if res.Ingested[feed.URL] != 2 {
		t.Fatalf("ingested: %+v failed %+v", res.Ingested, res.Failed)
	}

	rec = get(t, srv, "/api/deals/1")
	var one struct {
		Deal Deal `json:"deal"`
	}
	json.Unmarshal(rec.Body.Bytes(), &one)
	if one.Deal.PriceCents != 14999 {
		t.Fatalf("rss price extraction: got %d, want 14999", one.Deal.PriceCents)
	}
}

func TestParseAmount(t *testing.T) {
	for in, want := range map[string]int64{
		"1.234,56": 123456,
		"1,234.56": 123456,
		"299":      29900,
		"49,99":    4999,
		"0,99":     99,
	} {
		if got := parseAmount(in); got != want {
			t.Errorf("parseAmount(%q) = %d, want %d", in, got, want)
		}
	}
	if got := extractPrice("something for €12,50 today"); got != 1250 {
		t.Errorf("extractPrice prefix euro: got %d, want 1250", got)
	}
	if got := extractPrice("no money mentioned"); got != 0 {
		t.Errorf("extractPrice no amount: got %d, want 0", got)
	}
}

func TestUIAndHealthz(t *testing.T) {
	srv := tempStore(t)
	rec := get(t, srv, "/healthz")
	if rec.Code != 200 {
		t.Fatalf("healthz: %d", rec.Code)
	}
	rec = get(t, srv, "/")
	if rec.Code != 200 || !strings.Contains(rec.Body.String(), "private-deals") {
		t.Fatalf("ui: %d", rec.Code)
	}
}
