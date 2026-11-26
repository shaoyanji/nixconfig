package main

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func testDB(t *testing.T) string {
	t.Helper()
	return filepath.Join(t.TempDir(), "test.db")
}

func TestUpsertAndSearch(t *testing.T) {
	db, err := openStore(testDB(t))
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()
	id, fresh, err := upsertItem(db, Item{Name: "ThinkPad T480", Category: "laptop", Serial: "SN123", Tags: []string{"Fleet-Host", "work"}})
	if err != nil {
		t.Fatal(err)
	}
	if !fresh {
		t.Fatal("first insert must be new")
	}
	// Upsert again: same (name, serial) updates in place.
	id2, fresh2, err := upsertItem(db, Item{Name: "ThinkPad T480", Category: "laptop", Serial: "SN123", Location: "office"})
	if err != nil {
		t.Fatal(err)
	}
	if fresh2 || id2 != id {
		t.Fatalf("upsert must update in place: id %d vs %d, fresh %v", id, id2, fresh2)
	}
	it, err := getItem(db, id)
	if err != nil {
		t.Fatal(err)
	}
	if it.Location != "office" {
		t.Fatalf("location update lost: %q", it.Location)
	}
	// FTS finds by name token and by tag.
	for _, q := range []string{"thinkpad", "fleet-host", "fleet"} {
		got, err := searchItems(db, q, 10)
		if err != nil {
			t.Fatalf("search %q: %v", q, err)
		}
		if len(got) != 1 {
			t.Fatalf("search %q: want 1 hit, got %d", q, len(got))
		}
	}
	// FTS finds by serial.
	got, err := searchItems(db, "SN123", 10)
	if err != nil || len(got) != 1 {
		t.Fatalf("serial search: %v %d", err, len(got))
	}
}

func TestTagsNormalizedAndFaceted(t *testing.T) {
	db, err := openStore(testDB(t))
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()
	if _, _, err := upsertItem(db, Item{Name: "a", Tags: []string{"  Foo ", "foo", "BAR"}}); err != nil {
		t.Fatal(err)
	}
	_, _, tags, err := facets(db)
	if err != nil {
		t.Fatal(err)
	}
	joined := strings.Join(tags, ",")
	if joined != "bar,foo" {
		t.Fatalf("tags want bar,foo got %q", joined)
	}
	// Filter by tag (case-insensitive).
	got, err := filterItems(db, "", "", "FOO", 10)
	if err != nil || len(got) != 1 {
		t.Fatalf("tag filter: %v len=%d", err, len(got))
	}
}

func TestJSONRoundTrip(t *testing.T) {
	db, err := openStore(testDB(t))
	if err != nil {
		t.Fatal(err)
	}
	if _, _, err := upsertItem(db, Item{Name: "nas", Location: "cellar", ValueCents: 39900, Tags: []string{"storage"}}); err != nil {
		t.Fatal(err)
	}
	var buf bytes.Buffer
	if err := exportJSON(db, &buf); err != nil {
		t.Fatal(err)
	}
	db.Close()
	// Import into a fresh store.
	db2, err := openStore(testDB(t))
	if err != nil {
		t.Fatal(err)
	}
	defer db2.Close()
	n, err := importJSON(db2, &buf)
	if err != nil {
		t.Fatal(err)
	}
	if n != 1 {
		t.Fatalf("imported %d, want 1", n)
	}
	items, err := listItems(db2, 10)
	if err != nil || len(items) != 1 {
		t.Fatalf("list: %v len=%d", err, len(items))
	}
	if items[0].ValueCents != 39900 || len(items[0].Tags) != 1 || items[0].Tags[0] != "storage" {
		t.Fatalf("round trip lost data: %+v", items[0])
	}
}

func TestCSVRoundTrip(t *testing.T) {
	db, err := openStore(testDB(t))
	if err != nil {
		t.Fatal(err)
	}
	if _, _, err := upsertItem(db, Item{Name: "monitor, curved", Location: "desk", Serial: "M1", ValueCents: 19999, Tags: []string{"a", "b"}}); err != nil {
		t.Fatal(err)
	}
	var buf bytes.Buffer
	if err := exportCSV(db, &buf); err != nil {
		t.Fatal(err)
	}
	db.Close()
	db2, err := openStore(testDB(t))
	if err != nil {
		t.Fatal(err)
	}
	defer db2.Close()
	n, err := importCSV(db2, &buf)
	if err != nil {
		t.Fatalf("import: %v\ncsv:\n%s", err, buf.String())
	}
	if n != 1 {
		t.Fatalf("imported %d, want 1", n)
	}
	items, _ := listItems(db2, 10)
	if items[0].Name != "monitor, curved" || len(items[0].Tags) != 2 || items[0].ValueCents != 19999 {
		t.Fatalf("csv round trip: %+v", items[0])
	}
}

func TestSeedHosts(t *testing.T) {
	db, err := openStore(testDB(t))
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()
	seed := filepath.Join(t.TempDir(), "seed.json")
	os.WriteFile(seed, []byte(`[
	 {"name":"delphi","description":"OCI Ampere A1","tags":["fleet-host","aarch64-linux"],"notes":"tailnet resolver"},
	 {"name":"frieren","description":"MINISFORUM","tags":["fleet-host","x86_64-linux"],"notes":""}
	]`), 0o644)
	n, err := seedHosts(db, seed)
	if err != nil {
		t.Fatal(err)
	}
	if n != 2 {
		t.Fatalf("seeded %d, want 2", n)
	}
	// Idempotent: a second seed updates in place.
	if n2, err := seedHosts(db, seed); err != nil || n2 != 2 {
		t.Fatalf("reseed: %v %d", err, n2)
	}
	items, _ := listItems(db, 10)
	if len(items) != 2 {
		t.Fatalf("reseed duplicated: len=%d", len(items))
	}
	got, err := filterItems(db, "fleet", "host", "", 10)
	if err != nil || len(got) != 2 {
		t.Fatalf("filter fleet/host: %v len=%d", err, len(got))
	}
}

func TestHTTPAPI(t *testing.T) {
	db, err := openStore(testDB(t))
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()
	srv := httptest.NewServer((&server{db: db}).mux())
	defer srv.Close()

	// POST an item.
	body := `{"name":"camera","category":"photo","serial":"C77","tags":["kit"]}`
	resp, err := http.Post(srv.URL+"/api/items", "application/json", strings.NewReader(body))
	if err != nil {
		t.Fatal(err)
	}
	if resp.StatusCode != 200 {
		t.Fatalf("post status %d", resp.StatusCode)
	}
	resp.Body.Close()

	// GET list with FTS query.
	r, err := http.Get(srv.URL + "/api/items?q=camera")
	if err != nil {
		t.Fatal(err)
	}
	var out struct {
		Count int `json:"count"`
	}
	json.NewDecoder(r.Body).Decode(&out)
	r.Body.Close()
	if out.Count != 1 {
		t.Fatalf("fts via api: count %d", out.Count)
	}

	// CSV import endpoint.
	csvBody := "name,location,tags\nkettle,kitchen,appliance\n"
	r2, err := http.Post(srv.URL+"/api/import/csv", "text/csv", strings.NewReader(csvBody))
	if err != nil {
		t.Fatal(err)
	}
	var imp struct {
		Imported int `json:"imported"`
	}
	json.NewDecoder(r2.Body).Decode(&imp)
	r2.Body.Close()
	if imp.Imported != 1 {
		t.Fatalf("csv import via api: %d", imp.Imported)
	}

	// Delete.
	req, _ := http.NewRequest("DELETE", srv.URL+"/api/items/1", nil)
	dr, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	dr.Body.Close()
	if dr.StatusCode != 200 {
		t.Fatalf("delete status %d", dr.StatusCode)
	}

	// Health.
	hr, err := http.Get(srv.URL + "/healthz")
	if err != nil {
		t.Fatal(err)
	}
	hr.Body.Close()
	if hr.StatusCode != 200 {
		t.Fatalf("healthz %d", hr.StatusCode)
	}
}
