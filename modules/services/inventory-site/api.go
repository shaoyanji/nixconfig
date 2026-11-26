// HTTP API and the single-page UI. JSON in/JSON out except / (the operator's
// panel) and the export endpoints, which stream CSV or a JSON document.
package main

import (
	"database/sql"
	"encoding/json"
	"net/http"
	"strconv"
	"strings"
)

type server struct {
	db       *sql.DB
	seedPath string
}

func writeJSON(w http.ResponseWriter, code int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	json.NewEncoder(w).Encode(v)
}

func writeErr(w http.ResponseWriter, code int, msg string) {
	writeJSON(w, code, map[string]string{"error": msg})
}

func (s *server) mux() *http.ServeMux {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /api/items", s.handleList)
	mux.HandleFunc("POST /api/items", s.handleAdd)
	mux.HandleFunc("GET /api/items/{id}", s.handleGet)
	mux.HandleFunc("DELETE /api/items/{id}", s.handleDelete)
	mux.HandleFunc("GET /api/facets", s.handleFacets)
	mux.HandleFunc("GET /api/export/json", s.handleExportJSON)
	mux.HandleFunc("GET /api/export/csv", s.handleExportCSV)
	mux.HandleFunc("POST /api/import/json", s.handleImportJSON)
	mux.HandleFunc("POST /api/import/csv", s.handleImportCSV)
	mux.HandleFunc("POST /api/seed", s.handleSeed)
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, 200, map[string]bool{"ok": true})
	})
	mux.HandleFunc("GET /", s.handleUI)
	return mux
}

func queryLimit(r *http.Request) int {
	limit := 100
	if l := r.URL.Query().Get("limit"); l != "" {
		if n, err := strconv.Atoi(l); err == nil && n > 0 && n <= 1000 {
			limit = n
		}
	}
	return limit
}

func (s *server) handleList(w http.ResponseWriter, r *http.Request) {
	limit := queryLimit(r)
	var items []Item
	var err error
	q := strings.TrimSpace(r.URL.Query().Get("q"))
	loc := strings.TrimSpace(r.URL.Query().Get("location"))
	cat := strings.TrimSpace(r.URL.Query().Get("category"))
	tag := strings.TrimSpace(r.URL.Query().Get("tag"))
	switch {
	case q != "":
		items, err = searchItems(s.db, q, limit)
	case loc != "" || cat != "" || tag != "":
		items, err = filterItems(s.db, loc, cat, tag, limit)
	default:
		items, err = listItems(s.db, limit)
	}
	if err != nil {
		writeErr(w, 500, err.Error())
		return
	}
	if items == nil {
		items = []Item{}
	}
	writeJSON(w, 200, map[string]any{"count": len(items), "items": items})
}

func (s *server) handleAdd(w http.ResponseWriter, r *http.Request) {
	var it Item
	if err := json.NewDecoder(r.Body).Decode(&it); err != nil {
		writeErr(w, 400, "bad json: "+err.Error())
		return
	}
	if strings.TrimSpace(it.Name) == "" {
		writeErr(w, 400, "name is required")
		return
	}
	id, fresh, err := upsertItem(s.db, it)
	if err != nil {
		writeErr(w, 500, err.Error())
		return
	}
	writeJSON(w, 200, map[string]any{"id": id, "new": fresh})
}

func (s *server) handleGet(w http.ResponseWriter, r *http.Request) {
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil {
		writeErr(w, 400, "bad id")
		return
	}
	it, err := getItem(s.db, id)
	if err == sql.ErrNoRows {
		writeErr(w, 404, "no such item")
		return
	}
	if err != nil {
		writeErr(w, 500, err.Error())
		return
	}
	writeJSON(w, 200, map[string]any{"item": it})
}

func (s *server) handleDelete(w http.ResponseWriter, r *http.Request) {
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil {
		writeErr(w, 400, "bad id")
		return
	}
	if err := deleteItem(s.db, id); err == sql.ErrNoRows {
		writeErr(w, 404, "no such item")
		return
	} else if err != nil {
		writeErr(w, 500, err.Error())
		return
	}
	writeJSON(w, 200, map[string]any{"deleted": id})
}

func (s *server) handleFacets(w http.ResponseWriter, r *http.Request) {
	loc, cat, tags, err := facets(s.db)
	if err != nil {
		writeErr(w, 500, err.Error())
		return
	}
	writeJSON(w, 200, map[string]any{"locations": loc, "categories": cat, "tags": tags})
}

func (s *server) handleExportJSON(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Content-Disposition", `attachment; filename="inventory.json"`)
	if err := exportJSON(s.db, w); err != nil {
		writeErr(w, 500, err.Error())
	}
}

func (s *server) handleExportCSV(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "text/csv; charset=utf-8")
	w.Header().Set("Content-Disposition", `attachment; filename="inventory.csv"`)
	if err := exportCSV(s.db, w); err != nil {
		writeErr(w, 500, err.Error())
	}
}

func (s *server) handleImportJSON(w http.ResponseWriter, r *http.Request) {
	n, err := importJSON(s.db, r.Body)
	if err != nil {
		writeErr(w, 400, err.Error())
		return
	}
	writeJSON(w, 200, map[string]any{"imported": n})
}

func (s *server) handleImportCSV(w http.ResponseWriter, r *http.Request) {
	n, err := importCSV(s.db, r.Body)
	if err != nil {
		writeErr(w, 400, err.Error())
		return
	}
	writeJSON(w, 200, map[string]any{"imported": n})
}

func (s *server) handleSeed(w http.ResponseWriter, r *http.Request) {
	if s.seedPath == "" {
		writeErr(w, 400, "no seed configured")
		return
	}
	n, err := seedHosts(s.db, s.seedPath)
	if err != nil {
		writeErr(w, 500, err.Error())
		return
	}
	writeJSON(w, 200, map[string]any{"seeded": n})
}
