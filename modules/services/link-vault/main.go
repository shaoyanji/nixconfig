// link-vault: archive bookmarks and research pages in SQLite FTS5, then serve
// a private search UI and JSON API.
package main

import (
	"context"
	"embed"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"strconv"
	"strings"
	"sync"
	"time"
)

//go:embed web/*
var webFiles embed.FS

type server struct {
	store          *Store
	extractor      *extractor
	feedClient     *http.Client
	feedMu         sync.Mutex
	adminToken     string
	expectedOrigin string
	extractOnAdd   bool
	started        time.Time
}

type errorResponse struct {
	Error string `json:"error"`
}

func main() {
	addr := flag.String("addr", "127.0.0.1:8106", "loopback address to listen on")
	dbPath := flag.String("db", "links.sqlite", "SQLite database path")
	envFile := flag.String("env-file", "", "optional KEY=VALUE file for provider credentials (never logged)")
	extractOnAdd := flag.Bool("extract-on-add", false, "extract page text when a new link is saved")
	adminTokenEnv := flag.String("admin-token-env", "LINK_VAULT_ADMIN_TOKEN", "environment variable naming the optional write bearer token")
	expectedOrigin := flag.String("origin", "", "expected browser Origin for state-changing requests; empty disables the check")
	feedInterval := flag.Duration("feed-interval", 15*time.Minute, "background feed poll interval; 0 disables automatic polling")
	flag.Parse()

	if *envFile != "" {
		if err := loadEnvFile(*envFile); err != nil {
			log.Fatalf("link-vault: env file: %v", err)
		}
	}
	store, err := OpenStore(*dbPath)
	if err != nil {
		log.Fatalf("link-vault: open db: %v", err)
	}
	defer store.Close()

	cfg := providerConfig{
		FirecrawlKey:  strings.TrimSpace(os.Getenv("FIRECRAWL_API_KEY")),
		TavilyKey:     strings.TrimSpace(os.Getenv("TAVILY_API_KEY")),
		ContextKey:    firstEnv("CONTEXT_API_KEY", "CONTEXT_DEV_API_KEY"),
		FirecrawlBase: firstEnv("FIRECRAWL_API_BASE", "FIRECRAWL_API_URL"),
		TavilyBase:    firstEnv("TAVILY_API_BASE", "TAVILY_API_URL"),
		ContextBase:   firstEnv("CONTEXT_API_BASE", "CONTEXT_API_URL"),
	}
	s := &server{
		store:          store,
		extractor:      newExtractor(cfg),
		feedClient:     &http.Client{Timeout: 15 * time.Second},
		adminToken:     strings.TrimSpace(os.Getenv(*adminTokenEnv)),
		expectedOrigin: strings.TrimRight(*expectedOrigin, "/"),
		extractOnAdd:   *extractOnAdd,
		started:        time.Now().UTC(),
	}

	if *feedInterval > 0 {
		go s.feedLoop(*feedInterval)
	}
	mux := s.routes()
	log.Printf("link-vault: listening on %s, db %s", *addr, *dbPath)
	log.Printf("link-vault: providers firecrawl=%t tavily=%t context=%t extract_on_add=%t feed_interval=%s", cfg.FirecrawlKey != "", cfg.TavilyKey != "", cfg.ContextKey != "", *extractOnAdd, feedInterval.String())
	if err := http.ListenAndServe(*addr, mux); err != nil {
		log.Fatalf("link-vault: %v", err)
	}
}

func (s *server) routes() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /", s.index)
	mux.HandleFunc("GET /index.html", s.index)
	mux.HandleFunc("GET /style.css", s.static("web/style.css", "text/css; charset=utf-8"))
	mux.HandleFunc("GET /app.js", s.static("web/app.js", "text/javascript; charset=utf-8"))
	mux.HandleFunc("GET /favicon.svg", s.static("web/favicon.svg", "image/svg+xml"))
	mux.HandleFunc("GET /api/health", s.health)
	mux.HandleFunc("GET /api/stats", s.stats)
	mux.HandleFunc("GET /api/links", s.links)
	mux.HandleFunc("POST /api/links", s.createLink)
	mux.HandleFunc("POST /api/links/batch", s.batchLinks)
	mux.HandleFunc("GET /api/links/{id}", s.link)
	mux.HandleFunc("DELETE /api/links/{id}", s.deleteLink)
	mux.HandleFunc("POST /api/links/{id}/state", s.setLinkState)
	mux.HandleFunc("POST /api/links/{id}/extract", s.extractLink)
	mux.HandleFunc("POST /api/extract", s.extractPreview)
	mux.HandleFunc("GET /api/extraction/providers", s.providers)
	mux.HandleFunc("GET /api/collections", s.collections)
	mux.HandleFunc("POST /api/collections", s.createCollection)
	mux.HandleFunc("GET /api/tags", s.tags)
	mux.HandleFunc("GET /api/feeds", s.feeds)
	mux.HandleFunc("POST /api/feeds", s.createFeed)
	mux.HandleFunc("DELETE /api/feeds/{id}", s.deleteFeed)
	mux.HandleFunc("POST /api/feeds/poll", s.pollFeedsEndpoint)
	mux.HandleFunc("GET /api/analytics", s.analytics)
	mux.HandleFunc("POST /api/import", s.importLinks)
	mux.HandleFunc("GET /api/export.json", s.exportJSON)
	mux.HandleFunc("GET /api/export.md", s.exportMarkdown)

	return mux
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

func decodeJSON(r *http.Request, target any) error {
	decoder := json.NewDecoder(io.LimitReader(r.Body, 4<<20))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(target); err != nil {
		return err
	}
	return nil
}

func (s *server) writeAllowed(w http.ResponseWriter, r *http.Request) bool {
	if s.adminToken != "" {
		token := strings.TrimSpace(strings.TrimPrefix(r.Header.Get("Authorization"), "Bearer "))
		if token != s.adminToken {
			writeError(w, http.StatusUnauthorized, errors.New("a valid bearer token is required"))
			return false
		}
	}
	if s.expectedOrigin != "" {
		origin := strings.TrimRight(r.Header.Get("Origin"), "/")
		if origin != "" && origin != s.expectedOrigin {
			writeError(w, http.StatusForbidden, errors.New("browser origin is not the configured tailnet origin"))
			return false
		}
	}
	return true
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
	stats, err := s.store.Stats(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"ok":            true,
		"service":       "link-vault",
		"uptimeSeconds": int(time.Since(s.started).Seconds()),
		"bookmarks":     stats["bookmarks"],
		"providers":     s.extractor.providers(),
	})
}

func (s *server) stats(w http.ResponseWriter, r *http.Request) {
	stats, err := s.store.Stats(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"stats":             stats,
		"bookmarks":         stats["bookmarks"],
		"unread":            stats["unread"],
		"read":              stats["read"],
		"archived":          stats["archived"],
		"collections":       stats["collections"],
		"tags":              stats["tags"],
		"extracted":         stats["extracted"],
		"extraction_failed": stats["extraction_failed"],
		"providers":         s.extractor.providers(),
		"uptimeSeconds":     int(time.Since(s.started).Seconds()),
	})
}

func (s *server) links(w http.ResponseWriter, r *http.Request) {
	limit, _ := strconv.Atoi(r.URL.Query().Get("limit"))
	offset, _ := strconv.Atoi(r.URL.Query().Get("offset"))
	links, err := s.store.ListLinks(r.Context(), ListOptions{
		Query:      r.URL.Query().Get("q"),
		State:      r.URL.Query().Get("state"),
		Collection: r.URL.Query().Get("collection"),
		Tag:        r.URL.Query().Get("tag"),
		Limit:      limit,
		Offset:     offset,
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"links": links, "count": len(links)})
}

func (s *server) link(w http.ResponseWriter, r *http.Request) {
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("id must be numeric"))
		return
	}
	link, err := s.store.Link(r.Context(), id)
	if err != nil {
		writeError(w, http.StatusNotFound, errors.New("link not found"))
		return
	}
	writeJSON(w, http.StatusOK, link)
}

func (s *server) createLink(w http.ResponseWriter, r *http.Request) {
	if !s.writeAllowed(w, r) {
		return
	}
	var input LinkInput
	if err := decodeJSON(r, &input); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	link, created, err := s.store.UpsertLink(r.Context(), input)
	if err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	extraction := map[string]any{"requested": input.Extract || (created && s.extractOnAdd)}
	if input.Extract || (created && s.extractOnAdd) {
		extraction = s.extractSavedLink(r.Context(), link.ID, input.Provider)
		link, _ = s.store.Link(r.Context(), link.ID)
	}
	status := http.StatusOK
	if created {
		status = http.StatusCreated
	}
	writeJSON(w, status, map[string]any{"link": link, "created": created, "extraction": extraction})
}

type batchInput struct {
	Links []LinkInput `json:"links"`
}

func (s *server) batchLinks(w http.ResponseWriter, r *http.Request) {
	if !s.writeAllowed(w, r) {
		return
	}
	var input batchInput
	if err := decodeJSON(r, &input); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	if len(input.Links) == 0 || len(input.Links) > 200 {
		writeError(w, http.StatusBadRequest, errors.New("links must contain 1-200 rows"))
		return
	}
	created, updated, failed := 0, 0, 0
	errorsSeen := []string{}
	ids := []int64{}
	for index, row := range input.Links {
		link, wasCreated, err := s.store.UpsertLink(r.Context(), row)
		if err != nil {
			failed++
			errorsSeen = append(errorsSeen, fmt.Sprintf("row %d: %v", index, err))
			continue
		}
		if row.Extract || (wasCreated && s.extractOnAdd) {
			s.extractSavedLink(r.Context(), link.ID, row.Provider)
		}
		ids = append(ids, link.ID)
		if wasCreated {
			created++
		} else {
			updated++
		}
	}
	writeJSON(w, http.StatusOK, map[string]any{"created": created, "updated": updated, "failed": failed, "total": len(input.Links), "ids": ids, "errors": errorsSeen})
}

func (s *server) extractSavedLink(ctx context.Context, id int64, provider string) map[string]any {
	link, err := s.store.Link(ctx, id)
	if err != nil {
		return map[string]any{"ok": false, "error": err.Error()}
	}
	extractCtx, cancel := context.WithTimeout(ctx, 25*time.Second)
	defer cancel()
	result, err := s.extractor.extract(extractCtx, link.URL, provider)
	if err != nil {
		_ = s.store.UpdateExtraction(context.Background(), id, ExtractionResult{}, "error", err.Error())
		return map[string]any{"ok": false, "error": err.Error()}
	}
	if err := s.store.UpdateExtraction(context.Background(), id, result, "ok", ""); err != nil {
		return map[string]any{"ok": false, "error": err.Error()}
	}
	return map[string]any{"ok": true, "provider": result.Provider, "title": result.Title, "excerpt": result.Excerpt}
}

func (s *server) extractLink(w http.ResponseWriter, r *http.Request) {
	if !s.writeAllowed(w, r) {
		return
	}
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("id must be numeric"))
		return
	}
	provider := r.URL.Query().Get("provider")
	result := s.extractSavedLink(r.Context(), id, provider)
	link, linkErr := s.store.Link(r.Context(), id)
	if linkErr != nil {
		writeError(w, http.StatusNotFound, errors.New("link not found"))
		return
	}
	status := http.StatusOK
	if result["ok"] != true {
		status = http.StatusBadGateway
	}
	writeJSON(w, status, map[string]any{"link": link, "extraction": result})
}

func (s *server) extractPreview(w http.ResponseWriter, r *http.Request) {
	if !s.writeAllowed(w, r) {
		return
	}
	var input struct {
		URL      string `json:"url"`
		Provider string `json:"provider"`
	}
	if err := decodeJSON(r, &input); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	ctx, cancel := context.WithTimeout(r.Context(), 25*time.Second)
	defer cancel()
	result, err := s.extractor.extract(ctx, input.URL, input.Provider)
	if err != nil {
		writeError(w, http.StatusBadGateway, err)
		return
	}
	writeJSON(w, http.StatusOK, result)
}

func (s *server) setLinkState(w http.ResponseWriter, r *http.Request) {
	if !s.writeAllowed(w, r) {
		return
	}
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("id must be numeric"))
		return
	}
	var input struct {
		State string `json:"state"`
	}
	if err := decodeJSON(r, &input); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	if err := s.store.UpdateLinkState(r.Context(), id, input.State); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	link, _ := s.store.Link(r.Context(), id)
	writeJSON(w, http.StatusOK, link)
}

func (s *server) deleteLink(w http.ResponseWriter, r *http.Request) {
	if !s.writeAllowed(w, r) {
		return
	}
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("id must be numeric"))
		return
	}
	if err := s.store.DeleteLink(r.Context(), id); err != nil {
		writeError(w, http.StatusNotFound, errors.New("link not found"))
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"deleted": true, "id": id})
}

func (s *server) providers(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, map[string]any{"providers": s.extractor.providers()})
}

func (s *server) collections(w http.ResponseWriter, r *http.Request) {
	collections, err := s.store.Collections(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"collections": collections, "count": len(collections)})
}

func (s *server) createCollection(w http.ResponseWriter, r *http.Request) {
	if !s.writeAllowed(w, r) {
		return
	}
	var input struct {
		Name        string `json:"name"`
		Description string `json:"description"`
	}
	if err := decodeJSON(r, &input); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	if strings.TrimSpace(input.Name) == "" {
		writeError(w, http.StatusBadRequest, errors.New("name is required"))
		return
	}
	id, err := s.store.EnsureCollection(r.Context(), input.Name, input.Description)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusCreated, map[string]any{"id": id, "name": cleanSpace(input.Name)})
}

func (s *server) tags(w http.ResponseWriter, r *http.Request) {
	tags, err := s.store.Tags(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"tags": tags, "count": len(tags)})
}

func (s *server) importLinks(w http.ResponseWriter, r *http.Request) {
	if !s.writeAllowed(w, r) {
		return
	}
	var input batchInput
	if err := decodeJSON(r, &input); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	created, updated, failed := 0, 0, 0
	for _, row := range input.Links {
		_, wasCreated, err := s.store.UpsertLink(r.Context(), row)
		if err != nil {
			failed++
		} else if wasCreated {
			created++
		} else {
			updated++
		}
	}
	writeJSON(w, http.StatusOK, map[string]any{"created": created, "updated": updated, "failed": failed, "total": len(input.Links)})
}

func (s *server) exportJSON(w http.ResponseWriter, r *http.Request) {
	links, err := s.store.ListLinks(r.Context(), ListOptions{All: true})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	w.Header().Set("Content-Disposition", `attachment; filename="link-vault.json"`)
	writeJSON(w, http.StatusOK, map[string]any{"exported_at": time.Now().UTC(), "count": len(links), "links": links})
}

func (s *server) exportMarkdown(w http.ResponseWriter, r *http.Request) {
	markdown, err := s.store.ExportMarkdown(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	w.Header().Set("Content-Type", "text/markdown; charset=utf-8")
	w.Header().Set("Content-Disposition", `attachment; filename="link-vault.md"`)
	_, _ = w.Write([]byte(markdown))
}
