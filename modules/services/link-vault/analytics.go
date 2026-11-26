package main

import (
	"context"
	"database/sql"
	"net/http"
	"net/url"
	"sort"
	"strings"
)

type analyticsCount struct {
	Name  string `json:"name"`
	Count int64  `json:"count"`
}

type collectionAnalytics struct {
	Name     string `json:"name"`
	Count    int64  `json:"count"`
	Unread   int64  `json:"unread"`
	Read     int64  `json:"read"`
	Archived int64  `json:"archived"`
}

type stateAnalytics struct {
	Total       int64   `json:"total"`
	Unread      int64   `json:"unread"`
	Read        int64   `json:"read"`
	Archived    int64   `json:"archived"`
	ReadPercent float64 `json:"read_percent"`
}

type analyticsResponse struct {
	TopDomains          []analyticsCount      `json:"top_domains"`
	TopTags             []analyticsCount      `json:"top_tags"`
	Collections         []collectionAnalytics `json:"collections"`
	ExtractionProviders []analyticsCount      `json:"extraction_providers"`
	States              stateAnalytics        `json:"states"`
	Bookmarks           int64                 `json:"bookmarks"`
	Unread              int64                 `json:"unread"`
	Read                int64                 `json:"read"`
	Archived            int64                 `json:"archived"`
	ReadPercent         float64               `json:"read_percent"`
	Feeds               int64                 `json:"feeds"`
	GeneratedAt         string                `json:"generated_at"`
}

func countMapRows(rows *sql.Rows) ([]analyticsCount, error) {
	defer rows.Close()
	out := []analyticsCount{}
	for rows.Next() {
		var row analyticsCount
		if err := rows.Scan(&row.Name, &row.Count); err != nil {
			return nil, err
		}
		out = append(out, row)
	}
	return out, rows.Err()
}

func sortAnalyticsCounts(rows []analyticsCount, limit int) []analyticsCount {
	sort.Slice(rows, func(i, j int) bool {
		if rows[i].Count == rows[j].Count {
			return rows[i].Name < rows[j].Name
		}
		return rows[i].Count > rows[j].Count
	})
	if limit > 0 && len(rows) > limit {
		return rows[:limit]
	}
	return rows
}

func (s *Store) Analytics(ctx context.Context) (analyticsResponse, error) {
	out := analyticsResponse{
		TopDomains:          []analyticsCount{},
		TopTags:             []analyticsCount{},
		Collections:         []collectionAnalytics{},
		ExtractionProviders: []analyticsCount{},
		GeneratedAt:         nowString(),
	}

	urlRows, err := s.db.QueryContext(ctx, `SELECT canonical_url FROM links`)
	if err != nil {
		return out, err
	}
	domains := map[string]int64{}
	for urlRows.Next() {
		var raw string
		if err := urlRows.Scan(&raw); err != nil {
			urlRows.Close()
			return out, err
		}
		parsed, err := url.Parse(raw)
		if err != nil || parsed.Hostname() == "" {
			continue
		}
		domain := strings.ToLower(parsed.Hostname())
		domains[domain]++
	}
	if err := urlRows.Err(); err != nil {
		urlRows.Close()
		return out, err
	}
	urlRows.Close()
	for domain, count := range domains {
		out.TopDomains = append(out.TopDomains, analyticsCount{Name: domain, Count: count})
	}
	out.TopDomains = sortAnalyticsCounts(out.TopDomains, 10)

	tagRows, err := s.db.QueryContext(ctx, `SELECT lower(value),COUNT(*) FROM links,json_each(links.tags) GROUP BY lower(value) ORDER BY COUNT(*) DESC,lower(value) LIMIT 12`)
	if err != nil {
		return out, err
	}
	out.TopTags, err = countMapRows(tagRows)
	if err != nil {
		return out, err
	}
	for i := range out.TopTags {
		if out.TopTags[i].Name == "" {
			out.TopTags[i].Name = "untagged"
		}
	}

	collectionRows, err := s.db.QueryContext(ctx, `SELECT COALESCE(c.name,'uncategorized'),COUNT(l.id),SUM(CASE WHEN l.state='unread' THEN 1 ELSE 0 END),SUM(CASE WHEN l.state='read' THEN 1 ELSE 0 END),SUM(CASE WHEN l.state='archived' THEN 1 ELSE 0 END)
		FROM links l LEFT JOIN collections c ON c.id=l.collection_id
		GROUP BY COALESCE(c.name,'uncategorized')
		ORDER BY COUNT(l.id) DESC,COALESCE(c.name,'uncategorized') LIMIT 12`)
	if err != nil {
		return out, err
	}
	defer collectionRows.Close()
	for collectionRows.Next() {
		var row collectionAnalytics
		if err := collectionRows.Scan(&row.Name, &row.Count, &row.Unread, &row.Read, &row.Archived); err != nil {
			return out, err
		}
		out.Collections = append(out.Collections, row)
	}
	if err := collectionRows.Err(); err != nil {
		return out, err
	}

	providerRows, err := s.db.QueryContext(ctx, `SELECT CASE WHEN extraction_provider='' THEN 'unknown' ELSE extraction_provider END,COUNT(*) FROM links WHERE extraction_status='ok' GROUP BY CASE WHEN extraction_provider='' THEN 'unknown' ELSE extraction_provider END ORDER BY COUNT(*) DESC,1`)
	if err != nil {
		return out, err
	}
	out.ExtractionProviders, err = countMapRows(providerRows)
	if err != nil {
		return out, err
	}

	stats, err := s.Stats(ctx)
	if err != nil {
		return out, err
	}
	out.States = stateAnalytics{
		Total:    stats["bookmarks"],
		Unread:   stats["unread"],
		Read:     stats["read"],
		Archived: stats["archived"],
	}
	if out.States.Total > 0 {
		out.States.ReadPercent = float64(out.States.Read) * 100 / float64(out.States.Total)
	}
	out.Bookmarks = out.States.Total
	out.Unread = out.States.Unread
	out.Read = out.States.Read
	out.Archived = out.States.Archived
	out.ReadPercent = out.States.ReadPercent
	if err := s.db.QueryRowContext(ctx, `SELECT COUNT(*) FROM feeds`).Scan(&out.Feeds); err != nil {
		return out, err
	}
	return out, nil
}

func (s *server) analytics(w http.ResponseWriter, r *http.Request) {
	analytics, err := s.store.Analytics(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, analytics)
}
