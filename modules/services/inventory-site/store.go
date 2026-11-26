package main

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"regexp"
	"strings"
	"time"

	_ "modernc.org/sqlite"
)

type Store struct {
	db *sql.DB
}

type itemQueryOptions struct {
	Q               string
	Category        string
	Location        string
	Tag             string
	Source          string
	IncludeArchived bool
	WarrantyWithin  int
	Limit           int
	Offset          int
}

type itemPage struct {
	Items  []Item `json:"items"`
	Total  int    `json:"total"`
	Limit  int    `json:"limit"`
	Offset int    `json:"offset"`
}

type scanner interface {
	Scan(dest ...any) error
}

func OpenStore(path string) (*Store, error) {
	db, err := sql.Open("sqlite", path+"?_pragma=foreign_keys(1)&_pragma=busy_timeout(5000)")
	if err != nil {
		return nil, err
	}
	db.SetMaxOpenConns(1)
	store := &Store{db: db}
	if err := store.migrate(); err != nil {
		db.Close()
		return nil, err
	}
	return store, nil
}

func (s *Store) Close() error { return s.db.Close() }

func (s *Store) migrate() error {
	statements := []string{
		`PRAGMA journal_mode=WAL`,
		`CREATE TABLE IF NOT EXISTS items (
			id INTEGER PRIMARY KEY,
			source TEXT NOT NULL DEFAULT 'manual',
			source_key TEXT,
			name TEXT NOT NULL,
			category TEXT NOT NULL DEFAULT '',
			location TEXT NOT NULL DEFAULT '',
			description TEXT NOT NULL DEFAULT '',
			manufacturer TEXT NOT NULL DEFAULT '',
			model TEXT NOT NULL DEFAULT '',
			serial TEXT NOT NULL DEFAULT '',
			purchase_date TEXT NOT NULL DEFAULT '',
			warranty_until TEXT NOT NULL DEFAULT '',
			value_cents INTEGER NOT NULL DEFAULT 0,
			currency TEXT NOT NULL DEFAULT 'EUR',
			quantity INTEGER NOT NULL DEFAULT 1,
			url TEXT NOT NULL DEFAULT '',
			notes TEXT NOT NULL DEFAULT '',
			archived INTEGER NOT NULL DEFAULT 0,
			created_at TEXT NOT NULL,
			updated_at TEXT NOT NULL,
			UNIQUE(source, source_key)
		)`,
		`CREATE TABLE IF NOT EXISTS categories (
			name TEXT PRIMARY KEY,
			description TEXT NOT NULL DEFAULT '',
			created_at TEXT NOT NULL
		)`,
		`CREATE TABLE IF NOT EXISTS locations (
			name TEXT PRIMARY KEY,
			description TEXT NOT NULL DEFAULT '',
			created_at TEXT NOT NULL
		)`,
		`CREATE TABLE IF NOT EXISTS tags (
			name TEXT PRIMARY KEY,
			description TEXT NOT NULL DEFAULT '',
			created_at TEXT NOT NULL
		)`,
		`CREATE TABLE IF NOT EXISTS item_tags (
			item_id INTEGER NOT NULL REFERENCES items(id) ON DELETE CASCADE,
			tag TEXT NOT NULL REFERENCES tags(name) ON DELETE CASCADE,
			PRIMARY KEY (item_id, tag)
		)`,
		`CREATE VIRTUAL TABLE IF NOT EXISTS inventory_fts USING fts5(
			name, category, location, description, manufacturer, model, serial, notes, tags
		)`,
		`CREATE INDEX IF NOT EXISTS idx_items_category ON items(category)`,
		`CREATE INDEX IF NOT EXISTS idx_items_location ON items(location)`,
		`CREATE INDEX IF NOT EXISTS idx_items_source ON items(source)`,
		`CREATE INDEX IF NOT EXISTS idx_items_serial ON items(serial)`,
		`CREATE INDEX IF NOT EXISTS idx_items_warranty ON items(warranty_until)`,
		`CREATE INDEX IF NOT EXISTS idx_items_updated ON items(updated_at)`,
		`CREATE TABLE IF NOT EXISTS asset_events (
			id INTEGER PRIMARY KEY,
			item_id INTEGER NOT NULL REFERENCES items(id) ON DELETE CASCADE,
			kind TEXT NOT NULL,
			summary TEXT NOT NULL,
			actor TEXT NOT NULL DEFAULT '',
			from_location TEXT NOT NULL DEFAULT '',
			to_location TEXT NOT NULL DEFAULT '',
			note TEXT NOT NULL DEFAULT '',
			created_at TEXT NOT NULL
		)`,
		`CREATE INDEX IF NOT EXISTS idx_asset_events_item ON asset_events(item_id, id DESC)`,
		`CREATE INDEX IF NOT EXISTS idx_asset_events_kind ON asset_events(kind)`,
		`CREATE TABLE IF NOT EXISTS warranty_alerts (
			id INTEGER PRIMARY KEY,
			item_id INTEGER NOT NULL REFERENCES items(id) ON DELETE CASCADE,
			warranty_until TEXT NOT NULL,
			item_name TEXT NOT NULL,
			status TEXT NOT NULL DEFAULT 'pending',
			notify_count INTEGER NOT NULL DEFAULT 0,
			last_notified_at TEXT NOT NULL DEFAULT '',
			last_error TEXT NOT NULL DEFAULT '',
			created_at TEXT NOT NULL,
			updated_at TEXT NOT NULL,
			UNIQUE(item_id, warranty_until)
		)`,
		`CREATE INDEX IF NOT EXISTS idx_warranty_alerts_status ON warranty_alerts(status)`,
		`CREATE INDEX IF NOT EXISTS idx_warranty_alerts_warranty ON warranty_alerts(warranty_until)`,
	}
	for _, statement := range statements {
		if _, err := s.db.Exec(statement); err != nil {
			return fmt.Errorf("migrate: %w", err)
		}
	}
	return nil
}

func nowString() string { return time.Now().UTC().Format(time.RFC3339Nano) }

func parseDBTime(raw string) time.Time {
	for _, layout := range []string{time.RFC3339Nano, time.RFC3339, "2006-01-02 15:04:05"} {
		if parsed, err := time.Parse(layout, raw); err == nil {
			return parsed
		}
	}
	return time.Time{}
}

func scanItem(row scanner) (Item, error) {
	var item Item
	var sourceKey sql.NullString
	var archived int
	var createdAt, updatedAt string
	err := row.Scan(
		&item.ID, &item.Source, &sourceKey, &item.Name, &item.Category, &item.Location,
		&item.Description, &item.Manufacturer, &item.Model, &item.Serial, &item.PurchaseDate,
		&item.WarrantyUntil, &item.ValueCents, &item.Currency, &item.Quantity, &item.URL,
		&item.Notes, &archived, &createdAt, &updatedAt, &item.Snippet,
	)
	if err != nil {
		return item, err
	}
	item.SourceKey = sourceKey.String
	item.Archived = archived != 0
	item.CreatedAt = parseDBTime(createdAt)
	item.UpdatedAt = parseDBTime(updatedAt)
	return item, nil
}

const itemColumns = `i.id, i.source, i.source_key, i.name, i.category, i.location, i.description,
	i.manufacturer, i.model, i.serial, i.purchase_date, i.warranty_until, i.value_cents,
	i.currency, i.quantity, i.url, i.notes, i.archived, i.created_at, i.updated_at`

func (s *Store) attachTags(ctx context.Context, items []Item) error {
	for i := range items {
		rows, err := s.db.QueryContext(ctx, `SELECT tag FROM item_tags WHERE item_id = ? ORDER BY tag`, items[i].ID)
		if err != nil {
			return err
		}
		for rows.Next() {
			var tag string
			if err := rows.Scan(&tag); err != nil {
				rows.Close()
				return err
			}
			items[i].Tags = append(items[i].Tags, tag)
		}
		if err := rows.Close(); err != nil {
			return err
		}
		if items[i].Tags == nil {
			items[i].Tags = []string{}
		}
	}
	return nil
}

func ftsMatch(raw string) string {
	words := regexp.MustCompile(`[\pL\pN_+#.-]+`).FindAllString(strings.ToLower(raw), -1)
	for i, word := range words {
		words[i] = `"` + strings.ReplaceAll(word, `"`, `""`) + `"*`
	}
	return strings.Join(words, " AND ")
}

func (s *Store) ListItems(ctx context.Context, options itemQueryOptions) (itemPage, error) {
	limit := options.Limit
	if limit <= 0 {
		limit = 100
	}
	if limit > 500 {
		limit = 500
	}
	offset := max(options.Offset, 0)
	where := []string{}
	args := []any{}
	from := `FROM items i`
	snippet := `''`
	if strings.TrimSpace(options.Q) != "" {
		match := ftsMatch(options.Q)
		if match == "" {
			return itemPage{Items: []Item{}, Limit: limit, Offset: offset}, nil
		}
		from = `FROM inventory_fts JOIN items i ON i.id = inventory_fts.rowid`
		where = append(where, `inventory_fts MATCH ?`)
		args = append(args, match)
		snippet = `snippet(inventory_fts, -1, '<mark>', '</mark>', '…', 18)`
	}
	filters := []struct {
		column string
		value  string
	}{
		{"i.category", strings.TrimSpace(options.Category)},
		{"i.location", strings.TrimSpace(options.Location)},
		{"i.source", strings.TrimSpace(options.Source)},
	}
	for _, filter := range filters {
		if filter.value != "" {
			where = append(where, filter.column+` = ?`)
			args = append(args, filter.value)
		}
	}
	if strings.TrimSpace(options.Tag) != "" {
		where = append(where, `EXISTS (SELECT 1 FROM item_tags it WHERE it.item_id = i.id AND it.tag = ?)`)
		args = append(args, strings.ToLower(strings.TrimSpace(options.Tag)))
	}
	if !options.IncludeArchived {
		where = append(where, `i.archived = 0`)
	}
	if options.WarrantyWithin > 0 {
		where = append(where, `i.warranty_until != '' AND date(i.warranty_until) >= date('now') AND date(i.warranty_until) <= date('now', '+' || ? || ' days')`)
		args = append(args, options.WarrantyWithin)
	}
	whereSQL := ""
	if len(where) > 0 {
		whereSQL = " WHERE " + strings.Join(where, " AND ")
	}
	var total int
	if err := s.db.QueryRowContext(ctx, `SELECT count(*) `+from+whereSQL, args...).Scan(&total); err != nil {
		return itemPage{}, err
	}
	query := `SELECT ` + itemColumns + `, ` + snippet + ` ` + from + whereSQL + ` ORDER BY i.updated_at DESC, i.id DESC LIMIT ? OFFSET ?`
	queryArgs := append(append([]any{}, args...), limit, offset)
	rows, err := s.db.QueryContext(ctx, query, queryArgs...)
	if err != nil {
		return itemPage{}, err
	}
	defer rows.Close()
	items := []Item{}
	for rows.Next() {
		item, err := scanItem(rows)
		if err != nil {
			return itemPage{}, err
		}
		items = append(items, item)
	}
	if err := rows.Err(); err != nil {
		return itemPage{}, err
	}
	if err := s.attachTags(ctx, items); err != nil {
		return itemPage{}, err
	}
	return itemPage{Items: items, Total: total, Limit: limit, Offset: offset}, nil
}

func nullIfBlank(value string) any {
	if strings.TrimSpace(value) == "" {
		return nil
	}
	return value
}

func (s *Store) findExisting(ctx context.Context, input itemInput) (int64, bool, error) {
	if input.SourceKey == "" {
		return 0, false, nil
	}
	var id int64
	err := s.db.QueryRowContext(ctx, `SELECT id FROM items WHERE source = ? AND source_key = ?`, input.Source, input.SourceKey).Scan(&id)
	if errors.Is(err, sql.ErrNoRows) {
		return 0, false, nil
	}
	return id, err == nil, err
}

func (s *Store) UpsertItem(ctx context.Context, input itemInput) (int64, bool, error) {
	if err := validateItem(&input); err != nil {
		return 0, false, err
	}
	now := nowString()
	existing, found, err := s.findExisting(ctx, input)
	if err != nil {
		return 0, false, err
	}
	var id int64
	var before itemInput
	if found {
		current, getErr := s.GetItem(ctx, existing)
		if getErr != nil {
			return 0, false, getErr
		}
		before = inputFromItem(current)
		id = existing
		_, err = s.db.ExecContext(ctx, `UPDATE items SET name=?, category=?, location=?, description=?, manufacturer=?, model=?, serial=?,
			purchase_date=?, warranty_until=?, value_cents=?, currency=?, quantity=?, url=?, notes=?, archived=?, updated_at=? WHERE id=?`,
			input.Name, input.Category, input.Location, input.Description, input.Manufacturer, input.Model, input.Serial,
			input.PurchaseDate, input.WarrantyUntil, input.ValueCents, input.Currency, input.Quantity, input.URL,
			input.Notes, boolInt(input.Archived), now, id)
	} else {
		result, execErr := s.db.ExecContext(ctx, `INSERT INTO items
			(source, source_key, name, category, location, description, manufacturer, model, serial, purchase_date, warranty_until,
			value_cents, currency, quantity, url, notes, archived, created_at, updated_at)
			VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
			input.Source, nullIfBlank(input.SourceKey), input.Name, input.Category, input.Location, input.Description,
			input.Manufacturer, input.Model, input.Serial, input.PurchaseDate, input.WarrantyUntil, input.ValueCents,
			input.Currency, input.Quantity, input.URL, input.Notes, boolInt(input.Archived), now, now)
		if execErr != nil {
			return 0, false, execErr
		}
		id, err = result.LastInsertId()
	}
	if err != nil {
		return 0, false, err
	}
	if err := s.replaceTagsAndFTS(ctx, id, input); err != nil {
		return 0, false, err
	}
	if input.Category != "" {
		_ = s.UpsertMeta(ctx, "categories", input.Category, "")
	}
	if input.Location != "" {
		_ = s.UpsertMeta(ctx, "locations", input.Location, "")
	}
	s.logAutomaticEvents(ctx, id, !found, before, input)
	return id, !found, nil
}

func boolInt(value bool) int {
	if value {
		return 1
	}
	return 0
}

func (s *Store) replaceTagsAndFTS(ctx context.Context, id int64, input itemInput) error {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()
	if _, err := tx.ExecContext(ctx, `DELETE FROM item_tags WHERE item_id = ?`, id); err != nil {
		return err
	}
	for _, tag := range input.Tags {
		if _, err := tx.ExecContext(ctx, `INSERT OR IGNORE INTO tags(name, created_at) VALUES (?, ?)`, tag, nowString()); err != nil {
			return err
		}
		if _, err := tx.ExecContext(ctx, `INSERT OR IGNORE INTO item_tags(item_id, tag) VALUES (?, ?)`, id, tag); err != nil {
			return err
		}
	}
	if _, err := tx.ExecContext(ctx, `DELETE FROM inventory_fts WHERE rowid = ?`, id); err != nil {
		return err
	}
	if _, err := tx.ExecContext(ctx, `INSERT INTO inventory_fts(rowid, name, category, location, description, manufacturer, model, serial, notes, tags)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`, id, input.Name, input.Category, input.Location, input.Description,
		input.Manufacturer, input.Model, input.Serial, input.Notes, strings.Join(input.Tags, " ")); err != nil {
		return err
	}
	return tx.Commit()
}

func (s *Store) GetItem(ctx context.Context, id int64) (Item, error) {
	row := s.db.QueryRowContext(ctx, `SELECT `+itemColumns+`, '' FROM items i WHERE i.id = ?`, id)
	item, err := scanItem(row)
	if err != nil {
		return item, err
	}
	items := []Item{item}
	if err := s.attachTags(ctx, items); err != nil {
		return item, err
	}
	return items[0], nil
}

func (s *Store) UpdateItem(ctx context.Context, id int64, input itemInput) error {
	current, err := s.GetItem(ctx, id)
	if err != nil {
		return err
	}
	before := inputFromItem(current)
	if input.Source == "" {
		input.Source = current.Source
	}
	if input.SourceKey == "" {
		input.SourceKey = current.SourceKey
	}
	if err := validateItem(&input); err != nil {
		return err
	}
	now := nowString()
	_, err = s.db.ExecContext(ctx, `UPDATE items SET source=?, source_key=?, name=?, category=?, location=?, description=?, manufacturer=?, model=?, serial=?,
		purchase_date=?, warranty_until=?, value_cents=?, currency=?, quantity=?, url=?, notes=?, archived=?, updated_at=? WHERE id=?`,
		input.Source, nullIfBlank(input.SourceKey), input.Name, input.Category, input.Location, input.Description, input.Manufacturer,
		input.Model, input.Serial, input.PurchaseDate, input.WarrantyUntil, input.ValueCents, input.Currency, input.Quantity,
		input.URL, input.Notes, boolInt(input.Archived), now, id)
	if err != nil {
		return err
	}
	if err := s.replaceTagsAndFTS(ctx, id, input); err != nil {
		return err
	}
	if input.Category != "" {
		_ = s.UpsertMeta(ctx, "categories", input.Category, "")
	}
	if input.Location != "" {
		_ = s.UpsertMeta(ctx, "locations", input.Location, "")
	}
	s.logAutomaticEvents(ctx, id, false, before, input)
	return nil
}

func (s *Store) DeleteItem(ctx context.Context, id int64) error {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()
	for _, statement := range []string{`DELETE FROM inventory_fts WHERE rowid = ?`, `DELETE FROM item_tags WHERE item_id = ?`, `DELETE FROM items WHERE id = ?`} {
		if _, err := tx.ExecContext(ctx, statement, id); err != nil {
			return err
		}
	}
	return tx.Commit()
}

func metaTable(name string) (string, error) {
	switch name {
	case "categories", "locations", "tags":
		return name, nil
	default:
		return "", fmt.Errorf("unknown metadata table %q", name)
	}
}

func (s *Store) UpsertMeta(ctx context.Context, table, name, description string) error {
	table, err := metaTable(table)
	if err != nil {
		return err
	}
	name = clean(name)
	if name == "" {
		return fmt.Errorf("name is required")
	}
	_, err = s.db.ExecContext(ctx, `INSERT INTO `+table+`(name, description, created_at) VALUES (?, ?, ?)
		ON CONFLICT(name) DO UPDATE SET description = CASE WHEN excluded.description != '' THEN excluded.description ELSE `+table+`.description END`,
		name, clean(description), nowString())
	return err
}

func (s *Store) DeleteMeta(ctx context.Context, table, name string) error {
	table, err := metaTable(table)
	if err != nil {
		return err
	}
	_, err = s.db.ExecContext(ctx, `DELETE FROM `+table+` WHERE name = ?`, name)
	return err
}

func (s *Store) ListMeta(ctx context.Context, table string) ([]metaEntry, error) {
	table, err := metaTable(table)
	if err != nil {
		return nil, err
	}
	countExpr := "0"
	switch table {
	case "categories":
		countExpr = `(SELECT count(*) FROM items WHERE category = m.name AND archived = 0)`
	case "locations":
		countExpr = `(SELECT count(*) FROM items WHERE location = m.name AND archived = 0)`
	case "tags":
		countExpr = `(SELECT count(*) FROM item_tags it JOIN items i ON i.id = it.item_id WHERE it.tag = m.name AND i.archived = 0)`
	}
	rows, err := s.db.QueryContext(ctx, `SELECT m.name, m.description, m.created_at, `+countExpr+` FROM `+table+` m ORDER BY lower(m.name)`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []metaEntry{}
	for rows.Next() {
		var entry metaEntry
		var created string
		if err := rows.Scan(&entry.Name, &entry.Description, &created, &entry.ItemCount); err != nil {
			return nil, err
		}
		entry.CreatedAt = parseDBTime(created)
		out = append(out, entry)
	}
	return out, rows.Err()
}

func (s *Store) ImportItems(ctx context.Context, inputs []itemInput) (importResult, error) {
	result := importResult{}
	for i, input := range inputs {
		if err := validateItem(&input); err != nil {
			result.Skipped++
			result.Warnings = append(result.Warnings, fmt.Sprintf("row %d: %v", i+1, err))
			continue
		}
		_, created, err := s.UpsertItem(ctx, input)
		if err != nil {
			result.Skipped++
			result.Warnings = append(result.Warnings, fmt.Sprintf("row %d: %v", i+1, err))
			continue
		}
		if created {
			result.Inserted++
		} else {
			result.Updated++
		}
	}
	return result, nil
}

func (s *Store) ExportBundle(ctx context.Context) (exportBundle, error) {
	page, err := s.ListItems(ctx, itemQueryOptions{IncludeArchived: true, Limit: 500})
	if err != nil {
		return exportBundle{}, err
	}
	allItems := append([]Item{}, page.Items...)
	for offset := len(page.Items); offset < page.Total; offset += 500 {
		page, err = s.ListItems(ctx, itemQueryOptions{IncludeArchived: true, Limit: 500, Offset: offset})
		if err != nil {
			return exportBundle{}, err
		}
		allItems = append(allItems, page.Items...)
	}
	categories, err := s.ListMeta(ctx, "categories")
	if err != nil {
		return exportBundle{}, err
	}
	locations, err := s.ListMeta(ctx, "locations")
	if err != nil {
		return exportBundle{}, err
	}
	tags, err := s.ListMeta(ctx, "tags")
	if err != nil {
		return exportBundle{}, err
	}
	return exportBundle{Version: 1, ExportedAt: time.Now().UTC(), Items: allItems, Categories: categories, Locations: locations, Tags: tags}, nil
}

func (s *Store) Stats(ctx context.Context) (map[string]any, error) {
	stats := map[string]any{}
	row := s.db.QueryRowContext(ctx, `SELECT count(*), COALESCE(sum(value_cents * quantity), 0), COALESCE(sum(quantity), 0),
		COALESCE(sum(archived), 0), COALESCE(sum(CASE WHEN warranty_until != '' AND date(warranty_until) >= date('now') AND date(warranty_until) <= date('now', '+90 days') THEN 1 ELSE 0 END), 0)
		FROM items`)
	var total, value, quantity, archived, expiring int
	if err := row.Scan(&total, &value, &quantity, &archived, &expiring); err != nil {
		return nil, err
	}
	stats["items"] = total
	stats["value_cents"] = value
	stats["quantity"] = quantity
	stats["archived"] = archived
	stats["warranty_expiring_90d"] = expiring
	for _, table := range []string{"categories", "locations", "tags"} {
		var count int
		if err := s.db.QueryRowContext(ctx, `SELECT count(*) FROM `+table).Scan(&count); err != nil {
			return nil, err
		}
		stats[table] = count
	}
	var withSerial, withValue int
	if err := s.db.QueryRowContext(ctx, `SELECT count(*) FROM items WHERE serial != ''`).Scan(&withSerial); err != nil {
		return nil, err
	}
	if err := s.db.QueryRowContext(ctx, `SELECT count(*) FROM items WHERE value_cents > 0`).Scan(&withValue); err != nil {
		return nil, err
	}
	stats["with_serial"] = withSerial
	stats["with_value"] = withValue
	return stats, nil
}
