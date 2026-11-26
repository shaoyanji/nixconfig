package main

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"regexp"
	"slices"
	"sort"
	"strings"
	"time"

	_ "modernc.org/sqlite"
)

type Store struct {
	db *sql.DB
}

type queryOptions struct {
	Q        string
	Sort     string
	Source   string
	Company  string
	Location string
	Lane     string
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

type companyRow struct {
	Name     string    `json:"name"`
	Key      string    `json:"key"`
	Postings int       `json:"postings"`
	AvgScore float64   `json:"avg_score"`
	MaxScore int       `json:"max_score"`
	Remote   int       `json:"remote"`
	Newest   time.Time `json:"newest"`
}

type laneRow struct {
	Name     string  `json:"name"`
	Postings int     `json:"postings"`
	AvgScore float64 `json:"avg_score"`
	MaxScore int     `json:"max_score"`
}

type scoreBand struct {
	Band  string `json:"band"`
	Min   int    `json:"min"`
	Max   int    `json:"max"`
	Count int    `json:"count"`
}

type jobAnalytics struct {
	GeneratedAt time.Time    `json:"generated_at"`
	Days        int          `json:"days"`
	Active      int          `json:"active"`
	Remote      int          `json:"remote"`
	AvgScore    float64      `json:"avg_score"`
	Unscored    int          `json:"unscored"`
	Companies   []companyRow `json:"companies"`
	Locations   []countRow   `json:"locations"`
	Lanes       []laneRow    `json:"lanes"`
	Sources     []countRow   `json:"sources"`
	ScoreBands  []scoreBand  `json:"score_bands"`
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
			salary TEXT NOT NULL DEFAULT '',
			score INTEGER NOT NULL DEFAULT 0,
			lanes TEXT NOT NULL DEFAULT '[]'
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
		`CREATE TABLE IF NOT EXISTS job_score_alerts (
			id INTEGER PRIMARY KEY,
			fingerprint TEXT NOT NULL UNIQUE,
			posting_id INTEGER NOT NULL REFERENCES postings(id) ON DELETE CASCADE,
			company TEXT NOT NULL,
			title TEXT NOT NULL,
			url TEXT NOT NULL,
			score INTEGER NOT NULL,
			status TEXT NOT NULL DEFAULT 'pending',
			attempts INTEGER NOT NULL DEFAULT 0,
			notify_error TEXT NOT NULL DEFAULT '',
			first_seen TEXT NOT NULL,
			last_seen TEXT NOT NULL,
			notified_at TEXT
		)`,
		`CREATE INDEX IF NOT EXISTS job_score_alerts_status_idx ON job_score_alerts(status,last_seen DESC)`,
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
	columns := []struct {
		name string
		ddl  string
	}{
		{"score", `ALTER TABLE postings ADD COLUMN score INTEGER NOT NULL DEFAULT 0`},
		{"lanes", `ALTER TABLE postings ADD COLUMN lanes TEXT NOT NULL DEFAULT '[]'`},
	}
	missing := []string{}
	for _, column := range columns {
		exists, err := s.hasColumn("postings", column.name)
		if err != nil {
			return err
		}
		if !exists {
			missing = append(missing, column.name)
		}
	}
	if len(missing) > 0 {
		for _, trigger := range []string{"postings_ai", "postings_ad", "postings_au"} {
			if _, err := s.db.Exec(`DROP TRIGGER IF EXISTS ` + trigger); err != nil {
				return fmt.Errorf("drop %s: %w", trigger, err)
			}
		}
		if _, err := s.db.Exec(`DROP TABLE IF EXISTS postings_fts`); err != nil {
			return fmt.Errorf("drop postings fts: %w", err)
		}
		for _, column := range columns {
			if !slices.Contains(missing, column.name) {
				continue
			}
			if _, err := s.db.Exec(column.ddl); err != nil {
				return fmt.Errorf("add postings.%s: %w", column.name, err)
			}
		}
		_, err := s.db.Exec(`CREATE VIRTUAL TABLE postings_fts USING fts5(
			title, company, location, description, tags,
			content='postings', content_rowid='id'
		)`)
		if err != nil {
			return fmt.Errorf("recreate postings fts: %w", err)
		}
		for _, trigger := range []string{
			`CREATE TRIGGER postings_ai AFTER INSERT ON postings BEGIN
				INSERT INTO postings_fts(rowid, title, company, location, description, tags)
				VALUES (new.id, new.title, new.company, new.location, new.description, new.tags);
			END`,
			`CREATE TRIGGER postings_ad AFTER DELETE ON postings BEGIN
				INSERT INTO postings_fts(postings_fts, rowid, title, company, location, description, tags)
				VALUES('delete', old.id, old.title, old.company, old.location, old.description, old.tags);
			END`,
			`CREATE TRIGGER postings_au AFTER UPDATE ON postings BEGIN
				INSERT INTO postings_fts(postings_fts, rowid, title, company, location, description, tags)
				VALUES('delete', old.id, old.title, old.company, old.location, old.description, old.tags);
				INSERT INTO postings_fts(rowid, title, company, location, description, tags)
				VALUES (new.id, new.title, new.company, new.location, new.description, new.tags);
			END`,
		} {
			if _, err := s.db.Exec(trigger); err != nil {
				return fmt.Errorf("recreate postings fts trigger: %w", err)
			}
		}
		if _, err := s.db.Exec(`INSERT INTO postings_fts(postings_fts) VALUES('rebuild')`); err != nil {
			return fmt.Errorf("rebuild recreated fts: %w", err)
		}
	} else {
		var ftsRows, postingRows int
		if err := s.db.QueryRow(`SELECT count(*) FROM postings_fts`).Scan(&ftsRows); err != nil {
			return fmt.Errorf("count fts rows: %w", err)
		}
		if err := s.db.QueryRow(`SELECT count(*) FROM postings`).Scan(&postingRows); err != nil {
			return fmt.Errorf("count postings rows: %w", err)
		}
		if postingRows > 0 && ftsRows == 0 {
			if _, err := s.db.Exec(`INSERT INTO postings_fts(postings_fts) VALUES('rebuild')`); err != nil {
				return fmt.Errorf("rebuild fts: %w", err)
			}
		}
	}
	if _, err := s.db.Exec(`CREATE INDEX IF NOT EXISTS postings_score_idx ON postings(score DESC,last_seen DESC)`); err != nil {
		return fmt.Errorf("postings score index: %w", err)
	}
	if err := s.rescorePostings(); err != nil {
		return fmt.Errorf("rescore postings: %w", err)
	}
	return nil
}

func (s *Store) hasColumn(table, column string) (bool, error) {
	rows, err := s.db.Query(`PRAGMA table_info(` + table + `)`)
	if err != nil {
		return false, err
	}
	defer rows.Close()
	for rows.Next() {
		var cid int
		var name, kind string
		var notNull int
		var defaultValue any
		var pk int
		if err := rows.Scan(&cid, &name, &kind, &notNull, &defaultValue, &pk); err != nil {
			return false, err
		}
		if name == column {
			return true, rows.Err()
		}
	}
	return false, rows.Err()
}

func (s *Store) rescorePostings() error {
	rows, err := s.db.Query(`SELECT id,title,location,remote,description,tags,score,lanes FROM postings`)
	if err != nil {
		return fmt.Errorf("select postings: %w", err)
	}
	type row struct {
		id    int64
		score int
		lanes []string
	}
	pending := []row{}
	for rows.Next() {
		var id, remote int64
		var title, location, description, tags, currentLanes string
		var currentScore int
		if err := rows.Scan(&id, &title, &location, &remote, &description, &tags, &currentScore, &currentLanes); err != nil {
			rows.Close()
			return err
		}
		posting := Posting{Title: title, Location: location, Remote: remote == 1, Description: description, Tags: parseTagsJSON(tags)}
		score, lanes := scorePosting(posting)
		if score != currentScore || tagsJSON(lanes) != currentLanes {
			pending = append(pending, row{id: id, score: score, lanes: lanes})
		}
	}
	if err := rows.Close(); err != nil {
		return err
	}
	if err := rows.Err(); err != nil {
		return err
	}
	for _, item := range pending {
		if _, err := s.db.Exec(`UPDATE postings SET score=?,lanes=? WHERE id=?`, item.score, tagsJSON(item.lanes), item.id); err != nil {
			return fmt.Errorf("update posting %d: %w", item.id, err)
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
				remote, employment, description, tags, posted_at, first_seen, last_seen, seen_count, active, salary, score, lanes)
			VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`,
			p.Fingerprint, p.CanonicalURL, p.URL, p.Source, p.Company, p.CompanyKey, p.Title, p.Location,
			boolInt(p.Remote), p.Employment, p.Description, tagsJSON(p.Tags), p.PostedAt,
			now.Format(time.RFC3339), now.Format(time.RFC3339), 1, 1, p.Salary, p.Score, tagsJSON(p.Lanes))
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
	scored := p
	scored.Description = description
	scored.Score, scored.Lanes = scorePosting(scored)
	_, err = tx.ExecContext(ctx, `
		UPDATE postings SET canonical_url=?, url=?, source=?, company=?, company_key=?, title=?, location=?,
			remote=?, employment=?, description=?, tags=?, posted_at=COALESCE(NULLIF(?, ''), posted_at),
			last_seen=?, seen_count=?, active=1, salary=COALESCE(NULLIF(?, ''), salary), score=?, lanes=?
		WHERE id=?`,
		p.CanonicalURL, p.URL, p.Source, p.Company, p.CompanyKey, p.Title, p.Location,
		boolInt(p.Remote), p.Employment, description, tagsJSON(p.Tags), p.PostedAt,
		now.Format(time.RFC3339), seen+1, p.Salary, scored.Score, tagsJSON(scored.Lanes), id)
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
	posting, _, err := s.GetPosting(ctx, id)
	if err != nil {
		return err
	}
	posting.Description = description
	posting.Score, posting.Lanes = scorePosting(posting)
	_, err = s.db.ExecContext(ctx, `UPDATE postings SET description=?,score=?,lanes=? WHERE id=? AND length(description) < length(?)`, description, posting.Score, tagsJSON(posting.Lanes), id, description)
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
	if opt.Sort == "score" {
		order = "p.score DESC, p.last_seen DESC"
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
	if opt.Lane != "" {
		where = append(where, "EXISTS (SELECT 1 FROM json_each(p.lanes) WHERE json_each.value = ?)")
		args = append(args, opt.Lane)
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

	selectSnippet := "'' AS snippet, 0.0 AS search_score"
	if match != "" {
		selectSnippet = "snippet(postings_fts, 3, '<mark>', '</mark>', '…', 18) AS snippet, bm25(postings_fts) AS search_score"
	}
	query := `
		SELECT p.id, p.fingerprint, p.canonical_url, p.url, p.source, p.company, p.company_key, p.title, p.location,
			p.remote, p.employment, p.description, p.tags, p.posted_at, p.first_seen, p.last_seen, p.seen_count, p.active, p.salary, p.score, p.lanes,
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
	var lanes string
	var searchScore sql.NullFloat64
	var snippet sql.NullString
	err := row.Scan(&p.ID, &p.Fingerprint, &p.CanonicalURL, &p.URL, &p.Source, &p.Company, &p.CompanyKey,
		&p.Title, &p.Location, &remote, &p.Employment, &p.Description, &tags, &p.PostedAt,
		&first, &last, &p.SeenCount, &active, &p.Salary, &p.Score, &lanes, &snippet, &searchScore)
	if err != nil {
		return p, err
	}
	p.Remote = remote == 1
	p.Active = active == 1
	p.Tags = parseTagsJSON(tags)
	p.Lanes = parseTagsJSON(lanes)
	p.FirstSeen, _ = time.Parse(time.RFC3339, first)
	p.LastSeen, _ = time.Parse(time.RFC3339, last)
	p.Snippet = snippet.String
	if searchScore.Valid {
		p.SearchScore = searchScore.Float64
	}
	return p, nil
}

func (s *Store) GetPosting(ctx context.Context, id int64) (Posting, []Posting, error) {
	row := s.db.QueryRowContext(ctx, `
		SELECT id, fingerprint, canonical_url, url, source, company, company_key, title, location,
			remote, employment, description, tags, posted_at, first_seen, last_seen, seen_count, active, salary, score, lanes,
			'' AS snippet, 0.0 AS search_score
		FROM postings WHERE id=?`, id)
	p, err := scanPosting(row)
	if err != nil {
		return p, nil, err
	}
	rows, err := s.db.QueryContext(ctx, `
		SELECT id, fingerprint, canonical_url, url, source, company, company_key, title, location,
			remote, employment, description, tags, posted_at, first_seen, last_seen, seen_count, active, salary, score, lanes,
			'' AS snippet, 0.0 AS search_score
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

func jobAlertFingerprint(postingID int64, score int) string {
	return fmt.Sprintf("%d:%d", postingID, score)
}

func (s *Store) EvaluateHighScoreAlerts(ctx context.Context, minScore, limit int) (alertEvaluation, error) {
	if minScore <= 0 {
		minScore = 80
	}
	if minScore > 100 {
		minScore = 100
	}
	if limit <= 0 || limit > 200 {
		limit = 100
	}
	rows, err := s.db.QueryContext(ctx, `SELECT id,company,title,url,score FROM postings WHERE active=1 AND score>=? ORDER BY score DESC,last_seen DESC LIMIT ?`, minScore, limit)
	if err != nil {
		return alertEvaluation{}, err
	}
	candidates := []JobAlert{}
	for rows.Next() {
		var alert JobAlert
		if err := rows.Scan(&alert.PostingID, &alert.Company, &alert.Title, &alert.URL, &alert.Score); err != nil {
			rows.Close()
			return alertEvaluation{}, err
		}
		candidates = append(candidates, alert)
	}
	if err := rows.Close(); err != nil {
		return alertEvaluation{}, err
	}
	if err := rows.Err(); err != nil {
		return alertEvaluation{}, err
	}
	result := alertEvaluation{Alerts: []JobAlert{}}
	for _, alert := range candidates {
		fingerprint := jobAlertFingerprint(alert.PostingID, alert.Score)
		now := time.Now().UTC().Format(time.RFC3339)
		res, err := s.db.ExecContext(ctx, `INSERT OR IGNORE INTO job_score_alerts (fingerprint,posting_id,company,title,url,score,status,first_seen,last_seen) VALUES (?,?,?,?,?,?,'pending',?,?)`, fingerprint, alert.PostingID, alert.Company, alert.Title, alert.URL, alert.Score, now, now)
		if err != nil {
			return result, err
		}
		if n, _ := res.RowsAffected(); n > 0 {
			result.Created++
			alert.ID, _ = res.LastInsertId()
			alert.Status = "pending"
			alert.FirstSeen, _ = time.Parse(time.RFC3339, now)
			alert.LastSeen = alert.FirstSeen
		} else {
			result.Existing++
			if _, err := s.db.ExecContext(ctx, `UPDATE job_score_alerts SET company=?,title=?,url=?,last_seen=? WHERE fingerprint=?`, alert.Company, alert.Title, alert.URL, now, fingerprint); err != nil {
				return result, err
			}
			var firstSeen, lastSeen string
			var notified sql.NullString
			if err := s.db.QueryRowContext(ctx, `SELECT id,status,attempts,notify_error,first_seen,last_seen,notified_at FROM job_score_alerts WHERE fingerprint=?`, fingerprint).Scan(&alert.ID, &alert.Status, &alert.Attempts, &alert.NotifyError, &firstSeen, &lastSeen, &notified); err != nil {
				return result, err
			}
			alert.FirstSeen, _ = time.Parse(time.RFC3339, firstSeen)
			alert.LastSeen, _ = time.Parse(time.RFC3339, lastSeen)
			if notified.Valid && notified.String != "" {
				t, _ := time.Parse(time.RFC3339, notified.String)
				alert.NotifiedAt = &t
			}
		}
		result.Matched++
		result.Alerts = append(result.Alerts, alert)
	}
	return result, nil
}

func (s *Store) MarkJobAlertNotification(ctx context.Context, id int64, sent bool, notifyError string) error {
	status := "failed"
	notified := ""
	if sent {
		status = "sent"
		notified = time.Now().UTC().Format(time.RFC3339)
	}
	_, err := s.db.ExecContext(ctx, `UPDATE job_score_alerts SET status=?,attempts=attempts+1,notify_error=?,notified_at=?,last_seen=? WHERE id=?`, status, notifyError, notified, time.Now().UTC().Format(time.RFC3339), id)
	return err
}

func (s *Store) ListJobAlerts(ctx context.Context, limit int) ([]JobAlert, error) {
	if limit <= 0 || limit > 200 {
		limit = 50
	}
	rows, err := s.db.QueryContext(ctx, `SELECT id,posting_id,company,title,url,score,status,attempts,notify_error,first_seen,last_seen,COALESCE(notified_at,'') FROM job_score_alerts ORDER BY score DESC,last_seen DESC LIMIT ?`, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	alerts := []JobAlert{}
	for rows.Next() {
		var alert JobAlert
		var firstSeen, lastSeen, notified string
		if err := rows.Scan(&alert.ID, &alert.PostingID, &alert.Company, &alert.Title, &alert.URL, &alert.Score, &alert.Status, &alert.Attempts, &alert.NotifyError, &firstSeen, &lastSeen, &notified); err != nil {
			return nil, err
		}
		alert.FirstSeen, _ = time.Parse(time.RFC3339, firstSeen)
		alert.LastSeen, _ = time.Parse(time.RFC3339, lastSeen)
		if notified != "" {
			t, _ := time.Parse(time.RFC3339, notified)
			alert.NotifiedAt = &t
		}
		alerts = append(alerts, alert)
	}
	return alerts, rows.Err()
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

// Analytics reads the board rather than one row: who hires, where, which lanes
// the index covers, where the postings come from, and how the role-match scores
// are distributed. Lanes are a JSON column, so they are counted in Go from one
// scan — a JSON aggregate would hide rows whose lanes cannot be parsed.
func (s *Store) Analytics(ctx context.Context, days, limit int) (jobAnalytics, error) {
	if limit <= 0 {
		limit = 8
	}
	if limit > 50 {
		limit = 50
	}
	if days < 0 {
		days = 0
	}
	if days > 365 {
		days = 365
	}
	scope := "active=1"
	args := []any{}
	if days > 0 {
		scope += " AND last_seen >= ?"
		args = append(args, time.Now().UTC().Add(-time.Duration(days)*24*time.Hour).Format(time.RFC3339))
	}
	report := jobAnalytics{
		GeneratedAt: time.Now().UTC(), Days: days,
		Companies: []companyRow{}, Locations: []countRow{}, Lanes: []laneRow{},
		Sources: []countRow{}, ScoreBands: []scoreBand{},
	}

	var remote sql.NullInt64
	if err := s.db.QueryRowContext(ctx, `SELECT count(*), COALESCE(sum(remote),0), COALESCE(round(avg(score),1),0),
		COALESCE(sum(CASE WHEN score=0 THEN 1 ELSE 0 END),0) FROM postings WHERE `+scope, args...).
		Scan(&report.Active, &remote, &report.AvgScore, &report.Unscored); err != nil {
		return report, err
	}
	report.Remote = int(remote.Int64)

	companies, err := s.db.QueryContext(ctx, `SELECT company, company_key, count(*), COALESCE(round(avg(score),1),0),
		COALESCE(max(score),0), COALESCE(sum(remote),0), max(last_seen)
		FROM postings WHERE `+scope+`
		GROUP BY company_key
		ORDER BY count(*) DESC, max(score) DESC, company_key ASC LIMIT ?`, append(args, limit)...)
	if err != nil {
		return report, err
	}
	for companies.Next() {
		var row companyRow
		var newest string
		if err := companies.Scan(&row.Name, &row.Key, &row.Postings, &row.AvgScore, &row.MaxScore, &row.Remote, &newest); err != nil {
			companies.Close()
			return report, err
		}
		row.Newest, _ = time.Parse(time.RFC3339, newest)
		report.Companies = append(report.Companies, row)
	}
	if err := companies.Err(); err != nil {
		companies.Close()
		return report, err
	}
	companies.Close()

	counts := func(field string) ([]countRow, error) {
		rows, err := s.db.QueryContext(ctx, `SELECT `+field+`, count(*) FROM postings WHERE `+scope+`
			GROUP BY `+field+` ORDER BY count(*) DESC, `+field+` ASC LIMIT ?`, append(args, limit)...)
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
	if report.Locations, err = counts(`CASE WHEN location='' THEN 'unspecified' ELSE location END`); err != nil {
		return report, err
	}
	if report.Sources, err = counts(`source`); err != nil {
		return report, err
	}

	type laneTotal struct {
		count int
		score int
		max   int
	}
	lanes := map[string]*laneTotal{}
	rows, err := s.db.QueryContext(ctx, `SELECT lanes, score FROM postings WHERE `+scope, args...)
	if err != nil {
		return report, err
	}
	for rows.Next() {
		var raw string
		var score int
		if err := rows.Scan(&raw, &score); err != nil {
			rows.Close()
			return report, err
		}
		for _, lane := range parseLanes(raw) {
			total, ok := lanes[lane]
			if !ok {
				total = &laneTotal{}
				lanes[lane] = total
			}
			total.count++
			total.score += score
			if score > total.max {
				total.max = score
			}
		}
	}
	if err := rows.Err(); err != nil {
		rows.Close()
		return report, err
	}
	rows.Close()
	for name, total := range lanes {
		report.Lanes = append(report.Lanes, laneRow{
			Name: name, Postings: total.count,
			AvgScore: float64(total.score) / float64(total.count), MaxScore: total.max,
		})
	}
	sort.Slice(report.Lanes, func(i, j int) bool {
		if report.Lanes[i].Postings != report.Lanes[j].Postings {
			return report.Lanes[i].Postings > report.Lanes[j].Postings
		}
		if report.Lanes[i].AvgScore != report.Lanes[j].AvgScore {
			return report.Lanes[i].AvgScore > report.Lanes[j].AvgScore
		}
		return report.Lanes[i].Name < report.Lanes[j].Name
	})
	if len(report.Lanes) > limit {
		report.Lanes = report.Lanes[:limit]
	}

	bands := make([]scoreBand, 5)
	for i := range bands {
		bands[i] = scoreBand{Min: i * 20, Max: i*20 + 19, Band: fmt.Sprintf("%d-%d", i*20, i*20+19)}
	}
	bands[4].Max = 100
	bands[4].Band = "80-100"
	histogram, err := s.db.QueryContext(ctx, `SELECT min(score/20,4) AS band, count(*) FROM postings WHERE `+scope+` GROUP BY band`, args...)
	if err != nil {
		return report, err
	}
	for histogram.Next() {
		var band, count int
		if err := histogram.Scan(&band, &count); err != nil {
			histogram.Close()
			return report, err
		}
		if band >= 0 && band < len(bands) {
			bands[band].Count = count
		}
	}
	if err := histogram.Err(); err != nil {
		histogram.Close()
		return report, err
	}
	histogram.Close()
	report.ScoreBands = bands
	return report, nil
}

func parseLanes(raw string) []string {
	var lanes []string
	if raw == "" || json.Unmarshal([]byte(raw), &lanes) != nil {
		return nil
	}
	return lanes
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
