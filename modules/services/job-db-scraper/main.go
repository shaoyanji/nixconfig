// job-db-scraper: scrape, deduplicate and index job postings into SQLite FTS5,
// then serve a search API and a tailnet-only reading surface.
package main

import (
	"context"
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

	"embed"
)

//go:embed web/*
var webFiles embed.FS

type server struct {
	store          *Store
	scraper        *scraper
	alerts         *alertManager
	adminToken     string
	expectedOrigin string
	started        time.Time
}

type errorResponse struct {
	Error string `json:"error"`
}

func main() {
	addr := flag.String("addr", "127.0.0.1:8101", "loopback address to listen on")
	dbPath := flag.String("db", "jobs.sqlite", "SQLite database path")
	envFile := flag.String("env-file", "", "optional KEY=VALUE file for provider credentials (never logged)")
	interval := flag.Duration("interval", 6*time.Hour, "automatic scrape interval; 0 disables the timer")
	scrapeOnStart := flag.Bool("scrape-on-start", true, "run one scrape after startup")
	sourcesFlag := flag.String("sources", strings.Join(defaultSources, ","), "comma-separated scraper sources")
	enrich := flag.Bool("enrich", false, "enrich thin descriptions through Tavily, Firecrawl or Context when credentials exist")
	maxEnrich := flag.Int("max-enrich", 4, "maximum enriched postings per source run; provider calls cost credits")
	ntfyURL := flag.String("ntfy-url", "", "ntfy/webhook URL for high-score posting alerts; JOB_DB_NTFY_URL is the fallback")
	minAlertScore := flag.Int("min-alert-score", 80, "minimum deterministic role-match score that triggers an ntfy alert")
	adminToken := flag.String("admin-token-env", "JOB_DB_ADMIN_TOKEN", "environment variable naming the optional write bearer token")
	expectedOrigin := flag.String("origin", "", "expected browser Origin for state-changing requests; empty disables the check")
	flag.Parse()

	if *envFile != "" {
		if err := loadEnvFile(*envFile); err != nil {
			log.Fatalf("job-db-scraper: env file: %v", err)
		}
	}
	store, err := OpenStore(*dbPath)
	if err != nil {
		log.Fatalf("job-db-scraper: open db: %v", err)
	}
	defer store.Close()

	queries := splitCSVEnv("JOB_DB_SEARCH_QUERIES")
	cfg := providerConfig{
		FirecrawlKey:  strings.TrimSpace(os.Getenv("FIRECRAWL_API_KEY")),
		TavilyKey:     strings.TrimSpace(os.Getenv("TAVILY_API_KEY")),
		ContextKey:    firstEnv("CONTEXT_API_KEY", "CONTEXT_DEV_API_KEY"),
		FirecrawlBase: strings.TrimSpace(os.Getenv("FIRECRAWL_API_BASE")),
		TavilyBase:    strings.TrimSpace(os.Getenv("TAVILY_API_BASE")),
		ContextBase:   strings.TrimSpace(os.Getenv("CONTEXT_API_BASE")),
		SearchQueries: queries,
		Enrich:        *enrich,
		MaxEnrich:     *maxEnrich,
		AllowKeyless:  os.Getenv("JOB_DB_ALLOW_KEYLESS") == "1",
	}
	sc := newScraper(store, cfg)
	alertURL := *ntfyURL
	if alertURL == "" {
		alertURL = os.Getenv("JOB_DB_NTFY_URL")
	}
	if raw := os.Getenv("JOB_DB_MIN_ALERT_SCORE"); raw != "" && *minAlertScore == 80 {
		if parsed, err := strconv.Atoi(raw); err == nil {
			*minAlertScore = parsed
		}
	}
	alerts := newAlertManager(store, alertURL, *minAlertScore)
	sc.alerts = alerts
	s := &server{
		store:          store,
		scraper:        sc,
		alerts:         alerts,
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
	mux.HandleFunc("GET /api/analytics", s.analytics)
	mux.HandleFunc("GET /api/sources", s.sources)
	mux.HandleFunc("GET /api/postings", s.postings)
	mux.HandleFunc("GET /api/postings/{id}", s.posting)
	mux.HandleFunc("POST /api/postings", s.createPosting)
	mux.HandleFunc("POST /api/postings/batch", s.batchPostings)
	mux.HandleFunc("GET /api/scrape", s.scrapeStatus)
	mux.HandleFunc("POST /api/scrape", s.triggerScrape)
	mux.HandleFunc("GET /api/runs", s.runs)
	mux.HandleFunc("GET /api/export.csv", s.exportCSV)
	mux.HandleFunc("GET /api/alerts", s.alertList)
	mux.HandleFunc("POST /api/alerts/evaluate", s.evaluateAlerts)

	sources := splitCSV(*sourcesFlag)
	if *scrapeOnStart {
		sc.startAsync(context.Background(), sources)
	}
	if *interval > 0 {
		go func() {
			ticker := time.NewTicker(*interval)
			defer ticker.Stop()
			for range ticker.C {
				sc.startAsync(context.Background(), sources)
			}
		}()
	}

	log.Printf("job-db-scraper: listening on %s, db %s, sources %s", *addr, *dbPath, strings.Join(sources, ","))
	log.Printf("job-db-scraper: providers firecrawl=%t tavily=%t context=%t enrichment=%t alerts=%t min_score=%d", cfg.FirecrawlKey != "", cfg.TavilyKey != "", cfg.ContextKey != "", cfg.Enrich, alerts.enabled(), alerts.minScore)
	if err := http.ListenAndServe(*addr, mux); err != nil {
		log.Fatalf("job-db-scraper: %v", err)
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

func splitCSVEnv(key string) []string {
	return splitCSV(os.Getenv(key))
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
	s.static("web/index.html", "text/html; charset=utf-8")(w, r)
}

func (s *server) static(path, contentType string) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		raw, err := webFiles.ReadFile(path)
		if err != nil {
			http.NotFound(w, r)
			return
		}
		w.Header().Set("Content-Type", contentType)
		w.Header().Set("Cache-Control", "no-store")
		_, _ = w.Write(raw)
	}
}

func (s *server) health(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, map[string]any{
		"ok": true, "service": "job-db-scraper", "version": "0.1.0",
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
			"firecrawl":  s.scraper.cfg.FirecrawlKey != "" || s.scraper.cfg.AllowKeyless,
			"tavily":     s.scraper.cfg.TavilyKey != "",
			"context":    s.scraper.cfg.ContextKey != "",
			"enrichment": s.scraper.cfg.Enrich,
		},
	})
}

func (s *server) postings(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query()
	limit, _ := strconv.Atoi(q.Get("limit"))
	offset, _ := strconv.Atoi(q.Get("offset"))
	days, _ := strconv.Atoi(q.Get("days"))
	page, err := s.store.QueryPostings(r.Context(), queryOptions{
		Q: q.Get("q"), Source: q.Get("source"), Company: q.Get("company"), Location: q.Get("location"), Lane: q.Get("lane"),
		Remote: q.Get("remote") == "1" || q.Get("remote") == "true", Active: q.Get("active") != "0",
		Days: days, Limit: limit, Offset: offset, Sort: q.Get("sort"),
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, page)
}

func (s *server) analytics(w http.ResponseWriter, r *http.Request) {
	days, _ := strconv.Atoi(r.URL.Query().Get("days"))
	limit, _ := strconv.Atoi(r.URL.Query().Get("limit"))
	report, err := s.store.Analytics(r.Context(), days, limit)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, report)
}

func (s *server) posting(w http.ResponseWriter, r *http.Request) {
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("posting id must be numeric"))
		return
	}
	p, similar, err := s.store.GetPosting(r.Context(), id)
	if err != nil {
		writeError(w, http.StatusNotFound, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"posting": p, "similar": similar})
}

func (s *server) runs(w http.ResponseWriter, r *http.Request) {
	limit, _ := strconv.Atoi(r.URL.Query().Get("limit"))
	runs, err := s.store.RecentRuns(r.Context(), limit)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"runs": runs})
}

func (s *server) scrapeStatus(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, s.scraper.status())
}

func (s *server) triggerScrape(w http.ResponseWriter, r *http.Request) {
	if !s.writeAllowed(w, r) {
		return
	}
	var body struct {
		Sources []string `json:"sources"`
	}
	if r.Body != nil {
		_ = json.NewDecoder(r.Body).Decode(&body)
	}
	started, status := s.scraper.startAsync(context.Background(), body.Sources)
	if started {
		writeJSON(w, http.StatusAccepted, status)
		return
	}
	writeJSON(w, http.StatusConflict, status)
}

func (s *server) createPosting(w http.ResponseWriter, r *http.Request) {
	if !s.writeAllowed(w, r) {
		return
	}
	var input postingInput
	if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	if input.Source == "" {
		input.Source = "manual"
	}
	id, created, err := s.store.UpsertPosting(r.Context(), input)
	if err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	if s.alerts != nil {
		go s.alerts.evaluate(context.Background(), true)
	}
	writeJSON(w, map[bool]int{true: http.StatusCreated, false: http.StatusOK}[created], map[string]any{"id": id, "created": created})
}

func (s *server) batchPostings(w http.ResponseWriter, r *http.Request) {
	if !s.writeAllowed(w, r) {
		return
	}
	var payload struct {
		Postings []postingInput `json:"postings"`
		Items    []postingInput `json:"items"`
	}
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	inputs := payload.Postings
	if len(inputs) == 0 {
		inputs = payload.Items
	}
	if len(inputs) == 0 {
		writeError(w, http.StatusBadRequest, errors.New("batch must contain at least one posting"))
		return
	}
	if len(inputs) > 500 {
		writeError(w, http.StatusBadRequest, errors.New("batch is limited to 500 postings"))
		return
	}
	response := batchPostingsResponse{Total: len(inputs)}
	seen := map[string]bool{}
	for index, input := range inputs {
		if input.Source == "" {
			input.Source = "manual"
		}
		normalized := newPosting(input)
		if strings.TrimSpace(input.Title) == "" && strings.TrimSpace(input.Company) == "" && strings.TrimSpace(input.URL) == "" && strings.TrimSpace(input.Description) == "" {
			response.Skipped++
			continue
		}
		dedupeKey := fmt.Sprintf("%s|%s|%s|%s", normalized.Fingerprint, normalized.CanonicalURL, normalized.PostedAt, normalized.Description)
		if seen[dedupeKey] {
			response.Skipped++
			continue
		}
		seen[dedupeKey] = true
		_, created, err := s.store.UpsertPosting(r.Context(), input)
		if err != nil {
			response.Failed++
			if len(response.Errors) < 25 {
				response.Errors = append(response.Errors, batchPostingError{Index: index, Error: err.Error()})
			}
			continue
		}
		if created {
			response.Created++
		} else {
			response.Updated++
		}
	}
	if response.Created+response.Updated > 0 && s.alerts != nil {
		if summary, err := s.alerts.evaluate(r.Context(), true); err == nil {
			response.Alerts = &summary
		}
	}
	status := http.StatusOK
	if response.Created > 0 {
		status = http.StatusCreated
	}
	writeJSON(w, status, response)
}

func (s *server) alertList(w http.ResponseWriter, r *http.Request) {
	limit, _ := strconv.Atoi(r.URL.Query().Get("limit"))
	items, err := s.store.ListJobAlerts(r.Context(), limit)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": items, "total": len(items), "enabled": s.alerts.enabled(), "min_score": s.alerts.minScore})
}

func (s *server) evaluateAlerts(w http.ResponseWriter, r *http.Request) {
	if !s.writeAllowed(w, r) {
		return
	}
	summary, err := s.alerts.evaluate(r.Context(), true)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, summary)
}

func (s *server) writeAllowed(w http.ResponseWriter, r *http.Request) bool {
	if origin := strings.TrimRight(r.Header.Get("Origin"), "/"); origin != "" && s.expectedOrigin != "" && origin != s.expectedOrigin {
		writeError(w, http.StatusForbidden, errors.New("origin is not the configured tailnet origin"))
		return false
	}
	if s.adminToken == "" {
		return true
	}
	auth := strings.TrimSpace(r.Header.Get("Authorization"))
	if auth != "Bearer "+s.adminToken {
		w.Header().Set("WWW-Authenticate", `Bearer realm="job-db-scraper"`)
		writeError(w, http.StatusUnauthorized, errors.New("bearer token required"))
		return false
	}
	return true
}

func (s *server) exportCSV(w http.ResponseWriter, r *http.Request) {
	page, err := s.store.QueryPostings(r.Context(), queryOptions{Active: true, Limit: 200})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	w.Header().Set("Content-Type", "text/csv; charset=utf-8")
	w.Header().Set("Content-Disposition", "attachment; filename=job-postings.csv")
	writer := csv.NewWriter(w)
	_ = writer.Write([]string{"id", "source", "company", "title", "location", "remote", "posted_at", "last_seen", "url"})
	for _, p := range page.Items {
		_ = writer.Write([]string{strconv.FormatInt(p.ID, 10), p.Source, p.Company, p.Title, p.Location, strconv.FormatBool(p.Remote), p.PostedAt, p.LastSeen.Format(time.RFC3339), p.URL})
	}
	writer.Flush()
}
