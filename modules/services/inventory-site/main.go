// inventory-site — a tailnet asset inventory: SQLite/FTS5 store with
// locations, categories, tags, serials, warranties and value, JSON/CSV
// import and export, a JSON API and a search UI. Verbs:
//
//	inventory-site serve -addr 127.0.0.1:8100 -db /var/lib/inventory-site/inventory.db [-seed hosts.json]
//	inventory-site add -db ... -name X [-location L] [-category C] [-serial S] [-tags a,b]
//	inventory-site search -db ... <query>
//	inventory-site export -db ... [-format json|csv]
//	inventory-site import -db ... [-format json|csv] < file
//	inventory-site seed -db ... -seed hosts.json
package main

import (
	"database/sql"
	"flag"
	"fmt"
	"log"
	"net/http"
	"os"
	"strings"
	"time"
)

func usage() {
	fmt.Fprintln(os.Stderr, "usage: inventory-site <serve|add|search|export|import|seed> [flags]")
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
	case "export":
		err = cmdExport(os.Args[2:])
	case "import":
		err = cmdImport(os.Args[2:])
	case "seed":
		err = cmdSeed(os.Args[2:])
	default:
		usage()
	}
	if err != nil {
		log.Fatal(err)
	}
}

func dbFlag(fs *flag.FlagSet) *string {
	return fs.String("db", envOr("INVENTORY_SITE_DB", "/var/lib/inventory-site/inventory.db"), "sqlite path")
}

func envOr(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func cmdServe(args []string) error {
	fs := flag.NewFlagSet("serve", flag.ExitOnError)
	addr := fs.String("addr", envOr("INVENTORY_SITE_ADDR", "127.0.0.1:8100"), "loopback listen address")
	dbPath := dbFlag(fs)
	seed := fs.String("seed", envOr("INVENTORY_SITE_SEED", ""), "fleet seed JSON projected by the service module")
	fs.Parse(args)
	db, err := openStore(*dbPath)
	if err != nil {
		return err
	}
	defer db.Close()
	if *seed != "" {
		if empty, err := storeEmpty(db); err == nil && empty {
			if n, err := seedHosts(db, *seed); err != nil {
				log.Printf("seed: %v", err)
			} else if n > 0 {
				log.Printf("seeded %d fleet hosts", n)
			}
		}
	}
	srv := &http.Server{
		Addr:              *addr,
		Handler:           (&server{db: db, seedPath: *seed}).mux(),
		ReadHeaderTimeout: 10 * time.Second,
	}
	log.Printf("inventory-site listening on %s", *addr)
	return srv.ListenAndServe()
}

func storeEmpty(db *sql.DB) (bool, error) {
	var n int
	err := db.QueryRow(`SELECT count(*) FROM items`).Scan(&n)
	return n == 0, err
}

func cmdAdd(args []string) error {
	fs := flag.NewFlagSet("add", flag.ExitOnError)
	dbPath := dbFlag(fs)
	it := Item{}
	fs.StringVar(&it.Name, "name", "", "item name")
	fs.StringVar(&it.Description, "description", "", "")
	fs.StringVar(&it.Location, "location", "", "")
	fs.StringVar(&it.Category, "category", "", "")
	fs.StringVar(&it.Serial, "serial", "", "")
	fs.StringVar(&it.PurchaseDate, "purchase-date", "", "")
	fs.StringVar(&it.WarrantyUntil, "warranty-until", "", "")
	fs.Int64Var(&it.ValueCents, "value-cents", 0, "")
	fs.StringVar(&it.Notes, "notes", "", "")
	tags := fs.String("tags", "", "comma-separated")
	fs.Parse(args)
	if strings.TrimSpace(it.Name) == "" {
		return fmt.Errorf("-name is required")
	}
	if *tags != "" {
		for _, t := range strings.Split(*tags, ",") {
			it.Tags = append(it.Tags, strings.TrimSpace(t))
		}
	}
	db, err := openStore(*dbPath)
	if err != nil {
		return err
	}
	defer db.Close()
	id, fresh, err := upsertItem(db, it)
	if err != nil {
		return err
	}
	fmt.Printf("id=%d new=%v\n", id, fresh)
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
	items, err := searchItems(db, strings.Join(fs.Args(), " "), 50)
	if err != nil {
		return err
	}
	for _, it := range items {
		fmt.Printf("%d\t%s\t%s\t%s\n", it.ID, it.Name, it.Location, it.Category)
	}
	return nil
}

func cmdExport(args []string) error {
	fs := flag.NewFlagSet("export", flag.ExitOnError)
	dbPath := dbFlag(fs)
	format := fs.String("format", "json", "json|csv")
	fs.Parse(args)
	db, err := openStore(*dbPath)
	if err != nil {
		return err
	}
	defer db.Close()
	switch *format {
	case "json":
		return exportJSON(db, os.Stdout)
	case "csv":
		return exportCSV(db, os.Stdout)
	}
	return fmt.Errorf("unknown format %q", *format)
}

func cmdImport(args []string) error {
	fs := flag.NewFlagSet("import", flag.ExitOnError)
	dbPath := dbFlag(fs)
	format := fs.String("format", "json", "json|csv")
	fs.Parse(args)
	db, err := openStore(*dbPath)
	if err != nil {
		return err
	}
	defer db.Close()
	var n int
	switch *format {
	case "json":
		n, err = importJSON(db, os.Stdin)
	case "csv":
		n, err = importCSV(db, os.Stdin)
	default:
		return fmt.Errorf("unknown format %q", *format)
	}
	if err != nil {
		return err
	}
	fmt.Printf("imported=%d\n", n)
	return nil
}

func cmdSeed(args []string) error {
	fs := flag.NewFlagSet("seed", flag.ExitOnError)
	dbPath := dbFlag(fs)
	seed := fs.String("seed", "", "fleet seed JSON")
	fs.Parse(args)
	if *seed == "" {
		return fmt.Errorf("-seed is required")
	}
	db, err := openStore(*dbPath)
	if err != nil {
		return err
	}
	defer db.Close()
	n, err := seedHosts(db, *seed)
	if err != nil {
		return err
	}
	fmt.Printf("seeded=%d\n", n)
	return nil
}
