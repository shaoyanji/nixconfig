package main

import (
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

const origin = "https://mataroa.example:8454"

func newHarness(t *testing.T) (*config, *httptest.Server) {
	t.Helper()
	api := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Authorization") != "Bearer test-token" {
			w.WriteHeader(401)
			return
		}
		switch {
		case r.Method == "GET" && r.URL.Path == "/posts/":
			w.Header().Set("Content-Type", "application/json")
			fmt.Fprint(w, `{"post_list":[
				{"slug":"in-sync","title":"In sync","published_at":"2026-01-01","body":"same\n","url":"https://blog/in-sync"},
				{"slug":"differs","title":"Differs","published_at":"2026-01-02","body":"old\n","url":"https://blog/differs"},
				{"slug":"remote-only","title":"Remote only","published_at":"2026-01-03","body":"remote\n"}]}`)
		case r.Method == "POST" && r.URL.Path == "/posts/":
			w.Header().Set("Content-Type", "application/json")
			fmt.Fprint(w, `{"slug":"new-post","url":"https://blog/new-post","published_at":"2026-11-07"}`)
		case r.Method == "PATCH":
			w.Header().Set("Content-Type", "application/json")
			fmt.Fprint(w, `{"slug":"in-sync","url":"https://blog/in-sync","published_at":""}`)
		default:
			w.WriteHeader(404)
		}
	}))
	t.Cleanup(api.Close)

	state := t.TempDir()
	c := &config{state: state, origin: origin, apiBase: api.URL, commit: false, token: "test-token"}
	if _, err := c.postsDir(); err != nil {
		t.Fatalf("posts dir: %v", err)
	}
	// Local posts: one in sync with the stub, one that differs, one local-only.
	for slug, body := range map[string]string{"in-sync": "same\n", "differs": "new\n", "local-only": "local\n"} {
		post := "---\ntitle: " + slug + "\npublished_at: 2026-01-01\n---\n\n" + body
		if err := os.WriteFile(filepath.Join(state, "posts", slug+".md"), []byte(post), 0o644); err != nil {
			t.Fatalf("seed %s: %v", slug, err)
		}
	}
	return c, api
}

func (c *config) do(t *testing.T, method, target, body string, headers map[string]string) *httptest.ResponseRecorder {
	t.Helper()
	req := httptest.NewRequest(method, target, strings.NewReader(body))
	for key, value := range headers {
		req.Header.Set(key, value)
	}
	recorder := httptest.NewRecorder()
	c.ServeHTTP(recorder, req)
	return recorder
}

func writeHeaders() map[string]string {
	return map[string]string{"X-Mataroa-Write": "1", "Content-Type": "application/json", "Origin": origin}
}

func decodeJSON(t *testing.T, recorder *httptest.ResponseRecorder) map[string]any {
	t.Helper()
	var payload map[string]any
	if err := json.Unmarshal(recorder.Body.Bytes(), &payload); err != nil {
		t.Fatalf("decoding %q: %v", recorder.Body.String(), err)
	}
	return payload
}

func TestSlugifyAndFrontmatter(t *testing.T) {
	cases := map[string]string{
		"How To: Write":  "how-to-write",
		"  spaced  out ": "spaced-out",
		"!!!":            "untitled",
	}
	for input, want := range cases {
		if got := slugify(input); got != want {
			t.Fatalf("slugify(%q) = %q, want %q", input, got, want)
		}
	}
	meta, body := parseDoc("---\ntitle: \"A Note\"\npublished_at: 2026-01-02\n---\n\nhello\n")
	if meta["title"] != "A Note" || meta["published_at"] != "2026-01-02" || body != "hello\n" {
		t.Fatalf("parseDoc = %v %q", meta, body)
	}
	if title := titleCase("in-sync"); title != "In-Sync" {
		t.Fatalf("titleCase = %q", title)
	}
}

func TestLedgerStates(t *testing.T) {
	c, _ := newHarness(t)
	payload := decodeJSON(t, c.do(t, "GET", "/api/state", "", nil))
	if payload["ok"] != true {
		t.Fatalf("state %v", payload)
	}
	states := map[string]string{}
	for _, raw := range payload["posts"].([]any) {
		row := raw.(map[string]any)
		states[row["slug"].(string)] = row["state"].(string)
	}
	want := map[string]string{
		"in-sync": "in-sync", "differs": "differs",
		"local-only": "local-only", "remote-only": "remote-only",
	}
	for slug, expected := range want {
		if states[slug] != expected {
			t.Fatalf("%s is %q, want %q (all: %v)", slug, states[slug], expected, states)
		}
	}
}

func TestWriteGuardAndSave(t *testing.T) {
	c, _ := newHarness(t)
	body := `{"title":"Saved","body":"text\n","published_at":"2026-02-02"}`
	if code := c.do(t, "PUT", "/api/post/local-only", body, map[string]string{"Content-Type": "application/json"}).Code; code != 403 {
		t.Fatalf("no header: status %d, want 403", code)
	}
	headers := writeHeaders()
	headers["Origin"] = "https://evil.example"
	if code := c.do(t, "PUT", "/api/post/local-only", body, headers).Code; code != 403 {
		t.Fatalf("wrong origin: status %d, want 403", code)
	}

	recorder := c.do(t, "PUT", "/api/post/local-only", body, writeHeaders())
	if recorder.Code != 200 {
		t.Fatalf("status %d body %s, want 200", recorder.Code, recorder.Body.String())
	}
	saved := decodeJSON(t, recorder)["post"].(map[string]any)
	if saved["title"] != "Saved" || saved["published_at"] != "2026-02-02" {
		t.Fatalf("saved %v", saved)
	}
	onDisk, err := os.ReadFile(filepath.Join(c.state, "posts", "local-only.md"))
	if err != nil || !strings.Contains(string(onDisk), "title: Saved") {
		t.Fatalf("file %q (%v)", onDisk, err)
	}
}

func TestBadSlugAndMissingPost(t *testing.T) {
	c, _ := newHarness(t)
	if code := c.do(t, "GET", "/api/post/Not_A_Slug", "", nil).Code; code != 400 {
		t.Fatalf("bad slug: status %d, want 400", code)
	}
	if code := c.do(t, "GET", "/api/post/absent", "", nil).Code; code != 404 {
		t.Fatalf("missing: status %d, want 404", code)
	}
}

func TestPublishPatchesAKnownPost(t *testing.T) {
	c, _ := newHarness(t)
	recorder := c.do(t, "POST", "/api/publish/in-sync", `{}`, writeHeaders())
	if recorder.Code != 200 {
		t.Fatalf("status %d body %s", recorder.Code, recorder.Body.String())
	}
	if decodeJSON(t, recorder)["ok"] != true {
		t.Fatalf("publish body %s", recorder.Body.String())
	}
}

func TestPublishCreatesAnUnknownPost(t *testing.T) {
	c, _ := newHarness(t)
	recorder := c.do(t, "POST", "/api/publish/local-only", `{}`, writeHeaders())
	if recorder.Code != 200 {
		t.Fatalf("status %d body %s", recorder.Code, recorder.Body.String())
	}
	payload := decodeJSON(t, recorder)
	if payload["slug"] != "new-post" {
		t.Fatalf("publish %v, want the slug the blog answered", payload)
	}
	if _, err := os.Stat(filepath.Join(c.state, "posts", "new-post.md")); err != nil {
		t.Fatalf("the renamed file is not on disk: %v", err)
	}
}

func TestPullImportsRemoteOnly(t *testing.T) {
	c, _ := newHarness(t)
	recorder := c.do(t, "POST", "/api/pull", `{}`, writeHeaders())
	if recorder.Code != 200 {
		t.Fatalf("status %d body %s", recorder.Code, recorder.Body.String())
	}
	imported := decodeJSON(t, recorder)["imported"].([]any)
	if len(imported) != 1 || imported[0] != "remote-only" {
		t.Fatalf("imported %v, want [remote-only]", imported)
	}
}

func TestFormPathNeedsItsOrigin(t *testing.T) {
	c, _ := newHarness(t)
	form := "slug=local-only&title=Formed&body=x&published_at="
	if code := c.do(t, "POST", "/save", form, map[string]string{"Content-Type": "application/x-www-form-urlencoded"}).Code; code != 403 {
		t.Fatalf("no origin: status %d, want 403", code)
	}
	recorder := c.do(t, "POST", "/save", form, map[string]string{
		"Content-Type": "application/x-www-form-urlencoded", "Origin": origin,
	})
	if recorder.Code != 303 || recorder.Header().Get("Location") != "/e/local-only" {
		t.Fatalf("save: status %d location %q", recorder.Code, recorder.Header().Get("Location"))
	}
}

func TestPagesAndUnknownRoutes(t *testing.T) {
	c, _ := newHarness(t)
	if recorder := c.do(t, "GET", "/", "", nil); recorder.Code != 200 || !strings.Contains(recorder.Body.String(), "ledger") {
		t.Fatalf("ledger page: status %d", recorder.Code)
	}
	if recorder := c.do(t, "GET", "/p/in-sync", "", nil); recorder.Code != 200 || !strings.Contains(recorder.Body.String(), "in-sync") {
		t.Fatalf("post page: status %d", recorder.Code)
	}
	if recorder := c.do(t, "GET", "/e/new", "", nil); recorder.Code != 200 {
		t.Fatalf("editor: status %d", recorder.Code)
	}
	if code := c.do(t, "DELETE", "/api/post/local-only", "", nil).Code; code != 403 {
		t.Fatalf("guarded delete: status %d, want 403", code)
	}
	if code := c.do(t, "DELETE", "/api/post/local-only", "", writeHeaders()).Code; code != 200 {
		t.Fatalf("delete: status %d, want 200", code)
	}
	if code := c.do(t, "GET", "/api/nope", "", nil).Code; code != 404 {
		t.Fatalf("unknown api route: status %d, want 404", code)
	}
}

// A missing token is a ledger error and an empty pull — the Python server
// swallowed it there — but a publish cannot pretend it worked.
func TestNoTokenIsAnErrorOnTheLedgerAndA503OnPublish(t *testing.T) {
	c, _ := newHarness(t)
	c.token = ""
	state := decodeJSON(t, c.do(t, "GET", "/api/state", "", nil))
	if !strings.Contains(state["error"].(string), "no mataroa token") {
		t.Fatalf("state error %v, want the missing token", state["error"])
	}
	payload := decodeJSON(t, c.do(t, "POST", "/api/publish/in-sync", `{}`, writeHeaders()))
	if payload["ok"] != false || !strings.Contains(payload["error"].(string), "no mataroa token") {
		t.Fatalf("publish without a token: %v", payload)
	}
}
