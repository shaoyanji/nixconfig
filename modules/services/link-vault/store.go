package main

import (
	"context"
	"database/sql"
	"fmt"
	"strings"
	"time"

	_ "modernc.org/sqlite"
)

type Store struct {
	db *sql.DB
}

type ListOptions struct {
	Query      string
	State      string
	Collection string
	Tag        string
	Limit      int
	Offset     int
	All        bool
}

func OpenStore(path string) (*Store, error) {
	db, err := sql.Open("sqlite", path)
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
		`PRAGMA foreign_keys=ON`,
		`CREATE TABLE IF NOT EXISTS collections (
			id INTEGER PRIMARY KEY,
			name TEXT NOT NULL UNIQUE,
			description TEXT NOT NULL DEFAULT '',
			created_at TEXT NOT NULL,
			updated_at TEXT NOT NULL
		)`,
		`CREATE TABLE IF NOT EXISTS links (
			id INTEGER PRIMARY KEY,
			fingerprint TEXT NOT NULL UNIQUE,
			url TEXT NOT NULL,
			canonical_url TEXT NOT NULL,
			title TEXT NOT NULL DEFAULT '',
			description TEXT NOT NULL DEFAULT '',
			content TEXT NOT NULL DEFAULT '',
			excerpt TEXT NOT NULL DEFAULT '',
			site_name TEXT NOT NULL DEFAULT '',
			source TEXT NOT NULL DEFAULT 'manual',
			state TEXT NOT NULL DEFAULT 'unread',
			tags TEXT NOT NULL DEFAULT '[]',
			collection_id INTEGER REFERENCES collections(id) ON DELETE SET NULL,
			extraction_status TEXT NOT NULL DEFAULT 'never',
			extraction_error TEXT NOT NULL DEFAULT '',
			extracted_at TEXT NOT NULL DEFAULT '',
			created_at TEXT NOT NULL,
			updated_at TEXT NOT NULL
		)`,
		`CREATE VIRTUAL TABLE IF NOT EXISTS links_fts USING fts5(title, description, content, excerpt, site_name, tags, tokenize='unicode61')`,
		`CREATE INDEX IF NOT EXISTS idx_links_state ON links(state, updated_at DESC)`,
		`CREATE INDEX IF NOT EXISTS idx_links_collection ON links(collection_id, updated_at DESC)`,
		`CREATE INDEX IF NOT EXISTS idx_links_source ON links(source)`,
		`CREATE INDEX IF NOT EXISTS idx_links_updated ON links(updated_at DESC)`,
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
	t, _ := time.Parse(time.RFC3339Nano, raw)
	return t
}

func (s *Store) EnsureCollection(ctx context.Context, name, description string) (int64, error) {
	name = cleanSpace(name)
	if name == "" {
		return 0, nil
	}
	now := nowString()
	if _, err := s.db.ExecContext(ctx, `INSERT INTO collections(name, description, created_at, updated_at) VALUES(?,?,?,?) ON CONFLICT(name) DO NOTHING`, name, cleanSpace(description), now, now); err != nil {
		return 0, err
	}
	var id int64
	if err := s.db.QueryRowContext(ctx, `SELECT id FROM collections WHERE name=?`, name).Scan(&id); err != nil {
		return 0, err
	}
	return id, nil
}

func (s *Store) Collections(ctx context.Context) ([]Collection, error) {
	rows, err := s.db.QueryContext(ctx, `SELECT c.id,c.name,c.description,c.created_at,c.updated_at,COUNT(l.id) FROM collections c LEFT JOIN links l ON l.collection_id=c.id GROUP BY c.id ORDER BY lower(c.name)`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []Collection{}
	for rows.Next() {
		var c Collection
		var created, updated string
		if err := rows.Scan(&c.ID, &c.Name, &c.Description, &created, &updated, &c.Links); err != nil {
			return nil, err
		}
		c.CreatedAt = parseDBTime(created)
		c.UpdatedAt = parseDBTime(updated)
		out = append(out, c)
	}
	return out, rows.Err()
}

func (s *Store) UpsertLink(ctx context.Context, input LinkInput) (Link, bool, error) {
	if err := validateInput(&input); err != nil {
		return Link{}, false, err
	}
	var collectionID any
	if input.Collection != "" {
		id, err := s.EnsureCollection(ctx, input.Collection, "")
		if err != nil {
			return Link{}, false, err
		}
		collectionID = id
	}
	canonical, _ := canonicalURL(input.URL)
	fingerprint := fingerprintURL(canonical)
	now := nowString()
	excerpt := input.Excerpt
	if excerpt == "" {
		excerpt = excerptOf(firstNonEmptyString(input.Description, input.Content), 280)
	}
	result, err := s.db.ExecContext(ctx, `INSERT INTO links(fingerprint,url,canonical_url,title,description,content,excerpt,site_name,source,state,tags,collection_id,extraction_status,created_at,updated_at)
		VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
		ON CONFLICT(fingerprint) DO UPDATE SET
			url=excluded.url,
			title=CASE WHEN excluded.title!='' THEN excluded.title ELSE links.title END,
			description=CASE WHEN excluded.description!='' THEN excluded.description ELSE links.description END,
			content=CASE WHEN excluded.content!='' THEN excluded.content ELSE links.content END,
			excerpt=CASE WHEN excluded.excerpt!='' THEN excluded.excerpt ELSE links.excerpt END,
			site_name=CASE WHEN excluded.site_name!='' THEN excluded.site_name ELSE links.site_name END,
			state=excluded.state,
			tags=excluded.tags,
			collection_id=excluded.collection_id,
			updated_at=excluded.updated_at`,
		fingerprint, canonical, canonical, input.Title, input.Description, input.Content, excerpt, input.SiteName, input.Source, input.State, tagsJSON(input.Tags), collectionID, "never", now, now)
	if err != nil {
		return Link{}, false, err
	}
	var id int64
	var createdAt, updatedAt string
	if err := s.db.QueryRowContext(ctx, `SELECT id, created_at, updated_at FROM links WHERE fingerprint=?`, fingerprint).Scan(&id, &createdAt, &updatedAt); err != nil {
		return Link{}, false, err
	}
	created := createdAt == updatedAt
	if affected, _ := result.RowsAffected(); affected == 0 {
		created = false
	}
	link, err := s.Link(ctx, id)
	if err != nil {
		return Link{}, false, err
	}
	if err := s.indexLink(ctx, link); err != nil {
		return Link{}, false, err
	}
	return link, created, nil
}

func scanLink(row interface{ Scan(...any) error }) (Link, error) {
	var link Link
	var tags, created, updated string
	var collectionID sql.NullInt64
	var collectionName sql.NullString
	err := row.Scan(&link.ID, &link.URL, &link.CanonicalURL, &link.Title, &link.Description, &link.Content, &link.Excerpt, &link.SiteName, &link.Source, &link.State, &tags, &collectionID, &collectionName, &link.ExtractionStatus, &link.ExtractionError, &link.ExtractedAt, &created, &updated)
	if err != nil {
		return Link{}, err
	}
	link.Tags = parseTags(tags)
	if collectionID.Valid {
		link.CollectionID = collectionID.Int64
	}
	if collectionName.Valid {
		link.CollectionName = collectionName.String
	}
	link.CreatedAt = parseDBTime(created)
	link.UpdatedAt = parseDBTime(updated)
	return link, nil
}

const linkSelect = `SELECT l.id,l.url,l.canonical_url,l.title,l.description,l.content,l.excerpt,l.site_name,l.source,l.state,l.tags,l.collection_id,c.name,l.extraction_status,l.extraction_error,l.extracted_at,l.created_at,l.updated_at FROM links l LEFT JOIN collections c ON c.id=l.collection_id`

func (s *Store) Link(ctx context.Context, id int64) (Link, error) {
	return scanLink(s.db.QueryRowContext(ctx, linkSelect+` WHERE l.id=?`, id))
}

func ftsMatch(raw string) string {
	terms := strings.Fields(raw)
	quoted := make([]string, 0, len(terms))
	for _, term := range terms {
		term = strings.Trim(term, `"`)
		if term != "" {
			quoted = append(quoted, `"`+strings.ReplaceAll(term, `"`, `""`)+`"`)
		}
	}
	return strings.Join(quoted, " AND ")
}

func (s *Store) ListLinks(ctx context.Context, opts ListOptions) ([]Link, error) {
	if opts.Limit <= 0 || opts.Limit > 500 {
		opts.Limit = 100
	}
	where := []string{}
	args := []any{}
	if query := strings.TrimSpace(opts.Query); query != "" {
		where = append(where, `l.id IN (SELECT rowid FROM links_fts WHERE links_fts MATCH ?)`)
		args = append(args, ftsMatch(query))
	}
	if state := strings.ToLower(strings.TrimSpace(opts.State)); state != "" && state != "all" {
		where = append(where, `l.state=?`)
		args = append(args, state)
	}
	if collection := strings.TrimSpace(opts.Collection); collection != "" {
		where = append(where, `c.name=?`)
		args = append(args, collection)
	}
	if tag := strings.ToLower(strings.TrimSpace(opts.Tag)); tag != "" {
		where = append(where, `EXISTS (SELECT 1 FROM json_each(l.tags) WHERE lower(value)=?)`)
		args = append(args, tag)
	}
	sqlText := linkSelect
	if len(where) > 0 {
		sqlText += ` WHERE ` + strings.Join(where, ` AND `)
	}
	sqlText += ` ORDER BY l.updated_at DESC`
	if !opts.All {
		sqlText += ` LIMIT ? OFFSET ?`
		args = append(args, opts.Limit, opts.Offset)
	}
	rows, err := s.db.QueryContext(ctx, sqlText, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []Link{}
	for rows.Next() {
		link, err := scanLink(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, link)
	}
	return out, rows.Err()
}

func (s *Store) indexLink(ctx context.Context, link Link) error {
	if _, err := s.db.ExecContext(ctx, `DELETE FROM links_fts WHERE rowid=?`, link.ID); err != nil {
		return err
	}
	_, err := s.db.ExecContext(ctx, `INSERT INTO links_fts(rowid,title,description,content,excerpt,site_name,tags) VALUES(?,?,?,?,?,?,?)`, link.ID, link.Title, link.Description, link.Content, link.Excerpt, link.SiteName, tagsJSON(link.Tags))
	return err
}

func (s *Store) UpdateLinkState(ctx context.Context, id int64, state string) error {
	state, err := normalizeState(state)
	if err != nil {
		return err
	}
	result, err := s.db.ExecContext(ctx, `UPDATE links SET state=?, updated_at=? WHERE id=?`, state, nowString(), id)
	if err != nil {
		return err
	}
	if affected, _ := result.RowsAffected(); affected == 0 {
		return sql.ErrNoRows
	}
	return nil
}

func (s *Store) UpdateExtraction(ctx context.Context, id int64, result ExtractionResult, status, errText string) error {
	if status == "" {
		status = "ok"
	}
	if result.Title != "" || result.Content != "" {
		_, err := s.db.ExecContext(ctx, `UPDATE links SET title=CASE WHEN ?!='' THEN ? ELSE title END, description=CASE WHEN ?!='' THEN ? ELSE description END, content=CASE WHEN ?!='' THEN ? ELSE content END, excerpt=CASE WHEN ?!='' THEN ? ELSE excerpt END, site_name=CASE WHEN ?!='' THEN ? ELSE site_name END, extraction_status=?, extraction_error=?, extracted_at=?, updated_at=? WHERE id=?`, result.Title, result.Title, result.Description, result.Description, result.Content, result.Content, result.Excerpt, result.Excerpt, result.SiteName, result.SiteName, status, errText, nowString(), nowString(), id)
		if err != nil {
			return err
		}
	} else {
		_, err := s.db.ExecContext(ctx, `UPDATE links SET extraction_status=?, extraction_error=?, extracted_at=?, updated_at=? WHERE id=?`, status, errText, nowString(), nowString(), id)
		if err != nil {
			return err
		}
	}
	link, err := s.Link(ctx, id)
	if err != nil {
		return err
	}
	return s.indexLink(ctx, link)
}

func (s *Store) DeleteLink(ctx context.Context, id int64) error {
	if _, err := s.db.ExecContext(ctx, `DELETE FROM links_fts WHERE rowid=?`, id); err != nil {
		return err
	}
	result, err := s.db.ExecContext(ctx, `DELETE FROM links WHERE id=?`, id)
	if err != nil {
		return err
	}
	if affected, _ := result.RowsAffected(); affected == 0 {
		return sql.ErrNoRows
	}
	return nil
}

func (s *Store) Tags(ctx context.Context) ([]string, error) {
	rows, err := s.db.QueryContext(ctx, `SELECT DISTINCT lower(value) FROM links, json_each(links.tags) ORDER BY 1`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []string{}
	for rows.Next() {
		var tag string
		if err := rows.Scan(&tag); err != nil {
			return nil, err
		}
		if tag != "" {
			out = append(out, tag)
		}
	}
	return out, rows.Err()
}

func (s *Store) Stats(ctx context.Context) (map[string]int64, error) {
	stats := map[string]int64{}
	queries := map[string]string{
		"bookmarks":         `SELECT COUNT(*) FROM links`,
		"unread":            `SELECT COUNT(*) FROM links WHERE state='unread'`,
		"read":              `SELECT COUNT(*) FROM links WHERE state='read'`,
		"archived":          `SELECT COUNT(*) FROM links WHERE state='archived'`,
		"collections":       `SELECT COUNT(*) FROM collections`,
		"extracted":         `SELECT COUNT(*) FROM links WHERE extraction_status='ok'`,
		"extraction_failed": `SELECT COUNT(*) FROM links WHERE extraction_status='error'`,
	}
	for key, query := range queries {
		var value int64
		if err := s.db.QueryRowContext(ctx, query).Scan(&value); err != nil {
			return nil, err
		}
		stats[key] = value
	}
	tags, err := s.Tags(ctx)
	if err != nil {
		return nil, err
	}
	stats["tags"] = int64(len(tags))
	return stats, nil
}

func firstNonEmptyString(values ...string) string {
	for _, value := range values {
		if strings.TrimSpace(value) != "" {
			return value
		}
	}
	return ""
}

func (s *Store) ExportMarkdown(ctx context.Context) (string, error) {
	links, err := s.ListLinks(ctx, ListOptions{All: true})
	if err != nil {
		return "", err
	}
	var b strings.Builder
	b.WriteString("# Link vault export\n\n")
	for _, link := range links {
		title := link.Title
		if title == "" {
			title = link.URL
		}
		fmt.Fprintf(&b, "## [%s](%s)\n\n", strings.ReplaceAll(title, "]", "\\]"), link.URL)
		fmt.Fprintf(&b, "- state: `%s`\n- source: `%s`\n", link.State, link.Source)
		if link.CollectionName != "" {
			fmt.Fprintf(&b, "- collection: `%s`\n", link.CollectionName)
		}
		if len(link.Tags) > 0 {
			fmt.Fprintf(&b, "- tags: `%s`\n", strings.Join(link.Tags, "`, `"))
		}
		if link.Description != "" {
			fmt.Fprintf(&b, "\n%s\n", link.Description)
		} else if link.Excerpt != "" {
			fmt.Fprintf(&b, "\n%s\n", link.Excerpt)
		}
		b.WriteString("\n")
	}
	return b.String(), nil
}
