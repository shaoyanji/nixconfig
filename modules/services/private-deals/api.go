// HTTP API and the single-page UI. Everything is JSON in/JSON out except /,
// which is the operator's search panel.
package main

import (
	"database/sql"
	"encoding/json"
	"net/http"
	"strconv"
	"strings"
)

type server struct {
	db *sql.DB
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
	mux.HandleFunc("GET /api/deals", s.handleList)
	mux.HandleFunc("POST /api/deals", s.handleAdd)
	mux.HandleFunc("GET /api/deals/{id}", s.handleGet)
	mux.HandleFunc("GET /api/watchlists", s.handleWatchlists)
	mux.HandleFunc("POST /api/watchlists", s.handleAddWatchlist)
	mux.HandleFunc("GET /api/feeds", s.handleFeeds)
	mux.HandleFunc("POST /api/feeds", s.handleAddFeed)
	mux.HandleFunc("POST /api/ingest", s.handleIngest)
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, 200, map[string]bool{"ok": true})
	})
	mux.HandleFunc("GET /", s.handleUI)
	return mux
}

func (s *server) handleList(w http.ResponseWriter, r *http.Request) {
	limit := 50
	if l := r.URL.Query().Get("limit"); l != "" {
		if n, err := strconv.Atoi(l); err == nil && n > 0 && n <= 500 {
			limit = n
		}
	}
	var deals []Deal
	var err error
	if q := strings.TrimSpace(r.URL.Query().Get("q")); q != "" {
		deals, err = searchDeals(s.db, q, limit)
	} else {
		deals, err = listDeals(s.db, limit)
	}
	if err != nil {
		writeErr(w, 500, err.Error())
		return
	}
	if deals == nil {
		deals = []Deal{}
	}
	writeJSON(w, 200, map[string]any{"count": len(deals), "deals": deals})
}

func (s *server) handleAdd(w http.ResponseWriter, r *http.Request) {
	var d Deal
	if err := json.NewDecoder(r.Body).Decode(&d); err != nil {
		writeErr(w, 400, "bad json: "+err.Error())
		return
	}
	if strings.TrimSpace(d.Title) == "" {
		writeErr(w, 400, "title is required")
		return
	}
	id, fresh, err := upsertDeal(s.db, d)
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
	d, hist, err := getDeal(s.db, id)
	if err == sql.ErrNoRows {
		writeErr(w, 404, "no such deal")
		return
	}
	if err != nil {
		writeErr(w, 500, err.Error())
		return
	}
	writeJSON(w, 200, map[string]any{"deal": d, "price_history": hist})
}

func (s *server) handleWatchlists(w http.ResponseWriter, r *http.Request) {
	wl, err := listWatchlists(s.db)
	if err != nil {
		writeErr(w, 500, err.Error())
		return
	}
	if wl == nil {
		wl = []Watchlist{}
	}
	writeJSON(w, 200, map[string]any{"watchlists": wl})
}

func (s *server) handleAddWatchlist(w http.ResponseWriter, r *http.Request) {
	var in Watchlist
	if err := json.NewDecoder(r.Body).Decode(&in); err != nil {
		writeErr(w, 400, "bad json: "+err.Error())
		return
	}
	if strings.TrimSpace(in.Name) == "" || strings.TrimSpace(in.Query) == "" {
		writeErr(w, 400, "name and query are required")
		return
	}
	id, err := addWatchlist(s.db, in.Name, in.Query)
	if err != nil {
		writeErr(w, 500, err.Error())
		return
	}
	writeJSON(w, 200, map[string]any{"id": id})
}

func (s *server) handleFeeds(w http.ResponseWriter, r *http.Request) {
	feeds, err := listFeeds(s.db)
	if err != nil {
		writeErr(w, 500, err.Error())
		return
	}
	if feeds == nil {
		feeds = []string{}
	}
	writeJSON(w, 200, map[string]any{"feeds": feeds})
}

func (s *server) handleAddFeed(w http.ResponseWriter, r *http.Request) {
	var in struct {
		URL  string `json:"url"`
		Kind string `json:"kind"`
	}
	if err := json.NewDecoder(r.Body).Decode(&in); err != nil {
		writeErr(w, 400, "bad json: "+err.Error())
		return
	}
	if !strings.HasPrefix(in.URL, "http") {
		writeErr(w, 400, "url must be http(s)")
		return
	}
	if err := addFeed(s.db, in.URL, in.Kind); err != nil {
		writeErr(w, 500, err.Error())
		return
	}
	writeJSON(w, 200, map[string]string{"added": in.URL})
}

func (s *server) handleIngest(w http.ResponseWriter, r *http.Request) {
	ok, failed := ingestAll(s.db)
	writeJSON(w, 200, map[string]any{"ingested": ok, "failed": failed})
}
