package main

import (
	"context"
	"database/sql"
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
	"time"
)

//go:embed web/*
var webFiles embed.FS

type server struct {
	store          *Store
	adminToken     string
	expectedOrigin string
	alerts         *warrantyAlertManager
	warrantyWarn   int
	started        time.Time
}

type errorResponse struct {
	Error string `json:"error"`
}

func main() {
	addr := flag.String("addr", "127.0.0.1:8103", "loopback address to listen on")
	dbPath := flag.String("db", "inventory.sqlite", "SQLite database path")
	inventorySeed := flag.String("inventory-seed", "", "optional inventory.toml file to seed fleet hosts on startup")
	adminTokenEnv := flag.String("admin-token-env", "INVENTORY_SITE_ADMIN_TOKEN", "environment variable naming the optional write bearer token")
	expectedOrigin := flag.String("origin", "", "expected browser Origin for state-changing requests; empty disables the check")
	ntfyURLFlag := flag.String("ntfy-url", "", "optional ntfy/webhook URL for deduped warranty-expiry notifications")
	warrantyWarnDays := flag.Int("warranty-warn-days", 30, "number of days before warranty expiry that enters the alert ledger")
	flag.Parse()

	store, err := OpenStore(*dbPath)
	if err != nil {
		log.Fatalf("inventory-site: open db: %v", err)
	}
	defer store.Close()

	if *inventorySeed != "" {
		raw, err := os.ReadFile(*inventorySeed)
		if err != nil {
			log.Fatalf("inventory-site: read inventory seed: %v", err)
		}
		inputs, err := itemsFromFleetTOML(raw)
		if err != nil {
			log.Fatalf("inventory-site: parse inventory seed: %v", err)
		}
		result, err := store.ImportItems(context.Background(), inputs)
		if err != nil {
			log.Fatalf("inventory-site: seed inventory: %v", err)
		}
		log.Printf("inventory-site: inventory.toml seed inserted=%d updated=%d skipped=%d", result.Inserted, result.Updated, result.Skipped)
	}

	ntfyURL := strings.TrimSpace(*ntfyURLFlag)
	if ntfyURL == "" {
		ntfyURL = strings.TrimSpace(os.Getenv("INVENTORY_SITE_NTFY_URL"))
	}
	s := &server{
		store:          store,
		adminToken:     strings.TrimSpace(os.Getenv(*adminTokenEnv)),
		expectedOrigin: strings.TrimRight(*expectedOrigin, "/"),
		warrantyWarn:   *warrantyWarnDays,
		started:        time.Now().UTC(),
	}
	s.alerts = newWarrantyAlertManager(store, ntfyURL, *warrantyWarnDays)

	mux := http.NewServeMux()
	mux.HandleFunc("GET /", s.index)
	mux.HandleFunc("GET /index.html", s.index)
	mux.HandleFunc("GET /style.css", s.static("web/style.css", "text/css; charset=utf-8"))
	mux.HandleFunc("GET /app.js", s.static("web/app.js", "text/javascript; charset=utf-8"))
	mux.HandleFunc("GET /favicon.svg", s.static("web/favicon.svg", "image/svg+xml"))
	mux.HandleFunc("GET /api/health", s.health)
	mux.HandleFunc("GET /api/stats", s.stats)
	mux.HandleFunc("GET /api/items", s.items)
	mux.HandleFunc("POST /api/items", s.createItem)
	mux.HandleFunc("GET /api/items/{id}", s.item)
	mux.HandleFunc("PUT /api/items/{id}", s.updateItem)
	mux.HandleFunc("DELETE /api/items/{id}", s.deleteItem)
	mux.HandleFunc("GET /api/items/{id}/events", s.itemEvents)
	mux.HandleFunc("POST /api/items/{id}/events", s.createItemEvent)
	mux.HandleFunc("GET /api/items/{id}/qr.svg", s.itemQRLabel)
	mux.HandleFunc("GET /api/alerts", s.warrantyAlerts)
	mux.HandleFunc("POST /api/alerts/evaluate", s.evaluateWarrantyAlerts)
	mux.HandleFunc("GET /api/meta/{kind}", s.meta)
	mux.HandleFunc("POST /api/meta/{kind}", s.createMeta)
	mux.HandleFunc("DELETE /api/meta/{kind}/{name}", s.deleteMeta)
	mux.HandleFunc("GET /api/export.json", s.exportJSON)
	mux.HandleFunc("GET /api/export.csv", s.exportCSV)
	mux.HandleFunc("POST /api/import/json", s.importJSON)
	mux.HandleFunc("POST /api/import/csv", s.importCSV)
	mux.HandleFunc("POST /api/import/inventory-toml", s.importFleetTOML)

	go func() {
		time.Sleep(8 * time.Second)
		if _, err := s.alerts.evaluate(context.Background(), true); err != nil {
			log.Printf("inventory-site: initial warranty evaluation: %v", err)
		}
		ticker := time.NewTicker(6 * time.Hour)
		defer ticker.Stop()
		for range ticker.C {
			if _, err := s.alerts.evaluate(context.Background(), true); err != nil {
				log.Printf("inventory-site: warranty evaluation: %v", err)
			}
		}
	}()

	log.Printf("inventory-site: listening on %s, db %s", *addr, *dbPath)
	if err := http.ListenAndServe(*addr, mux); err != nil {
		log.Fatalf("inventory-site: %v", err)
	}
}

func (s *server) alertManager() *warrantyAlertManager {
	if s.alerts != nil {
		return s.alerts
	}
	return newWarrantyAlertManager(s.store, "", s.warrantyWarn)
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
		"ok": true, "service": "inventory-site", "version": "0.2.0",
		"uptime_seconds": int(time.Since(s.started).Seconds()), "time": time.Now().UTC().Format(time.RFC3339),
		"warranty_warn_days": s.warrantyWarn, "ntfy_configured": s.alerts != nil && s.alerts.enabled(),
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

func intQuery(r *http.Request, key string) int {
	value, _ := strconv.Atoi(r.URL.Query().Get(key))
	return value
}

func (s *server) items(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query()
	page, err := s.store.ListItems(r.Context(), itemQueryOptions{
		Q: q.Get("q"), Category: q.Get("category"), Location: q.Get("location"), Tag: q.Get("tag"), Source: q.Get("source"),
		IncludeArchived: q.Get("archived") == "1" || q.Get("include_archived") == "1", WarrantyWithin: intQuery(r, "warranty_within"),
		Limit: intQuery(r, "limit"), Offset: intQuery(r, "offset"),
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, page)
}

func parseID(r *http.Request, label string) (int64, error) {
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil {
		return 0, fmt.Errorf("%s id must be numeric", label)
	}
	return id, nil
}

func (s *server) item(w http.ResponseWriter, r *http.Request) {
	id, err := parseID(r, "item")
	if err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	item, err := s.store.GetItem(r.Context(), id)
	if err != nil {
		writeError(w, http.StatusNotFound, err)
		return
	}
	writeJSON(w, http.StatusOK, item)
}

func decodeItemInput(r *http.Request) (itemInput, error) {
	var input itemInput
	decoder := json.NewDecoder(r.Body)
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(&input); err != nil {
		return input, err
	}
	return input, validateItem(&input)
}

func (s *server) createItem(w http.ResponseWriter, r *http.Request) {
	if !s.writeAllowed(w, r) {
		return
	}
	input, err := decodeItemInput(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	id, created, err := s.store.UpsertItem(r.Context(), input)
	if err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	status := http.StatusOK
	if created {
		status = http.StatusCreated
	}
	writeJSON(w, status, map[string]any{"id": id, "created": created})
}

func (s *server) updateItem(w http.ResponseWriter, r *http.Request) {
	if !s.writeAllowed(w, r) {
		return
	}
	id, err := parseID(r, "item")
	if err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	input, err := decodeItemInput(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	if err := s.store.UpdateItem(r.Context(), id, input); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"ok": true})
}

func (s *server) deleteItem(w http.ResponseWriter, r *http.Request) {
	if !s.writeAllowed(w, r) {
		return
	}
	id, err := parseID(r, "item")
	if err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	if err := s.store.DeleteItem(r.Context(), id); err != nil {
		writeError(w, http.StatusNotFound, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"ok": true})
}

func (s *server) itemEvents(w http.ResponseWriter, r *http.Request) {
	id, err := parseID(r, "item")
	if err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	if _, err := s.store.GetItem(r.Context(), id); err != nil {
		writeError(w, http.StatusNotFound, err)
		return
	}
	events, err := s.store.ListAssetEvents(r.Context(), id, intQuery(r, "limit"))
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"events": events, "total": len(events)})
}

func (s *server) createItemEvent(w http.ResponseWriter, r *http.Request) {
	if !s.writeAllowed(w, r) {
		return
	}
	id, err := parseID(r, "item")
	if err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	var input assetEventInput
	decoder := json.NewDecoder(io.LimitReader(r.Body, 1<<20))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(&input); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	event, err := s.store.AddAssetEvent(r.Context(), id, input)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			writeError(w, http.StatusNotFound, err)
		} else {
			writeError(w, http.StatusBadRequest, err)
		}
		return
	}
	writeJSON(w, http.StatusCreated, event)
}

func (s *server) itemQRLabel(w http.ResponseWriter, r *http.Request) {
	id, err := parseID(r, "item")
	if err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	item, err := s.store.GetItem(r.Context(), id)
	if err != nil {
		writeError(w, http.StatusNotFound, err)
		return
	}
	origin := s.expectedOrigin
	if origin == "" {
		origin = "http://" + r.Host
	}
	svg, err := renderQRLabelSVG(item, qrLabelTarget(origin, id))
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	w.Header().Set("Content-Type", "image/svg+xml; charset=utf-8")
	w.Header().Set("Cache-Control", "private, max-age=300")
	_, _ = w.Write(svg)
}

func (s *server) warrantyAlerts(w http.ResponseWriter, r *http.Request) {
	alerts, err := s.store.ListWarrantyAlerts(r.Context(), intQuery(r, "limit"))
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"alerts": alerts, "total": len(alerts), "warranty_warn_days": s.warrantyWarn,
		"ntfy_configured": s.alerts != nil && s.alerts.enabled(),
	})
}

func (s *server) evaluateWarrantyAlerts(w http.ResponseWriter, r *http.Request) {
	if !s.writeAllowed(w, r) {
		return
	}
	notify := r.URL.Query().Get("notify") != "0"
	summary, err := s.alertManager().evaluate(r.Context(), notify)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, summary)
}

func validMetaKind(kind string) bool {
	return kind == "categories" || kind == "locations" || kind == "tags"
}

func (s *server) meta(w http.ResponseWriter, r *http.Request) {
	kind := r.PathValue("kind")
	if !validMetaKind(kind) {
		writeError(w, http.StatusBadRequest, errors.New("kind must be categories, locations or tags"))
		return
	}
	entries, err := s.store.ListMeta(r.Context(), kind)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": entries, "total": len(entries)})
}

func (s *server) createMeta(w http.ResponseWriter, r *http.Request) {
	if !s.writeAllowed(w, r) {
		return
	}
	kind := r.PathValue("kind")
	if !validMetaKind(kind) {
		writeError(w, http.StatusBadRequest, errors.New("kind must be categories, locations or tags"))
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
	if err := s.store.UpsertMeta(r.Context(), kind, body.Name, body.Description); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	writeJSON(w, http.StatusCreated, map[string]any{"ok": true})
}

func (s *server) deleteMeta(w http.ResponseWriter, r *http.Request) {
	if !s.writeAllowed(w, r) {
		return
	}
	kind := r.PathValue("kind")
	if !validMetaKind(kind) {
		writeError(w, http.StatusBadRequest, errors.New("kind must be categories, locations or tags"))
		return
	}
	name, err := decodePathPart(r.PathValue("name"))
	if err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	if err := s.store.DeleteMeta(r.Context(), kind, name); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"ok": true})
}

func decodePathPart(value string) (string, error) {
	return strings.TrimSpace(value), nil
}

func (s *server) exportJSON(w http.ResponseWriter, r *http.Request) {
	bundle, err := s.store.ExportBundle(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	w.Header().Set("Content-Disposition", "attachment; filename=inventory-site.json")
	writeJSON(w, http.StatusOK, bundle)
}

func (s *server) exportCSV(w http.ResponseWriter, r *http.Request) {
	bundle, err := s.store.ExportBundle(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	w.Header().Set("Content-Type", "text/csv; charset=utf-8")
	w.Header().Set("Content-Disposition", "attachment; filename=inventory-site.csv")
	if err := writeItemsCSV(w, bundle.Items); err != nil {
		log.Printf("inventory-site: csv export: %v", err)
	}
}

func inputFromItem(item Item) itemInput {
	return itemInput{
		Source: item.Source, SourceKey: item.SourceKey, Name: item.Name, Category: item.Category,
		Location: item.Location, Description: item.Description, Manufacturer: item.Manufacturer, Model: item.Model,
		Serial: item.Serial, PurchaseDate: item.PurchaseDate, WarrantyUntil: item.WarrantyUntil,
		ValueCents: item.ValueCents, Currency: item.Currency, Quantity: item.Quantity, URL: item.URL,
		Notes: item.Notes, Tags: item.Tags, Archived: item.Archived,
	}
}

func (s *server) importJSON(w http.ResponseWriter, r *http.Request) {
	if !s.writeAllowed(w, r) {
		return
	}
	raw, err := io.ReadAll(io.LimitReader(r.Body, 32<<20))
	if err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	inputs := []itemInput{}
	var bundle exportBundle
	if err := json.Unmarshal(raw, &bundle); err == nil && bundle.Items != nil {
		for _, item := range bundle.Items {
			inputs = append(inputs, inputFromItem(item))
		}
	} else {
		var direct []itemInput
		if err := json.Unmarshal(raw, &direct); err != nil {
			var wrapper struct {
				Items []itemInput `json:"items"`
			}
			if err2 := json.Unmarshal(raw, &wrapper); err2 != nil || wrapper.Items == nil {
				writeError(w, http.StatusBadRequest, fmt.Errorf("JSON import must be an export bundle, an items object, or an item array: %v", err))
				return
			}
			inputs = wrapper.Items
		} else {
			inputs = direct
		}
	}
	result, err := s.store.ImportItems(r.Context(), inputs)
	if err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	writeJSON(w, http.StatusOK, result)
}

func (s *server) importCSV(w http.ResponseWriter, r *http.Request) {
	if !s.writeAllowed(w, r) {
		return
	}
	inputs, warnings, err := itemsFromCSV(io.LimitReader(r.Body, 32<<20))
	if err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	result, err := s.store.ImportItems(r.Context(), inputs)
	if err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	result.Warnings = append(warnings, result.Warnings...)
	writeJSON(w, http.StatusOK, result)
}

func (s *server) importFleetTOML(w http.ResponseWriter, r *http.Request) {
	if !s.writeAllowed(w, r) {
		return
	}
	raw, err := io.ReadAll(io.LimitReader(r.Body, 16<<20))
	if err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	inputs, err := itemsFromFleetTOML(raw)
	if err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	result, err := s.store.ImportItems(r.Context(), inputs)
	if err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	writeJSON(w, http.StatusOK, result)
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
		w.Header().Set("WWW-Authenticate", `Bearer realm="inventory-site"`)
		writeError(w, http.StatusUnauthorized, errors.New("bearer token required"))
		return false
	}
	return true
}
