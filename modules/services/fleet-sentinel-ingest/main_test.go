package main

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"testing"
)

const token = "0123456789abcdef0123456789abcdef"

func newIngest(t *testing.T) *ingest {
	t.Helper()
	dir := t.TempDir()
	tokenPath := filepath.Join(dir, "token")
	// Trailing newline on purpose: sops writes one, and a token carrying it
	// would fail every comparison.
	if err := os.WriteFile(tokenPath, []byte(token+"\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	incoming := filepath.Join(dir, "incoming")
	if err := os.MkdirAll(incoming, 0o755); err != nil {
		t.Fatal(err)
	}
	return &ingest{tokenFile: tokenPath, incoming: incoming}
}

func statusBody(t *testing.T, host, state string) string {
	t.Helper()
	raw, err := json.Marshal(map[string]any{
		"schema":  1,
		"ts":      "2026-11-19T12:00:00Z",
		"host":    host,
		"state":   state,
		"reasons": []string{},
	})
	if err != nil {
		t.Fatal(err)
	}
	return string(raw)
}

func post(in *ingest, body, auth string) *httptest.ResponseRecorder {
	req := httptest.NewRequest(http.MethodPost, "/sentinel/ingest", strings.NewReader(body))
	if auth != "" {
		req.Header.Set("Authorization", auth)
	}
	rec := httptest.NewRecorder()
	in.ServeHTTP(rec, req)
	return rec
}

func written(t *testing.T, in *ingest) []string {
	t.Helper()
	entries, err := os.ReadDir(in.incoming)
	if err != nil {
		t.Fatal(err)
	}
	var names []string
	for _, e := range entries {
		names = append(names, e.Name())
	}
	sort.Strings(names)
	return names
}

func TestAcceptsAndStoresPerHost(t *testing.T) {
	in := newIngest(t)
	rec := post(in, statusBody(t, "delphi", "ok"), "Bearer "+token)
	if rec.Code != http.StatusNoContent {
		t.Fatalf("status = %d, want 204 (%s)", rec.Code, rec.Body)
	}
	if names := written(t, in); len(names) != 1 || names[0] != "delphi.json" {
		t.Fatalf("files = %v, want [delphi.json]", names)
	}
	body, err := os.ReadFile(filepath.Join(in.incoming, "delphi.json"))
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(string(body), `"host":"delphi"`) {
		t.Fatalf("stored body lost the event: %s", body)
	}
}

func TestOverwritesTheSameHost(t *testing.T) {
	in := newIngest(t)
	post(in, statusBody(t, "delphi", "degraded"), "Bearer "+token)
	post(in, statusBody(t, "delphi", "ok"), "Bearer "+token)
	if names := written(t, in); len(names) != 1 {
		t.Fatalf("files = %v, want one file per host", names)
	}
	body, _ := os.ReadFile(filepath.Join(in.incoming, "delphi.json"))
	if !strings.Contains(string(body), `"state":"ok"`) {
		t.Fatalf("newest push did not win: %s", body)
	}
}

func TestRejectsAWrongOrMissingBearer(t *testing.T) {
	in := newIngest(t)
	for _, auth := range []string{"", "Bearer wrong", token, "Basic " + token} {
		if rec := post(in, statusBody(t, "delphi", "ok"), auth); rec.Code != http.StatusUnauthorized {
			t.Fatalf("auth %q: status = %d, want 401", auth, rec.Code)
		}
	}
	if names := written(t, in); len(names) != 0 {
		t.Fatalf("a refused push wrote %v", names)
	}
}

func TestRejectsBodiesThatAreNotAStatus(t *testing.T) {
	in := newIngest(t)
	cases := map[string]string{
		"not json":       "{",
		"no schema":      `{"ts":"2026-11-19T12:00:00Z","host":"delphi","state":"ok"}`,
		"bad host":       statusBody(t, "../etc", "ok"),
		"uppercase host": statusBody(t, "Delphi", "ok"),
		"bad state":      statusBody(t, "delphi", "fine"),
		"bad ts":         `{"schema":1,"ts":"yesterday","host":"delphi","state":"ok"}`,
	}
	for name, body := range cases {
		if rec := post(in, body, "Bearer "+token); rec.Code != http.StatusBadRequest {
			t.Fatalf("%s: status = %d, want 400", name, rec.Code)
		}
	}
	if names := written(t, in); len(names) != 0 {
		t.Fatalf("a refused body wrote %v", names)
	}
}

func TestRejectsOversizedBodies(t *testing.T) {
	in := newIngest(t)
	big := `{"schema":1,"ts":"2026-11-19T12:00:00Z","host":"delphi","state":"ok","pad":"` +
		strings.Repeat("x", maxBody) + `"}`
	if rec := post(in, big, "Bearer "+token); rec.Code != http.StatusRequestEntityTooLarge {
		t.Fatalf("status = %d, want 413", rec.Code)
	}
}

func TestOnlyPostIsAccepted(t *testing.T) {
	in := newIngest(t)
	req := httptest.NewRequest(http.MethodGet, "/sentinel/ingest", nil)
	rec := httptest.NewRecorder()
	in.ServeHTTP(rec, req)
	if rec.Code != http.StatusMethodNotAllowed {
		t.Fatalf("status = %d, want 405", rec.Code)
	}
	if got := rec.Header().Get("Allow"); got != http.MethodPost {
		t.Fatalf("Allow = %q, want POST", got)
	}
}

func TestRefusesWithoutAUsableToken(t *testing.T) {
	in := newIngest(t)
	if err := os.WriteFile(in.tokenFile, []byte("short\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	if rec := post(in, statusBody(t, "delphi", "ok"), "Bearer short"); rec.Code != http.StatusServiceUnavailable {
		t.Fatalf("status = %d, want 503 so a missing secret cannot open the door", rec.Code)
	}
	if err := os.Remove(in.tokenFile); err != nil {
		t.Fatal(err)
	}
	if rec := post(in, statusBody(t, "delphi", "ok"), "Bearer "+token); rec.Code != http.StatusServiceUnavailable {
		t.Fatalf("status = %d, want 503 when the token file is gone", rec.Code)
	}
}
