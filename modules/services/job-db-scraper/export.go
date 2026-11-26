package main

import (
	"encoding/csv"
	"fmt"
	"net/http"
	"strconv"
	"strings"
	"time"
)

func (s *server) exportPostings(w http.ResponseWriter, r *http.Request) {
	format := strings.ToLower(r.URL.Query().Get("format"))
	if format == "" {
		format = "json"
	}
	var page postingsPage
	if rawID := r.URL.Query().Get("id"); rawID != "" {
		id, err := strconv.ParseInt(rawID, 10, 64)
		if err != nil {
			writeError(w, http.StatusBadRequest, err)
			return
		}
		posting, _, err := s.store.GetPosting(r.Context(), id)
		if err != nil {
			writeError(w, http.StatusNotFound, err)
			return
		}
		page = postingsPage{Items: []Posting{posting}, Total: 1, Limit: 1}
	} else {
		var err error
		page, err = s.store.QueryPostings(r.Context(), queryOptions{Q: r.URL.Query().Get("q"), Stage: r.URL.Query().Get("stage"), Active: r.URL.Query().Get("active") != "0", Limit: 200, Sort: "score"})
		if err != nil {
			writeError(w, http.StatusInternalServerError, err)
			return
		}
	}
	switch format {
	case "json":
		writeJSON(w, http.StatusOK, page)
	case "csv":
		w.Header().Set("Content-Type", "text/csv; charset=utf-8")
		w.Header().Set("Content-Disposition", "attachment; filename=job-postings.csv")
		writer := csv.NewWriter(w)
		_ = writer.Write([]string{"id", "source", "merged_sources", "duplicate_count", "stage", "company", "title", "location", "remote", "score", "posted_at", "first_seen", "last_seen", "url"})
		for _, p := range page.Items {
			_ = writer.Write([]string{strconv.FormatInt(p.ID, 10), p.Source, strings.Join(p.MergedSources, "|"), strconv.Itoa(p.DuplicateCount), p.Stage, p.Company, p.Title, p.Location, strconv.FormatBool(p.Remote), strconv.Itoa(p.Score), p.PostedAt, p.FirstSeen.Format(time.RFC3339), p.LastSeen.Format(time.RFC3339), p.URL})
		}
		writer.Flush()
	case "markdown", "md":
		w.Header().Set("Content-Type", "text/markdown; charset=utf-8")
		w.Header().Set("Content-Disposition", "attachment; filename=job-postings.md")
		fmt.Fprintln(w, "# Job posting packet")
		for _, p := range page.Items {
			fmt.Fprintf(w, "## %s — %s\n\n- Stage: `%s`\n- Score: %d\n- Location: %s\n- Sources: %s\n- URL: %s\n\n%s\n\n", p.Title, p.Company, p.Stage, p.Score, p.Location, strings.Join(p.MergedSources, ", "), p.URL, p.Description)
		}
	default:
		writeError(w, http.StatusBadRequest, fmt.Errorf("format must be csv, json or markdown"))
	}
}
