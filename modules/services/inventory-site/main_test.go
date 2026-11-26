package main

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"strings"
	"testing"
)

func testStore(t *testing.T) *Store {
	t.Helper()
	store, err := OpenStore(filepath.Join(t.TempDir(), "inventory.sqlite"))
	if err != nil {
		t.Fatalf("OpenStore: %v", err)
	}
	t.Cleanup(func() { _ = store.Close() })
	return store
}

func sampleInput() itemInput {
	return itemInput{
		Source: "manual", SourceKey: "asset/x1", Name: "ThinkPad X1 Carbon", Category: "computing", Location: "office",
		Description: "Primary laptop", Manufacturer: "Lenovo", Model: "X1 Carbon Gen 10", Serial: "PF-TEST-01",
		PurchaseDate: "2024-01-15", WarrantyUntil: "2027-01-15", ValueCents: 145000, Currency: "EUR", Quantity: 1,
		Tags: []string{"fleet", "Laptop", "fleet"}, Notes: "32 GB RAM",
	}
}

func TestValidateNormalizesItem(t *testing.T) {
	input := sampleInput()
	input.Name = "  ThinkPad   X1   Carbon  "
	input.Currency = "eur"
	input.Tags = []string{"Fleet, laptop", "fleet", "bad tag!"}
	if err := validateItem(&input); err != nil {
		t.Fatalf("validateItem: %v", err)
	}
	if input.Name != "ThinkPad X1 Carbon" || input.Currency != "EUR" || input.Quantity != 1 {
		t.Fatalf("unexpected normalization: %#v", input)
	}
	want := []string{"badtag", "fleet", "laptop"}
	if strings.Join(input.Tags, ",") != strings.Join(want, ",") {
		t.Fatalf("tags %#v want %#v", input.Tags, want)
	}
}

func TestStoreCRUDFTSMetaStatsAndCSV(t *testing.T) {
	ctx := context.Background()
	store := testStore(t)
	id, created, err := store.UpsertItem(ctx, sampleInput())
	if err != nil || !created {
		t.Fatalf("UpsertItem created=%v err=%v", created, err)
	}
	page, err := store.ListItems(ctx, itemQueryOptions{Q: "lenovo laptop", Limit: 10})
	if err != nil {
		t.Fatalf("ListItems fts: %v", err)
	}
	if page.Total != 1 || len(page.Items) != 1 || !strings.Contains(page.Items[0].Snippet, "<mark>") {
		t.Fatalf("fts page %#v", page)
	}
	item, err := store.GetItem(ctx, id)
	if err != nil {
		t.Fatalf("GetItem: %v", err)
	}
	if len(item.Tags) != 2 || item.Category != "computing" || item.Location != "office" {
		t.Fatalf("item %#v", item)
	}
	input := sampleInput()
	input.Notes = "32 GB RAM; docked"
	input.ValueCents = 139000
	updatedID, created, err := store.UpsertItem(ctx, input)
	if err != nil || created || updatedID != id {
		t.Fatalf("upsert update id=%d created=%v err=%v", updatedID, created, err)
	}
	item, err = store.GetItem(ctx, id)
	if err != nil || item.ValueCents != 139000 {
		t.Fatalf("updated item %#v err=%v", item, err)
	}

	categories, err := store.ListMeta(ctx, "categories")
	if err != nil || len(categories) != 1 || categories[0].ItemCount != 1 {
		t.Fatalf("categories %#v err=%v", categories, err)
	}
	locations, err := store.ListMeta(ctx, "locations")
	if err != nil || len(locations) != 1 || locations[0].ItemCount != 1 {
		t.Fatalf("locations %#v err=%v", locations, err)
	}
	tags, err := store.ListMeta(ctx, "tags")
	if err != nil || len(tags) != 2 {
		t.Fatalf("tags %#v err=%v", tags, err)
	}
	stats, err := store.Stats(ctx)
	if err != nil {
		t.Fatalf("Stats: %v", err)
	}
	if stats["items"] != 1 || stats["value_cents"] != 139000 || stats["with_serial"] != 1 {
		t.Fatalf("stats %#v", stats)
	}

	bundle, err := store.ExportBundle(ctx)
	if err != nil || len(bundle.Items) != 1 || len(bundle.Categories) != 1 {
		t.Fatalf("export %#v err=%v", bundle, err)
	}
	var csvOut bytes.Buffer
	if err := writeItemsCSV(&csvOut, bundle.Items); err != nil {
		t.Fatalf("writeItemsCSV: %v", err)
	}
	imported, warnings, err := itemsFromCSV(strings.NewReader(csvOut.String()))
	if err != nil || len(imported) != 1 || len(warnings) != 0 {
		t.Fatalf("itemsFromCSV len=%d warnings=%v err=%v", len(imported), warnings, err)
	}
	if imported[0].Name != item.Name || imported[0].ValueCents != item.ValueCents {
		t.Fatalf("csv roundtrip %#v", imported[0])
	}
}

func TestFleetTOMLSeedIsIdempotent(t *testing.T) {
	raw := []byte(`
[hosts.frieren]
hostname = "frieren"
status = "active"
status_detail = "NAS host"
kind = "nixos"
arch = "x86_64-linux"
role = "Central NAS"
category = "server"
[hosts.frieren.hardware]
model = "Lenovo ideapad 320"
cpu = "Intel i5"
ram = "12 GiB"
[hosts.frieren.network]
lan_ip = "192.168.3.25"
tailscale_hostname = "frieren"
[hosts.frieren.software]
module_chain = "globalModulesNixos"
traits = ["nas-server", "agent-backend"]
key_services = ["Jellyfin"]
`)
	inputs, err := itemsFromFleetTOML(raw)
	if err != nil {
		t.Fatalf("itemsFromFleetTOML: %v", err)
	}
	if len(inputs) != 1 || inputs[0].Name != "frieren" || inputs[0].SourceKey != "host/frieren" || inputs[0].Manufacturer != "Lenovo" {
		t.Fatalf("seed input %#v", inputs)
	}
	store := testStore(t)
	first, err := store.ImportItems(context.Background(), inputs)
	if err != nil || first.Inserted != 1 || first.Updated != 0 {
		t.Fatalf("first import %#v err=%v", first, err)
	}
	second, err := store.ImportItems(context.Background(), inputs)
	if err != nil || second.Inserted != 0 || second.Updated != 1 {
		t.Fatalf("second import %#v err=%v", second, err)
	}
}

func TestHTTPWriteOriginAndImportExport(t *testing.T) {
	store := testStore(t)
	s := &server{store: store, expectedOrigin: "https://delphi.example:8466"}
	mux := http.NewServeMux()
	mux.HandleFunc("POST /api/items", s.createItem)
	mux.HandleFunc("GET /api/items", s.items)
	mux.HandleFunc("POST /api/import/inventory-toml", s.importFleetTOML)

	body := strings.NewReader(`{"name":"NAS backup disk","category":"storage","location":"basement","value_cents":8900,"tags":["backup"]}`)
	req := httptest.NewRequest("POST", "/api/items", body)
	req.Header.Set("content-type", "application/json")
	req.Header.Set("origin", "https://evil.example")
	recorder := httptest.NewRecorder()
	mux.ServeHTTP(recorder, req)
	if recorder.Code != http.StatusForbidden {
		t.Fatalf("wrong origin status %d body %s", recorder.Code, recorder.Body.String())
	}

	req = httptest.NewRequest("POST", "/api/items", strings.NewReader(`{"name":"NAS backup disk","category":"storage","location":"basement","value_cents":8900,"tags":["backup"]}`))
	req.Header.Set("content-type", "application/json")
	req.Header.Set("origin", "https://delphi.example:8466")
	recorder = httptest.NewRecorder()
	mux.ServeHTTP(recorder, req)
	if recorder.Code != http.StatusCreated {
		t.Fatalf("create status %d body %s", recorder.Code, recorder.Body.String())
	}

	req = httptest.NewRequest("GET", "/api/items?q=backup", nil)
	recorder = httptest.NewRecorder()
	mux.ServeHTTP(recorder, req)
	if recorder.Code != http.StatusOK || !strings.Contains(recorder.Body.String(), "NAS backup disk") {
		t.Fatalf("search status %d body %s", recorder.Code, recorder.Body.String())
	}

	seed := `[hosts.testbox]
hostname = "testbox"
status = "active"
kind = "nixos"
arch = "x86_64-linux"
category = "server"
[hosts.testbox.hardware]
model = "Test Machine"
`
	req = httptest.NewRequest("POST", "/api/import/inventory-toml", strings.NewReader(seed))
	req.Header.Set("origin", "https://delphi.example:8466")
	recorder = httptest.NewRecorder()
	mux.ServeHTTP(recorder, req)
	if recorder.Code != http.StatusOK {
		t.Fatalf("toml import status %d body %s", recorder.Code, recorder.Body.String())
	}
	var result importResult
	if err := json.Unmarshal(recorder.Body.Bytes(), &result); err != nil {
		t.Fatalf("decode import result: %v", err)
	}
	if result.Inserted != 1 {
		t.Fatalf("import result %#v", result)
	}
}
