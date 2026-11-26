// private-deals: track products, deals, watchlists and price history in SQLite FTS5,
// then serve a search API and tailnet-only reading surface.
package main

import (
	"context"
	"embed"
	"encoding/csv"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"log"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"
)

//go:embed web/*
var webFiles embed.FS

type server struct {
	store          *Store
	ingester       *ingester
	adminToken     string
	expectedOrigin string
	started        time.Time
}

type errorResponse struct {
	Error string `json:"error"`
}

func main() {
	addr := flag.String("addr", "127.0.0.1:8102", "loopback address to listen on")
	dbPath := flag.String("db", "deals.sqlite", "SQLite database path")
	envFile := flag.String("env-file", "", "optional KEY=VALUE file for provider credentials (never logged)")
	interval := flag.Duration("interval", 6*time.Hour, "automatic ingestion interval; 0 disables the timer")
	ingestOnStart := flag.Bool("ingest-on-start", true, "run one ingestion after startup")
	sourcesFlag := flag.String("sources", strings.Join(defaultSources, ","), "comma-separated ingestion sources")
	rssFlag := flag.String("rss-feeds", "", "comma-separated RSS/Atom feed URLs; PRIVATE_DEALS_RSS_FEEDS is the fallback")
	jsonFlag := flag.String("json-feeds", "", "comma-separated JSON feed URLs; PRIVATE_DEALS_JSON_FEEDS is the fallback")
	scrapeFlag := flag.String("scrape-urls", "", "comma-separated URLs to scrape through providers; PRIVATE_DEALS_SCRAPE_URLS is the fallback")
	queriesFlag := flag.String("search-queries", "", "comma-separated web-search queries; PRIVATE_DEALS_SEARCH_QUERIES is the fallback")
	adminToken := flag.String("admin-token-env", "PRIVATE_DEALS_ADMIN_TOKEN", "environment variable naming the optional write bearer token")
	expectedOrigin := flag.String("origin", "", "expected browser Origin for state-changing requests; empty disables the check")
	flag.Parse()

	if *envFile != "" {
		if err := loadEnvFile(*envFile); err != nil {
			log.Fatalf("private-deals: env file: %v", err)
		}
	}
	store, err := OpenStore(*dbPath)
	if err != nil {
		log.Fatalf("private-deals: open db: %v", err)
	}
	defer store.Close()

	cfg := providerConfig{
		FirecrawlKey:  strings.TrimSpace(os.Getenv("FIRECRAWL_API_KEY")),
		TavilyKey:     strings.TrimSpace(os.Getenv("TAVILY_API_KEY")),
		ContextKey:    firstEnv("CONTEXT_API_KEY", "CONTEXT_DEV_API_KEY"),
		FirecrawlBase: firstEnv("FIRECRAWL_API_BASE", "FIRECRAWL_API_URL"),
		TavilyBase:    firstEnv("TAVILY_API_BASE", "TAVILY_API_URL"),
		ContextBase:   firstEnv("CONTEXT_API_BASE", "CONTEXT_API_URL"),
		SearchQueries: splitCSV(firstNonEmpty(*queriesFlag, os.Getenv("PRIVATE_DEALS_SEARCH_QUERIES"))),
		RSSFeeds:      splitCSV(firstNonEmpty(*rssFlag, os.Getenv("PRIVATE_DEALS_RSS_FEEDS"))),
		JSONFeeds:     splitCSV(firstNonEmpty(*jsonFlag, os.Getenv("PRIVATE_DEALS_JSON_FEEDS"))),
		ScrapeURLs:    splitCSV(firstNonEmpty(*scrapeFlag, os.Getenv("PRIVATE_DEALS_SCRAPE_URLS"))),
		AllowKeyless:  os.Getenv("PRIVATE_DEALS_ALLOW_KEYLESS") == "1",
	}
	ingest := newIngester(store, cfg)
	s := &server{
		store:          store,
		ingester:       ingest,
		adminToken:     strings.TrimSpace(os.Getenv(*adminToken)),
		expectedOrigin: strings.TrimRight(*expectedOrigin, "/"),
		started:        time.Now().UTC(),
	}

	mux := http.NewServeMux()
	mux.HandleFunc("GET /", s.index)
	mux.HandleFunc("GET /index.html", s.index)
	mux.HandleFunc("GET /style.css", s.static("web/style.css", "text/css; charset=utf-8"))
	mux.HandleFunc("GET /app.js", s.static("web/app.js", "text/javascript; charset=utf-8"))
	mux.HandleFunc("GET /favicon.svg", s.static("web/favicon.svg", "image/svg+xml"))
	mux.HandleFunc("GET /api/health", s.health)
	mux.HandleFunc("GET /api/stats", s.stats)
	mux.HandleFunc("GET /api/sources", s.sources)
	mux.HandleFunc("GET /api/deals", s.deals)
	mux.HandleFunc("POST /api/deals", s.createDeal)
	mux.HandleFunc("GET /api/deals/{id}", s.deal)
	mux.HandleFunc("GET /api/products", s.products)
	mux.HandleFunc("POST /api/products", s.createProduct)
	mux.HandleFunc("GET /api/products/{id}", s.product)
	mux.HandleFunc("GET /api/price-history", s.priceHistory)
	mux.HandleFunc("GET /api/watchlists", s.watchlists)
	mux.HandleFunc("POST /api/watchlists", s.createWatchlist)
	mux.HandleFunc("GET /api/watchlists/{id}/items", s.watchlistItems)
	mux.HandleFunc("POST /api/watchlists/{id}/items", s.addWatchlistItem)
	mux.HandleFunc("DELETE /api/watchlists/{id}/items/{product}", s.removeWatchlistItem)
	mux.HandleFunc("GET /api/ingest", s.ingestStatus)
	mux.HandleFunc("POST /api/ingest", s.triggerIngest)
	mux.HandleFunc("GET /api/runs", s.runs)
	mux.HandleFunc("GET /api/export.csv", s.exportCSV)

	sources := splitCSV(*sourcesFlag)
	if *ingestOnStart {
		ingest.startAsync(context.Background(), sources)
	}
	if *interval > 0 {
		go func() {
			ticker := time.NewTicker(*interval)
			defer ticker.Stop()
			for range ticker.C {
				ingest.startAsync(context.Background(), sources)
			}
		}()
	}

	log.Printf("private-deals: listening on %s, db %s, sources %s", *addr, *dbPath, strings.Join(sources, ","))
	log.Printf("private-deals: providers firecrawl=%t tavily=%t context=%t rss_feeds=%d json_feeds=%d scrape_urls=%d", cfg.FirecrawlKey != "", cfg.TavilyKey != "", cfg.ContextKey != "", len(cfg.RSSFeeds), len(cfg.JSONFeeds), len(cfg.ScrapeURLs))
	if err := http.ListenAndServe(*addr, mux); err != nil {
		log.Fatalf("private-deals: %v", err)
	}
}

func loadEnvFile(path string) error {
	raw, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	for number, line := range strings.Split(string(raw), "\n") {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		key, value, ok := strings.Cut(line, "=")
		if !ok || strings.TrimSpace(key) == "" {
			return fmt.Errorf("line %d is not KEY=VALUE", number+1)
		}
		key = strings.TrimSpace(key)
		value = strings.Trim(strings.TrimSpace(value), `"'`)
		if os.Getenv(key) == "" {
			if err := os.Setenv(key, value); err != nil {
				return err
			}
		}
	}
	return nil
}

func firstEnv(keys ...string) string {
	for _, key := range keys {
		if value := strings.TrimSpace(os.Getenv(key)); value != "" {
			return value
		}
	}
	return ""
}

func splitCSV(raw string) []string {
	out := []string{}
	for _, part := range strings.Split(raw, ",") {
		part = strings.TrimSpace(part)
		if part != "" {
			out = append(out, part)
		}
	}
	return out
}

func writeJSON(w http.ResponseWriter, status int, value any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.Header().Set("Cache-Control", "no-store")
	w.WriteHeader(status)
	enc := json.NewEncoder(w)
	enc.SetIndent("", "  ")
	_ = enc.Encode(value)
}

func writeError(w http.ResponseWriter, status int, err error) {
	writeJSON(w, status, errorResponse{Error: err.Error()})
}

func (s *server) index(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != "/" && r.URL.Path != "/index.html" {
		http.NotFound(w, r)
		return
	}
	raw, err := webFiles.ReadFile("web/index.html")
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	_, _ = w.Write(raw)
}

func (s *server) static(path, contentType string) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		raw, err := webFiles.ReadFile(path)
		if err != nil {
			http.NotFound(w, r)
			return
		}
		w.Header().Set("Content-Type", contentType)
		w.Header().Set("Cache-Control", "public, max-age=300")
		_, _ = w.Write(raw)
	}
}

func (s *server) health(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, map[string]any{
		"ok": true, "service": "private-deals", "version": "0.1.0",
		"uptime_seconds": int(time.Since(s.started).Seconds()), "time": time.Now().UTC().Format(time.RFC3339),
	})
}

func (s *server) stats(w http.ResponseWriter, r *http.Request) {
	stats, err := s.store.Stats(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, stats)
}

func (s *server) sources(w http.ResponseWriter, r *http.Request) {
	states, err := s.store.SourceStates(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"configured": defaultSources,
		"states":     states,
		"providers": map[string]bool{
			"firecrawl": s.ingester.cfg.FirecrawlKey != "" || s.ingester.cfg.AllowKeyless,
			"tavily":    s.ingester.cfg.TavilyKey != "",
			"context":   s.ingester.cfg.ContextKey != "",
		},
	})
}

func intQuery(r *http.Request, key string) int {
	value, _ := strconv.Atoi(r.URL.Query().Get(key))
	return value
}

func floatQuery(r *http.Request, key string) float64 {
	value, _ := strconv.ParseFloat(r.URL.Query().Get(key), 64)
	return value
}

func (s *server) deals(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query()
	page, err := s.store.QueryDeals(r.Context(), dealQueryOptions{
		Q: q.Get("q"), Source: q.Get("source"), Merchant: q.Get("merchant"), Category: q.Get("category"),
		Active: q.Get("active") != "0", MinDiscount: floatQuery(r, "min_discount"), MaxPrice: floatQuery(r, "max_price"),
		WatchlistID: int64(intQuery(r, "watchlist")), Limit: intQuery(r, "limit"), Offset: intQuery(r, "offset"),
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, page)
}

func (s *server) deal(w http.ResponseWriter, r *http.Request) {
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("deal id must be numeric"))
		return
	}
	deal, history, err := s.store.GetDeal(r.Context(), id)
	if err != nil {
		writeError(w, http.StatusNotFound, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"deal": deal, "price_history": history})
}

func (s *server) createDeal(w http.ResponseWriter, r *http.Request) {
	if !s.writeAllowed(w, r) {
		return
	}
	var input dealInput
	if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	id, created, err := s.store.UpsertDeal(r.Context(), input)
	if err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	writeJSON(w, map[bool]int{true: http.StatusCreated, false: http.StatusOK}[created], map[string]any{"id": id, "created": created})
}

func (s *server) products(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query()
	page, err := s.store.QueryProducts(r.Context(), productQueryOptions{
		Q: q.Get("q"), Source: q.Get("source"), Merchant: q.Get("merchant"), Category: q.Get("category"),
		Active: q.Get("active") != "0", Limit: intQuery(r, "limit"), Offset: intQuery(r, "offset"),
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, page)
}

func (s *server) product(w http.ResponseWriter, r *http.Request) {
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("product id must be numeric"))
		return
	}
	product, history, deals, err := s.store.GetProduct(r.Context(), id)
	if err != nil {
		writeError(w, http.StatusNotFound, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"product": product, "price_history": history, "deals": deals})
}

func (s *server) createProduct(w http.ResponseWriter, r *http.Request) {
	if !s.writeAllowed(w, r) {
		return
	}
	var input productInput
	if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	id, created, err := s.store.UpsertProduct(r.Context(), input)
	if err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	writeJSON(w, map[bool]int{true: http.StatusCreated, false: http.StatusOK}[created], map[string]any{"id": id, "created": created})
}

func (s *server) priceHistory(w http.ResponseWriter, r *http.Request) {
	var productID, dealID *int64
	if raw := r.URL.Query().Get("product_id"); raw != "" {
		if id, err := strconv.ParseInt(raw, 10, 64); err == nil {
			productID = &id
		}
	}
	if raw := r.URL.Query().Get("deal_id"); raw != "" {
		if id, err := strconv.ParseInt(raw, 10, 64); err == nil {
			dealID = &id
		}
	}
	points, err := s.store.PriceHistory(r.Context(), productID, dealID, intQuery(r, "limit"))
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": points, "total": len(points)})
}

func (s *server) watchlists(w http.ResponseWriter, r *http.Request) {
	lists, err := s.store.Watchlists(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": lists, "total": len(lists)})
}

func (s *server) createWatchlist(w http.ResponseWriter, r *http.Request) {
	if !s.writeAllowed(w, r) {
		return
	}
	var body struct {
		Name        string `json:"name"`
		Description string `json:"description"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	id, err := s.store.CreateWatchlist(r.Context(), body.Name, body.Description)
	if err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	writeJSON(w, http.StatusCreated, map[string]any{"id": id})
}

func (s *server) watchlistItems(w http.ResponseWriter, r *http.Request) {
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("watchlist id must be numeric"))
		return
	}
	items, err := s.store.WatchlistItems(r.Context(), id)
	if err != nil {
		writeError(w, http.StatusNotFound, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": items, "total": len(items)})
}

func (s *server) addWatchlistItem(w http.ResponseWriter, r *http.Request) {
	if !s.writeAllowed(w, r) {
		return
	}
	watchlistID, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("watchlist id must be numeric"))
		return
	}
	var body struct {
		ProductID int64  `json:"product_id"`
		DealID    int64  `json:"deal_id"`
		Notes     string `json:"notes"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	if body.ProductID == 0 && body.DealID != 0 {
		deal, _, err := s.store.GetDeal(r.Context(), body.DealID)
		if err == nil && deal.ProductID != nil {
			body.ProductID = *deal.ProductID
		}
	}
	if body.ProductID == 0 {
		writeError(w, http.StatusBadRequest, errors.New("product_id is required (or a deal already linked to a product)"))
		return
	}
	if err := s.store.AddWatchlistItem(r.Context(), watchlistID, body.ProductID, body.Notes); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	writeJSON(w, http.StatusCreated, map[string]any{"ok": true})
}

func (s *server) removeWatchlistItem(w http.ResponseWriter, r *http.Request) {
	if !s.writeAllowed(w, r) {
		return
	}
	watchlistID, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("watchlist id must be numeric"))
		return
	}
	productID, err := strconv.ParseInt(r.PathValue("product"), 10, 64)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("product id must be numeric"))
		return
	}
	if err := s.store.RemoveWatchlistItem(r.Context(), watchlistID, productID); err != nil {
		writeError(w, http.StatusNotFound, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"ok": true})
}

func (s *server) ingestStatus(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, s.ingester.status())
}

func (s *server) triggerIngest(w http.ResponseWriter, r *http.Request) {
	if !s.writeAllowed(w, r) {
		return
	}
	var body struct {
		Sources []string `json:"sources"`
	}
	if r.Body != nil {
		_ = json.NewDecoder(r.Body).Decode(&body)
	}
	started, status := s.ingester.startAsync(context.Background(), body.Sources)
	if started {
		writeJSON(w, http.StatusAccepted, status)
		return
	}
	writeJSON(w, http.StatusConflict, status)
}

func (s *server) runs(w http.ResponseWriter, r *http.Request) {
	runs, err := s.store.RecentRuns(r.Context(), intQuery(r, "limit"))
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"runs": runs})
}

func (s *server) writeAllowed(w http.ResponseWriter, r *http.Request) bool {
	if origin := strings.TrimRight(r.Header.Get("Origin"), "/"); origin != "" && s.expectedOrigin != "" && origin != s.expectedOrigin {
		writeError(w, http.StatusForbidden, errors.New("origin is not the configured tailnet origin"))
		return false
	}
	if s.adminToken == "" {
		return true
	}
	if strings.TrimSpace(r.Header.Get("Authorization")) != "Bearer "+s.adminToken {
		w.Header().Set("WWW-Authenticate", `Bearer realm="private-deals"`)
		writeError(w, http.StatusUnauthorized, errors.New("bearer token required"))
		return false
	}
	return true
}

func (s *server) exportCSV(w http.ResponseWriter, r *http.Request) {
	page, err := s.store.QueryDeals(r.Context(), dealQueryOptions{Active: true, Limit: 200})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	w.Header().Set("Content-Type", "text/csv; charset=utf-8")
	w.Header().Set("Content-Disposition", "attachment; filename=private-deals.csv")
	writer := csv.NewWriter(w)
	_ = writer.Write([]string{"id", "source", "merchant", "title", "category", "price", "list_price", "discount_pct", "currency", "expires_at", "last_seen", "url"})
	for _, deal := range page.Items {
		_ = writer.Write([]string{
			strconv.FormatInt(deal.ID, 10), deal.Source, deal.Merchant, deal.Title, deal.Category,
			formatMoney(deal.Price), formatMoney(deal.ListPrice), strconv.FormatFloat(deal.DiscountPct, 'f', 1, 64), deal.Currency, deal.ExpiresAt, deal.LastSeen.Format(time.RFC3339), deal.URL,
		})
	}
	writer.Flush()
}

func formatMoney(value *float64) string {
	if value == nil {
		return ""
	}
	return strconv.FormatFloat(*value, 'f', 2, 64)
}
