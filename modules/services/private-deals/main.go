// private-deals — a tailnet deals/watchlist service: SQLite/FTS5 store, RSS
// and manual ingestion, JSON API and a search UI. Verbs:
//
//	private-deals serve -addr 127.0.0.1:8471 -db /var/lib/private-deals/deals.db
//	private-deals ingest -db ...           one ingestion pass over the feeds
//	private-deals add -db ... -title X [-url U] [-price-cents N] [-notes T]
//	private-deals search -db ... <query>
package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"net/http"
	"os"
	"time"
)

func usage() {
	fmt.Fprintln(os.Stderr, "usage: private-deals <serve|ingest|add|search> [flags]")
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
	case "ingest":
		err = cmdIngest(os.Args[2:])
	case "add":
		err = cmdAdd(os.Args[2:])
	case "search":
		err = cmdSearch(os.Args[2:])
	default:
		usage()
	}
	if err != nil {
		log.Fatal(err)
	}
}

func dbFlag(fs *flag.FlagSet) *string {
	return fs.String("db", envOr("PRIVATE_DEALS_DB", "/var/lib/private-deals/deals.db"), "sqlite path")
}

func envOr(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func cmdServe(args []string) error {
	fs := flag.NewFlagSet("serve", flag.ExitOnError)
	addr := fs.String("addr", envOr("PRIVATE_DEALS_ADDR", "127.0.0.1:8471"), "listen address")
	db := dbFlag(fs)
	fs.Parse(args)
	store, err := openStore(*db)
	if err != nil {
		return err
	}
	defer store.Close()
	srv := &http.Server{
		Addr:              *addr,
		Handler:           (&server{db: store}).mux(),
		ReadHeaderTimeout: 5 * time.Second,
	}
	log.Printf("private-deals: serving %s (db %s)", *addr, *db)
	return srv.ListenAndServe()
}

func cmdIngest(args []string) error {
	fs := flag.NewFlagSet("ingest", flag.ExitOnError)
	db := dbFlag(fs)
	fs.Parse(args)
	store, err := openStore(*db)
	if err != nil {
		return err
	}
	defer store.Close()
	ok, failed := ingestAll(store)
	out, _ := json.Marshal(map[string]any{"ingested": ok, "failed": failed})
	fmt.Println(string(out))
	if len(failed) > 0 && len(ok) == 0 {
		return fmt.Errorf("every feed failed")
	}
	return nil
}

func cmdAdd(args []string) error {
	fs := flag.NewFlagSet("add", flag.ExitOnError)
	db := dbFlag(fs)
	title := fs.String("title", "", "deal title (required)")
	url := fs.String("url", "", "deal url")
	price := fs.Int64("price-cents", 0, "price in cents")
	notes := fs.String("notes", "", "notes")
	source := fs.String("source", "manual", "ingestion source")
	fs.Parse(args)
	if *title == "" {
		return fmt.Errorf("add: -title is required")
	}
	store, err := openStore(*db)
	if err != nil {
		return err
	}
	defer store.Close()
	id, fresh, err := upsertDeal(store, Deal{Title: *title, URL: *url, PriceCents: *price, Notes: *notes, Source: *source})
	if err != nil {
		return err
	}
	fmt.Printf("id=%d new=%v\n", id, fresh)
	return nil
}

func cmdSearch(args []string) error {
	fs := flag.NewFlagSet("search", flag.ExitOnError)
	db := dbFlag(fs)
	fs.Parse(args)
	if fs.NArg() == 0 {
		return fmt.Errorf("search: a query is required")
	}
	store, err := openStore(*db)
	if err != nil {
		return err
	}
	defer store.Close()
	deals, err := searchDeals(store, fs.Arg(0), 50)
	if err != nil {
		return err
	}
	out, _ := json.MarshalIndent(deals, "", "  ")
	fmt.Println(string(out))
	return nil
}
