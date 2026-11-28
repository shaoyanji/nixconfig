package main

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"strconv"
	"strings"
	"testing"
	"time"
)

func testStore(t *testing.T) *Store {
	t.Helper()
	store, err := OpenStore(filepath.Join(t.TempDir(), "jobs.sqlite"))
	if err != nil {
		t.Fatalf("OpenStore: %v", err)
	}
	t.Cleanup(func() { _ = store.Close() })
	return store
}

func TestNormalizeCompanyAndFingerprint(t *testing.T) {
	if got := normalizeCompany("Kältemaschinen GmbH"); got != normalizeCompany("Kaeltemaschinen") {
		t.Fatalf("umlaut/company folding mismatch: %q", got)
	}
	a := postingFingerprint("Upvest GmbH", "DevOps Engineer (m/w/d)", "Berlin")
	b := postingFingerprint("upvest", "DevOps Engineer", "berlin")
	if a != b {
		t.Fatalf("fingerprints differ: %s != %s", a, b)
	}
}

func TestCanonicalURLStripsTracking(t *testing.T) {
	got := canonicalURL("HTTPS://WWW.Example.com/jobs/one/?utm_source=x&ref=board&id=42#section")
	want := "https://example.com/jobs/one?id=42"
	if got != want {
		t.Fatalf("canonical url: got %q want %q", got, want)
	}
}

func TestUpsertDedupesAndFTSFinds(t *testing.T) {
	store, err := OpenStore(filepath.Join(t.TempDir(), "jobs.sqlite"))
	if err != nil {
		t.Fatal(err)
	}
	defer store.Close()
	ctx := context.Background()
	first := postingInput{
		Source: "test", URL: "https://example.com/jobs/1?utm_source=x", Company: "Acme GmbH",
		Title: "Platform Engineer (m/w/d)", Location: "Berlin", Description: "Kubernetes Terraform cloud platform",
	}
	id, created, err := store.UpsertPosting(ctx, first)
	if err != nil || !created {
		t.Fatalf("first upsert created=%v err=%v", created, err)
	}
	second := first
	second.URL = "https://example.com/different-board-copy"
	_, created, err = store.UpsertPosting(ctx, second)
	if err != nil {
		t.Fatal(err)
	}
	if created {
		t.Fatal("second copy was inserted instead of deduplicated")
	}
	page, err := store.QueryPostings(ctx, queryOptions{Q: "kubernetes terraform", Active: true, Limit: 10})
	if err != nil {
		t.Fatal(err)
	}
	if page.Total != 1 || len(page.Items) != 1 || page.Items[0].ID != id {
		t.Fatalf("fts page: total=%d items=%+v", page.Total, page.Items)
	}
	if !strings.Contains(page.Items[0].Snippet, "<mark>") {
		t.Fatalf("snippet has no highlight: %q", page.Items[0].Snippet)
	}
}

func TestGermanTechJobsTitleShape(t *testing.T) {
	m := germanTitleRE.FindStringSubmatch("Senior DevOps Engineer @ Example GmbH [Berlin]")
	if len(m) != 4 || m[1] != "Senior DevOps Engineer" || m[2] != "Example GmbH" || m[3] != "Berlin" {
		t.Fatalf("unexpected parse: %#v", m)
	}
}

func TestInferCompany(t *testing.T) {
	if got := inferCompany("Platform Engineer at Example GmbH - Berlin", "https://example.com/job/123"); got != "Example GmbH" {
		t.Fatalf("at pattern: %q", got)
	}
	if got := inferCompany("Example GmbH: Platform Engineer", "https://example.com/job/123"); got != "Example GmbH" {
		t.Fatalf("colon pattern: %q", got)
	}
}

func TestSearchResultHeuristicsUseDetailPagesOnly(t *testing.T) {
	for _, raw := range []string{
		"https://www.devjobsscanner.com/devops-engineer-jobs-in-germany",
		"https://englishjobs.de/jobs/devops",
		"https://www.indeed.com/q-devops-germany-jobs.html",
		"https://dailyremote.com/remote-devops-engineer-jobs-in-germany",
	} {
		if isSearchDetailURL(raw) {
			t.Fatalf("listing accepted as detail: %s", raw)
		}
	}
	for _, raw := range []string{
		"https://www.linuxcareers.com/jobs/senior-devops-engineer-f-m-d-ed1fa19f707f",
		"https://join.com/companies/xalt/16977895-senior-devops-engineer",
		"https://careers.sap.com/job/Berlin-DevOps-Engineer-10557/1456971233/",
		"https://magazino.jobs.personio.com/job/2905493",
	} {
		if !isSearchDetailURL(raw) {
			t.Fatalf("detail rejected: %s", raw)
		}
	}
}

func TestSearchCompanyAndTitleCleanup(t *testing.T) {
	if got := inferCompany("Senior DevOps Engineer (f/m/d) at Zeal Network, Hamburg, Germany", "https://www.linuxcareers.com/jobs/x-ed1fa19f707f"); got != "Zeal Network" {
		t.Fatalf("zeal company: %q", got)
	}
	if got := inferCompany("Senior DevOps Engineer - XALT Business Consulting (Munich)", "https://join.com/companies/xalt/16977895-senior-devops-engineer"); got != "XALT Business Consulting" {
		t.Fatalf("xalt company: %q", got)
	}
	if got := inferCompany("DevOps Engineer Job Details", "https://careers.sap.com/job/Berlin-DevOps-Engineer-10557/1456971233/"); got != "SAP" {
		t.Fatalf("sap company: %q", got)
	}
	if got := cleanSearchTitle("Senior DevOps Engineer (f/m/d) at Zeal Network, Hamburg, Germany"); got != "Senior DevOps Engineer (f/m/d)" {
		t.Fatalf("clean at title: %q", got)
	}
	if got := cleanSearchTitle("Senior DevOps Engineer - XALT Business Consulting (Munich)"); got != "Senior DevOps Engineer" {
		t.Fatalf("clean hyphen title: %q", got)
	}
}

func TestSourceStatesAndStats(t *testing.T) {
	store, err := OpenStore(filepath.Join(t.TempDir(), "jobs.sqlite"))
	if err != nil {
		t.Fatal(err)
	}
	defer store.Close()
	ctx := context.Background()
	_, _, err = store.UpsertPosting(ctx, postingInput{Source: "test", URL: "https://example.com/1", Company: "Acme", Title: "SRE", Location: "Remote", Remote: true})
	if err != nil {
		t.Fatal(err)
	}
	runID, err := store.BeginRun(ctx, "test")
	if err != nil {
		t.Fatal(err)
	}
	if err := store.FinishRun(ctx, runID, "test", "ok", 1, 1, 0, ""); err != nil {
		t.Fatal(err)
	}
	states, err := store.SourceStates(ctx)
	if err != nil {
		t.Fatal(err)
	}
	if len(states) != 1 || states[0].Source != "test" || states[0].Postings != 1 {
		t.Fatalf("states: %+v", states)
	}
	stats, err := store.Stats(ctx)
	if err != nil {
		t.Fatal(err)
	}
	if stats.TotalPostings != 1 || stats.Remote != 1 || stats.LatestRun == nil {
		t.Fatalf("stats: %+v", stats)
	}
}

func TestProviderClientsAgainstMockAPIs(t *testing.T) {
	store, err := OpenStore(filepath.Join(t.TempDir(), "jobs.sqlite"))
	if err != nil {
		t.Fatal(err)
	}
	defer store.Close()
	mux := http.NewServeMux()
	mux.HandleFunc("/search", func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Authorization") != "Bearer test-token" {
			http.Error(w, "missing auth", http.StatusUnauthorized)
			return
		}
		fmt.Fprint(w, `{"results":[{"title":"Platform Engineer at Example GmbH","url":"https://example.com/job/123","content":"Kubernetes platform engineer job","score":0.9}]}`)
	})
	mux.HandleFunc("/scrape", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprint(w, `{"success":true,"data":{"markdown":"A long markdown job description with Kubernetes, Terraform and platform operations detail. This is intentionally long enough to be useful."}}`)
	})
	mux.HandleFunc("/web/scrape/markdown", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/markdown")
		fmt.Fprint(w, "A long Context markdown job description with enough words to pass the enrichment length check and index usefully.")
	})
	api := httptest.NewServer(mux)
	defer api.Close()
	sc := newScraper(store, providerConfig{TavilyKey: "test-token", TavilyBase: api.URL, FirecrawlKey: "test-token", FirecrawlBase: api.URL, ContextKey: "test-token", ContextBase: api.URL})
	postings, err := sc.tavilySearch(context.Background(), "platform engineer")
	if err != nil {
		t.Fatal(err)
	}
	if len(postings) != 1 || postings[0].Company != "Example GmbH" {
		t.Fatalf("tavily postings: %+v", postings)
	}
	text, err := sc.firecrawlScrape(context.Background(), "https://example.com/job/123")
	if err != nil || !strings.Contains(text, "Kubernetes") {
		t.Fatalf("firecrawl text %q err %v", text, err)
	}
	text, err = sc.contextScrape(context.Background(), "https://example.com/job/123")
	if err != nil || !strings.Contains(text, "Context markdown") {
		t.Fatalf("context text %q err %v", text, err)
	}
}

func TestRoleMatchScoringAndScoreSort(t *testing.T) {
	store, err := OpenStore(filepath.Join(t.TempDir(), "jobs.sqlite"))
	if err != nil {
		t.Fatal(err)
	}
	defer store.Close()
	ctx := context.Background()
	high := postingInput{Source: "test", URL: "https://example.com/high", Company: "Acme", Title: "Senior DevOps Platform Engineer", Location: "Berlin, Germany", Remote: true, Description: "Kubernetes cloud platform on Linux with Go and NixOS"}
	low := postingInput{Source: "test", URL: "https://example.com/low", Company: "Acme", Title: "Office Manager", Location: "Berlin", Description: "Administration"}
	highID, _, err := store.UpsertPosting(ctx, high)
	if err != nil {
		t.Fatal(err)
	}
	if _, _, err := store.UpsertPosting(ctx, low); err != nil {
		t.Fatal(err)
	}
	page, err := store.QueryPostings(ctx, queryOptions{Active: true, Limit: 10, Sort: "score"})
	if err != nil {
		t.Fatal(err)
	}
	if len(page.Items) != 2 || page.Items[0].ID != highID || page.Items[0].Score < 80 {
		t.Fatalf("score sorted page: %+v", page.Items)
	}
	wantLanes := []string{"DevOps", "Platform", "Cloud", "Kubernetes", "NixOS", "Linux", "Go"}
	for _, lane := range wantLanes {
		found := false
		for _, got := range page.Items[0].Lanes {
			if got == lane {
				found = true
			}
		}
		if !found {
			t.Fatalf("lane %s missing in %#v", lane, page.Items[0].Lanes)
		}
	}
}

func TestHighScoreAlertsAreDedupedAndNotifyNtfy(t *testing.T) {
	store, err := OpenStore(filepath.Join(t.TempDir(), "jobs.sqlite"))
	if err != nil {
		t.Fatal(err)
	}
	defer store.Close()
	ctx := context.Background()
	if _, _, err := store.UpsertPosting(ctx, postingInput{Source: "test", URL: "https://example.com/high", Company: "Acme", Title: "Senior Platform Engineer", Location: "Remote Germany", Remote: true, Description: "Kubernetes cloud platform on Linux with Go and NixOS"}); err != nil {
		t.Fatal(err)
	}
	posts := 0
	ntfy := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		posts++
		if !strings.Contains(r.Header.Get("Title"), "high-score") {
			t.Errorf("unexpected ntfy title %q", r.Header.Get("Title"))
		}
		w.WriteHeader(http.StatusOK)
	}))
	defer ntfy.Close()
	manager := newAlertManager(store, ntfy.URL, 80)
	first, err := manager.evaluate(ctx, true)
	if err != nil {
		t.Fatal(err)
	}
	if first.Matched != 1 || first.Created != 1 || first.Notified != 1 || first.Failed != 0 {
		t.Fatalf("first alert summary %#v", first)
	}
	second, err := manager.evaluate(ctx, true)
	if err != nil {
		t.Fatal(err)
	}
	if second.Matched != 1 || second.Created != 0 || second.Existing != 1 || second.Notified != 0 {
		t.Fatalf("second alert summary %#v", second)
	}
	if posts != 1 {
		t.Fatalf("ntfy posts %d, want deduped single post", posts)
	}
	alerts, err := store.ListJobAlerts(ctx, 10)
	if err != nil || len(alerts) != 1 || alerts[0].Status != "sent" || alerts[0].Score < 80 {
		t.Fatalf("alerts %#v err=%v", alerts, err)
	}
}

func TestBatchPostingsEndpointAccountsForOutcomes(t *testing.T) {
	store, err := OpenStore(filepath.Join(t.TempDir(), "jobs.sqlite"))
	if err != nil {
		t.Fatal(err)
	}
	defer store.Close()
	s := &server{store: store, alerts: newAlertManager(store, "", 90)}
	body := `{"postings":[
		{"title":"Platform Engineer","company":"Acme","source":"manual","url":"https://example.com/1","description":"Kubernetes cloud platform"},
		{"title":"Platform Engineer","company":"Acme","source":"manual","url":"https://example.com/1","description":"Kubernetes cloud platform"},
		{"title":"Platform Engineer","company":"Acme","source":"manual","url":"https://example.com/1","description":"Kubernetes cloud platform with NixOS"},
		{}
	]}`
	req := httptest.NewRequest(http.MethodPost, "/api/postings/batch", strings.NewReader(body))
	recorder := httptest.NewRecorder()
	s.batchPostings(recorder, req)
	if recorder.Code != http.StatusCreated {
		t.Fatalf("status %d body %s", recorder.Code, recorder.Body.String())
	}
	var response batchPostingsResponse
	if err := json.NewDecoder(recorder.Body).Decode(&response); err != nil {
		t.Fatal(err)
	}
	if response.Created != 1 || response.Updated != 1 || response.Skipped != 2 || response.Failed != 0 || response.Total != 4 {
		t.Fatalf("batch response %#v", response)
	}
}

func TestStoreMigratesLegacySchemaAndBackfillsScores(t *testing.T) {
	path := filepath.Join(t.TempDir(), "legacy.sqlite")
	db, err := sql.Open("sqlite", path)
	if err != nil {
		t.Fatal(err)
	}
	_, err = db.Exec(`CREATE TABLE postings (
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
	)`)
	if err != nil {
		t.Fatal(err)
	}
	_, err = db.Exec(`INSERT INTO postings (fingerprint,canonical_url,url,source,company,company_key,title,location,remote,description,tags,first_seen,last_seen) VALUES ('legacy','https://example.com/legacy','https://example.com/legacy','test','Acme','acme','DevOps Engineer','Germany',1,'Kubernetes cloud Linux Go NixOS','[]','2026-01-01T00:00:00Z','2026-01-01T00:00:00Z')`)
	if err != nil {
		t.Fatal(err)
	}
	if err := db.Close(); err != nil {
		t.Fatal(err)
	}
	store, err := OpenStore(path)
	if err != nil {
		t.Fatal(err)
	}
	defer store.Close()
	posting, _, err := store.GetPosting(context.Background(), 1)
	if err != nil {
		t.Fatal(err)
	}
	if posting.Score < 80 || len(posting.Lanes) == 0 {
		t.Fatalf("legacy row was not backfilled: %+v", posting)
	}
	if posting.CanonicalKey == "" || posting.Stage != "saved" || len(posting.MergedSources) != 1 {
		t.Fatalf("legacy row missing canonical/stage merge metadata: %+v", posting)
	}
	if _, _, err := store.UpsertPosting(context.Background(), postingInput{Source: "test", URL: "https://example.com/legacy", Company: "Acme", Title: "DevOps Engineer", Location: "Germany", Remote: true, Description: "Kubernetes cloud Linux Go NixOS with platform ownership"}); err != nil {
		t.Fatalf("update migrated row: %v", err)
	}
	page, err := store.QueryPostings(context.Background(), queryOptions{Q: "platform", Active: true, Limit: 10})
	if err != nil || len(page.Items) != 1 {
		t.Fatalf("fts after migrated update: page=%+v err=%v", page, err)
	}
}

func analyticsSeed(t *testing.T, store *Store) {
	t.Helper()
	ctx := context.Background()
	for _, in := range []postingInput{
		{Source: "rss", URL: "https://example.com/a", Company: "Example GmbH", Title: "Senior DevOps Engineer", Location: "Berlin", Description: "Kubernetes and NixOS on Linux"},
		{Source: "rss", URL: "https://example.com/b", Company: "Example GmbH", Title: "SRE", Location: "Berlin", Description: "site reliability engineer"},
		{Source: "greenhouse", URL: "https://example.com/c", Company: "Other AG", Title: "Platform Engineer", Location: "Munich", Remote: true, Description: "AWS platform"},
		{Source: "greenhouse", URL: "https://example.com/d", Company: "Other AG", Title: "Office Manager", Location: "", Description: "Administration"},
	} {
		if _, _, err := store.UpsertPosting(ctx, in); err != nil {
			t.Fatalf("UpsertPosting %s: %v", in.URL, err)
		}
	}
}

func countOf(rows []countRow, name string) int {
	for _, row := range rows {
		if row.Name == name {
			return row.Count
		}
	}
	return 0
}

func TestAnalyticsCountsCompaniesLanesBoardsAndBands(t *testing.T) {
	store, err := OpenStore(filepath.Join(t.TempDir(), "jobs.sqlite"))
	if err != nil {
		t.Fatal(err)
	}
	defer store.Close()
	analyticsSeed(t, store)

	report, err := store.Analytics(context.Background(), 0, 8)
	if err != nil {
		t.Fatalf("Analytics: %v", err)
	}
	if report.Active != 4 || report.Remote != 1 {
		t.Fatalf("totals %#v, want 4 active and 1 remote", report)
	}
	if report.Unscored != 1 || report.AvgScore <= 0 {
		t.Fatalf("scores %#v, want one unscored posting and a positive mean", report)
	}

	if len(report.Companies) != 2 {
		t.Fatalf("companies %#v, want both", report.Companies)
	}
	for _, name := range []string{"Example GmbH", "Other AG"} {
		found := false
		for _, company := range report.Companies {
			if company.Name == name && company.Postings == 2 {
				found = true
			}
		}
		if !found {
			t.Fatalf("company %s missing from %#v", name, report.Companies)
		}
	}
	if report.Companies[0].Key == "" || report.Companies[0].Newest.IsZero() {
		t.Fatalf("company row %#v, want a key and a newest timestamp", report.Companies[0])
	}

	if countOf(report.Locations, "Berlin") != 2 || countOf(report.Locations, "Munich") != 1 || countOf(report.Locations, "unspecified") != 1 {
		t.Fatalf("locations %#v", report.Locations)
	}
	if countOf(report.Sources, "rss") != 2 || countOf(report.Sources, "greenhouse") != 2 {
		t.Fatalf("sources %#v", report.Sources)
	}

	if len(report.Lanes) != 7 {
		t.Fatalf("lanes %#v, want the seven matched lanes", report.Lanes)
	}
	for _, lane := range []string{"DevOps", "SRE", "Platform", "Cloud", "Kubernetes", "NixOS", "Linux"} {
		found := false
		for _, row := range report.Lanes {
			if row.Name == lane && row.Postings == 1 && row.MaxScore > 0 {
				found = true
			}
		}
		if !found {
			t.Fatalf("lane %s missing or miscounted in %#v", lane, report.Lanes)
		}
	}

	if len(report.ScoreBands) != 5 {
		t.Fatalf("bands %#v, want five", report.ScoreBands)
	}
	total := 0
	for _, band := range report.ScoreBands {
		total += band.Count
	}
	if total != report.Active {
		t.Fatalf("bands sum to %d, want %d", total, report.Active)
	}
	if report.ScoreBands[0].Band != "0-19" || report.ScoreBands[0].Count != 1 {
		t.Fatalf("first band %#v, want the unscored posting", report.ScoreBands[0])
	}
	if report.ScoreBands[4].Max != 100 || report.ScoreBands[4].Band != "80-100" {
		t.Fatalf("last band %#v, want 80-100", report.ScoreBands[4])
	}
}

func TestPostingsFilterByCompanyAndLane(t *testing.T) {
	store, err := OpenStore(filepath.Join(t.TempDir(), "jobs.sqlite"))
	if err != nil {
		t.Fatal(err)
	}
	defer store.Close()
	analyticsSeed(t, store)
	ctx := context.Background()

	cases := []struct {
		name string
		opt  queryOptions
		want int
	}{
		{"company", queryOptions{Company: "Example GmbH"}, 2},
		{"lane DevOps", queryOptions{Lane: "DevOps"}, 1},
		{"lane Platform", queryOptions{Lane: "Platform"}, 1},
		{"lane without rows", queryOptions{Lane: "Rust"}, 0},
	}
	for _, tc := range cases {
		opt := tc.opt
		opt.Active = true
		opt.Limit = 20
		page, err := store.QueryPostings(ctx, opt)
		if err != nil {
			t.Fatalf("%s: %v", tc.name, err)
		}
		if page.Total != tc.want {
			t.Fatalf("%s: total %d, want %d (%#v)", tc.name, page.Total, tc.want, page.Items)
		}
	}
}

func TestAnalyticsWindowClampsAndHandlerAnswers(t *testing.T) {
	store, err := OpenStore(filepath.Join(t.TempDir(), "jobs.sqlite"))
	if err != nil {
		t.Fatal(err)
	}
	defer store.Close()
	analyticsSeed(t, store)

	wide, err := store.Analytics(context.Background(), 9999, 9999)
	if err != nil {
		t.Fatalf("Analytics wide: %v", err)
	}
	if wide.Days != 365 {
		t.Fatalf("days %d, want 365", wide.Days)
	}
	negative, err := store.Analytics(context.Background(), -5, 0)
	if err != nil {
		t.Fatalf("Analytics negative: %v", err)
	}
	if negative.Days != 0 || negative.Active != 4 {
		t.Fatalf("negative window %#v, want every active posting", negative)
	}

	s := &server{store: store}
	rec := httptest.NewRecorder()
	s.analytics(rec, httptest.NewRequest(http.MethodGet, "/api/analytics?limit=1", nil))
	if rec.Code != http.StatusOK {
		t.Fatalf("status %d: %s", rec.Code, rec.Body.String())
	}
	var report jobAnalytics
	if err := json.Unmarshal(rec.Body.Bytes(), &report); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if len(report.Companies) != 1 || len(report.Lanes) != 1 {
		t.Fatalf("limit not applied: %#v", report)
	}
	if len(report.ScoreBands) != 5 || report.Active != 4 {
		t.Fatalf("report %#v, want five bands over four postings", report)
	}
}

func TestCrossSourceCanonicalDedupeMergesSources(t *testing.T) {
	ctx := context.Background()
	store := testStore(t)
	first, created, err := store.UpsertPosting(ctx, postingInput{Source: "board-a", Company: "Example GmbH", Title: "Platform Engineer", Location: "Remote", URL: "https://a.example/job/1?utm_source=x"})
	if err != nil || !created {
		t.Fatalf("first created=%v err=%v", created, err)
	}
	second, created, err := store.UpsertPosting(ctx, postingInput{Source: "board-b", Company: "Example", Title: "Platform Engineer (m/w/d)", Location: "Germany", URL: "https://b.example/posting/42"})
	if err != nil {
		t.Fatalf("second err=%v", err)
	}
	if created || second != first {
		t.Fatalf("second id=%d created=%v want merge into %d", second, created, first)
	}
	p, _, err := store.GetPosting(ctx, first)
	if err != nil {
		t.Fatal(err)
	}
	if p.DuplicateCount != 1 || len(p.MergedSources) != 2 {
		t.Fatalf("merge %#v", p)
	}
	if p.FirstSeen.After(time.Now()) {
		t.Fatalf("bad first_seen %v", p.FirstSeen)
	}
}

func TestStageNotesJournalAndStageFilter(t *testing.T) {
	ctx := context.Background()
	store := testStore(t)
	id, _, err := store.UpsertPosting(ctx, postingInput{Source: "manual", Company: "Example", Title: "DevOps Engineer", Location: "Remote"})
	if err != nil {
		t.Fatal(err)
	}
	if err := store.UpdateStage(ctx, id, "applied", "sent packet", "", ""); err != nil {
		t.Fatalf("stage: %v", err)
	}
	if _, err := store.AddNote(ctx, id, "recruiter confirmed receipt"); err != nil {
		t.Fatalf("note: %v", err)
	}
	p, _, err := store.GetPosting(ctx, id)
	if err != nil {
		t.Fatal(err)
	}
	if p.Stage != "applied" || p.AppliedAt == "" {
		t.Fatalf("posting stage %#v", p)
	}
	notes, history, err := store.PostingJournal(ctx, id)
	if err != nil {
		t.Fatal(err)
	}
	if len(notes) != 1 || len(history) != 1 || history[0].FromStage != "saved" || history[0].ToStage != "applied" {
		t.Fatalf("journal %#v %#v", notes, history)
	}
	page, err := store.QueryPostings(ctx, queryOptions{Stage: "applied", Active: true, Limit: 10})
	if err != nil || page.Total != 1 {
		t.Fatalf("stage page %#v err=%v", page, err)
	}
	stats, err := store.Stats(ctx)
	if err != nil || len(stats.Stages) == 0 {
		t.Fatalf("stats %#v err=%v", stats, err)
	}
}

func TestPostingExportFormatsAndHandlers(t *testing.T) {
	ctx := context.Background()
	store := testStore(t)
	id, _, _ := store.UpsertPosting(ctx, postingInput{Source: "manual", Company: "Example", Title: "Kubernetes Platform Engineer", Location: "Remote", Description: "kubernetes nixos linux platform role"})
	_ = store.UpdateStage(ctx, id, "interview", "technical round", "", "2026-12-01T10:00:00Z")
	s := &server{store: store}
	for _, format := range []string{"json", "csv", "markdown"} {
		req := httptest.NewRequest(http.MethodGet, "/api/postings/export?format="+format, nil)
		rec := httptest.NewRecorder()
		s.exportPostings(rec, req)
		if rec.Code != http.StatusOK || !strings.Contains(rec.Body.String(), "Kubernetes") {
			t.Fatalf("%s code=%d body=%s", format, rec.Code, rec.Body.String())
		}
	}
	req := httptest.NewRequest(http.MethodPatch, "/api/postings/1/stage", strings.NewReader(`{"stage":"offer","note":"offer call"}`))
	req.SetPathValue("id", strconv.FormatInt(id, 10))
	rec := httptest.NewRecorder()
	s.updatePostingStage(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("stage endpoint %d %s", rec.Code, rec.Body.String())
	}
	req = httptest.NewRequest(http.MethodPost, "/api/postings/1/notes", strings.NewReader(`{"note":"packet export sent"}`))
	req.SetPathValue("id", strconv.FormatInt(id, 10))
	rec = httptest.NewRecorder()
	s.addPostingNote(rec, req)
	if rec.Code != http.StatusCreated {
		t.Fatalf("note endpoint %d %s", rec.Code, rec.Body.String())
	}
}
