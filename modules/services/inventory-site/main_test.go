package main

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"strconv"
	"strings"
	"sync/atomic"
	"testing"
	"time"
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

func TestAssetEventsAutomaticAndManualCheckout(t *testing.T) {
	ctx := context.Background()
	store := testStore(t)
	input := sampleInput()
	id, _, err := store.UpsertItem(ctx, input)
	if err != nil {
		t.Fatalf("UpsertItem: %v", err)
	}
	input.Location = "workshop"
	input.Notes = "moved for repair"
	if err := store.UpdateItem(ctx, id, input); err != nil {
		t.Fatalf("UpdateItem: %v", err)
	}
	event, err := store.AddAssetEvent(ctx, id, assetEventInput{Kind: "checkout", Actor: "dev", Location: "field kit", Note: "weekend diagnostics"})
	if err != nil {
		t.Fatalf("AddAssetEvent: %v", err)
	}
	if event.Kind != "checkout" || event.FromLocation != "workshop" || event.ToLocation != "field kit" {
		t.Fatalf("manual event %#v", event)
	}
	item, err := store.GetItem(ctx, id)
	if err != nil || item.Location != "field kit" {
		t.Fatalf("location after checkout %#v err=%v", item, err)
	}
	events, err := store.ListAssetEvents(ctx, id, 20)
	if err != nil {
		t.Fatalf("ListAssetEvents: %v", err)
	}
	kinds := map[string]int{}
	for _, event := range events {
		kinds[event.Kind]++
	}
	if kinds["create"] != 1 || kinds["location-move"] != 1 || kinds["update"] != 1 || kinds["checkout"] != 1 {
		t.Fatalf("event kinds %#v events=%#v", kinds, events)
	}
}

func TestWarrantyAlertEvaluationIsDedupedAndNotifies(t *testing.T) {
	ctx := context.Background()
	store := testStore(t)
	input := sampleInput()
	input.WarrantyUntil = time.Now().UTC().AddDate(0, 0, 9).Format("2006-01-02")
	if _, _, err := store.UpsertItem(ctx, input); err != nil {
		t.Fatalf("UpsertItem: %v", err)
	}
	var calls atomic.Int32
	ntfy := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		calls.Add(1)
		if r.Header.Get("Title") == "" {
			t.Errorf("missing ntfy title")
		}
		w.WriteHeader(http.StatusOK)
	}))
	defer ntfy.Close()
	manager := newWarrantyAlertManager(store, ntfy.URL, 30)
	first, err := manager.evaluate(ctx, true)
	if err != nil {
		t.Fatalf("first evaluate: %v", err)
	}
	if first.Matched != 1 || first.Created != 1 || first.Notified != 1 || first.Failed != 0 {
		t.Fatalf("first summary %#v", first)
	}
	second, err := manager.evaluate(ctx, true)
	if err != nil {
		t.Fatalf("second evaluate: %v", err)
	}
	if second.Matched != 1 || second.Created != 0 || second.Existing != 1 || second.Notified != 0 {
		t.Fatalf("second summary %#v", second)
	}
	if calls.Load() != 1 {
		t.Fatalf("ntfy calls %d", calls.Load())
	}
	alerts, err := store.ListWarrantyAlerts(ctx, 10)
	if err != nil || len(alerts) != 1 || alerts[0].Status != "sent" || alerts[0].NotifyCount != 1 {
		t.Fatalf("alerts %#v err=%v", alerts, err)
	}
}

func TestWarrantyEvaluationFailureIsRecorded(t *testing.T) {
	ctx := context.Background()
	store := testStore(t)
	input := sampleInput()
	input.WarrantyUntil = time.Now().UTC().AddDate(0, 0, 2).Format("2006-01-02")
	if _, _, err := store.UpsertItem(ctx, input); err != nil {
		t.Fatalf("UpsertItem: %v", err)
	}
	ntfy := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusBadGateway)
	}))
	defer ntfy.Close()
	manager := newWarrantyAlertManager(store, ntfy.URL, 30)
	summary, err := manager.evaluate(ctx, true)
	if err != nil || summary.Failed != 1 {
		t.Fatalf("summary %#v err=%v", summary, err)
	}
	alerts, err := store.ListWarrantyAlerts(ctx, 10)
	if err != nil || len(alerts) != 1 || alerts[0].Status != "failed" || alerts[0].LastError == "" {
		t.Fatalf("alerts %#v err=%v", alerts, err)
	}
}

func TestQRLabelEndpointReturnsPrintableSVG(t *testing.T) {
	store := testStore(t)
	id, _, err := store.UpsertItem(context.Background(), sampleInput())
	if err != nil {
		t.Fatalf("UpsertItem: %v", err)
	}
	s := &server{store: store, expectedOrigin: "https://delphi.example:8466"}
	mux := http.NewServeMux()
	mux.HandleFunc("GET /api/items/{id}/qr.svg", s.itemQRLabel)
	mux.HandleFunc("GET /api/items/{id}/events", s.itemEvents)
	recorder := httptest.NewRecorder()
	mux.ServeHTTP(recorder, httptest.NewRequest("GET", "/api/items/"+strconv.FormatInt(id, 10)+"/qr.svg", nil))
	body := recorder.Body.String()
	if recorder.Code != http.StatusOK || !strings.Contains(body, "<svg") || !strings.Contains(body, "<rect") || !strings.Contains(body, "ThinkPad X1 Carbon") {
		t.Fatalf("qr status=%d type=%s body=%.300s", recorder.Code, recorder.Header().Get("content-type"), body)
	}
	recorder = httptest.NewRecorder()
	mux.ServeHTTP(recorder, httptest.NewRequest("GET", "/api/items/"+strconv.FormatInt(id, 10)+"/events", nil))
	if recorder.Code != http.StatusOK || !strings.Contains(recorder.Body.String(), "asset created") {
		t.Fatalf("events status=%d body=%s", recorder.Code, recorder.Body.String())
	}
}

func analyticsSeed(t *testing.T, store *Store) map[string]int64 {
	t.Helper()
	ctx := context.Background()
	expiring := time.Now().UTC().AddDate(0, 0, 10).Format("2006-01-02")
	inputs := map[string]itemInput{
		"laptop": {Source: "manual", SourceKey: "analytics/laptop", Name: "Laptop", Category: "computing", Location: "office",
			ValueCents: 100000, Currency: "EUR", Quantity: 2, WarrantyUntil: "2099-01-15", Tags: []string{"fleet", "laptop"}},
		"headset": {Source: "manual", SourceKey: "analytics/headset", Name: "Headset", Category: "audio", Location: "lounge",
			ValueCents: 50000, Currency: "EUR", Quantity: 1, WarrantyUntil: "2020-01-01", Tags: []string{"audio"}},
		"cable": {Source: "manual", SourceKey: "analytics/cable", Name: "Cable", Category: "misc", Location: "",
			ValueCents: 0, Currency: "EUR", Quantity: 1, WarrantyUntil: expiring, Tags: []string{"fleet"}},
		"desk": {Source: "manual", SourceKey: "analytics/desk", Name: "Desk", Category: "misc", Location: "office",
			ValueCents: 25000, Currency: "EUR", Quantity: 1, WarrantyUntil: ""},
	}
	ids := map[string]int64{}
	for key, input := range inputs {
		id, created, err := store.UpsertItem(ctx, input)
		if err != nil || !created {
			t.Fatalf("UpsertItem %s created=%v err=%v", key, created, err)
		}
		ids[key] = id
	}
	for _, event := range []struct {
		item int64
		in   assetEventInput
	}{
		{ids["laptop"], assetEventInput{Kind: "checkout", Actor: "buffy", Location: "office", Note: "lent out"}},
		{ids["laptop"], assetEventInput{Kind: "checkin", Actor: "buffy", Note: "returned"}},
		{ids["desk"], assetEventInput{Kind: "note", Note: "assembled"}},
	} {
		if _, err := store.AddAssetEvent(ctx, event.item, event.in); err != nil {
			t.Fatalf("AddAssetEvent %s: %v", event.in.Kind, err)
		}
	}
	return ids
}

func bucketByName(rows []valueBucket, name string) (valueBucket, bool) {
	for _, row := range rows {
		if row.Name == name {
			return row, true
		}
	}
	return valueBucket{}, false
}

func TestAnalyticsValuesTheRegisterByCategoryAndLocation(t *testing.T) {
	store := testStore(t)
	analyticsSeed(t, store)

	report, err := store.Analytics(context.Background(), 30, 8)
	if err != nil {
		t.Fatalf("Analytics: %v", err)
	}
	if report.Items != 4 || report.Quantity != 5 || report.ValueCents != 275000 {
		t.Fatalf("totals %#v, want 4 items, 5 units, 275000 cents", report)
	}
	if report.Currency != "EUR" || report.Archived != 0 {
		t.Fatalf("currency/archived %#v", report)
	}

	if len(report.Categories) != 3 {
		t.Fatalf("categories %#v, want computing, audio, misc", report.Categories)
	}
	if report.Categories[0].Name != "computing" || report.Categories[0].ValueCents != 200000 || report.Categories[0].Quantity != 2 {
		t.Fatalf("top category %#v, want computing at 200000 over two units", report.Categories[0])
	}
	if report.Categories[0].Share != 72.7 {
		t.Fatalf("computing share %v, want 72.7", report.Categories[0].Share)
	}
	if last := report.Categories[len(report.Categories)-1]; last.Name != "misc" || last.ValueCents != 25000 {
		t.Fatalf("last category %#v, want misc at 25000", last)
	}

	office, ok := bucketByName(report.Locations, "office")
	if !ok || office.ValueCents != 225000 || office.Share != 81.8 {
		t.Fatalf("office bucket %#v ok=%v, want 225000 and 81.8%%", office, ok)
	}
	if unplaced, ok := bucketByName(report.Locations, "unplaced"); !ok || unplaced.Items != 1 || unplaced.ValueCents != 0 {
		t.Fatalf("unplaced bucket %#v ok=%v, want the zero-value cable", unplaced, ok)
	}
}

func TestAnalyticsWarrantyTagsAndEvents(t *testing.T) {
	store := testStore(t)
	analyticsSeed(t, store)

	report, err := store.Analytics(context.Background(), 30, 8)
	if err != nil {
		t.Fatalf("Analytics: %v", err)
	}
	if len(report.Warranty) != 4 {
		t.Fatalf("warranty %#v, want four buckets always", report.Warranty)
	}
	want := map[string]struct {
		items int
		value int64
	}{
		"expired":      {1, 50000},
		"expiring_30d": {1, 0},
		"healthy":      {1, 200000},
		"none":         {1, 25000},
	}
	for i, key := range []string{"expired", "expiring_30d", "healthy", "none"} {
		bucket := report.Warranty[i]
		if bucket.Key != key || bucket.Items != want[key].items || bucket.ValueCents != want[key].value {
			t.Fatalf("warranty bucket %d %#v, want %s %+v", i, bucket, key, want[key])
		}
	}

	if len(report.Tags) != 3 || report.Tags[0].Name != "fleet" || report.Tags[0].Items != 2 {
		t.Fatalf("tags %#v, want fleet leading with two items", report.Tags)
	}
	if len(report.Events) == 0 || report.Events[0].Kind != "create" || report.Events[0].Events != 4 {
		t.Fatalf("events %#v, want create leading with four", report.Events)
	}
	if report.EventsTotal != 7 || report.EventsRecent != 7 {
		t.Fatalf("event totals total=%d recent=%d, want 7/7", report.EventsTotal, report.EventsRecent)
	}
	for _, bucket := range report.Events {
		if bucket.Kind == "checkout" && (bucket.Events != 1 || bucket.Items != 1 || bucket.LastAt.IsZero()) {
			t.Fatalf("checkout bucket %#v", bucket)
		}
	}
}

func TestAnalyticsHandlerDefaultsAndLimits(t *testing.T) {
	store := testStore(t)
	analyticsSeed(t, store)
	s := &server{store: store}

	rec := httptest.NewRecorder()
	s.analytics(rec, httptest.NewRequest(http.MethodGet, "/api/analytics", nil))
	if rec.Code != http.StatusOK {
		t.Fatalf("status %d: %s", rec.Code, rec.Body.String())
	}
	var report inventoryAnalytics
	if err := json.Unmarshal(rec.Body.Bytes(), &report); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if report.Days != 30 || len(report.Warranty) != 4 || report.Items != 4 {
		t.Fatalf("defaults %#v, want a 30-day window over four items", report)
	}

	rec = httptest.NewRecorder()
	s.analytics(rec, httptest.NewRequest(http.MethodGet, "/api/analytics?limit=1&days=900", nil))
	if err := json.Unmarshal(rec.Body.Bytes(), &report); err != nil {
		t.Fatalf("decode second: %v", err)
	}
	if len(report.Categories) != 1 || len(report.Locations) != 1 || report.Days != 365 {
		t.Fatalf("limit/days not applied: %#v", report)
	}
}
