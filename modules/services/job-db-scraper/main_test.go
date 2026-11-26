package main

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"strings"
	"testing"
)

func testDB(t *testing.T) string {
	t.Helper()
	return filepath.Join(t.TempDir(), "test.db")
}

func TestScoringDeterministic(t *testing.T) {
	in := Posting{Title: "DevOps Engineer (m/w/d)", Employer: "Muster GmbH", Location: "Freiburg, Germany"}
	lane1, score1, reasons1 := scorePosting(in)
	lane2, score2, reasons2 := scorePosting(in)
	if lane1 != lane2 || score1 != score2 || strings.Join(reasons1, ",") != strings.Join(reasons2, ",") {
		t.Fatal("scoring must be deterministic")
	}
	if lane1 != "in" {
		t.Fatalf("DevOps Engineer in Germany must be in-lane, got %q", lane1)
	}
	// base 50 + lane 30 + goodloc 10 = 90
	if score1 != 90 {
		t.Fatalf("score want 90 got %d (%v)", score1, reasons1)
	}
	// OUT wins over LANE: an apprenticeship with lane words is out.
	out := Posting{Title: "Ausbildung DevOps Engineer", Employer: "x", Location: "berlin"}
	lane, score, _ := scorePosting(out)
	if lane != "out" {
		t.Fatalf("Ausbildung must be out, got %q score %d", lane, score)
	}
	// Software developer is out of lane.
	sw := Posting{Title: "Backend Softwareentwickler", Employer: "x"}
	if lane, _, _ := scorePosting(sw); lane != "out" {
		t.Fatalf("backend developer must be out, got %q", lane)
	}
	// US-only is penalised below the Germany score.
	us := Posting{Title: "DevOps Engineer", Employer: "x", Location: "US only"}
	_, usScore, _ := scorePosting(us)
	if usScore >= score1-30 {
		t.Fatalf("us-only penalty missing: %d", usScore)
	}
}

func TestDedupeKeyNormalization(t *testing.T) {
	cases := [][2]string{
		{"Muster GmbH", "muster"},
		{"muster gmbh", "muster"},
		{"Müller AG", "mueller"},
		{"plusserver GmbH", "plusserver"},
	}
	for _, c := range cases {
		if got := normName(c[0]); got != c[1] {
			t.Fatalf("normName(%q) = %q, want %q", c[0], got, c[1])
		}
	}
	// Same employer+role spelled two ways is one dedupe key.
	k1 := dedupeKey("Muster GmbH", "DevOps Engineer")
	k2 := dedupeKey("muster", "DevOps Engineer")
	if k1 != k2 {
		t.Fatalf("dedupe keys differ: %q vs %q", k1, k2)
	}
	if dedupeKey("", "x") != "" || dedupeKey("x", "") != "" {
		t.Fatal("empty side must yield empty key")
	}
}

func TestUpsertDedupesReposting(t *testing.T) {
	db, err := openStore(testDB(t))
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()
	id1, fresh1, err := upsertPosting(db, Posting{Title: "Platform Engineer", Employer: "Upvest GmbH", URL: "http://a"})
	if err != nil || !fresh1 {
		t.Fatalf("first: %v fresh=%v", err, fresh1)
	}
	// The reposting, spelled differently, updates the same row.
	id2, fresh2, err := upsertPosting(db, Posting{Title: "platform engineer", Employer: "upvest", Location: "Berlin"})
	if err != nil {
		t.Fatal(err)
	}
	if fresh2 || id2 != id1 {
		t.Fatalf("reposting must update: id %d vs %d fresh %v", id1, id2, fresh2)
	}
	got, err := listPostings(db, 0, "", 10)
	if err != nil || len(got) != 1 {
		t.Fatalf("want 1 row, got %v len=%d", err, len(got))
	}
	if got[0].Location != "Berlin" {
		t.Fatalf("update lost: %q", got[0].Location)
	}
	if got[0].URL != "http://a" {
		t.Fatalf("empty url must not erase the first fact: %q", got[0].URL)
	}
}

func TestScoreSortedSurface(t *testing.T) {
	db, err := openStore(testDB(t))
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()
	upsertPosting(db, Posting{Title: "DevOps Engineer", Employer: "a", Location: "germany"})  // 90
	upsertPosting(db, Posting{Title: "Helpdesk Support", Employer: "b"})                       // 10
	upsertPosting(db, Posting{Title: "Office Manager", Employer: "c"})                         // 50
	got, _ := listPostings(db, 0, "", 10)
	if len(got) != 3 || got[0].Score < got[1].Score || got[1].Score < got[2].Score {
		t.Fatalf("not sorted by score desc: %v", []int{got[0].Score, got[1].Score, got[2].Score})
	}
	// min_score filters the surface.
	high, _ := listPostings(db, 60, "", 10)
	if len(high) != 1 || high[0].Employer != "a" {
		t.Fatalf("min_score 60: %+v", high)
	}
	// lane filter.
	in, _ := listPostings(db, 0, "in", 10)
	if len(in) != 1 {
		t.Fatalf("lane in: len=%d", len(in))
	}
	// FTS still orders by score.
	sr, err := searchPostings(db, "engineer", 0, 10)
	if err != nil || len(sr) != 1 {
		t.Fatalf("fts: %v len=%d", err, len(sr))
	}
}

func TestBatchAPI(t *testing.T) {
	db, err := openStore(testDB(t))
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()
	srv := httptest.NewServer((&server{db: db}).mux())
	defer srv.Close()

	batch := `{"postings":[
	  {"title":"SRE","employer":"A GmbH","location":"remote"},
	  {"title":"SRE","employer":"a gmbh","location":"remote"},
	  {"title":"Cloud Engineer","employer":"B AG","location":"Munich"},
	  {"title":"","employer":"bad row"}
	]}`
	resp, err := http.Post(srv.URL+"/api/postings/batch", "application/json", strings.NewReader(batch))
	if err != nil {
		t.Fatal(err)
	}
	var out struct {
		Inserted int `json:"inserted"`
		Updated  int `json:"updated"`
		Failed   int `json:"failed"`
	}
	json.NewDecoder(resp.Body).Decode(&out)
	resp.Body.Close()
	// Two spellings of one employer+role: one insert, one update; the empty-title row fails.
	if out.Inserted != 2 || out.Updated != 1 || out.Failed != 1 {
		t.Fatalf("batch: %+v", out)
	}

	// GET list with min_score.
	r, err := http.Get(srv.URL + "/api/postings?min_score=70")
	if err != nil {
		t.Fatal(err)
	}
	var lst struct {
		Count int `json:"count"`
	}
	json.NewDecoder(r.Body).Decode(&lst)
	r.Body.Close()
	// SRE remote: 50+30+10=90; Cloud Munich: 90 — both pass 70.
	if lst.Count != 2 {
		t.Fatalf("min_score surface: %d", lst.Count)
	}

	hr, err := http.Get(srv.URL + "/healthz")
	if err != nil {
		t.Fatal(err)
	}
	hr.Body.Close()
	if hr.StatusCode != 200 {
		t.Fatalf("healthz %d", hr.StatusCode)
	}
}
