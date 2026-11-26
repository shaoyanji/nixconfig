package mailatlas

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func read(t *testing.T, name string) string {
	t.Helper()
	b, err := os.ReadFile(filepath.Clean(name))
	if err != nil {
		t.Fatalf("read %s: %v", name, err)
	}
	return string(b)
}

func requireContains(t *testing.T, haystack string, needles ...string) {
	t.Helper()
	for _, needle := range needles {
		if !strings.Contains(haystack, needle) {
			t.Errorf("missing %q", needle)
		}
	}
}

func TestSavedViewSchemaContract(t *testing.T) {
	schema := read(t, "schema.sql")
	requireContains(t, schema,
		"CREATE TABLE IF NOT EXISTS saved_view",
		"name       text UNIQUE NOT NULL",
		"q          text NOT NULL DEFAULT ''",
		"cat        text NOT NULL DEFAULT ''",
		"box        text NOT NULL DEFAULT 'inbox'",
		"sender     text NOT NULL DEFAULT ''",
		"tier       text NOT NULL DEFAULT ''",
		"pinned     boolean NOT NULL DEFAULT true",
		"CREATE INDEX IF NOT EXISTS saved_view_pinned_idx",
	)
}

func TestEndpointContracts(t *testing.T) {
	tests := map[string][]string{
		"endpoints/atlas-views.sql":        {"-- HTTP GET", "from saved_view", "limit :lim"},
		"endpoints/atlas-view-save.sql":    {"-- HTTP POST", "insert into saved_view", "on conflict (name) do update", ":q", ":cat", ":box", ":sender", ":tier", ":pinned"},
		"endpoints/atlas-view-delete.sql":  {"-- HTTP DELETE", "delete from saved_view", ":id::bigint"},
		"endpoints/atlas-view-run.sql":     {"-- HTTP GET", "from saved_view", "v.sender", "v.tier", "offset greatest(coalesce(:off, 0), 0)"},
		"endpoints/atlas-thread.sql":       {"-- HTTP GET", "with anchor as", "participants", "order by c.sent_at asc", "limit :lim"},
		"endpoints/atlas-analytics.sql":    {"-- HTTP GET", "domains", "tags", "triage", "timeline", "attachments"},
	}
	for file, needles := range tests {
		t.Run(file, func(t *testing.T) {
			requireContains(t, read(t, file), needles...)
		})
	}
}

func TestBackwardCompatibleRoutesAndDOM(t *testing.T) {
	for _, endpoint := range []string{
		"atlas-search.sql", "atlas-message.sql", "atlas-stats.sql", "atlas-taxonomy.sql",
		"atlas-tags.sql", "atlas-act.sql", "atlas-actions.sql", "atlas-close.sql",
		"atlas-command.sql", "atlas-commands.sql", "atlas-command-close.sql",
		"atlas-boxes.sql", "atlas-box-set.sql",
	} {
		if _, err := os.Stat(filepath.Join("endpoints", endpoint)); err != nil {
			t.Errorf("existing endpoint %s missing: %v", endpoint, err)
		}
	}

	html := read(t, "site/index.html")
	requireContains(t, html,
		`id="search-form"`, `id="q"`, `id="chips"`, `id="categories"`, `id="results"`,
		`id="box-tabs"`, `id="more"`, `id="reader"`, `id="reader-close"`, `id="reader-kicker"`,
		`id="reader-subject"`, `id="reader-meta"`, `id="reader-body"`, `id="act-archive"`,
		`id="act-delete"`, `id="act-hermes"`, `id="act-state"`, `id="instruct-form"`,
		`id="instruction"`, `id="sources"`, `id="sources-open"`, `id="sources-list"`,
		`id="save-view"`, `id="saved-view-chips"`, `id="analytics-open"`, `id="analytics-body"`, `id="thread-timeline"`,
	)
}

func TestUIUsesNewAPIContracts(t *testing.T) {
	js := read(t, "site/app.js")
	requireContains(t, js,
		"/atlas-views?lim=40",
		"/atlas-view-save",
		"/atlas-view-delete",
		"/atlas-view-run?id=",
		"/atlas-thread?id=",
		"/atlas-analytics?days=90&lim=12",
		"renderSavedViews",
		"loadThreadTimeline",
		"loadAnalytics",
	)
}

func TestNpgsqlRestWriteShapes(t *testing.T) {
	type call struct {
		method string
		path   string
		body   map[string]any
	}
	var calls []call
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		var body map[string]any
		if r.Method != http.MethodGet {
			if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
				t.Errorf("decode request body: %v", err)
			}
		}
		calls = append(calls, call{method: r.Method, path: r.URL.Path, body: body})
		w.Header().Set("content-type", "application/json")
		_, _ = w.Write([]byte(`[]`))
	}))
	defer server.Close()

	for _, req := range []struct {
		method string
		path   string
		body   string
	}{
		{http.MethodPost, "/api/atlas-view-save", `{"name":"ci","q":"failed","cat":"infra","box":"all","sender":"github","tier":"action","pinned":true}`},
		{http.MethodDelete, "/api/atlas-view-delete", `{"id":7}`},
	} {
		httpReq, err := http.NewRequest(req.method, server.URL+req.path, strings.NewReader(req.body))
		if err != nil {
			t.Fatal(err)
		}
		httpReq.Header.Set("content-type", "application/json")
		response, err := http.DefaultClient.Do(httpReq)
		if err != nil {
			t.Fatalf("%s %s: %v", req.method, req.path, err)
		}
		_ = response.Body.Close()
		if response.StatusCode != http.StatusOK {
			t.Errorf("%s %s status %d", req.method, req.path, response.StatusCode)
		}
	}

	if len(calls) != 2 {
		t.Fatalf("got %d calls, want 2", len(calls))
	}
	if calls[0].method != http.MethodPost || calls[0].body["name"] != "ci" || calls[0].body["pinned"] != true {
		t.Errorf("bad save call: %+v", calls[0])
	}
	if calls[1].method != http.MethodDelete || calls[1].body["id"] != float64(7) {
		t.Errorf("bad delete call: %+v", calls[1])
	}
}
