// job-db-scraper — a tailnet job-posting inventory: SQLite/FTS5 store with
// deterministic lane scoring, batch upsert for sweep output, and a
// score-sorted UI. Verbs:
//
//	job-db-scraper serve -addr 127.0.0.1:8102 -db /var/lib/job-db-scraper/jobs.db
//	job-db-scraper add -db ... -title X -employer Y [-url U] [-location L]
//	job-db-scraper search -db ... <query>
//	job-db-scraper batch -db ... < postings.json      one upsert pass over a batch document
package main

import (
	"database/sql"
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"net/http"
	"os"
	"strings"
	"time"
)

func usage() {
	fmt.Fprintln(os.Stderr, "usage: job-db-scraper <serve|add|search|batch> [flags]")
	os.Exit(2)
}

func main() {
	if len(os.Args) < 2 {
		usage()
	}
	var err error
	switch os.Args[1] {
	case "serve":
		err = cmdServe(os.Args[2:])
	case "add":
		err = cmdAdd(os.Args[2:])
	case "search":
		err = cmdSearch(os.Args[2:])
	case "batch":
		err = cmdBatch(os.Args[2:])
	default:
		usage()
	}
	if err != nil {
		log.Fatal(err)
	}
}

func dbFlag(fs *flag.FlagSet) *string {
	return fs.String("db", envOr("JOB_DB_SCRAPER_DB", "/var/lib/job-db-scraper/jobs.db"), "sqlite path")
}

func envOr(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func cmdServe(args []string) error {
	fs := flag.NewFlagSet("serve", flag.ExitOnError)
	addr := fs.String("addr", envOr("JOB_DB_SCRAPER_ADDR", "127.0.0.1:8102"), "loopback listen address")
	dbPath := dbFlag(fs)
	fs.Parse(args)
	db, err := openStore(*dbPath)
	if err != nil {
		return err
	}
	defer db.Close()
	srv := &http.Server{
		Addr:              *addr,
		Handler:           (&server{db: db}).mux(),
		ReadHeaderTimeout: 10 * time.Second,
	}
	log.Printf("job-db-scraper listening on %s", *addr)
	return srv.ListenAndServe()
}

func cmdAdd(args []string) error {
	fs := flag.NewFlagSet("add", flag.ExitOnError)
	dbPath := dbFlag(fs)
	p := Posting{}
	fs.StringVar(&p.Title, "title", "", "role title")
	fs.StringVar(&p.Employer, "employer", "", "employer name")
	fs.StringVar(&p.URL, "url", "", "")
	fs.StringVar(&p.Location, "location", "", "")
	fs.StringVar(&p.Description, "description", "", "")
	fs.Parse(args)
	if strings.TrimSpace(p.Title) == "" || strings.TrimSpace(p.Employer) == "" {
		return fmt.Errorf("-title and -employer are required")
	}
	db, err := openStore(*dbPath)
	if err != nil {
		return err
	}
	defer db.Close()
	id, fresh, err := upsertPosting(db, p)
	if err != nil {
		return err
	}
	fmt.Printf("id=%d new=%v lane=%s score=%d\n", id, fresh, p.Lane, p.Score)
	return nil
}

func cmdSearch(args []string) error {
	fs := flag.NewFlagSet("search", flag.ExitOnError)
	dbPath := dbFlag(fs)
	fs.Parse(args)
	if fs.NArg() == 0 {
		return fmt.Errorf("search needs a query")
	}
	db, err := openStore(*dbPath)
	if err != nil {
		return err
	}
	defer db.Close()
	postings, err := searchPostings(db, strings.Join(fs.Args(), " "), 0, 50)
	if err != nil {
		return err
	}
	for _, p := range postings {
		fmt.Printf("%d\t%d\t%s\t%s\t%s\n", p.ID, p.Score, p.Title, p.Employer, p.Lane)
	}
	return nil
}

func cmdBatch(args []string) error {
	fs := flag.NewFlagSet("batch", flag.ExitOnError)
	dbPath := dbFlag(fs)
	fs.Parse(args)
	db, err := openStore(*dbPath)
	if err != nil {
		return err
	}
	defer db.Close()
	var in struct {
		Postings []Posting `json:"postings"`
	}
	if err := json.NewDecoder(os.Stdin).Decode(&in); err != nil {
		return fmt.Errorf("bad batch json: %w", err)
	}
	inserted, updated := 0, 0
	for _, p := range in.Postings {
		if strings.TrimSpace(p.Title) == "" || strings.TrimSpace(p.Employer) == "" {
			continue
		}
		_, fresh, err := upsertPosting(db, p)
		if err != nil {
			return err
		}
		if fresh {
			inserted++
		} else {
			updated++
		}
	}
	fmt.Printf("inserted=%d updated=%d\n", inserted, updated)
	return nil
}

var _ = sql.ErrNoRows
