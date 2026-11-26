package main

import (
	"context"
	"fmt"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"strings"
	"testing"
)

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
