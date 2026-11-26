// SQLite/FTS5 store for job postings with deterministic lane scoring.
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

type Posting struct {
	ID          int64    `json:"id"`
	Title       string   `json:"title"`
	Employer    string   `json:"employer"`
	URL         string   `json:"url"`
	Location    string   `json:"location"`
	Source      string   `json:"source"`
	Description string   `json:"description"`
	Lane        string   `json:"lane"`
	Score       int      `json:"score"`
	Reasons     []string `json:"reasons"`
	FirstSeen   string   `json:"first_seen"`
	LastSeen    string   `json:"last_seen"`
}

const schema = `
CREATE TABLE IF NOT EXISTS postings (
  id INTEGER PRIMARY KEY,
  title TEXT NOT NULL,
  employer TEXT NOT NULL,
  url TEXT NOT NULL DEFAULT '',
  location TEXT NOT NULL DEFAULT '',
  source TEXT NOT NULL DEFAULT 'manual',
  description TEXT NOT NULL DEFAULT '',
  lane TEXT NOT NULL DEFAULT 'unclear',
  score INTEGER NOT NULL DEFAULT 0,
  reasons TEXT NOT NULL DEFAULT '[]',
  dedupe_key TEXT NOT NULL UNIQUE,
  first_seen TEXT NOT NULL,
  last_seen TEXT NOT NULL
);
CREATE VIRTUAL TABLE IF NOT EXISTS postings_fts USING fts5(
  title, employer, description, location,
  content='postings', content_rowid='id'
);
CREATE TRIGGER IF NOT EXISTS postings_ai AFTER INSERT ON postings BEGIN
  INSERT INTO postings_fts(rowid, title, employer, description, location)
    VALUES (new.id, new.title, new.employer, new.description, new.location);
END;
CREATE TRIGGER IF NOT EXISTS postings_ad AFTER DELETE ON postings BEGIN
  INSERT INTO postings_fts(postings_fts, rowid, title, employer, description, location)
    VALUES ('delete', old.id, old.title, old.employer, old.description, old.location);
END;
CREATE TRIGGER IF NOT EXISTS postings_au AFTER UPDATE ON postings BEGIN
  INSERT INTO postings_fts(postings_fts, rowid, title, employer, description, location)
    VALUES ('delete', old.id, old.title, old.employer, old.description, old.location);
  INSERT INTO postings_fts(rowid, title, employer, description, location)
    VALUES (new.id, new.title, new.employer, new.description, new.location);
END;
CREATE INDEX IF NOT EXISTS postings_score ON postings (score DESC, last_seen DESC);
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

// upsertPosting scores deterministically, then inserts or refreshes the row
// keyed on the normalized (employer, title) pair: one employer's one role is
// one row, and a reposting only moves last_seen. Returns id, is-new, score.
func upsertPosting(db *sql.DB, p Posting) (int64, bool, error) {
	if p.Source == "" {
		p.Source = "manual"
	}
	lane, score, reasons := scorePosting(p)
	p.Lane, p.Score, p.Reasons = lane, score, reasons
	key := dedupeKey(p.Employer, p.Title)
	if key == "" {
		return 0, false, fmt.Errorf("posting %q/%q has no dedupe key", p.Employer, p.Title)
	}
	reasonsJSON := marshalReasons(reasons)
	now := nowRFC()
	var id int64
	err := db.QueryRow(`SELECT id FROM postings WHERE dedupe_key = ?`, key).Scan(&id)
	switch {
	case err == sql.ErrNoRows:
		res, err := db.Exec(`INSERT INTO postings (title, employer, url, location, source, description, lane, score, reasons, dedupe_key, first_seen, last_seen)
			VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
			p.Title, p.Employer, p.URL, p.Location, p.Source, p.Description, lane, score, reasonsJSON, key, now, now)
		if err != nil {
			return 0, false, err
		}
		id, err = res.LastInsertId()
		if err != nil {
			return 0, false, err
		}
		return id, true, nil
	case err != nil:
		return 0, false, err
	}
	// The row exists: the newest facts win, but first_seen never moves — the
	// dedupe key is the identity, not the posting's birthday.
	_, err = db.Exec(`UPDATE postings SET url = CASE WHEN ? != '' THEN ? ELSE url END,
		location = CASE WHEN ? != '' THEN ? ELSE location END,
		description = CASE WHEN ? != '' THEN ? ELSE description END,
		lane = ?, score = ?, reasons = ?, last_seen = ? WHERE id = ?`,
		p.URL, p.URL, p.Location, p.Location, p.Description, p.Description,
		lane, score, reasonsJSON, now, id)
	return id, false, err
}

const postingCols = `id, title, employer, url, location, source, description, lane, score, reasons, first_seen, last_seen`
const postingColsPrefixed = `p.id, p.title, p.employer, p.url, p.location, p.source, p.description, p.lane, p.score, p.reasons, p.first_seen, p.last_seen`

func scanPostings(rows *sql.Rows) ([]Posting, error) {
	defer rows.Close()
	var out []Posting
	for rows.Next() {
		var p Posting
		var reasons string
		if err := rows.Scan(&p.ID, &p.Title, &p.Employer, &p.URL, &p.Location, &p.Source,
			&p.Description, &p.Lane, &p.Score, &reasons, &p.FirstSeen, &p.LastSeen); err != nil {
			return nil, err
		}
		p.Reasons = unmarshalReasons(reasons)
		out = append(out, p)
	}
	return out, rows.Err()
}

// listPostings is the deduped high-score surface: score desc, newest first,
// one row per dedupe key by construction of the UNIQUE constraint.
func listPostings(db *sql.DB, minScore int, lane string, limit int) ([]Posting, error) {
	q := `SELECT ` + postingCols + ` FROM postings WHERE score >= ?`
	args := []any{minScore}
	if lane != "" {
		q += ` AND lane = ?`
		args = append(args, lane)
	}
	q += ` ORDER BY score DESC, last_seen DESC LIMIT ?`
	args = append(args, limit)
	rows, err := db.Query(q, args...)
	if err != nil {
		return nil, err
	}
	return scanPostings(rows)
}

// searchPostings runs FTS5 over the text and still orders by score: a search
// narrows the surface, it does not re-rank it. Every column carries the table
// prefix — the FTS table shares the column names.
func searchPostings(db *sql.DB, query string, minScore int, limit int) ([]Posting, error) {
	rows, err := db.Query(`SELECT `+postingColsPrefixed+` FROM postings p
		JOIN postings_fts f ON p.id = f.rowid
		WHERE postings_fts MATCH ? AND p.score >= ?
		ORDER BY p.score DESC, p.last_seen DESC LIMIT ?`, ftsQuote(query), minScore, limit)
	if err != nil {
		return nil, err
	}
	return scanPostings(rows)
}

func laneCounts(db *sql.DB) (map[string]int, error) {
	rows, err := db.Query(`SELECT lane, count(*) FROM postings GROUP BY lane`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := map[string]int{}
	for rows.Next() {
		var lane string
		var n int
		if err := rows.Scan(&lane, &n); err != nil {
			return nil, err
		}
		out[lane] = n
	}
	return out, rows.Err()
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
