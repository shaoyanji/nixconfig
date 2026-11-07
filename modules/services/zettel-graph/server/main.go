// zettel-graph: serve the zettel reader and its vault export on one loopback
// port.
//
// The reader is static: `index.html`, `graph.json` and `demo/`. The verbs that
// change something are the whole API.
//
//	GET  /api/health        what is being served (note/link counts, vault HEAD)
//	GET  /api/note/<id>     raw markdown of one note
//	PUT  /api/note/<id>     write it back, commit, re-export the graph, push
//	POST /api/new           create a note through the vault's create_note.py
//	POST /api/publish       render PDFs through the vault's own publish_md.py
//	POST /api/reload        re-export the graph from the working tree
//	GET  /publish/<name>    one rendered PDF
//
// There is no authentication of its own: the listener is loopback and the only
// route in is the host's `tailscale serve` mount, so "on the tailnet" is the
// fence. A write additionally needs `X-Zettel-Write: 1` and, when the browser
// sends one, an Origin equal to --origin — a simple cross-site request can reach
// a tailnet name without ever reading the answer, and this is what makes that
// request not a write.
//
// Nothing here parses markdown or resolves a link: the vault's exporter does
// that and this process only runs it. A second copy of those rules is how the
// page and the gate start disagreeing.
package main

import (
	"errors"
	"flag"
	"fmt"
	"log"
	"net"
	"net/http"
	"os"
	"os/signal"
	"path"
	"path/filepath"
	"regexp"
	"strings"
	"sync"
	"syscall"
	"time"
)

const maxNote = 512 * 1024

// The three directories a note may live in. A write outside them is a typo or
// an attack; either way it is not this service's business. Ids come from the
// export, which drops the suffix (`zettels/2026…-a-note`); an explicit `.md` is
// accepted because a caller reading `git status` will have one.
var (
	idRe  = regexp.MustCompile(`^(?:zettels|010 - MOCs|journal)/[^/\\` + "\x00" + `]+$`)
	pdfRe = regexp.MustCompile(`^[^/\\` + "\x00" + `]+\.pdf$`)
)

// The types whose `create_note.py` target is a directory this service writes
// to. `note`/`idea`/`reference` land elsewhere, which the id shape here does
// not cover; offering them would be a button that 400s.
var createTypes = []string{"zettel", "moc"}

type config struct {
	www     string
	vault   string
	python  string
	git     string
	ref     string
	origin  string
	commit  bool
	push    bool
	publish bool
}

type server struct {
	cfg config

	// One lock for the working tree: a write, a create, a publish and a reload
	// all mutate the vault, so they queue behind each other.
	mutate sync.Mutex

	// env is appended to every subprocess this server runs. It is empty in
	// production and carries the test stubs' marker under `go test`.
	env []string

	headMu  sync.Mutex
	headAt  time.Time
	headVal string
}

// refused is a status and a sentence: the only error shape this service answers.
type refused struct {
	code int
	msg  string
}

func (r refused) Error() string { return r.msg }

func refuse(code int, format string, args ...any) error {
	return refused{code: code, msg: fmt.Sprintf(format, args...)}
}

func main() {
	www := flag.String("www", "", "directory holding index.html and graph.json")
	vaultDir := flag.String("vault", "", "vault checkout the exporter and publisher run in")
	port := flag.Int("port", 8083, "loopback port")
	origin := flag.String("origin", "", "the exact origin the page is served under")
	ref := flag.String("ref", "main", "vault branch a write is pushed to")
	commit := flag.Bool("commit", false, "commit a write in the vault")
	push := flag.Bool("push", false, "push a commit to origin")
	publish := flag.Bool("publish", false, "allow /api/publish to render PDFs")
	python := flag.String("python", "python3", "interpreter the vault's own scripts run under")
	git := flag.String("git", "git", "git binary used for the vault")

	flag.Parse()
	if *www == "" || *vaultDir == "" || *origin == "" {
		log.Fatal("zettel-graph: --www, --vault and --origin are required")
	}

	s := &server{cfg: config{
		www: *www, vault: *vaultDir, python: *python, git: *git,
		ref: *ref, origin: strings.TrimRight(*origin, "/"),
		commit: *commit, push: *push, publish: *publish,
	}}

	addr := net.JoinHostPort("127.0.0.1", fmt.Sprint(*port))
	srv := &http.Server{Addr: addr, Handler: s, ReadHeaderTimeout: 10 * time.Second}

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, syscall.SIGTERM, syscall.SIGINT)
	go func() {
		<-stop
		srv.Close()
	}()

	log.Printf("zettel-graph: http://%s -> %s (vault %s)", addr, s.cfg.www, s.cfg.vault)
	if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
		log.Fatal(err)
	}
}

func (s *server) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	if err := s.route(w, r); err != nil {
		var status int
		var message string
		var r refused
		if errors.As(err, &r) {
			status, message = r.code, r.msg
		} else {
			status, message = http.StatusInternalServerError, err.Error()
		}
		writeJSON(w, status, map[string]any{"error": message})
	}
}

func (s *server) route(w http.ResponseWriter, r *http.Request) error {
	// Binary bodies (a PDF, a markdown note) are streamed, not buffered in this
	// process: a publish can emit tens of megabytes.
	decoded, err := decodePath(r.URL.EscapedPath())
	if err != nil {
		return refuse(400, "unreadable path")
	}
	method := r.Method

	switch {
	case decoded == "/graph.json" || decoded == "/api/graph.json":
		return sendFile(w, filepath.Join(s.cfg.www, "graph.json"), "application/json")
	case decoded == "/api/health":
		meta := readMeta(s.cfg.www)
		writeJSON(w, 200, map[string]any{
			"ok":        meta["notes"] != nil,
			"notes":     metaInt(meta, "notes"),
			"links":     metaInt(meta, "links"),
			"generated": metaString(meta, "generated"),
			"vault":     s.head(),
			"write":     true,
			"publish":   s.cfg.publish,
		})
		return nil
	case strings.HasPrefix(decoded, "/api/note/") && method == "GET":
		relative, file, err := s.noteFile(strings.TrimPrefix(decoded, "/api/note/"))
		if err != nil {
			return err
		}
		text, err := os.ReadFile(file)
		if err != nil {
			return refuse(404, "%s is not in the working tree", relative)
		}
		writeJSON(w, 200, map[string]any{"id": relative, "text": string(text)})
		return nil
	case strings.HasPrefix(decoded, "/api/note/") && method == "PUT":
		if err := s.guardWrite(r); err != nil {
			return err
		}
		body, err := readBody(r)
		if err != nil {
			return err
		}
		text, ok := body["text"].(string)
		if !ok {
			return refuse(400, "body is {text: <markdown>}")
		}
		s.mutate.Lock()
		defer s.mutate.Unlock()
		result, err := s.writeNote(strings.TrimPrefix(decoded, "/api/note/"), text)
		if err != nil {
			return err
		}
		writeJSON(w, 200, result)
		return nil
	case decoded == "/api/new" && method == "POST":
		if err := s.guardWrite(r); err != nil {
			return err
		}
		spec, err := readBody(r)
		if err != nil {
			return err
		}
		s.mutate.Lock()
		defer s.mutate.Unlock()
		result, err := s.createNote(spec)
		if err != nil {
			return err
		}
		writeJSON(w, 201, result)
		return nil
	case decoded == "/api/reload" && method == "POST":
		if err := s.guardWrite(r); err != nil {
			return err
		}
		s.mutate.Lock()
		defer s.mutate.Unlock()
		meta, err := s.reexport()
		if err != nil {
			return err
		}
		writeJSON(w, 200, map[string]any{"ok": true, "meta": meta})
		return nil
	case decoded == "/api/publish" && method == "POST":
		if err := s.guardWrite(r); err != nil {
			return err
		}
		if !s.cfg.publish {
			return refuse(405, "publish is off on this host")
		}
		spec, err := readBody(r)
		if err != nil {
			return err
		}
		s.mutate.Lock()
		defer s.mutate.Unlock()
		result, err := s.publish(spec)
		if err != nil {
			return err
		}
		writeJSON(w, 200, result)
		return nil
	case strings.HasPrefix(decoded, "/publish/"):
		name := strings.TrimPrefix(decoded, "/publish/")
		if !pdfRe.MatchString(name) {
			return refuse(400, "only a .pdf name is served here")
		}
		return sendFile(w, filepath.Join(s.cfg.vault, "publish", name), "application/pdf")
	case method == "GET":
		return s.static(w, decoded)
	default:
		return refuse(405, "%s is not a route", method)
	}
}

// decodePath percent-decodes the request path once, as the Python server did
// with `unquote`.
func decodePath(raw string) (string, error) {
	decoded, err := urlUnescape(raw)
	if err != nil {
		return "", err
	}
	return decoded, nil
}

func (s *server) static(w http.ResponseWriter, requestPath string) error {
	rel := "index.html"
	if requestPath != "" && requestPath != "/" {
		rel = strings.TrimPrefix(requestPath, "/")
	}
	root, err := filepath.Abs(s.cfg.www)
	if err != nil {
		return err
	}
	candidate := filepath.Join(root, filepath.FromSlash(path.Clean("/"+rel)))
	if candidate != root && !strings.HasPrefix(candidate, root+string(filepath.Separator)) {
		return refuse(404, "not found")
	}
	info, err := os.Stat(candidate)
	if err != nil || info.IsDir() {
		return refuse(404, "not found")
	}
	ctypes := map[string]string{
		".html": "text/html; charset=utf-8",
		".json": "application/json",
		".js":   "text/javascript",
		".css":  "text/css",
		".svg":  "image/svg+xml",
		".png":  "image/png",
	}
	return sendFile(w, candidate, ctypes[filepath.Ext(candidate)])
}

// guardWrite is the write fence: a header no cross-site form can set, an origin
// that has to match the mount, and JSON on any request that carries a body.
func (s *server) guardWrite(r *http.Request) error {
	if r.Header.Get("X-Zettel-Write") != "1" {
		return refuse(403, "writes need X-Zettel-Write: 1")
	}
	if origin := r.Header.Get("Origin"); origin != "" && origin != s.cfg.origin {
		return refuse(403, "origin %s is not %s", origin, s.cfg.origin)
	}
	// Only a request that carries a body has a content type to judge: a
	// bodyless `/api/reload` sent by `fetch` without one is not a form post, and
	// rejecting it would be a guard against nothing.
	if r.ContentLength != 0 {
		ctype := r.Header.Get("Content-Type")
		if i := strings.Index(ctype, ";"); i >= 0 {
			ctype = ctype[:i]
		}
		if strings.TrimSpace(ctype) != "application/json" {
			return refuse(415, "body must be application/json")
		}
	}
	return nil
}
