// JSON and CSV import/export, plus the fleet-host seed from inventory.toml.
//
// JSON is the full-fidelity format (round-trips tags as arrays); CSV is the
// spreadsheet interchange — one row per item, tags as a semicolon-joined cell.
package main

import (
	"os"
	"database/sql"
	"encoding/csv"
	"encoding/json"
	"fmt"
	"io"
	"strconv"
	"strings"
)

const exportVersion = 1

type exportDoc struct {
	Version int    `json:"version"`
	Items   []Item `json:"items"`
}

func exportJSON(db *sql.DB, w io.Writer) error {
	items, err := listItems(db, 1<<30)
	if err != nil {
		return err
	}
	if items == nil {
		items = []Item{}
	}
	enc := json.NewEncoder(w)
	enc.SetIndent("", "  ")
	return enc.Encode(exportDoc{Version: exportVersion, Items: items})
}

func importJSON(db *sql.DB, r io.Reader) (int, error) {
	var doc exportDoc
	if err := json.NewDecoder(r).Decode(&doc); err != nil {
		return 0, fmt.Errorf("bad json: %w", err)
	}
	n := 0
	for _, it := range doc.Items {
		if strings.TrimSpace(it.Name) == "" {
			continue
		}
		if _, _, err := upsertItem(db, it); err != nil {
			return n, fmt.Errorf("item %q: %w", it.Name, err)
		}
		n++
	}
	return n, nil
}

var csvHeader = []string{"name", "description", "location", "category", "serial", "purchase_date", "warranty_until", "value_cents", "currency", "notes", "tags"}

func exportCSV(db *sql.DB, w io.Writer) error {
	items, err := listItems(db, 1<<30)
	if err != nil {
		return err
	}
	cw := csv.NewWriter(w)
	defer cw.Flush()
	if err := cw.Write(csvHeader); err != nil {
		return err
	}
	for _, it := range items {
		if err := cw.Write([]string{
			it.Name, it.Description, it.Location, it.Category, it.Serial,
			it.PurchaseDate, it.WarrantyUntil, strconv.FormatInt(it.ValueCents, 10), it.Currency,
			it.Notes, strings.Join(it.Tags, ";"),
		}); err != nil {
			return err
		}
	}
	return cw.Error()
}

func importCSV(db *sql.DB, r io.Reader) (int, error) {
	cr := csv.NewReader(r)
	cr.TrimLeadingSpace = true
	head, err := cr.Read()
	if err != nil {
		return 0, fmt.Errorf("bad csv header: %w", err)
	}
	idx := map[string]int{}
	for i, h := range head {
		idx[strings.ToLower(strings.TrimSpace(h))] = i
	}
	if _, ok := idx["name"]; !ok {
		return 0, fmt.Errorf("csv needs a name column")
	}
	cell := func(row []string, k string) string {
		if i, ok := idx[k]; ok && i < len(row) {
			return row[i]
		}
		return ""
	}
	n := 0
	for {
		row, err := cr.Read()
		if err == io.EOF {
			return n, nil
		}
		if err != nil {
			return n, fmt.Errorf("row %d: %w", n+2, err)
		}
		cents, _ := strconv.ParseInt(cell(row, "value_cents"), 10, 64)
		var tags []string
		for _, t := range strings.Split(cell(row, "tags"), ";") {
			if strings.TrimSpace(t) != "" {
				tags = append(tags, t)
			}
		}
		it := Item{
			Name:          cell(row, "name"),
			Description:   cell(row, "description"),
			Location:      cell(row, "location"),
			Category:      cell(row, "category"),
			Serial:        cell(row, "serial"),
			PurchaseDate:  cell(row, "purchase_date"),
			WarrantyUntil: cell(row, "warranty_until"),
			ValueCents:    cents,
			Currency:      cell(row, "currency"),
			Notes:         cell(row, "notes"),
			Tags:          tags,
		}
		if strings.TrimSpace(it.Name) == "" {
			continue
		}
		if _, _, err := upsertItem(db, it); err != nil {
			return n, fmt.Errorf("row %d %q: %w", n+2, it.Name, err)
		}
		n++
	}
}

// seedHostDoc is the module-projected fleet seed: one object per host, written
// at eval time from the compiled inventory so the service never parses TOML.
type seedHost struct {
	Name        string   `json:"name"`
	Description string   `json:"description"`
	Tags        []string `json:"tags"`
	Notes       string   `json:"notes"`
}

// seedHosts upserts one item per fleet host from the seed JSON the service
// module projects out of the compiled inventory at eval time.
func seedHosts(db *sql.DB, seedPath string) (int, error) {
	f, err := osOpen(seedPath)
	if err != nil {
		return 0, err
	}
	defer f.Close()
	var hosts []seedHost
	if err := json.NewDecoder(f).Decode(&hosts); err != nil {
		return 0, fmt.Errorf("bad seed json: %w", err)
	}
	n := 0
	for _, h := range hosts {
		it := Item{
			Name:        h.Name,
			Description: h.Description,
			Location:    "fleet",
			Category:    "host",
			Tags:        h.Tags,
			Notes:       h.Notes,
		}
		if _, _, err := upsertItem(db, it); err != nil {
			return n, fmt.Errorf("host %q: %w", h.Name, err)
		}
		n++
	}
	return n, nil
}

// osOpen is a variable so tests can hook it; the fleet seed is a store path.
var osOpen = func(p string) (io.ReadCloser, error) { return os.Open(p) }
