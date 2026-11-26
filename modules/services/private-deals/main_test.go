package main

import (
	"context"
	"encoding/json"
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

func TestWatchlistAlertsAreDedupedAndNotifyNtfy(t *testing.T) {
	ctx := context.Background()
	store := testStore(t)
	current := 999.0
	target := 850.0
	productID, _, err := store.UpsertProduct(ctx, productInput{Source: "manual", Merchant: "Shop", Name: "Example Laptop", URL: "https://shop.example/x1", CurrentPrice: &current, TargetPrice: &target})
	if err != nil {
		t.Fatalf("UpsertProduct: %v", err)
	}
	watchlistID, err := store.CreateWatchlist(ctx, "Hardware", "")
	if err != nil {
		t.Fatalf("CreateWatchlist: %v", err)
	}
	if err := store.AddWatchlistItem(ctx, watchlistID, productID, ""); err != nil {
		t.Fatalf("AddWatchlistItem: %v", err)
	}
	price := 799.0
	if _, _, err := store.UpsertDeal(ctx, dealInput{Source: "manual", Merchant: "Shop", Title: "Example Laptop sale", URL: "https://shop.example/x1", Price: &price}); err != nil {
		t.Fatalf("UpsertDeal: %v", err)
	}

	posts := 0
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		posts++
		if r.Header.Get("Title") == "" {
			t.Error("missing ntfy title")
		}
		w.WriteHeader(http.StatusOK)
	}))
	defer server.Close()

	manager := newAlertManager(store, server.URL)
	first, err := manager.evaluate(ctx, true)
	if err != nil {
		t.Fatalf("first evaluate: %v", err)
	}
	if first.Matched != 1 || first.Created != 1 || first.Notified != 1 || first.Failed != 0 {
		t.Fatalf("first summary %#v", first)
	}
	second, err := manager.evaluate(ctx, true)
	if err != nil {
		t.Fatalf("second evaluate: %v", err)
	}
	if second.Matched != 1 || second.Created != 0 || second.Existing != 1 || second.Notified != 0 {
		t.Fatalf("second summary %#v", second)
	}
	if posts != 1 {
		t.Fatalf("posts %d, want deduped single notification", posts)
	}

	price = 749.0
	if _, _, err := store.UpsertDeal(ctx, dealInput{Source: "manual", Merchant: "Shop", Title: "Example Laptop sale", URL: "https://shop.example/x1", Price: &price}); err != nil {
		t.Fatalf("price-change UpsertDeal: %v", err)
	}
	third, err := manager.evaluate(ctx, true)
	if err != nil {
		t.Fatalf("third evaluate: %v", err)
	}
	if third.Created != 1 || third.Notified != 1 || posts != 2 {
		t.Fatalf("third summary %#v posts=%d, want new price notification", third, posts)
	}
	alerts, err := store.ListAlerts(ctx, 10, "")
	if err != nil || len(alerts) != 2 {
		t.Fatalf("alerts %#v err=%v", alerts, err)
	}
	if alerts[0].Reason != "target-price" || alerts[0].Status != "sent" {
		t.Fatalf("unexpected alert %#v", alerts[0])
	}
}

func TestBatchDealsEndpointAccountsForOutcomes(t *testing.T) {
	store := testStore(t)
	s := &server{store: store, alerts: newAlertManager(store, "")}
	body := `{"deals":[
		{"title":"SSD sale","source":"manual","merchant":"Shop","price":89},
		{"title":"SSD sale","source":"manual","merchant":"Shop","price":89},
		{"title":"SSD sale","source":"manual","merchant":"Shop","price":79},
		{}
	]}`
	req := httptest.NewRequest(http.MethodPost, "/api/deals/batch", strings.NewReader(body))
	recorder := httptest.NewRecorder()
	s.batchDeals(recorder, req)
	if recorder.Code != http.StatusCreated {
		t.Fatalf("status %d body %s", recorder.Code, recorder.Body.String())
	}
	var response batchDealsResponse
	if err := json.NewDecoder(recorder.Body).Decode(&response); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if response.Created != 1 || response.Updated != 1 || response.Skipped != 2 || response.Failed != 0 || response.Total != 4 {
		t.Fatalf("response %#v", response)
	}
}

func seedAnalytics(t *testing.T, store *Store) (dealA, dealB, dealC, productA, productB int64) {
	t.Helper()
	ctx := context.Background()

	target := 800.0
	a, _, err := store.UpsertProduct(ctx, productInput{
		URL: "https://shop.example/laptop", Source: "manual", Merchant: "ShopA", Name: "Example Laptop",
		Category: "computing", Currency: "EUR", TargetPrice: &target,
	})
	if err != nil {
		t.Fatalf("UpsertProduct a: %v", err)
	}
	b, _, err := store.UpsertProduct(ctx, productInput{
		URL: "https://shop.example/headset", Source: "manual", Merchant: "ShopB", Name: "Example Headset",
		Category: "audio", Currency: "EUR",
	})
	if err != nil {
		t.Fatalf("UpsertProduct b: %v", err)
	}
	for _, price := range []float64{999, 899, 799} {
		value := price
		if err := store.RecordPrice(ctx, &a, nil, &value, nil, 0, "EUR", "test", ""); err != nil {
			t.Fatalf("RecordPrice a %v: %v", price, err)
		}
	}
	for _, price := range []float64{100, 120} {
		value := price
		if err := store.RecordPrice(ctx, &b, nil, &value, nil, 0, "EUR", "test", ""); err != nil {
			t.Fatalf("RecordPrice b %v: %v", price, err)
		}
	}

	dealA, _, err = store.UpsertDeal(ctx, dealInput{
		URL: "https://shop.example/laptop-deal", Source: "rss", Merchant: "ShopA", Title: "Example Laptop deal",
		Category: "computing", Price: floatPtrOf(799), ListPrice: floatPtrOf(999),
	})
	if err != nil {
		t.Fatalf("UpsertDeal a: %v", err)
	}
	dealB, _, err = store.UpsertDeal(ctx, dealInput{
		URL: "https://shop.example/headset-deal", Source: "rss", Merchant: "ShopB", Title: "Example Headset deal",
		Category: "audio", Price: floatPtrOf(45), ListPrice: floatPtrOf(50),
	})
	if err != nil {
		t.Fatalf("UpsertDeal b: %v", err)
	}
	dealC, _, err = store.UpsertDeal(ctx, dealInput{
		URL: "https://shop.example/speaker-deal", Source: "rss", Merchant: "ShopA", Title: "Example Speaker deal",
		Category: "audio", Price: floatPtrOf(40), ListPrice: floatPtrOf(50),
	})
	if err != nil {
		t.Fatalf("UpsertDeal c: %v", err)
	}
	return dealA, dealB, dealC, a, b
}

func floatPtrOf(value float64) *float64 { return &value }

func TestAnalyticsRanksDiscountsDropsAndBreakdowns(t *testing.T) {
	ctx := context.Background()
	store := testStore(t)
	dealA, dealB, dealC, productA, productB := seedAnalytics(t, store)

	report, err := store.Analytics(ctx, analyticsQuery{Window: 30, Limit: 5})
	if err != nil {
		t.Fatalf("Analytics: %v", err)
	}

	if len(report.TopDiscounts) != 3 {
		t.Fatalf("top discounts %#v, want 3 active discounted deals", report.TopDiscounts)
	}
	if report.TopDiscounts[0].ID != dealC || report.TopDiscounts[2].ID != dealB {
		t.Fatalf("top discount order %#v, want cheapest of the tied lead then the smallest", report.TopDiscounts)
	}
	if report.TopDiscounts[0].DiscountPct <= report.TopDiscounts[2].DiscountPct {
		t.Fatalf("discounts not descending: %#v", report.TopDiscounts)
	}

	if len(report.Merchants) != 2 || report.Merchants[0].Name != "ShopA" || report.Merchants[0].Deals != 2 {
		t.Fatalf("merchants %#v, want ShopA leading with two deals", report.Merchants)
	}
	if len(report.Categories) != 2 || report.Categories[0].Name != "audio" || report.Categories[0].Deals != 2 {
		t.Fatalf("categories %#v, want audio leading", report.Categories)
	}

	if len(report.BiggestDrops) != 1 {
		t.Fatalf("drops %#v, want only the product that fell", report.BiggestDrops)
	}
	drop := report.BiggestDrops[0]
	if drop.ProductID != productA || drop.DropPct != 20 || drop.From != 999 || drop.To != 799 || drop.Points != 3 {
		t.Fatalf("drop %#v, want %d from 999 to 799 (20%%, 3 points)", drop, productA)
	}
	if drop.TargetPrice == nil || *drop.TargetPrice != 800 {
		t.Fatalf("drop target %#v, want 800", drop.TargetPrice)
	}

	history := report.History
	if history.Fell != 1 || history.Rose != 1 || history.Flat != 0 {
		t.Fatalf("movement counts %#v, want one falling and one rising product", history)
	}
	if history.Points < 8 || history.Products < 2 {
		t.Fatalf("history totals %#v, want at least the seeded points", history)
	}
	if history.Currency != "EUR" || len(history.Daily) == 0 {
		t.Fatalf("history shape %#v, want EUR with daily buckets", history)
	}
	if history.MinPrice == nil || *history.MinPrice > 40 || history.MaxPrice == nil || *history.MaxPrice < 999 {
		t.Fatalf("price range %#v", history)
	}
	_ = dealA
	_ = dealB
	_ = productB
}

func TestAnalyticsWindowAndLimitAreClamped(t *testing.T) {
	ctx := context.Background()
	store := testStore(t)
	seedAnalytics(t, store)

	wide, err := store.Analytics(ctx, analyticsQuery{Window: 9999, Limit: 9999})
	if err != nil {
		t.Fatalf("Analytics wide: %v", err)
	}
	if wide.WindowDays != 365 {
		t.Fatalf("window %d, want 365", wide.WindowDays)
	}

	narrow, err := store.Analytics(ctx, analyticsQuery{Window: 1, Limit: 1})
	if err != nil {
		t.Fatalf("Analytics narrow: %v", err)
	}
	if narrow.WindowDays != 1 || len(narrow.TopDiscounts) != 1 {
		t.Fatalf("narrow report %#v, want one row", narrow)
	}
	if len(narrow.History.Daily) > 1 {
		t.Fatalf("daily buckets %#v, want at most today inside a one-day window", narrow.History.Daily)
	}
}

func TestAnalyticsEndpointAnswersJSONOnAnEmptyIndex(t *testing.T) {
	store := testStore(t)
	s := &server{store: store}

	rec := httptest.NewRecorder()
	s.analytics(rec, httptest.NewRequest(http.MethodGet, "/api/analytics", nil))
	if rec.Code != http.StatusOK {
		t.Fatalf("status %d: %s", rec.Code, rec.Body.String())
	}
	var report analyticsReport
	if err := json.Unmarshal(rec.Body.Bytes(), &report); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if report.WindowDays != 30 || report.History.WindowDays != 30 {
		t.Fatalf("defaults %#v, want a 30-day window", report)
	}
	for _, fragment := range []string{`"top_discounts": []`, `"biggest_drops": []`, `"merchants": []`, `"categories": []`, `"daily": []`} {
		if !strings.Contains(rec.Body.String(), fragment) {
			t.Fatalf("empty index should answer %s, got %s", fragment, rec.Body.String())
		}
	}

	rec = httptest.NewRecorder()
	s.analytics(rec, httptest.NewRequest(http.MethodGet, "/api/analytics?window=7&limit=2", nil))
	if err := json.Unmarshal(rec.Body.Bytes(), &report); err != nil {
		t.Fatalf("decode second: %v", err)
	}
	if report.WindowDays != 7 {
		t.Fatalf("window %d, want 7", report.WindowDays)
	}
}
