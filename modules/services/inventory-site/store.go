// SQLite/FTS5 store for the asset inventory: items with location, category,
// tags, serials, warranty and value.
//
// modernc.org/sqlite (pure Go, FTS5 compiled in) so the fleet's CGO_ENABLED=0
// build holds; the same dep and version as the agent-turns shim.
package main

import (
	"database/sql"
	"fmt"
	"strings"
	"time"

	_ "modernc.org/sqlite"
)

type Item struct {
	ID            int64    `json:"id"`
	Name          string   `json:"name"`
	Description   string   `json:"description"`
	Location      string   `json:"location"`
	Category      string   `json:"category"`
	Serial        string   `json:"serial"`
	PurchaseDate  string   `json:"purchase_date"`
	WarrantyUntil string   `json:"warranty_until"`
	ValueCents    int64    `json:"value_cents"`
	Currency      string   `json:"currency"`
	Notes         string   `json:"notes"`
	Tags          []string `json:"tags"`
	Created       string   `json:"created"`
	Updated       string   `json:"updated"`
}

const schema = `
CREATE TABLE IF NOT EXISTS items (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  location TEXT NOT NULL DEFAULT '',
  category TEXT NOT NULL DEFAULT '',
  serial TEXT NOT NULL DEFAULT '',
  purchase_date TEXT NOT NULL DEFAULT '',
  warranty_until TEXT NOT NULL DEFAULT '',
  value_cents INTEGER NOT NULL DEFAULT 0,
  currency TEXT NOT NULL DEFAULT 'EUR',
  notes TEXT NOT NULL DEFAULT '',
  created TEXT NOT NULL,
  updated TEXT NOT NULL,
  UNIQUE(name, serial)
);
CREATE VIRTUAL TABLE IF NOT EXISTS items_fts USING fts5(
  name, description, location, category, serial, notes, tags,
  content='items', content_rowid='id'
);
CREATE TRIGGER IF NOT EXISTS items_ai AFTER INSERT ON items BEGIN
  INSERT INTO items_fts(rowid, name, description, location, category, serial, notes, tags)
    VALUES (new.id, new.name, new.description, new.location, new.category, new.serial, new.notes,
      (SELECT group_concat(tag, ' ') FROM item_tags WHERE item_id = new.id));
END;
CREATE TRIGGER IF NOT EXISTS items_ad AFTER DELETE ON items BEGIN
  INSERT INTO items_fts(items_fts, rowid, name, description, location, category, serial, notes, tags)
    VALUES ('delete', old.id, old.name, old.description, old.location, old.category, old.serial, old.notes, '');
END;
CREATE TRIGGER IF NOT EXISTS items_au AFTER UPDATE ON items BEGIN
  INSERT INTO items_fts(items_fts, rowid, name, description, location, category, serial, notes, tags)
    VALUES ('delete', old.id, old.name, old.description, old.location, old.category, old.serial, old.notes, '');
  INSERT INTO items_fts(rowid, name, description, location, category, serial, notes, tags)
    VALUES (new.id, new.name, new.description, new.location, new.category, new.serial, new.notes,
      (SELECT group_concat(tag, ' ') FROM item_tags WHERE item_id = new.id));
END;
CREATE TABLE IF NOT EXISTS item_tags (
  item_id INTEGER NOT NULL REFERENCES items(id) ON DELETE CASCADE,
  tag TEXT NOT NULL,
  PRIMARY KEY (item_id, tag)
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

func normTags(tags []string) []string {
	seen := map[string]bool{}
	var out []string
	for _, t := range tags {
		t = strings.TrimSpace(strings.ToLower(t))
		if t != "" && !seen[t] {
			seen[t] = true
			out = append(out, t)
		}
	}
	return out
}

func setTags(db *sql.DB, id int64, tags []string) error {
	if _, err := db.Exec(`DELETE FROM item_tags WHERE item_id = ?`, id); err != nil {
		return err
	}
	for _, t := range normTags(tags) {
		if _, err := db.Exec(`INSERT OR IGNORE INTO item_tags (item_id, tag) VALUES (?, ?)`, id, t); err != nil {
			return err
		}
	}
	return nil
}

// upsertItem inserts an item or updates the row sharing (name, serial). The
// FTS row is maintained by trigger; tags are replaced wholesale when given.
// Returns the id and whether the row was new.
func upsertItem(db *sql.DB, it Item) (int64, bool, error) {
	if it.Currency == "" {
		it.Currency = "EUR"
	}
	now := nowRFC()
	var id int64
	err := db.QueryRow(`SELECT id FROM items WHERE name = ? AND serial = ?`, it.Name, it.Serial).Scan(&id)
	switch {
	case err == sql.ErrNoRows:
		res, err := db.Exec(`INSERT INTO items (name, description, location, category, serial, purchase_date, warranty_until, value_cents, currency, notes, created, updated)
			VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
			it.Name, it.Description, it.Location, it.Category, it.Serial, it.PurchaseDate, it.WarrantyUntil, it.ValueCents, it.Currency, it.Notes, now, now)
		if err != nil {
			return 0, false, err
		}
		id, err = res.LastInsertId()
		if err != nil {
			return 0, false, err
		}
		if err := setTags(db, id, it.Tags); err != nil {
			return 0, false, err
		}
		// Tags land after the insert trigger ran, so refresh the FTS row.
		if err := refreshFTS(db, id); err != nil {
			return 0, false, err
		}
		return id, true, nil
	case err != nil:
		return 0, false, err
	}
	_, err = db.Exec(`UPDATE items SET description = ?, location = ?, category = ?, purchase_date = ?, warranty_until = ?,
		value_cents = CASE WHEN ? > 0 THEN ? ELSE value_cents END, currency = ?, notes = ?, updated = ? WHERE id = ?`,
		it.Description, it.Location, it.Category, it.PurchaseDate, it.WarrantyUntil, it.ValueCents, it.ValueCents, it.Currency, it.Notes, now, id)
	if err != nil {
		return id, false, err
	}
	if err := setTags(db, id, it.Tags); err != nil {
		return id, false, err
	}
	if err := refreshFTS(db, id); err != nil {
		return id, false, err
	}
	return id, false, nil
}

// refreshFTS rewrites one row's FTS entry: the insert/update triggers fire
// before setTags replaces item_tags, so the tag text must be re-indexed after.
func refreshFTS(db *sql.DB, id int64) error {
	_, err := db.Exec(`INSERT INTO items_fts(items_fts, rowid, name, description, location, category, serial, notes, tags)
		SELECT 'delete', i.id, i.name, i.description, i.location, i.category, i.serial, i.notes, ''
		FROM items i WHERE i.id = ?`, id)
	if err != nil {
		return err
	}
	_, err = db.Exec(`INSERT INTO items_fts(rowid, name, description, location, category, serial, notes, tags)
		SELECT i.id, i.name, i.description, i.location, i.category, i.serial, i.notes,
			COALESCE((SELECT group_concat(tag, ' ') FROM item_tags WHERE item_id = i.id), '')
		FROM items i WHERE i.id = ?`, id)
	return err
}

const itemCols = `id, name, description, location, category, serial, purchase_date, warranty_until, value_cents, currency, notes, created, updated`
const itemColsPrefixed = `i.id, i.name, i.description, i.location, i.category, i.serial, i.purchase_date, i.warranty_until, i.value_cents, i.currency, i.notes, i.created, i.updated`

func scanItems(db *sql.DB, rows *sql.Rows) ([]Item, error) {
	defer rows.Close()
	var out []Item
	for rows.Next() {
		var it Item
		if err := rows.Scan(&it.ID, &it.Name, &it.Description, &it.Location, &it.Category, &it.Serial,
			&it.PurchaseDate, &it.WarrantyUntil, &it.ValueCents, &it.Currency, &it.Notes, &it.Created, &it.Updated); err != nil {
			return nil, err
		}
		tags, err := itemTags(db, it.ID)
		if err != nil {
			return nil, err
		}
		it.Tags = tags
		out = append(out, it)
	}
	return out, rows.Err()
}

func itemTags(db *sql.DB, id int64) ([]string, error) {
	rows, err := db.Query(`SELECT tag FROM item_tags WHERE item_id = ? ORDER BY tag`, id)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []string{}
	for rows.Next() {
		var t string
		if err := rows.Scan(&t); err != nil {
			return nil, err
		}
		out = append(out, t)
	}
	return out, rows.Err()
}

func listItems(db *sql.DB, limit int) ([]Item, error) {
	rows, err := db.Query(`SELECT `+itemCols+` FROM items ORDER BY updated DESC LIMIT ?`, limit)
	if err != nil {
		return nil, err
	}
	return scanItems(db, rows)
}

func filterItems(db *sql.DB, location, category, tag string, limit int) ([]Item, error) {
	q := `SELECT DISTINCT ` + itemColsPrefixed + ` FROM items i LEFT JOIN item_tags t ON t.item_id = i.id WHERE 1=1`
	var args []any
	if location != "" {
		q += ` AND i.location = ?`
		args = append(args, location)
	}
	if category != "" {
		q += ` AND i.category = ?`
		args = append(args, category)
	}
	if tag != "" {
		q += ` AND t.tag = ?`
		args = append(args, strings.ToLower(tag))
	}
	q += ` ORDER BY i.updated DESC LIMIT ?`
	args = append(args, limit)
	rows, err := db.Query(q, args...)
	if err != nil {
		return nil, err
	}
	return scanItems(db, rows)
}

// searchItems runs an FTS5 MATCH query; a bare word query is quoted per token
// so user input cannot break the MATCH syntax. Every column in the join
// carries the table prefix — the FTS table shares the column names.
func searchItems(db *sql.DB, q string, limit int) ([]Item, error) {
	rows, err := db.Query(`SELECT `+itemColsPrefixed+` FROM items i
		JOIN items_fts f ON i.id = f.rowid
		WHERE items_fts MATCH ?
		ORDER BY rank LIMIT ?`, ftsQuote(q), limit)
	if err != nil {
		return nil, err
	}
	return scanItems(db, rows)
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

func getItem(db *sql.DB, id int64) (*Item, error) {
	var it Item
	err := db.QueryRow(`SELECT `+itemCols+` FROM items WHERE id = ?`, id).
		Scan(&it.ID, &it.Name, &it.Description, &it.Location, &it.Category, &it.Serial,
			&it.PurchaseDate, &it.WarrantyUntil, &it.ValueCents, &it.Currency, &it.Notes, &it.Created, &it.Updated)
	if err != nil {
		return nil, err
	}
	tags, err := itemTags(db, id)
	if err != nil {
		return nil, err
	}
	it.Tags = tags
	return &it, nil
}

func deleteItem(db *sql.DB, id int64) error {
	res, err := db.Exec(`DELETE FROM items WHERE id = ?`, id)
	if err != nil {
		return err
	}
	n, err := res.RowsAffected()
	if err != nil {
		return err
	}
	if n == 0 {
		return sql.ErrNoRows
	}
	return nil
}

func facets(db *sql.DB) (locations, categories, tags []string, err error) {
	collect := func(q string) ([]string, error) {
		rows, err := db.Query(q)
		if err != nil {
			return nil, err
		}
		defer rows.Close()
		out := []string{}
		for rows.Next() {
			var s string
			if err := rows.Scan(&s); err != nil {
				return nil, err
			}
			out = append(out, s)
		}
		return out, rows.Err()
	}
	if locations, err = collect(`SELECT DISTINCT location FROM items WHERE location != '' ORDER BY location`); err != nil {
		return nil, nil, nil, err
	}
	if categories, err = collect(`SELECT DISTINCT category FROM items WHERE category != '' ORDER BY category`); err != nil {
		return nil, nil, nil, err
	}
	if tags, err = collect(`SELECT DISTINCT tag FROM item_tags ORDER BY tag`); err != nil {
		return nil, nil, nil, err
	}
	return locations, categories, tags, nil
}
