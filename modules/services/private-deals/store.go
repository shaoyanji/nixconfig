// SQLite/FTS5 store for deals, watchlists and price history.
//
// modernc.org/sqlite (pure Go, FTS5 compiled in) so the fleet's CGO_ENABLED=0
// build holds; the same dep and version as the agent-turns shim.
package main

import (
	"database/sql"
	"fmt"
	"time"

	_ "modernc.org/sqlite"
)

type Deal struct {
	ID         int64  `json:"id"`
	Title      string `json:"title"`
	URL        string `json:"url"`
	PriceCents int64  `json:"price_cents"`
	Currency   string `json:"currency"`
	Source     string `json:"source"`
	FirstSeen  string `json:"first_seen"`
	LastSeen   string `json:"last_seen"`
	Notes      string `json:"notes"`
}

type PricePoint struct {
	PriceCents int64  `json:"price_cents"`
	SeenAt     string `json:"seen_at"`
}

type Watchlist struct {
	ID      int64  `json:"id"`
	Name    string `json:"name"`
	Query   string `json:"query"`
	Created string `json:"created"`
}

const schema = `
CREATE TABLE IF NOT EXISTS deals (
  id INTEGER PRIMARY KEY,
  title TEXT NOT NULL,
  url TEXT NOT NULL DEFAULT '',
  price_cents INTEGER NOT NULL DEFAULT 0,
  currency TEXT NOT NULL DEFAULT 'EUR',
  source TEXT NOT NULL DEFAULT 'manual',
  first_seen TEXT NOT NULL,
  last_seen TEXT NOT NULL,
  notes TEXT NOT NULL DEFAULT '',
  UNIQUE(title, url)
);
CREATE VIRTUAL TABLE IF NOT EXISTS deals_fts USING fts5(
  title, notes, content='deals', content_rowid='id'
);
CREATE TRIGGER IF NOT EXISTS deals_ai AFTER INSERT ON deals BEGIN
  INSERT INTO deals_fts(rowid, title, notes) VALUES (new.id, new.title, new.notes);
END;
CREATE TRIGGER IF NOT EXISTS deals_ad AFTER DELETE ON deals BEGIN
  INSERT INTO deals_fts(deals_fts, rowid, title, notes) VALUES ('delete', old.id, old.title, old.notes);
END;
CREATE TRIGGER IF NOT EXISTS deals_au AFTER UPDATE ON deals BEGIN
  INSERT INTO deals_fts(deals_fts, rowid, title, notes) VALUES ('delete', old.id, old.title, old.notes);
  INSERT INTO deals_fts(rowid, title, notes) VALUES (new.id, new.title, new.notes);
END;
CREATE TABLE IF NOT EXISTS price_history (
  deal_id INTEGER NOT NULL REFERENCES deals(id),
  price_cents INTEGER NOT NULL,
  seen_at TEXT NOT NULL,
  PRIMARY KEY (deal_id, seen_at)
);
CREATE TABLE IF NOT EXISTS watchlists (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL UNIQUE,
  query TEXT NOT NULL,
  created TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS feeds (
  id INTEGER PRIMARY KEY,
  url TEXT NOT NULL UNIQUE,
  kind TEXT NOT NULL DEFAULT 'rss',
  added TEXT NOT NULL
);
`

func openStore(path string) (*sql.DB, error) {
	db, err := sql.Open("sqlite", path+"?_pragma=journal_mode(wal)&_pragma=busy_timeout(5000)&_pragma=foreign_keys(1)")
	if err != nil {
		return nil, err
	}
	if _, err := db.Exec(schema); err != nil {
		db.Close()
		return nil, fmt.Errorf("schema: %w", err)
	}
	return db, nil
}

func nowRFC() string { return time.Now().UTC().Format(time.RFC3339Nano) }

// upsertDeal inserts a deal or updates price/last_seen when (title, url) is
// already held; a price change appends one price_history row. Returns the id
// and whether the row was new.
func upsertDeal(db *sql.DB, d Deal) (int64, bool, error) {
	if d.Currency == "" {
		d.Currency = "EUR"
	}
	if d.Source == "" {
		d.Source = "manual"
	}
	now := nowRFC()
	var id int64
	var oldPrice int64
	err := db.QueryRow(`SELECT id, price_cents FROM deals WHERE title = ? AND url = ?`, d.Title, d.URL).Scan(&id, &oldPrice)
	switch {
	case err == sql.ErrNoRows:
		res, err := db.Exec(`INSERT INTO deals (title, url, price_cents, currency, source, first_seen, last_seen, notes)
			VALUES (?, ?, ?, ?, ?, ?, ?, ?)`, d.Title, d.URL, d.PriceCents, d.Currency, d.Source, now, now, d.Notes)
		if err != nil {
			return 0, false, err
		}
		id, err = res.LastInsertId()
		if err != nil {
			return 0, false, err
		}
		if d.PriceCents > 0 {
			if _, err := db.Exec(`INSERT OR IGNORE INTO price_history (deal_id, price_cents, seen_at) VALUES (?, ?, ?)`, id, d.PriceCents, now); err != nil {
				return 0, false, err
			}
		}
		return id, true, nil
	case err != nil:
		return 0, false, err
	}
	if d.PriceCents > 0 && d.PriceCents != oldPrice {
		if _, err := db.Exec(`INSERT OR IGNORE INTO price_history (deal_id, price_cents, seen_at) VALUES (?, ?, ?)`, id, d.PriceCents, now); err != nil {
			return 0, false, err
		}
	}
	if d.Notes == "" {
		_, err = db.Exec(`UPDATE deals SET price_cents = CASE WHEN ? > 0 THEN ? ELSE price_cents END, last_seen = ? WHERE id = ?`, d.PriceCents, d.PriceCents, now, id)
	} else {
		_, err = db.Exec(`UPDATE deals SET price_cents = CASE WHEN ? > 0 THEN ? ELSE price_cents END, last_seen = ?, notes = ? WHERE id = ?`, d.PriceCents, d.PriceCents, now, d.Notes, id)
	}
	return id, false, err
}

func scanDeals(rows *sql.Rows) ([]Deal, error) {
	defer rows.Close()
	var out []Deal
	for rows.Next() {
		var d Deal
		if err := rows.Scan(&d.ID, &d.Title, &d.URL, &d.PriceCents, &d.Currency, &d.Source, &d.FirstSeen, &d.LastSeen, &d.Notes); err != nil {
			return nil, err
		}
		out = append(out, d)
	}
	return out, rows.Err()
}

const dealCols = `id, title, url, price_cents, currency, source, first_seen, last_seen, notes`

// The join against deals_fts shares title/notes, so every column in the FTS
// query must carry the table prefix — interpolating `d.` once only prefixes
// the first.
const dealColsPrefixed = `d.id, d.title, d.url, d.price_cents, d.currency, d.source, d.first_seen, d.last_seen, d.notes`

func listDeals(db *sql.DB, limit int) ([]Deal, error) {
	rows, err := db.Query(`SELECT `+dealCols+` FROM deals ORDER BY last_seen DESC LIMIT ?`, limit)
	if err != nil {
		return nil, err
	}
	return scanDeals(rows)
}

// searchDeals runs an FTS5 MATCH query; a bare word query is quoted per token
// so user input cannot break the MATCH syntax.
func searchDeals(db *sql.DB, q string, limit int) ([]Deal, error) {
	rows, err := db.Query(`SELECT `+dealColsPrefixed+` FROM deals d
		JOIN deals_fts f ON d.id = f.rowid
		WHERE deals_fts MATCH ?
		ORDER BY rank LIMIT ?`, ftsQuote(q), limit)
	if err != nil {
		return nil, err
	}
	return scanDeals(rows)
}

func ftsQuote(q string) string {
	out := ""
	for _, w := range splitWords(q) {
		if out != "" {
			out += " "
		}
		out += `"` + w + `"`
	}
	return out
}

func splitWords(q string) []string {
	var out []string
	cur := ""
	for _, r := range q {
		switch {
		case r >= 'a' && r <= 'z' || r >= 'A' && r <= 'Z' || r >= '0' && r <= '9' || r == '_' || r >= 0x80:
			cur += string(r)
		default:
			if cur != "" {
				out = append(out, cur)
				cur = ""
			}
		}
	}
	if cur != "" {
		out = append(out, cur)
	}
	if len(out) == 0 {
		return []string{""}
	}
	return out
}

func getDeal(db *sql.DB, id int64) (*Deal, []PricePoint, error) {
	var d Deal
	err := db.QueryRow(`SELECT `+dealCols+` FROM deals WHERE id = ?`, id).
		Scan(&d.ID, &d.Title, &d.URL, &d.PriceCents, &d.Currency, &d.Source, &d.FirstSeen, &d.LastSeen, &d.Notes)
	if err != nil {
		return nil, nil, err
	}
	rows, err := db.Query(`SELECT price_cents, seen_at FROM price_history WHERE deal_id = ? ORDER BY seen_at`, id)
	if err != nil {
		return nil, nil, err
	}
	defer rows.Close()
	var hist []PricePoint
	for rows.Next() {
		var p PricePoint
		if err := rows.Scan(&p.PriceCents, &p.SeenAt); err != nil {
			return nil, nil, err
		}
		hist = append(hist, p)
	}
	return &d, hist, rows.Err()
}

func addWatchlist(db *sql.DB, name, query string) (int64, error) {
	res, err := db.Exec(`INSERT INTO watchlists (name, query, created) VALUES (?, ?, ?)
		ON CONFLICT(name) DO UPDATE SET query = excluded.query`, name, query, nowRFC())
	if err != nil {
		return 0, err
	}
	return res.LastInsertId()
}

func listWatchlists(db *sql.DB) ([]Watchlist, error) {
	rows, err := db.Query(`SELECT id, name, query, created FROM watchlists ORDER BY name`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []Watchlist
	for rows.Next() {
		var w Watchlist
		if err := rows.Scan(&w.ID, &w.Name, &w.Query, &w.Created); err != nil {
			return nil, err
		}
		out = append(out, w)
	}
	return out, rows.Err()
}

func addFeed(db *sql.DB, url, kind string) error {
	if kind == "" {
		kind = "rss"
	}
	_, err := db.Exec(`INSERT OR IGNORE INTO feeds (url, kind, added) VALUES (?, ?, ?)`, url, kind, nowRFC())
	return err
}

func listFeeds(db *sql.DB) ([]string, error) {
	rows, err := db.Query(`SELECT url FROM feeds ORDER BY url`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []string
	for rows.Next() {
		var u string
		if err := rows.Scan(&u); err != nil {
			return nil, err
		}
		out = append(out, u)
	}
	return out, rows.Err()
}
