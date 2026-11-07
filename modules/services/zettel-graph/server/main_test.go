package main

// The server's contract is its refusals as much as its routes: a write without
// the header, an id outside the three directories, a publish on a host that has
// it off. These tests run the real handler against a temp vault, with git and
// the vault's python scripts replaced by copies of the test binary — no external
// tool is needed, which is what keeps them honest inside a nix sandbox.

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

func TestMain(m *testing.M) {
	switch filepath.Base(os.Args[0]) {
	case "git":
		fakeGit()
		os.Exit(0)
	case "python3":
		fakePython()
		os.Exit(0)
	}
	os.Exit(m.Run())
}

func fakeGit() {
	for _, arg := range os.Args[1:] {
		switch arg {
		case "rev-parse":
			fmt.Println("abc1234")
			return
		case "diff":
			// A staged change exists, so the commit path runs.
			os.Exit(1)
		}
	}
}

func fakePython() {
	args := os.Args[1:]
	if len(args) == 0 {
		return
	}
	switch {
	case strings.HasSuffix(args[0], "export_graph.py"):
		for i, arg := range args {
			if arg == "--out" && i+1 < len(args) {
				body := `{"meta":{"notes":2,"links":3,"generated":"2026-11-07T10:00:00Z"}}`
				if err := os.WriteFile(args[i+1], []byte(body), 0o644); err != nil {
					fmt.Fprintln(os.Stderr, err)
					os.Exit(1)
				}
			}
		}
	case strings.HasSuffix(args[0], "create_note.py"):
		title := "untitled"
		for i, arg := range args {
			if arg == "--title" && i+1 < len(args) {
				title = args[i+1]
			}
		}
		slug := strings.ToLower(strings.ReplaceAll(title, " ", "-"))
		if err := os.MkdirAll("zettels", 0o755); err != nil {
			os.Exit(1)
		}
		note := filepath.Join("zettels", slug+".md")
		if err := os.WriteFile(note, []byte("---\ntitle: "+title+"\n---\n"), 0o644); err != nil {
			os.Exit(1)
		}
		fmt.Println(note)
	case strings.HasSuffix(args[0], "publish_md.py"):
		if err := os.MkdirAll("publish", 0o755); err != nil {
			os.Exit(1)
		}
		if err := os.WriteFile(filepath.Join("publish", "all.pdf"), []byte("%PDF-1.4"), 0o644); err != nil {
			os.Exit(1)
		}
		fmt.Println("rendered 1 file")
	}
}

type harness struct {
	handler http.Handler
	vault   string
	www     string
}

func newHarness(t *testing.T) *harness {
	t.Helper()
	root := t.TempDir()
	vaultDir := filepath.Join(root, "vault")
	www := filepath.Join(root, "www")
	for _, dir := range []string{filepath.Join(vaultDir, "zettels"), filepath.Join(vaultDir, "scripts"), www} {
		if err := os.MkdirAll(dir, 0o755); err != nil {
			t.Fatalf("mkdir %s: %v", dir, err)
		}
	}
	write := func(path, body string) {
		if err := os.WriteFile(path, []byte(body), 0o644); err != nil {
			t.Fatalf("write %s: %v", path, err)
		}
	}
	write(filepath.Join(vaultDir, "zettels", "a-note.md"), "# a note\n\nbody\n")
	write(filepath.Join(www, "index.html"), "<html>reader</html>")
	write(filepath.Join(www, "graph.json"), `{"meta":{"notes":2,"links":3,"generated":"2026-11-07T10:00:00Z"}}`)

	self, err := os.Executable()
	if err != nil {
		t.Fatalf("executable: %v", err)
	}
	gitPath := filepath.Join(root, "git")
	pythonPath := filepath.Join(root, "python3")
	for _, target := range []string{gitPath, pythonPath} {
		body, err := os.ReadFile(self)
		if err != nil {
			t.Fatalf("read self: %v", err)
		}
		if err := os.WriteFile(target, body, 0o755); err != nil {
			t.Fatalf("write %s: %v", target, err)
		}
	}

	s := &server{cfg: config{
		www: www, vault: vaultDir, python: pythonPath, git: gitPath,
		ref: "main", origin: "https://zeta.example:8453",
		commit: true, publish: true,
	}}
	return &harness{handler: s, vault: vaultDir, www: www}
}

func (h *harness) do(t *testing.T, method, target string, body string, headers map[string]string) *httptest.ResponseRecorder {
	t.Helper()
	var reader *strings.Reader
	if body == "" {
		reader = strings.NewReader("")
	} else {
		reader = strings.NewReader(body)
	}
	req := httptest.NewRequest(method, target, reader)
	for key, value := range headers {
		req.Header.Set(key, value)
	}
	recorder := httptest.NewRecorder()
	h.handler.ServeHTTP(recorder, req)
	return recorder
}

func writeHeaders() map[string]string {
	return map[string]string{
		"X-Zettel-Write": "1",
		"Content-Type":   "application/json",
		"Content-Length": "0",
	}
}

func decodeBody(t *testing.T, recorder *httptest.ResponseRecorder) map[string]any {
	t.Helper()
	var payload map[string]any
	if err := json.Unmarshal(recorder.Body.Bytes(), &payload); err != nil {
		t.Fatalf("decoding %q: %v", recorder.Body.String(), err)
	}
	return payload
}

func TestHealthReportsTheGraphAndHead(t *testing.T) {
	h := newHarness(t)
	recorder := h.do(t, "GET", "/api/health", "", nil)
	if recorder.Code != http.StatusOK {
		t.Fatalf("status %d, want 200", recorder.Code)
	}
	payload := decodeBody(t, recorder)
	if payload["ok"] != true || payload["notes"] != float64(2) || payload["links"] != float64(3) {
		t.Fatalf("health %v, want ok with notes 2 and links 3", payload)
	}
	if payload["vault"] != "abc1234" {
		t.Fatalf("vault %v, want the stub HEAD", payload["vault"])
	}
	if payload["write"] != true || payload["publish"] != true {
		t.Fatalf("health %v, want write and publish true", payload)
	}
}

func TestHealthWithoutGraphIsNotOK(t *testing.T) {
	h := newHarness(t)
	os.Remove(filepath.Join(h.www, "graph.json"))
	payload := decodeBody(t, h.do(t, "GET", "/api/health", "", nil))
	if payload["ok"] != false {
		t.Fatalf("health %v, want ok false with no graph.json", payload)
	}
}

func TestNoteReadAndIdRefusals(t *testing.T) {
	h := newHarness(t)
	payload := decodeBody(t, h.do(t, "GET", "/api/note/zettels/a-note", "", nil))
	if payload["id"] != "zettels/a-note.md" || !strings.Contains(payload["text"].(string), "# a note") {
		t.Fatalf("note %v", payload)
	}
	// An explicit .md is accepted: a caller reading `git status` will have one.
	if recorder := h.do(t, "GET", "/api/note/zettels/a-note.md", "", nil); recorder.Code != http.StatusOK {
		t.Fatalf("with suffix: status %d, want 200", recorder.Code)
	}
	for name, target := range map[string]string{
		"outside the three dirs": "/api/note/secrets/keys",
		"traversal":              "/api/note/zettels/../../etc/passwd",
		"empty":                  "/api/note/zettels/",
	} {
		recorder := h.do(t, "GET", target, "", nil)
		if recorder.Code != http.StatusBadRequest {
			t.Fatalf("%s: status %d, want 400", name, recorder.Code)
		}
	}
	if recorder := h.do(t, "GET", "/api/note/zettels/missing", "", nil); recorder.Code != http.StatusNotFound {
		t.Fatalf("missing note: status %d, want 404", recorder.Code)
	}
}

func TestWriteGuard(t *testing.T) {
	h := newHarness(t)
	body := `{"text":"# rewritten\n"}`
	if recorder := h.do(t, "PUT", "/api/note/zettels/a-note", body, map[string]string{"Content-Type": "application/json"}); recorder.Code != http.StatusForbidden {
		t.Fatalf("no header: status %d, want 403", recorder.Code)
	}
	headers := writeHeaders()
	headers["Origin"] = "https://evil.example"
	if recorder := h.do(t, "PUT", "/api/note/zettels/a-note", body, headers); recorder.Code != http.StatusForbidden {
		t.Fatalf("wrong origin: status %d, want 403", recorder.Code)
	}
	headers = writeHeaders()
	headers["Content-Type"] = "text/plain"
	if recorder := h.do(t, "PUT", "/api/note/zettels/a-note", body, headers); recorder.Code != http.StatusUnsupportedMediaType {
		t.Fatalf("wrong content type: status %d, want 415", recorder.Code)
	}
}

func TestWriteRewritesCommitsAndReexports(t *testing.T) {
	h := newHarness(t)
	headers := writeHeaders()
	headers["Origin"] = "https://zeta.example:8453"
	recorder := h.do(t, "PUT", "/api/note/zettels/a-note", `{"text":"# rewritten\n"}`, headers)
	if recorder.Code != http.StatusOK {
		t.Fatalf("status %d body %s, want 200", recorder.Code, recorder.Body.String())
	}
	payload := decodeBody(t, recorder)
	if payload["committed"] != true || payload["pushed"] != false {
		t.Fatalf("write %v, want committed true and pushed false", payload)
	}
	if meta, ok := payload["meta"].(map[string]any); !ok || meta["notes"] != float64(2) {
		t.Fatalf("write %v, want the exported meta", payload["meta"])
	}
	written, err := os.ReadFile(filepath.Join(h.vault, "zettels", "a-note.md"))
	if err != nil || string(written) != "# rewritten\n" {
		t.Fatalf("file holds %q (%v)", written, err)
	}
}

func TestWriteRefusesOversizedNote(t *testing.T) {
	h := newHarness(t)
	big := `{"text":"` + strings.Repeat("a", maxNote+10) + `"}`
	recorder := h.do(t, "PUT", "/api/note/zettels/a-note", big, writeHeaders())
	if recorder.Code != http.StatusRequestEntityTooLarge {
		t.Fatalf("status %d, want 413", recorder.Code)
	}
}

func TestCreateNote(t *testing.T) {
	h := newHarness(t)
	for name, body := range map[string]string{
		"no title":  `{"type":"zettel"}`,
		"bad type":  `{"title":"x","type":"note"}`,
		"not json":  `title=`,
		"empty body": ``,
	} {
		code := h.do(t, "POST", "/api/new", body, writeHeaders()).Code
		if code != http.StatusBadRequest && code != http.StatusRequestEntityTooLarge {
			t.Fatalf("%s: status %d, want 400 or 413", name, code)
		}
	}

	recorder := h.do(t, "POST", "/api/new", `{"title":"My  New Note","type":"zettel","tags":"a, b"}`, writeHeaders())
	if recorder.Code != http.StatusCreated {
		t.Fatalf("status %d body %s, want 201", recorder.Code, recorder.Body.String())
	}
	payload := decodeBody(t, recorder)
	if payload["path"] != "zettels/my-new-note.md" {
		t.Fatalf("created %v", payload)
	}
	if _, err := os.Stat(filepath.Join(h.vault, "zettels", "my-new-note.md")); err != nil {
		t.Fatalf("the note is not on disk: %v", err)
	}
}

func TestPublishAndReload(t *testing.T) {
	h := newHarness(t)
	recorder := h.do(t, "POST", "/api/publish", `{"all":true}`, writeHeaders())
	if recorder.Code != http.StatusOK {
		t.Fatalf("publish status %d body %s", recorder.Code, recorder.Body.String())
	}
	payload := decodeBody(t, recorder)
	if payload["ok"] != true {
		t.Fatalf("publish %v, want ok", payload)
	}
	files, _ := payload["files"].([]any)
	if len(files) != 1 || files[0] != "publish/all.pdf" {
		t.Fatalf("publish files %v, want publish/all.pdf", payload["files"])
	}

	reload := decodeBody(t, h.do(t, "POST", "/api/reload", "", writeHeaders()))
	if reload["ok"] != true {
		t.Fatalf("reload %v", reload)
	}
}

func TestPublishOffIs405(t *testing.T) {
	h := newHarness(t)
	h.handler.(*server).cfg.publish = false
	if code := h.do(t, "POST", "/api/publish", `{"all":true}`, writeHeaders()).Code; code != http.StatusMethodNotAllowed {
		t.Fatalf("status %d, want 405", code)
	}
}

func TestStaticAndUnknownRoutes(t *testing.T) {
	h := newHarness(t)
	recorder := h.do(t, "GET", "/", "", nil)
	if recorder.Code != http.StatusOK || !strings.Contains(recorder.Body.String(), "reader") {
		t.Fatalf("index: status %d body %q", recorder.Code, recorder.Body.String())
	}
	if code := h.do(t, "GET", "/missing.html", "", nil).Code; code != http.StatusNotFound {
		t.Fatalf("missing static: status %d, want 404", code)
	}
	if recorder := h.do(t, "GET", "/graph.json", "", nil); recorder.Header().Get("Cache-Control") != "no-store" {
		t.Fatalf("graph.json cache header %q, want no-store", recorder.Header().Get("Cache-Control"))
	}
	// Parity, not preference: the Python server's health branch never looked at
	// the method, so a POST answers too. Pinned here so a later "fix" is a
	// deliberate change to the contract rather than a surprise.
	if code := h.do(t, "POST", "/api/health", "", nil).Code; code != http.StatusOK {
		t.Fatalf("POST /api/health: status %d, want 200 (parity)", code)
	}
	if code := h.do(t, "GET", "/publish/notapdf.txt", "", nil).Code; code != http.StatusBadRequest {
		t.Fatalf("bad pdf name: status %d, want 400", code)
	}
}
