// HTTP API and the score-sorted UI. JSON in/JSON out except /, which is the
// operator's ranked surface.
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
	mux.HandleFunc("GET /api/postings", s.handleList)
	mux.HandleFunc("POST /api/postings", s.handleAdd)
	mux.HandleFunc("POST /api/postings/batch", s.handleBatch)
	mux.HandleFunc("GET /api/postings/{id}", s.handleGet)
	mux.HandleFunc("DELETE /api/postings/{id}", s.handleDelete)
	mux.HandleFunc("GET /api/stats", s.handleStats)
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

func queryMinScore(r *http.Request) int {
	if ms := r.URL.Query().Get("min_score"); ms != "" {
		if n, err := strconv.Atoi(ms); err == nil && n >= 0 && n <= 100 {
			return n
		}
	}
	return 0
}

func (s *server) handleList(w http.ResponseWriter, r *http.Request) {
	limit := queryLimit(r)
	minScore := queryMinScore(r)
	var postings []Posting
	var err error
	if q := strings.TrimSpace(r.URL.Query().Get("q")); q != "" {
		postings, err = searchPostings(s.db, q, minScore, limit)
	} else {
		postings, err = listPostings(s.db, minScore, strings.TrimSpace(r.URL.Query().Get("lane")), limit)
	}
	if err != nil {
		writeErr(w, 500, err.Error())
		return
	}
	if postings == nil {
		postings = []Posting{}
	}
	writeJSON(w, 200, map[string]any{"count": len(postings), "postings": postings})
}

func validPosting(p *Posting) string {
	if strings.TrimSpace(p.Title) == "" {
		return "title is required"
	}
	if strings.TrimSpace(p.Employer) == "" {
		return "employer is required"
	}
	return ""
}

func (s *server) handleAdd(w http.ResponseWriter, r *http.Request) {
	var p Posting
	if err := json.NewDecoder(r.Body).Decode(&p); err != nil {
		writeErr(w, 400, "bad json: "+err.Error())
		return
	}
	if msg := validPosting(&p); msg != "" {
		writeErr(w, 400, msg)
		return
	}
	id, fresh, err := upsertPosting(s.db, p)
	if err != nil {
		writeErr(w, 500, err.Error())
		return
	}
	writeJSON(w, 200, map[string]any{"id": id, "new": fresh, "score": p.Score, "lane": p.Lane})
}

// handleBatch is the sweep's write path: one request, every posting upserted,
// per-row errors reported rather than aborting the batch.
func (s *server) handleBatch(w http.ResponseWriter, r *http.Request) {
	var in struct {
		Postings []Posting `json:"postings"`
	}
	if err := json.NewDecoder(r.Body).Decode(&in); err != nil {
		writeErr(w, 400, "bad json: "+err.Error())
		return
	}
	if len(in.Postings) == 0 {
		writeErr(w, 400, "postings array is empty")
		return
	}
	if len(in.Postings) > 500 {
		writeErr(w, 400, "batch over 500 rows")
		return
	}
	inserted, updated, failed := 0, 0, 0
	var errs []string
	for _, p := range in.Postings {
		if msg := validPosting(&p); msg != "" {
			failed++
			errs = append(errs, p.Title+": "+msg)
			continue
		}
		_, fresh, err := upsertPosting(s.db, p)
		if err != nil {
			failed++
			errs = append(errs, p.Title+": "+err.Error())
			continue
		}
		if fresh {
			inserted++
		} else {
			updated++
		}
	}
	writeJSON(w, 200, map[string]any{"inserted": inserted, "updated": updated, "failed": failed, "errors": errs})
}

func (s *server) handleGet(w http.ResponseWriter, r *http.Request) {
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil {
		writeErr(w, 400, "bad id")
		return
	}
	rows, err := s.db.Query(`SELECT `+postingCols+` FROM postings WHERE id = ?`, id)
	if err != nil {
		writeErr(w, 500, err.Error())
		return
	}
	postings, err := scanPostings(rows)
	if err != nil {
		writeErr(w, 500, err.Error())
		return
	}
	if len(postings) == 0 {
		writeErr(w, 404, "no such posting")
		return
	}
	writeJSON(w, 200, map[string]any{"posting": postings[0]})
}

func (s *server) handleDelete(w http.ResponseWriter, r *http.Request) {
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil {
		writeErr(w, 400, "bad id")
		return
	}
	res, err := s.db.Exec(`DELETE FROM postings WHERE id = ?`, id)
	if err != nil {
		writeErr(w, 500, err.Error())
		return
	}
	if n, _ := res.RowsAffected(); n == 0 {
		writeErr(w, 404, "no such posting")
		return
	}
	writeJSON(w, 200, map[string]any{"deleted": id})
}

func (s *server) handleStats(w http.ResponseWriter, r *http.Request) {
	counts, err := laneCounts(s.db)
	if err != nil {
		writeErr(w, 500, err.Error())
		return
	}
	writeJSON(w, 200, map[string]any{"lanes": counts})
}
