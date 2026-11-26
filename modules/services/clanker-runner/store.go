package main

import (
	"context"
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"fmt"
	"strings"
	"time"

	_ "modernc.org/sqlite"
)

type Store struct {
	db *sql.DB
}

type queryOptions struct {
	Q       string
	Machine string
	Kind    string
	Status  string
	Limit   int
	Offset  int
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
		`CREATE TABLE IF NOT EXISTS jobs (
			id INTEGER PRIMARY KEY,
			public_id TEXT NOT NULL UNIQUE,
			machine TEXT NOT NULL,
			machine_id TEXT NOT NULL,
			kind TEXT NOT NULL,
			command TEXT NOT NULL,
			status TEXT NOT NULL,
			exit_code INTEGER,
			stdout TEXT NOT NULL DEFAULT '',
			stderr TEXT NOT NULL DEFAULT '',
			error TEXT NOT NULL DEFAULT '',
			created_at TEXT NOT NULL,
			started_at TEXT,
			finished_at TEXT
		)`,
		`CREATE INDEX IF NOT EXISTS jobs_created_idx ON jobs(created_at DESC)`,
		`CREATE INDEX IF NOT EXISTS jobs_status_idx ON jobs(status,created_at DESC)`,
		`CREATE INDEX IF NOT EXISTS jobs_machine_idx ON jobs(machine,created_at DESC)`,
		`CREATE TABLE IF NOT EXISTS job_logs (
			job_rowid INTEGER NOT NULL REFERENCES jobs(id) ON DELETE CASCADE,
			seq INTEGER NOT NULL,
			stream TEXT NOT NULL,
			line TEXT NOT NULL,
			created_at TEXT NOT NULL,
			PRIMARY KEY(job_rowid,seq)
		)`,
		`CREATE TABLE IF NOT EXISTS schedules (
			id INTEGER PRIMARY KEY,
			name TEXT NOT NULL,
			preset_id TEXT NOT NULL,
			machine TEXT NOT NULL DEFAULT 'clanker',
			params_json TEXT NOT NULL DEFAULT '{}',
			interval_seconds INTEGER NOT NULL,
			enabled INTEGER NOT NULL DEFAULT 1,
			next_run_at TEXT NOT NULL,
			last_run_at TEXT NOT NULL DEFAULT '',
			last_job_id TEXT NOT NULL DEFAULT '',
			last_error TEXT NOT NULL DEFAULT '',
			created_at TEXT NOT NULL,
			updated_at TEXT NOT NULL
		)`,
		`CREATE INDEX IF NOT EXISTS schedules_due_idx ON schedules(enabled,next_run_at)`,
		`CREATE TABLE IF NOT EXISTS job_artifacts (
			id INTEGER PRIMARY KEY,
			job_rowid INTEGER NOT NULL REFERENCES jobs(id) ON DELETE CASCADE,
			name TEXT NOT NULL,
			kind TEXT NOT NULL,
			mime TEXT NOT NULL,
			size INTEGER NOT NULL,
			sha256 TEXT NOT NULL,
			excerpt TEXT NOT NULL DEFAULT '',
			content BLOB NOT NULL,
			created_at TEXT NOT NULL,
			UNIQUE(job_rowid,name)
		)`,
		`CREATE INDEX IF NOT EXISTS job_artifacts_job_idx ON job_artifacts(job_rowid,id)`,
		`CREATE VIRTUAL TABLE IF NOT EXISTS jobs_fts USING fts5(
			public_id UNINDEXED, machine, kind, command, stdout, stderr, error,
			content='jobs', content_rowid='id'
		)`,
		`CREATE TRIGGER IF NOT EXISTS jobs_ai AFTER INSERT ON jobs BEGIN
			INSERT INTO jobs_fts(rowid, public_id, machine, kind, command, stdout, stderr, error)
			VALUES (new.id, new.public_id, new.machine, new.kind, new.command, new.stdout, new.stderr, new.error);
		END`,
		`CREATE TRIGGER IF NOT EXISTS jobs_ad AFTER DELETE ON jobs BEGIN
			INSERT INTO jobs_fts(jobs_fts, rowid, public_id, machine, kind, command, stdout, stderr, error)
			VALUES('delete', old.id, old.public_id, old.machine, old.kind, old.command, old.stdout, old.stderr, old.error);
		END`,
		`CREATE TRIGGER IF NOT EXISTS jobs_au AFTER UPDATE ON jobs BEGIN
			INSERT INTO jobs_fts(jobs_fts, rowid, public_id, machine, kind, command, stdout, stderr, error)
			VALUES('delete', old.id, old.public_id, old.machine, old.kind, old.command, old.stdout, old.stderr, old.error);
			INSERT INTO jobs_fts(rowid, public_id, machine, kind, command, stdout, stderr, error)
			VALUES (new.id, new.public_id, new.machine, new.kind, new.command, new.stdout, new.stderr, new.error);
		END`,
	}
	for _, stmt := range stmts {
		if _, err := s.db.Exec(stmt); err != nil {
			return fmt.Errorf("migrate: %w", err)
		}
	}
	return nil
}

func (s *Store) CreateJob(ctx context.Context, publicID, machine, machineID, kind, command string) error {
	now := time.Now().UTC().Format(time.RFC3339)
	_, err := s.db.ExecContext(ctx, `INSERT INTO jobs (public_id,machine,machine_id,kind,command,status,created_at) VALUES (?,?,?,?,?,'queued',?)`, publicID, machine, machineID, kind, command, now)
	return err
}

func (s *Store) StartJob(ctx context.Context, publicID string) error {
	now := time.Now().UTC().Format(time.RFC3339)
	res, err := s.db.ExecContext(ctx, `UPDATE jobs SET status='running',started_at=COALESCE(started_at,?) WHERE public_id=? AND status IN ('queued','running')`, now, publicID)
	if err != nil {
		return err
	}
	if n, _ := res.RowsAffected(); n == 0 {
		return sql.ErrNoRows
	}
	return nil
}

func (s *Store) FinishJob(ctx context.Context, publicID, status string, exitCode *int, stdout, stderr, runErr string) error {
	now := time.Now().UTC().Format(time.RFC3339)
	_, err := s.db.ExecContext(ctx, `UPDATE jobs SET status=?,exit_code=?,stdout=?,stderr=?,error=?,finished_at=? WHERE public_id=?`, status, nullableInt(exitCode), stdout, stderr, runErr, now, publicID)
	return err
}

func nullableInt(v *int) any {
	if v == nil {
		return nil
	}
	return *v
}

func (s *Store) AppendJobLog(ctx context.Context, publicID, stream, line string) error {
	line = strings.TrimRight(line, "\r\n")
	if line == "" {
		return nil
	}
	now := time.Now().UTC().Format(time.RFC3339)
	_, err := s.db.ExecContext(ctx, `INSERT INTO job_logs (job_rowid,seq,stream,line,created_at)
		SELECT id, COALESCE((SELECT max(seq)+1 FROM job_logs WHERE job_rowid=jobs.id),1),?,?,?
		FROM jobs WHERE public_id=?`, stream, line, now, publicID)
	return err
}

func ftsQuery(raw string) string {
	terms := strings.Fields(raw)
	if len(terms) == 0 {
		return ""
	}
	out := make([]string, 0, len(terms))
	for _, term := range terms {
		term = strings.TrimSpace(strings.Trim(term, `"'`))
		if term == "" {
			continue
		}
		term = strings.ReplaceAll(term, `"`, `""`)
		out = append(out, `"`+term+`"*`)
	}
	return strings.Join(out, " AND ")
}

func (s *Store) QueryJobs(ctx context.Context, opt queryOptions) (jobsPage, error) {
	if opt.Limit <= 0 || opt.Limit > 100 {
		opt.Limit = 25
	}
	if opt.Offset < 0 {
		opt.Offset = 0
	}
	where := []string{"1=1"}
	args := []any{}
	join := ""
	match := ftsQuery(opt.Q)
	order := "j.created_at DESC"
	if match != "" {
		join = " JOIN jobs_fts ON jobs_fts.rowid = j.id"
		where = append(where, "jobs_fts MATCH ?")
		args = append(args, match)
		order = "bm25(jobs_fts), j.created_at DESC"
	}
	if opt.Machine != "" {
		where = append(where, "(j.machine = ? OR j.machine_id = ?)")
		args = append(args, opt.Machine, opt.Machine)
	}
	if opt.Kind != "" {
		where = append(where, "j.kind = ?")
		args = append(args, opt.Kind)
	}
	if opt.Status != "" {
		where = append(where, "j.status = ?")
		args = append(args, opt.Status)
	}
	predicate := " WHERE " + strings.Join(where, " AND ")
	var total int
	if err := s.db.QueryRowContext(ctx, `SELECT count(*) FROM jobs j`+join+predicate, args...).Scan(&total); err != nil {
		return jobsPage{}, err
	}
	selectSnippet := "'' AS snippet"
	if match != "" {
		selectSnippet = "snippet(jobs_fts, 3, '<mark>', '</mark>', '…', 24) AS snippet"
	}
	argsWithLimit := append(append([]any{}, args...), opt.Limit, opt.Offset)
	rows, err := s.db.QueryContext(ctx, `
		SELECT j.public_id,j.machine,j.kind,j.command,j.status,j.exit_code,j.stdout,j.stderr,j.error,j.created_at,j.started_at,j.finished_at,`+selectSnippet+`
		FROM jobs j`+join+predicate+`
		ORDER BY `+order+`
		LIMIT ? OFFSET ?`, argsWithLimit...)
	if err != nil {
		return jobsPage{}, err
	}
	defer rows.Close()
	items := []Job{}
	for rows.Next() {
		job, err := scanJob(rows)
		if err != nil {
			return jobsPage{}, err
		}
		items = append(items, job)
	}
	return jobsPage{Items: items, Total: total, Limit: opt.Limit, Offset: opt.Offset, Q: opt.Q}, rows.Err()
}

type rowScanner interface{ Scan(dest ...any) error }

func scanJob(row rowScanner) (Job, error) {
	var job Job
	var exit sql.NullInt64
	var created string
	var started, finished, snippet sql.NullString
	err := row.Scan(&job.ID, &job.Machine, &job.Kind, &job.Command, &job.Status, &exit, &job.Stdout, &job.Stderr, &job.Error, &created, &started, &finished, &snippet)
	if err != nil {
		return job, err
	}
	if exit.Valid {
		code := int(exit.Int64)
		job.ExitCode = &code
	}
	job.CreatedAt, _ = time.Parse(time.RFC3339, created)
	if started.Valid && started.String != "" {
		t, _ := time.Parse(time.RFC3339, started.String)
		job.StartedAt = &t
	}
	if finished.Valid && finished.String != "" {
		t, _ := time.Parse(time.RFC3339, finished.String)
		job.FinishedAt = &t
	}
	job.Snippet = snippet.String
	return job, nil
}

func (s *Store) GetJob(ctx context.Context, publicID string) (Job, []logEntry, error) {
	row := s.db.QueryRowContext(ctx, `
		SELECT public_id,machine,kind,command,status,exit_code,stdout,stderr,error,created_at,started_at,finished_at,'' AS snippet
		FROM jobs WHERE public_id=?`, publicID)
	job, err := scanJob(row)
	if err != nil {
		return job, nil, err
	}
	rows, err := s.db.QueryContext(ctx, `SELECT l.seq,l.stream,l.line,l.created_at FROM job_logs l JOIN jobs j ON j.id=l.job_rowid WHERE j.public_id=? ORDER BY l.seq`, publicID)
	if err != nil {
		return job, nil, err
	}
	defer rows.Close()
	logs := []logEntry{}
	for rows.Next() {
		var entry logEntry
		var created string
		if err := rows.Scan(&entry.Seq, &entry.Stream, &entry.Line, &created); err != nil {
			return job, nil, err
		}
		entry.CreatedAt, _ = time.Parse(time.RFC3339, created)
		logs = append(logs, entry)
	}
	return job, logs, rows.Err()
}

func artifactExcerpt(content []byte) string {
	const limit = 512
	text := strings.Map(func(r rune) rune {
		if r == '\n' || r == '\r' || r == '\t' || r >= 32 && r != 0x7f {
			return r
		}
		return -1
	}, string(content))
	if len(text) > limit {
		return text[:limit] + "…"
	}
	return text
}

func (s *Store) CreateArtifact(ctx context.Context, publicID string, input artifactInput) error {
	if len(input.Content) > 8<<20 {
		return fmt.Errorf("artifact %s exceeds 8 MiB capture bound", input.Name)
	}
	sum := sha256.Sum256(input.Content)
	_, err := s.db.ExecContext(ctx, `
		INSERT INTO job_artifacts (job_rowid,name,kind,mime,size,sha256,excerpt,content,created_at)
		SELECT j.id,?,?,?,?,?,?,?,? FROM jobs j WHERE j.public_id=?
		ON CONFLICT(job_rowid,name) DO UPDATE SET kind=excluded.kind,mime=excluded.mime,size=excluded.size,sha256=excluded.sha256,excerpt=excluded.excerpt,content=excluded.content,created_at=excluded.created_at`,
		input.Name, input.Kind, input.Mime, len(input.Content), hex.EncodeToString(sum[:]), artifactExcerpt(input.Content), input.Content, time.Now().UTC().Format(time.RFC3339), publicID)
	return err
}

func (s *Store) ListArtifacts(ctx context.Context, publicID string) ([]Artifact, error) {
	rows, err := s.db.QueryContext(ctx, `
		SELECT a.id,j.public_id,a.name,a.kind,a.mime,a.size,a.sha256,a.excerpt,a.created_at
		FROM job_artifacts a JOIN jobs j ON j.id=a.job_rowid WHERE j.public_id=? ORDER BY a.id`, publicID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	items := []Artifact{}
	for rows.Next() {
		var item Artifact
		var created string
		if err := rows.Scan(&item.ID, &item.JobID, &item.Name, &item.Kind, &item.Mime, &item.Size, &item.SHA256, &item.Excerpt, &created); err != nil {
			return nil, err
		}
		item.CreatedAt, _ = time.Parse(time.RFC3339, created)
		items = append(items, item)
	}
	return items, rows.Err()
}

func (s *Store) GetArtifact(ctx context.Context, publicID string, artifactID int64) (Artifact, []byte, error) {
	row := s.db.QueryRowContext(ctx, `
		SELECT a.id,j.public_id,a.name,a.kind,a.mime,a.size,a.sha256,a.excerpt,a.created_at,a.content
		FROM job_artifacts a JOIN jobs j ON j.id=a.job_rowid WHERE j.public_id=? AND a.id=?`, publicID, artifactID)
	var item Artifact
	var created string
	var content []byte
	if err := row.Scan(&item.ID, &item.JobID, &item.Name, &item.Kind, &item.Mime, &item.Size, &item.SHA256, &item.Excerpt, &created, &content); err != nil {
		return item, nil, err
	}
	item.CreatedAt, _ = time.Parse(time.RFC3339, created)
	return item, content, nil
}

func (s *Store) Stats(ctx context.Context) (statsResponse, error) {
	stats := statsResponse{GeneratedAt: time.Now().UTC(), Kinds: []countRow{}, Machines: []countRow{}}
	if err := s.db.QueryRowContext(ctx, `SELECT count(*) FROM jobs`).Scan(&stats.TotalJobs); err != nil {
		return stats, err
	}
	if err := s.db.QueryRowContext(ctx, `SELECT count(*) FROM jobs WHERE status IN ('queued','running')`).Scan(&stats.RunningJobs); err != nil {
		return stats, err
	}
	if err := s.db.QueryRowContext(ctx, `SELECT count(*) FROM jobs WHERE status='failed' OR (exit_code IS NOT NULL AND exit_code != 0)`).Scan(&stats.FailedJobs); err != nil {
		return stats, err
	}
	if err := s.db.QueryRowContext(ctx, `SELECT count(*) FROM jobs WHERE status='finished' AND coalesce(exit_code,0)=0`).Scan(&stats.Successful); err != nil {
		return stats, err
	}
	var last sql.NullString
	if err := s.db.QueryRowContext(ctx, `SELECT max(finished_at) FROM jobs WHERE finished_at IS NOT NULL`).Scan(&last); err != nil {
		return stats, err
	}
	if last.Valid && last.String != "" {
		t, _ := time.Parse(time.RFC3339, last.String)
		stats.LastFinished = &t
	}
	kindRows, err := s.db.QueryContext(ctx, `SELECT kind,count(*) FROM jobs GROUP BY kind ORDER BY count(*) DESC,kind LIMIT 8`)
	if err != nil {
		return stats, err
	}
	if err := scanCounts(kindRows, &stats.Kinds); err != nil {
		return stats, err
	}
	machineRows, err := s.db.QueryContext(ctx, `SELECT machine,count(*) FROM jobs GROUP BY machine ORDER BY count(*) DESC,machine LIMIT 8`)
	if err != nil {
		return stats, err
	}
	if err := scanCounts(machineRows, &stats.Machines); err != nil {
		return stats, err
	}
	return stats, nil
}

func scanCounts(rows *sql.Rows, out *[]countRow) error {
	defer rows.Close()
	for rows.Next() {
		var row countRow
		if err := rows.Scan(&row.Name, &row.Count); err != nil {
			return err
		}
		*out = append(*out, row)
	}
	return rows.Err()
}
