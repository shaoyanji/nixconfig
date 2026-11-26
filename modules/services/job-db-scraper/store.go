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

type queryOptions struct {
	Q        string
	Source   string
	Company  string
	Location string
	Remote   bool
	Active   bool
	Days     int
	Limit    int
	Offset   int
}

type postingsPage struct {
	Items  []Posting `json:"items"`
	Total  int       `json:"total"`
	Limit  int       `json:"limit"`
	Offset int       `json:"offset"`
	Q      string    `json:"q"`
}

type runRecord struct {
	ID         int64     `json:"id"`
	StartedAt  time.Time `json:"started_at"`
	FinishedAt time.Time `json:"finished_at"`
	Source     string    `json:"source"`
	Status     string    `json:"status"`
	Fetched    int       `json:"fetched"`
	Inserted   int       `json:"inserted"`
	Updated    int       `json:"updated"`
	Error      string    `json:"error,omitempty"`
}

type sourceState struct {
	Source        string `json:"source"`
	LastRunAt     string `json:"last_run_at,omitempty"`
	LastStatus    string `json:"last_status,omitempty"`
	LastError     string `json:"last_error,omitempty"`
	TotalFetched  int    `json:"total_fetched"`
	TotalInserted int    `json:"total_inserted"`
	TotalUpdated  int    `json:"total_updated"`
	Postings      int    `json:"postings"`
}

type countRow struct {
	Name  string `json:"name"`
	Count int    `json:"count"`
}

type statsPayload struct {
	TotalPostings  int        `json:"total_postings"`
	ActivePostings int        `json:"active_postings"`
	Companies      int        `json:"companies"`
	Sources        int        `json:"sources"`
	Remote         int        `json:"remote"`
	Last7Days      int        `json:"last_7_days"`
	TopSources     []countRow `json:"top_sources"`
	TopCompanies   []countRow `json:"top_companies"`
	Locations      []countRow `json:"locations"`
	LatestRun      *runRecord `json:"latest_run,omitempty"`
	GeneratedAt    time.Time  `json:"generated_at"`
}

func OpenStore(path string) (*Store, error) {
	dsn := fmt.Sprintf("file:%s?_pragma=busy_timeout(5000)&_pragma=journal_mode(WAL)&_pragma=foreign_keys(1)", path)
	db, err := sql.Open("sqlite", dsn)
	if err != nil {
		return nil, err
	}
	db.SetMaxOpenConns(1)
	db.SetMaxIdleConns(1)
	s := &Store{db: db}
	if err := s.migrate(); err != nil {
		db.Close()
		return nil, err
	}
	return s, nil
}

func (s *Store) Close() error { return s.db.Close() }

func (s *Store) migrate() error {
	stmts := []string{
		`CREATE TABLE IF NOT EXISTS postings (
			id INTEGER PRIMARY KEY,
			fingerprint TEXT NOT NULL UNIQUE,
			canonical_url TEXT NOT NULL,
			url TEXT NOT NULL,
			source TEXT NOT NULL,
			company TEXT NOT NULL,
			company_key TEXT NOT NULL,
			title TEXT NOT NULL,
			location TEXT NOT NULL,
			remote INTEGER NOT NULL DEFAULT 0,
			employment TEXT NOT NULL DEFAULT '',
			description TEXT NOT NULL DEFAULT '',
			tags TEXT NOT NULL DEFAULT '[]',
			posted_at TEXT NOT NULL DEFAULT '',
			first_seen TEXT NOT NULL,
			last_seen TEXT NOT NULL,
			seen_count INTEGER NOT NULL DEFAULT 1,
			active INTEGER NOT NULL DEFAULT 1,
			salary TEXT NOT NULL DEFAULT ''
		)`,
		`CREATE INDEX IF NOT EXISTS postings_source_idx ON postings(source)`,
		`CREATE INDEX IF NOT EXISTS postings_company_idx ON postings(company_key)`,
		`CREATE INDEX IF NOT EXISTS postings_posted_idx ON postings(posted_at)`,
		`CREATE INDEX IF NOT EXISTS postings_last_seen_idx ON postings(last_seen)`,
		`CREATE INDEX IF NOT EXISTS postings_canonical_idx ON postings(canonical_url)`,
		`CREATE VIRTUAL TABLE IF NOT EXISTS postings_fts USING fts5(
			title, company, location, description, tags,
			content='postings', content_rowid='id'
		)`,
		`CREATE TRIGGER IF NOT EXISTS postings_ai AFTER INSERT ON postings BEGIN
			INSERT INTO postings_fts(rowid, title, company, location, description, tags)
			VALUES (new.id, new.title, new.company, new.location, new.description, new.tags);
		END`,
		`CREATE TRIGGER IF NOT EXISTS postings_ad AFTER DELETE ON postings BEGIN
			INSERT INTO postings_fts(postings_fts, rowid, title, company, location, description, tags)
			VALUES('delete', old.id, old.title, old.company, old.location, old.description, old.tags);
		END`,
		`CREATE TRIGGER IF NOT EXISTS postings_au AFTER UPDATE ON postings BEGIN
			INSERT INTO postings_fts(postings_fts, rowid, title, company, location, description, tags)
			VALUES('delete', old.id, old.title, old.company, old.location, old.description, old.tags);
			INSERT INTO postings_fts(rowid, title, company, location, description, tags)
			VALUES (new.id, new.title, new.company, new.location, new.description, new.tags);
		END`,
		`CREATE TABLE IF NOT EXISTS scrape_runs (
			id INTEGER PRIMARY KEY,
			started_at TEXT NOT NULL,
			finished_at TEXT NOT NULL DEFAULT '',
			source TEXT NOT NULL,
			status TEXT NOT NULL,
			fetched INTEGER NOT NULL DEFAULT 0,
			inserted INTEGER NOT NULL DEFAULT 0,
			updated INTEGER NOT NULL DEFAULT 0,
			error TEXT NOT NULL DEFAULT ''
		)`,
		`CREATE INDEX IF NOT EXISTS scrape_runs_started_idx ON scrape_runs(started_at DESC)`,
		`CREATE TABLE IF NOT EXISTS source_state (
			source TEXT PRIMARY KEY,
			last_run_at TEXT NOT NULL DEFAULT '',
			last_status TEXT NOT NULL DEFAULT '',
			last_error TEXT NOT NULL DEFAULT '',
			total_fetched INTEGER NOT NULL DEFAULT 0,
			total_inserted INTEGER NOT NULL DEFAULT 0,
			total_updated INTEGER NOT NULL DEFAULT 0
		)`,
	}
	for _, stmt := range stmts {
		if _, err := s.db.Exec(stmt); err != nil {
			return fmt.Errorf("migrate: %w", err)
		}
	}
	var ftsRows, postingRows int
	_ = s.db.QueryRow(`SELECT count(*) FROM postings_fts`).Scan(&ftsRows)
	_ = s.db.QueryRow(`SELECT count(*) FROM postings`).Scan(&postingRows)
	if postingRows > 0 && ftsRows == 0 {
		if _, err := s.db.Exec(`INSERT INTO postings_fts(postings_fts) VALUES('rebuild')`); err != nil {
			return fmt.Errorf("rebuild fts: %w", err)
		}
	}
	return nil
}

func (s *Store) UpsertPosting(ctx context.Context, in postingInput) (int64, bool, error) {
	p := newPosting(in)
	if !validPosting(p) {
		return 0, false, errors.New("posting needs a source, company and title")
	}
	now := time.Now().UTC()
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return 0, false, err
	}
	defer tx.Rollback()

	var id, seen int64
	var existingDescription string
	row := tx.QueryRowContext(ctx, `
		SELECT id, seen_count, description FROM postings
		WHERE fingerprint = ? OR (canonical_url != '' AND canonical_url = ?)
		ORDER BY CASE WHEN canonical_url = ? THEN 0 ELSE 1 END
		LIMIT 1`, p.Fingerprint, p.CanonicalURL, p.CanonicalURL)
	err = row.Scan(&id, &seen, &existingDescription)
	if err != nil && !errors.Is(err, sql.ErrNoRows) {
		return 0, false, err
	}
	if errors.Is(err, sql.ErrNoRows) {
		res, err := tx.ExecContext(ctx, `
			INSERT INTO postings (fingerprint, canonical_url, url, source, company, company_key, title, location,
				remote, employment, description, tags, posted_at, first_seen, last_seen, seen_count, active, salary)
			VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`,
			p.Fingerprint, p.CanonicalURL, p.URL, p.Source, p.Company, p.CompanyKey, p.Title, p.Location,
			boolInt(p.Remote), p.Employment, p.Description, tagsJSON(p.Tags), p.PostedAt,
			now.Format(time.RFC3339), now.Format(time.RFC3339), 1, 1, p.Salary)
		if err != nil {
			return 0, false, err
		}
		id, err = res.LastInsertId()
		if err != nil {
			return 0, false, err
		}
		return id, true, tx.Commit()
	}

	description := p.Description
	if len(existingDescription) > len(description) {
		description = existingDescription
	}
	_, err = tx.ExecContext(ctx, `
		UPDATE postings SET canonical_url=?, url=?, source=?, company=?, company_key=?, title=?, location=?,
			remote=?, employment=?, description=?, tags=?, posted_at=COALESCE(NULLIF(?, ''), posted_at),
			last_seen=?, seen_count=?, active=1, salary=COALESCE(NULLIF(?, ''), salary)
		WHERE id=?`,
		p.CanonicalURL, p.URL, p.Source, p.Company, p.CompanyKey, p.Title, p.Location,
		boolInt(p.Remote), p.Employment, description, tagsJSON(p.Tags), p.PostedAt,
		now.Format(time.RFC3339), seen+1, p.Salary, id)
	if err != nil {
		return 0, false, err
	}
	return id, false, tx.Commit()
}

func boolInt(v bool) int {
	if v {
		return 1
	}
	return 0
}

func (s *Store) UpdateDescription(ctx context.Context, id int64, description string) error {
	description = strings.TrimSpace(description)
	if len(description) < 80 {
		return errors.New("enrichment too short")
	}
	_, err := s.db.ExecContext(ctx, `UPDATE postings SET description=? WHERE id=? AND length(description) < length(?)`, description, id, description)
	return err
}

var ftsTokenRE = regexp.MustCompile(`[\p{L}\p{N}_+#.]+`)

func makeFTSQuery(q string) string {
	terms := ftsTokenRE.FindAllString(strings.ToLower(q), 8)
	out := make([]string, 0, len(terms))
	for _, term := range terms {
		term = strings.Trim(term, `".`)
		if len(term) < 2 {
			continue
		}
		escaped := strings.ReplaceAll(term, `"`, `""`)
		out = append(out, `"`+escaped+`"*`)
	}
	return strings.Join(out, " ")
}

func (s *Store) QueryPostings(ctx context.Context, opt queryOptions) (postingsPage, error) {
	if opt.Limit <= 0 || opt.Limit > 200 {
		opt.Limit = 50
	}
	if opt.Offset < 0 {
		opt.Offset = 0
	}
	where := []string{}
	args := []any{}
	join := ""
	order := "p.last_seen DESC"
	match := makeFTSQuery(opt.Q)
	if match != "" {
		join = " JOIN postings_fts ON postings_fts.rowid = p.id"
		where = append(where, "postings_fts MATCH ?")
		args = append(args, match)
		order = "bm25(postings_fts), p.last_seen DESC"
	}
	if opt.Source != "" {
		where = append(where, "p.source = ?")
		args = append(args, opt.Source)
	}
	if opt.Company != "" {
		where = append(where, "p.company_key = ?")
		args = append(args, normalizeCompany(opt.Company))
	}
	if opt.Location != "" {
		where = append(where, "lower(p.location) LIKE ?")
		args = append(args, "%"+strings.ToLower(opt.Location)+"%")
	}
	if opt.Remote {
		where = append(where, "p.remote = 1")
	}
	if opt.Active {
		where = append(where, "p.active = 1")
	}
	if opt.Days > 0 {
		where = append(where, "p.last_seen >= ?")
		args = append(args, time.Now().UTC().Add(-time.Duration(opt.Days)*24*time.Hour).Format(time.RFC3339))
	}
	predicate := ""
	if len(where) > 0 {
		predicate = " WHERE " + strings.Join(where, " AND ")
	}

	var total int
	if err := s.db.QueryRowContext(ctx, `SELECT count(*) FROM postings p`+join+predicate, args...).Scan(&total); err != nil {
		return postingsPage{}, err
	}

	selectSnippet := "'' AS snippet, 0.0 AS score"
	if match != "" {
		selectSnippet = "snippet(postings_fts, 3, '<mark>', '</mark>', '…', 18) AS snippet, bm25(postings_fts) AS score"
	}
	query := `
		SELECT p.id, p.fingerprint, p.canonical_url, p.url, p.source, p.company, p.company_key, p.title, p.location,
			p.remote, p.employment, p.description, p.tags, p.posted_at, p.first_seen, p.last_seen, p.seen_count, p.active, p.salary,
			` + selectSnippet + `
		FROM postings p` + join + predicate + `
		ORDER BY ` + order + `
		LIMIT ? OFFSET ?`
	args = append(args, opt.Limit, opt.Offset)
	rows, err := s.db.QueryContext(ctx, query, args...)
	if err != nil {
		return postingsPage{}, err
	}
	defer rows.Close()
	items := []Posting{}
	for rows.Next() {
		p, err := scanPosting(rows)
		if err != nil {
			return postingsPage{}, err
		}
		items = append(items, p)
	}
	return postingsPage{Items: items, Total: total, Limit: opt.Limit, Offset: opt.Offset, Q: opt.Q}, rows.Err()
}

type rowScanner interface {
	Scan(dest ...any) error
}

func scanPosting(row rowScanner) (Posting, error) {
	var p Posting
	var remote, active int
	var tags, first, last string
	var score sql.NullFloat64
	var snippet sql.NullString
	err := row.Scan(&p.ID, &p.Fingerprint, &p.CanonicalURL, &p.URL, &p.Source, &p.Company, &p.CompanyKey,
		&p.Title, &p.Location, &remote, &p.Employment, &p.Description, &tags, &p.PostedAt,
		&first, &last, &p.SeenCount, &active, &p.Salary, &snippet, &score)
	if err != nil {
		return p, err
	}
	p.Remote = remote == 1
	p.Active = active == 1
	p.Tags = parseTagsJSON(tags)
	p.FirstSeen, _ = time.Parse(time.RFC3339, first)
	p.LastSeen, _ = time.Parse(time.RFC3339, last)
	p.Snippet = snippet.String
	if score.Valid {
		p.Score = score.Float64
	}
	return p, nil
}

func (s *Store) GetPosting(ctx context.Context, id int64) (Posting, []Posting, error) {
	row := s.db.QueryRowContext(ctx, `
		SELECT id, fingerprint, canonical_url, url, source, company, company_key, title, location,
			remote, employment, description, tags, posted_at, first_seen, last_seen, seen_count, active, salary,
			'' AS snippet, 0.0 AS score
		FROM postings WHERE id=?`, id)
	p, err := scanPosting(row)
	if err != nil {
		return p, nil, err
	}
	rows, err := s.db.QueryContext(ctx, `
		SELECT id, fingerprint, canonical_url, url, source, company, company_key, title, location,
			remote, employment, description, tags, posted_at, first_seen, last_seen, seen_count, active, salary,
			'' AS snippet, 0.0 AS score
		FROM postings WHERE id != ? AND active = 1 AND (company_key = ? OR lower(title) LIKE ?)
		ORDER BY last_seen DESC LIMIT 6`, id, p.CompanyKey, "%"+strings.ToLower(firstWords(p.Title, 3))+"%")
	if err != nil {
		return p, nil, err
	}
	defer rows.Close()
	similar := []Posting{}
	for rows.Next() {
		item, err := scanPosting(rows)
		if err != nil {
			return p, nil, err
		}
		similar = append(similar, item)
	}
	return p, similar, rows.Err()
}

func firstWords(s string, n int) string {
	parts := strings.Fields(s)
	if len(parts) > n {
		parts = parts[:n]
	}
	return strings.Join(parts, " ")
}

func (s *Store) BeginRun(ctx context.Context, source string) (int64, error) {
	res, err := s.db.ExecContext(ctx, `INSERT INTO scrape_runs(started_at, source, status) VALUES(?,?, 'running')`, time.Now().UTC().Format(time.RFC3339), source)
	if err != nil {
		return 0, err
	}
	return res.LastInsertId()
}

func (s *Store) FinishRun(ctx context.Context, id int64, source, status string, fetched, inserted, updated int, runErr string) error {
	finished := time.Now().UTC().Format(time.RFC3339)
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()
	if _, err := tx.ExecContext(ctx, `UPDATE scrape_runs SET finished_at=?, status=?, fetched=?, inserted=?, updated=?, error=? WHERE id=?`, finished, status, fetched, inserted, updated, runErr, id); err != nil {
		return err
	}
	_, err = tx.ExecContext(ctx, `
		INSERT INTO source_state(source,last_run_at,last_status,last_error,total_fetched,total_inserted,total_updated)
		VALUES(?,?,?,?,?,?,?)
		ON CONFLICT(source) DO UPDATE SET last_run_at=excluded.last_run_at,last_status=excluded.last_status,
			last_error=excluded.last_error,total_fetched=total_fetched+excluded.total_fetched,
			total_inserted=total_inserted+excluded.total_inserted,total_updated=total_updated+excluded.total_updated`,
		source, finished, status, runErr, fetched, inserted, updated)
	if err != nil {
		return err
	}
	return tx.Commit()
}

func (s *Store) RecentRuns(ctx context.Context, limit int) ([]runRecord, error) {
	if limit <= 0 || limit > 100 {
		limit = 30
	}
	rows, err := s.db.QueryContext(ctx, `SELECT id,started_at,finished_at,source,status,fetched,inserted,updated,error FROM scrape_runs ORDER BY started_at DESC LIMIT ?`, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []runRecord{}
	for rows.Next() {
		var r runRecord
		var started, finished string
		if err := rows.Scan(&r.ID, &started, &finished, &r.Source, &r.Status, &r.Fetched, &r.Inserted, &r.Updated, &r.Error); err != nil {
			return nil, err
		}
		r.StartedAt, _ = time.Parse(time.RFC3339, started)
		r.FinishedAt, _ = time.Parse(time.RFC3339, finished)
		out = append(out, r)
	}
	return out, rows.Err()
}

func (s *Store) SourceStates(ctx context.Context) ([]sourceState, error) {
	rows, err := s.db.QueryContext(ctx, `
		SELECT coalesce(s.source, p.source) AS source, coalesce(s.last_run_at,''), coalesce(s.last_status,''), coalesce(s.last_error,''),
			coalesce(s.total_fetched,0), coalesce(s.total_inserted,0), coalesce(s.total_updated,0), count(p.id)
		FROM postings p FULL OUTER JOIN source_state s ON s.source = p.source
		GROUP BY coalesce(s.source, p.source)
		ORDER BY source`)
	if err != nil {
		// SQLite versions before 3.39 lack FULL OUTER JOIN; the union shape below
		// returns the same rows for this small registry.
		rows, err = s.db.QueryContext(ctx, `
			SELECT source,last_run_at,last_status,last_error,total_fetched,total_inserted,total_updated,
				(SELECT count(*) FROM postings WHERE postings.source=source_state.source)
			FROM source_state
			UNION
			SELECT source,'','','',0,0,0,count(*) FROM postings WHERE source NOT IN (SELECT source FROM source_state) GROUP BY source
			ORDER BY source`)
	}
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []sourceState{}
	for rows.Next() {
		var st sourceState
		if err := rows.Scan(&st.Source, &st.LastRunAt, &st.LastStatus, &st.LastError, &st.TotalFetched, &st.TotalInserted, &st.TotalUpdated, &st.Postings); err != nil {
			return nil, err
		}
		out = append(out, st)
	}
	return out, rows.Err()
}

func (s *Store) Stats(ctx context.Context) (statsPayload, error) {
	var st statsPayload
	st.GeneratedAt = time.Now().UTC()
	queries := []struct {
		sql string
		dst *int
	}{
		{`SELECT count(*) FROM postings`, &st.TotalPostings},
		{`SELECT count(*) FROM postings WHERE active=1`, &st.ActivePostings},
		{`SELECT count(DISTINCT company_key) FROM postings`, &st.Companies},
		{`SELECT count(DISTINCT source) FROM postings`, &st.Sources},
		{`SELECT count(*) FROM postings WHERE remote=1 AND active=1`, &st.Remote},
		{`SELECT count(*) FROM postings WHERE active=1 AND last_seen >= ?`, &st.Last7Days},
	}
	for _, q := range queries {
		var err error
		if strings.Contains(q.sql, "?") {
			err = s.db.QueryRowContext(ctx, q.sql, time.Now().UTC().Add(-7*24*time.Hour).Format(time.RFC3339)).Scan(q.dst)
		} else {
			err = s.db.QueryRowContext(ctx, q.sql).Scan(q.dst)
		}
		if err != nil {
			return st, err
		}
	}
	var err error
	if st.TopSources, err = s.counts(ctx, `SELECT source,count(*) FROM postings WHERE active=1 GROUP BY source ORDER BY count(*) DESC, source LIMIT 12`); err != nil {
		return st, err
	}
	if st.TopCompanies, err = s.counts(ctx, `SELECT company,count(*) FROM postings WHERE active=1 GROUP BY company_key ORDER BY count(*) DESC, company LIMIT 10`); err != nil {
		return st, err
	}
	if st.Locations, err = s.counts(ctx, `SELECT CASE WHEN location='' THEN 'unspecified' ELSE location END,count(*) FROM postings WHERE active=1 GROUP BY location ORDER BY count(*) DESC, location LIMIT 10`); err != nil {
		return st, err
	}
	if runs, err := s.RecentRuns(ctx, 1); err == nil && len(runs) > 0 {
		latest := runs[0]
		st.LatestRun = &latest
	}
	return st, nil
}

func (s *Store) counts(ctx context.Context, query string) ([]countRow, error) {
	rows, err := s.db.QueryContext(ctx, query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []countRow{}
	for rows.Next() {
		var row countRow
		if err := rows.Scan(&row.Name, &row.Count); err != nil {
			return nil, err
		}
		out = append(out, row)
	}
	return out, rows.Err()
}

func (s *Store) MarkInactiveMissing(ctx context.Context, sources []string, startedBefore time.Time) error {
	if len(sources) == 0 {
		return nil
	}
	placeholders := strings.TrimSuffix(strings.Repeat("?,", len(sources)), ",")
	args := []any{startedBefore.UTC().Format(time.RFC3339)}
	for _, source := range sources {
		args = append(args, source)
	}
	_, err := s.db.ExecContext(ctx, `UPDATE postings SET active=0 WHERE last_seen < ? AND source IN (`+placeholders+`)`, args...)
	return err
}
