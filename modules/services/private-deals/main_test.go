package main

import (
	"context"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"strings"
	"testing"
)

func testStore(t *testing.T) *Store {
	t.Helper()
	store, err := OpenStore(filepath.Join(t.TempDir(), "deals.sqlite"))
	if err != nil {
		t.Fatalf("OpenStore: %v", err)
	}
	t.Cleanup(func() { _ = store.Close() })
	return store
}

func TestCanonicalURLStripsTracking(t *testing.T) {
	got := canonicalURL("HTTPS://WWW.Example.com/deal/42/?utm_source=x&aff=abc&size=8#fragment")
	want := "https://example.com/deal/42?size=8"
	if got != want {
		t.Fatalf("canonicalURL got %q want %q", got, want)
	}
}

func TestExtractPricing(t *testing.T) {
	price, list, discount := extractPricing("ThinkPad X1 now €799, statt €999 — 20% off")
	if price == nil || *price != 799 {
		t.Fatalf("price %#v, want 799", price)
	}
	if list == nil || *list != 999 {
		t.Fatalf("list %#v, want 999", list)
	}
	if discount != 20 {
		t.Fatalf("discount %v, want 20", discount)
	}
}

func TestParseRSSFeed(t *testing.T) {
	items, err := parseFeed([]byte(`<?xml version="1.0"?><rss version="2.0"><channel><item><title>SSD sale €89</title><link>https://shop.example/deal/1?utm_source=x</link><pubDate>Thu, 26 Nov 2026 10:00:00 +0000</pubDate><description>Fast NVMe SSD deal</description><category>computing</category></item></channel></rss>`))
	if err != nil {
		t.Fatalf("parseFeed: %v", err)
	}
	if len(items) != 1 || items[0].Title != "SSD sale €89" || items[0].Categories[0] != "computing" {
		t.Fatalf("unexpected items: %#v", items)
	}
}

func TestParseAtomFeed(t *testing.T) {
	items, err := parseFeed([]byte(`<feed xmlns="http://www.w3.org/2005/Atom"><entry><title>Headphones deal</title><link rel="alternate" href="https://audio.example/deals/9"/><summary>Now £49, was £99</summary><updated>2026-11-26T10:00:00Z</updated><category term="audio"/></entry></feed>`))
	if err != nil {
		t.Fatalf("parseFeed atom: %v", err)
	}
	if len(items) != 1 || items[0].Link != "https://audio.example/deals/9" || items[0].Categories[0] != "audio" {
		t.Fatalf("unexpected atom items: %#v", items)
	}
}

func TestDealFromMap(t *testing.T) {
	payload := map[string]any{
		"title": "NVMe SSD", "url": "https://shop.example/p/1", "merchant": "Shop", "price": "€89.99", "list_price": "129.99", "tags": []any{"ssd", "nvme"},
	}
	deal, ok := dealFromMap(payload)
	if !ok {
		t.Fatal("dealFromMap not ok")
	}
	if deal.Price == nil || *deal.Price != 89.99 {
		t.Fatalf("price %#v", deal.Price)
	}
	if len(deal.Tags) != 3 { // json + ssd + nvme
		t.Fatalf("tags %#v", deal.Tags)
	}
}

func TestStoreDealProductFTSPriceHistoryAndWatchlist(t *testing.T) {
	ctx := context.Background()
	store := testStore(t)

	price := 799.0
	list := 999.0
	productID, created, err := store.UpsertProduct(ctx, productInput{
		URL: "https://shop.example/products/x1?utm_source=newsletter", Source: "manual", Merchant: "Shop", Brand: "Example", Name: "Example X1 Laptop",
		Category: "computing", Currency: "EUR", CurrentPrice: &price, ListPrice: &list,
	})
	if err != nil || !created {
		t.Fatalf("UpsertProduct created=%v err=%v", created, err)
	}

	dealID, created, err := store.UpsertDeal(ctx, dealInput{
		URL: "https://shop.example/products/x1", Source: "rss", Merchant: "Shop", Title: "Example X1 Laptop deal", Description: "Now €799, was €999",
		Price: &price, ListPrice: &list, Tags: []string{"laptop"},
	})
	if err != nil || !created {
		t.Fatalf("UpsertDeal created=%v err=%v", created, err)
	}
	deal, history, err := store.GetDeal(ctx, dealID)
	if err != nil {
		t.Fatalf("GetDeal: %v", err)
	}
	if deal.ProductID == nil || *deal.ProductID != productID {
		t.Fatalf("deal product link %#v, want %d", deal.ProductID, productID)
	}
	if deal.DiscountPct != 20 {
		t.Fatalf("discount %v, want 20", deal.DiscountPct)
	}
	if len(history) == 0 {
		t.Fatal("expected price history")
	}

	page, err := store.QueryDeals(ctx, dealQueryOptions{Q: "laptop", Active: true, Limit: 10})
	if err != nil {
		t.Fatalf("QueryDeals: %v", err)
	}
	if page.Total != 1 || !strings.Contains(page.Items[0].Snippet, "<mark>") {
		t.Fatalf("fts page %#v", page)
	}

	watchlistID, err := store.CreateWatchlist(ctx, "Office upgrade", "machines")
	if err != nil {
		t.Fatalf("CreateWatchlist: %v", err)
	}
	if err := store.AddWatchlistItem(ctx, watchlistID, productID, "buy under 750"); err != nil {
		t.Fatalf("AddWatchlistItem: %v", err)
	}
	items, err := store.WatchlistItems(ctx, watchlistID)
	if err != nil || len(items) != 1 || items[0].Product.Name != "Example X1 Laptop" {
		t.Fatalf("watchlist items %#v err=%v", items, err)
	}

	product, productHistory, linkedDeals, err := store.GetProduct(ctx, productID)
	if err != nil {
		t.Fatalf("GetProduct: %v", err)
	}
	if product.DiscountPct != 20 || len(productHistory) == 0 || len(linkedDeals) != 1 {
		t.Fatalf("product %#v history=%d deals=%d", product, len(productHistory), len(linkedDeals))
	}
	stats, err := store.Stats(ctx)
	if err != nil {
		t.Fatalf("Stats: %v", err)
	}
	if stats["deals"] != 1 || stats["products"] != 1 || stats["watchlists"] != 1 {
		t.Fatalf("stats %#v", stats)
	}
}

func TestDealDedupesAndIncrementsSeenCount(t *testing.T) {
	ctx := context.Background()
	store := testStore(t)
	input := dealInput{Source: "manual", Merchant: "Shop", Title: "Noise cancelling headphones", Description: "€99 instead of €149"}
	first, created, err := store.UpsertDeal(ctx, input)
	if err != nil || !created {
		t.Fatalf("first created=%v err=%v", created, err)
	}
	second, created, err := store.UpsertDeal(ctx, input)
	if err != nil {
		t.Fatalf("second: %v", err)
	}
	if created || second != first {
		t.Fatalf("second id=%d created=%v, want same existing id %d", second, created, first)
	}
	deal, _, err := store.GetDeal(ctx, first)
	if err != nil {
		t.Fatalf("GetDeal: %v", err)
	}
	if deal.SeenCount != 2 {
		t.Fatalf("seen count %d, want 2", deal.SeenCount)
	}
}

func TestRunAndSourceState(t *testing.T) {
	ctx := context.Background()
	store := testStore(t)
	id, err := store.BeginRun(ctx, "rss")
	if err != nil {
		t.Fatalf("BeginRun: %v", err)
	}
	if err := store.FinishRun(ctx, id, "rss", "ok", 4, 2, 2, ""); err != nil {
		t.Fatalf("FinishRun: %v", err)
	}
	states, err := store.SourceStates(ctx)
	if err != nil || len(states) != 1 || states[0].TotalFetched != 4 {
		t.Fatalf("states %#v err=%v", states, err)
	}
	runs, err := store.RecentRuns(ctx, 10)
	if err != nil || len(runs) != 1 || runs[0].Status != "ok" {
		t.Fatalf("runs %#v err=%v", runs, err)
	}
}

func TestProviderSearchAndScrapeClients(t *testing.T) {
	t.Helper()
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("content-type", "application/json")
		switch r.URL.Path {
		case "/search":
			_, _ = w.Write([]byte(`{"results":[{"title":"Laptop deal now €799 was €999","url":"https://shop.example/laptop-deal","content":"20% off laptop coupon","score":0.9}]}`))
		case "/web/search":
			_, _ = w.Write([]byte(`{"results":[{"title":"SSD sale €89","url":"https://shop.example/ssd","description":"NVMe SSD deal"}]}`))
		case "/extract":
			_, _ = w.Write([]byte(`{"results":[{"url":"https://shop.example/laptop-deal","raw_content":"# Laptop deal\nNow €799 was €999"}]}`))
		case "/scrape":
			_, _ = w.Write([]byte(`{"success":true,"data":{"markdown":"# Firecrawl deal\nNow €49 was €99"}}`))
		case "/web/scrape/markdown":
			w.Header().Set("content-type", "text/markdown")
			_, _ = w.Write([]byte("# Context deal\nNow €25 was €50"))
		default:
			http.NotFound(w, r)
		}
	}))
	defer server.Close()

	store := testStore(t)
	ing := newIngester(store, providerConfig{
		TavilyKey: "test", ContextKey: "test", FirecrawlKey: "test",
		TavilyBase: server.URL, ContextBase: server.URL, FirecrawlBase: server.URL,
	})
	tavily, err := ing.tavilySearch(context.Background(), "laptop deal")
	if err != nil || len(tavily) != 1 {
		t.Fatalf("tavilySearch len=%d err=%v", len(tavily), err)
	}
	if tavily[0].Price == nil || *tavily[0].Price != 799 || tavily[0].Source != "tavily-search" {
		t.Fatalf("unexpected tavily deal %#v", tavily[0])
	}
	contextDeals, err := ing.contextSearch(context.Background(), "ssd deal")
	if err != nil || len(contextDeals) != 1 {
		t.Fatalf("contextSearch len=%d err=%v", len(contextDeals), err)
	}
	text, err := ing.tavilyExtract(context.Background(), "https://shop.example/laptop-deal")
	if err != nil || !strings.Contains(text, "Laptop deal") {
		t.Fatalf("tavilyExtract %q err=%v", text, err)
	}
	text, err = ing.firecrawlScrape(context.Background(), "https://example.com/deal")
	if err != nil || !strings.Contains(text, "Firecrawl deal") {
		t.Fatalf("firecrawlScrape %q err=%v", text, err)
	}
	text, err = ing.contextScrape(context.Background(), "https://example.com/deal")
	if err != nil || !strings.Contains(text, "Context deal") {
		t.Fatalf("contextScrape %q err=%v", text, err)
	}
}
