package main

// The contract is the point: these tests pin the four answers an agent can get
// (201 append, 200 replay, 400 refused, 401 unauthenticated) and the read shape
// the dashboard and every `agents:xs:list` call depend on. They run against a
// fake store on a real Unix socket, so the client path is exercised too.

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"strings"
	"sync"
	"testing"

	_ "modernc.org/sqlite"
)

type fakeFrame struct {
	id   string
	hash string
}

// fakeXS is the slice of xs this shim uses: append, last, cas. It answers in the
// store's order — oldest first — which is what makes the reversal testable.
type fakeXS struct {
	mu     sync.Mutex
	frames []fakeFrame
	bodies map[string][]byte
}

func newFakeXS(t *testing.T) (*fakeXS, string) {
	t.Helper()
	socket := filepath.Join(t.TempDir(), "xs.sock")
	listener, err := net.Listen("unix", socket)
	if err != nil {
		t.Fatalf("listening on %s: %v", socket, err)
	}
	store := &fakeXS{bodies: map[string][]byte{}}
	server := &http.Server{Handler: store}
	go server.Serve(listener)
	t.Cleanup(func() { server.Close() })
	return store, socket
}

func (f *fakeXS) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	f.mu.Lock()
	defer f.mu.Unlock()
	switch {
	case r.Method == "POST" && strings.HasPrefix(r.URL.Path, "/append/"):
		body, _ := io.ReadAll(r.Body)
		hash := fmt.Sprintf("hash%03d", len(f.frames)+1)
		f.frames = append(f.frames, fakeFrame{id: fmt.Sprintf("frame%03d", len(f.frames)+1), hash: hash})
		f.bodies[hash] = body
		w.WriteHeader(http.StatusOK)
		fmt.Fprintf(w, `{"id":%q}`, f.frames[len(f.frames)-1].id)
	case r.Method == "GET" && strings.HasPrefix(r.URL.Path, "/last/"):
		limit := 50
		fmt.Sscanf(r.URL.Query().Get("last"), "%d", &limit)
		start := len(f.frames) - limit
		if start < 0 {
			start = 0
		}
		var b strings.Builder
		for _, frame := range f.frames[start:] {
			fmt.Fprintf(&b, `{"id":%q,"hash":%q}`+"\n", frame.id, frame.hash)
		}
		w.Write([]byte(b.String()))
	case r.Method == "GET" && strings.HasPrefix(r.URL.Path, "/cas/"):
		body, ok := f.bodies[strings.TrimPrefix(r.URL.Path, "/cas/")]
		if !ok {
			w.WriteHeader(http.StatusNotFound)
			return
		}
		w.Write(body)
	default:
		w.WriteHeader(http.StatusNotFound)
	}
}

// seed appends a turn directly, in the canonical form the shim would write.
func (f *fakeXS) seed(t *testing.T, entry map[string]any) {
	t.Helper()
	body, err := canonical(entry)
	if err != nil {
		t.Fatalf("canonical: %v", err)
	}
	f.mu.Lock()
	defer f.mu.Unlock()
	hash := fmt.Sprintf("hash%03d", len(f.frames)+1)
	f.frames = append(f.frames, fakeFrame{id: fmt.Sprintf("frame%03d", len(f.frames)+1), hash: hash})
	f.bodies[hash] = body
}

const testToken = "0123456789abcdef0123456789abcdef"

type harness struct {
	handler http.Handler
	store   *fakeXS
	socket  string
	dbPath  string
}

func newHarness(t *testing.T) *harness {
	t.Helper()
	store, socket := newFakeXS(t)
	dbPath := filepath.Join(t.TempDir(), "dedup.sqlite")
	dedupStore, err := openDedup(dbPath)
	if err != nil {
		t.Fatalf("open dedup: %v", err)
	}
	t.Cleanup(func() { dedupStore.db.Close() })
	s := &shim{
		store:  newXSStore(socket),
		dedup:  dedupStore,
		tokens: map[string]string{"test": testToken},
		writes: make(chan struct{}, 1),
	}
	return &harness{handler: s.routes(), store: store, socket: socket, dbPath: dbPath}
}

func (h *harness) do(t *testing.T, method, path string, body any, token string) *httptest.ResponseRecorder {
	t.Helper()
	var reader io.Reader
	if body != nil {
		raw, err := json.Marshal(body)
		if err != nil {
			t.Fatalf("marshal body: %v", err)
		}
		reader = strings.NewReader(string(raw))
	}
	req := httptest.NewRequest(method, path, reader)
	req.RemoteAddr = "127.0.0.1:1"
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	recorder := httptest.NewRecorder()
	h.handler.ServeHTTP(recorder, req)
	return recorder
}

func validTurn(id string) map[string]any {
	return map[string]any{
		"id":            id,
		"ts":            "2026-11-07T10:00:00Z",
		"source":        "buffY",
		"kind":          "turn",
		"subject":       "nixconfig:shim-port",
		"action":        "Ported the shim to Go",
		"rationale":     "the last Python in the turns path",
		"outcome":       "done",
		"base_commit":   "a7eb7d1e",
		"branch":        "main",
		"files_changed": []string{"modules/services/agent-turns/shim/main.go"},
		"commits":       []string{"a7eb7d1e"},
		"claims":        []string{"modules/services/agent-turns"},
	}
}

func decode(t *testing.T, recorder *httptest.ResponseRecorder) map[string]any {
	t.Helper()
	var payload map[string]any
	if err := json.Unmarshal(recorder.Body.Bytes(), &payload); err != nil {
		t.Fatalf("decoding %q: %v", recorder.Body.String(), err)
	}
	return payload
}

func TestHealthNeedsNoToken(t *testing.T) {
	h := newHarness(t)
	recorder := h.do(t, "GET", "/healthz", nil, "")
	if recorder.Code != http.StatusOK {
		t.Fatalf("status %d, want 200", recorder.Code)
	}
	if ok, _ := decode(t, recorder)["ok"].(bool); !ok {
		t.Fatalf("body %q, want ok true", recorder.Body.String())
	}
}

func TestAuthIsRequiredAndRefused(t *testing.T) {
	h := newHarness(t)
	for name, token := range map[string]string{"missing": "", "wrong": strings.Repeat("x", 32)} {
		if recorder := h.do(t, "GET", "/v1/events", nil, token); recorder.Code != http.StatusUnauthorized {
			t.Fatalf("%s: GET status %d, want 401", name, recorder.Code)
		}
		if recorder := h.do(t, "POST", "/v1/events", validTurn(uuid(1)), token); recorder.Code != http.StatusUnauthorized {
			t.Fatalf("%s: POST status %d, want 401", name, recorder.Code)
		}
	}
}

func TestAppendStoresCanonicalAndReplays(t *testing.T) {
	h := newHarness(t)
	entry := validTurn(uuid(1))
	entry["action"] = "a <b> & c" // HTML-escaped in Go's default marshal, not here

	recorder := h.do(t, "POST", "/v1/events", entry, testToken)
	if recorder.Code != http.StatusCreated {
		t.Fatalf("status %d body %s, want 201", recorder.Code, recorder.Body.String())
	}
	payload := decode(t, recorder)
	if payload["duplicate"] != false || payload["id"] != "frame001" {
		t.Fatalf("body %v, want duplicate false and frame001", payload)
	}

	stored := h.store.bodies["hash001"]
	if !strings.HasPrefix(string(stored), `{"action":"a <b> & c","base_commit":`) {
		t.Fatalf("stored body %q is not sorted-key, compact, unescaped", stored)
	}
	if strings.Contains(string(stored), `\u003c`) {
		t.Fatalf("stored body %q escaped HTML", stored)
	}

	recorder = h.do(t, "POST", "/v1/events", entry, testToken)
	if recorder.Code != http.StatusOK {
		t.Fatalf("replay status %d, want 200", recorder.Code)
	}
	payload = decode(t, recorder)
	if payload["duplicate"] != true || payload["id"] != "frame001" {
		t.Fatalf("replay body %v, want duplicate true and the stored id", payload)
	}
	if len(h.store.frames) != 1 {
		t.Fatalf("store has %d frames, want 1 after a replay", len(h.store.frames))
	}
}

// TestMinimalBody is the shape every agent actually posts: no rationale key at
// all. It caught a bug the httptest suite could not see, because the fixture
// carried a rationale (`go run` against the built binary, 2026-11-07).
func TestMinimalBody(t *testing.T) {
	h := newHarness(t)
	entry := map[string]any{
		"id":      uuid(7),
		"ts":      "2026-11-07T10:00:00Z",
		"source":  "buffY",
		"kind":    "turn",
		"subject": "nixconfig:minimal",
		"action":  "posted the seven required fields and nothing else",
		"outcome": "done",
	}
	recorder := h.do(t, "POST", "/v1/events", entry, testToken)
	if recorder.Code != http.StatusCreated {
		t.Fatalf("status %d body %s, want 201", recorder.Code, recorder.Body.String())
	}
}

func TestValidationRefusals(t *testing.T) {
	cases := []struct {
		name   string
		mutate func(map[string]any)
		want   string
	}{
		{"unknown field", func(e map[string]any) { e["extra"] = "x" }, "unknown field(s): extra"},
		{"missing field", func(e map[string]any) { delete(e, "action") }, "missing field(s): action"},
		{"kind", func(e map[string]any) { e["kind"] = "note" }, "kind must be 'turn'"},
		{"id", func(e map[string]any) { e["id"] = "not-a-uuid" }, "id must be a client-generated UUID"},
		{"ts shape", func(e map[string]any) { e["ts"] = "2026-11-07 10:00" }, "ts must be an RFC 3339"},
		{"ts value", func(e map[string]any) { e["ts"] = "2026-13-07T10:00:00Z" }, "ts is not a valid timestamp"},
		{"source", func(e map[string]any) { e["source"] = "bad source!" }, "source must be a short agent name"},
		{"empty subject", func(e map[string]any) { e["subject"] = "  " }, "subject must not be empty"},
		{"empty action", func(e map[string]any) { e["action"] = "" }, "action must not be empty"},
		{"outcome", func(e map[string]any) { e["outcome"] = "finished" }, "outcome must be done"},
		{"blocked without note", func(e map[string]any) { e["outcome"] = "blocked" }, "one-line note"},
		{"subject too long", func(e map[string]any) { e["subject"] = strings.Repeat("a", 201) }, "subject is longer than 200"},
		// The Python shim str()s a non-string outcome before its regex, so a
		// number fails on the enum, not on the type.
		{"outcome not a string", func(e map[string]any) { e["outcome"] = 3 }, "outcome must be done"},
		{"rationale null is allowed", func(e map[string]any) { e["rationale"] = nil }, ""},
		{"base_commit", func(e map[string]any) { e["base_commit"] = "HEAD" }, "base_commit must be a git commit hash"},
		{"branch", func(e map[string]any) { e["branch"] = "bad branch" }, "branch must be a branch name"},
		{"claims shape", func(e map[string]any) { e["claims"] = "one area" }, "claims must be a list of strings"},
		{"commits", func(e map[string]any) { e["commits"] = []string{"zzz"} }, "commits must be git commit hashes"},
		{"key material", func(e map[string]any) {
			e["action"] = "-----BEGIN OPENSSH PRIVATE KEY-----"
		}, "contains key material"},
		{"credential word", func(e map[string]any) { e["action"] = "set the api_key" }, "reads like it contains a credential"},
		{"credential in claims", func(e map[string]any) { e["claims"] = []string{"the refresh_token field"} }, "reads like it contains a credential"},
	}
	for i, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			h := newHarness(t)
			entry := validTurn(uuid(i + 100))
			tc.mutate(entry)
			recorder := h.do(t, "POST", "/v1/events", entry, testToken)
			payload := decode(t, recorder)
			if tc.want == "" {
				if recorder.Code != http.StatusCreated {
					t.Fatalf("status %d body %v, want 201", recorder.Code, payload)
				}
				return
			}
			if recorder.Code != http.StatusBadRequest {
				t.Fatalf("status %d body %v, want 400", recorder.Code, payload)
			}
			if got, _ := payload["error"].(string); !strings.Contains(got, tc.want) {
				t.Fatalf("error %q, want it to contain %q", got, tc.want)
			}
		})
	}
}

func TestMalformedBodies(t *testing.T) {
	h := newHarness(t)
	for name, body := range map[string]string{
		"array":   `[1,2]`,
		"garbage": `{"id":`,
		"empty":   ``,
	} {
		req := httptest.NewRequest("POST", "/v1/events", strings.NewReader(body))
		req.Header.Set("Authorization", "Bearer "+testToken)
		recorder := httptest.NewRecorder()
		h.handler.ServeHTTP(recorder, req)
		if recorder.Code != http.StatusBadRequest {
			t.Fatalf("%s: status %d, want 400", name, recorder.Code)
		}
	}
}

func TestReadIsNewestFirstAndFilters(t *testing.T) {
	h := newHarness(t)
	for i := 1; i <= 5; i++ {
		entry := validTurn(uuid(i))
		entry["ts"] = fmt.Sprintf("2026-11-0%dT10:00:00Z", i)
		entry["subject"] = fmt.Sprintf("repo%d:task", i)
		entry["source"] = []string{"alpha", "beta"}[i%2]
		h.store.seed(t, entry)
	}

	// Unfiltered stays one page: the store is asked for `limit` frames, so both
	// numbers are the page size, not the log size.
	payload := decode(t, h.do(t, "GET", "/v1/events?limit=2", nil, testToken))
	if payload["count"] != float64(2) || payload["scanned"] != float64(2) {
		t.Fatalf("count/scanned %v/%v, want 2/2", payload["count"], payload["scanned"])
	}
	events := payload["events"].([]any)
	if len(events) != 2 {
		t.Fatalf("%d events, want 2", len(events))
	}
	first := events[0].(map[string]any)
	if first["subject"] != "repo5:task" || first["_frame"] != "frame005" {
		t.Fatalf("first event %v, want the newest (repo5:task)", first)
	}

	filtered := decode(t, h.do(t, "GET", "/v1/events?repo=repo3", nil, testToken))
	if filtered["count"] != float64(1) || filtered["truncated"] != false {
		t.Fatalf("repo filter %v, want 1 match and truncated false", filtered)
	}
	if events := filtered["events"].([]any); events[0].(map[string]any)["subject"] != "repo3:task" {
		t.Fatalf("repo filter returned %v", events)
	}

	bySource := decode(t, h.do(t, "GET", "/v1/events?source=beta", nil, testToken))
	if bySource["count"] != float64(3) {
		t.Fatalf("source filter count %v, want 3", bySource["count"])
	}

	clamped := decode(t, h.do(t, "GET", "/v1/events?limit=0", nil, testToken))
	if len(clamped["events"].([]any)) != 1 {
		t.Fatalf("limit=0 returned %d events, want the clamp to 1", len(clamped["events"].([]any)))
	}
	if recorder := h.do(t, "GET", "/v1/events?limit=abc", nil, testToken); recorder.Code != http.StatusBadRequest {
		t.Fatalf("limit=abc status %d, want 400", recorder.Code)
	}
}

func TestUpdatesAndDeletesAreRefused(t *testing.T) {
	h := newHarness(t)
	for _, method := range []string{"PUT", "PATCH", "DELETE"} {
		recorder := h.do(t, method, "/v1/events", nil, testToken)
		if recorder.Code != http.StatusMethodNotAllowed {
			t.Fatalf("%s status %d, want 405", method, recorder.Code)
		}
		if recorder.Header().Get("Allow") != "GET, POST" {
			t.Fatalf("%s Allow header %q", method, recorder.Header().Get("Allow"))
		}
	}
	if recorder := h.do(t, "GET", "/v1/nope", nil, testToken); recorder.Code != http.StatusNotFound {
		t.Fatalf("unknown path status %d, want 404", recorder.Code)
	}
}

// TestLegacyDedupRows is the cutover test: the Python shim's sqlite file must be
// read as-is, or the first replay after the switch appends a second turn.
func TestLegacyDedupRows(t *testing.T) {
	dbPath := filepath.Join(t.TempDir(), "dedup.sqlite")
	legacy, err := sql.Open("sqlite", "file:"+dbPath)
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	if _, err := legacy.Exec(`CREATE TABLE turn_dedup (
		client_uuid TEXT PRIMARY KEY, frame_id TEXT NOT NULL, created_at TEXT NOT NULL)`); err != nil {
		t.Fatalf("schema: %v", err)
	}
	if _, err := legacy.Exec(
		"INSERT INTO turn_dedup VALUES (?, ?, ?)", uuid(9), "frame-legacy", "2026-11-06T20:00:00+00:00",
	); err != nil {
		t.Fatalf("seed: %v", err)
	}
	legacy.Close()

	store, socket := newFakeXS(t)
	dedupStore, err := openDedup(dbPath)
	if err != nil {
		t.Fatalf("openDedup on the legacy file: %v", err)
	}
	defer dedupStore.db.Close()
	s := &shim{store: newXSStore(socket), dedup: dedupStore, tokens: map[string]string{"test": testToken}, writes: make(chan struct{}, 1)}
	h := &harness{handler: s.routes(), store: store}

	recorder := h.do(t, "POST", "/v1/events", validTurn(uuid(9)), testToken)
	if recorder.Code != http.StatusOK {
		t.Fatalf("status %d body %s, want 200 replay", recorder.Code, recorder.Body.String())
	}
	if payload := decode(t, recorder); payload["id"] != "frame-legacy" {
		t.Fatalf("body %v, want the legacy frame id", payload)
	}
	if len(store.frames) != 0 {
		t.Fatalf("%d frames appended, want none", len(store.frames))
	}
}

func uuid(n int) string {
	return fmt.Sprintf("00000000-0000-4000-8000-%012d", n)
}
