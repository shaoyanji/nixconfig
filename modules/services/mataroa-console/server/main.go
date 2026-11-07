// mataroa-console: a tailnet console over a mataroa.blog blog, with markdown
// files as the source.
//
// mataroa gives you a form in a browser and an API. Neither gives you a directory
// of files you can grep, diff, commit or edit in vim, and the API alone makes
// "what is on my blog?" a question you answer by reading HTTP. So this service
// keeps the posts as files and treats the blog as a deployment target:
//
//	$STATE/posts/<slug>.md     frontmatter `title`, `published_at`, then markdown
//	GET  /                     the ledger: local files, and how each differs
//	GET  /p/<slug>             one post, rendered
//	GET  /e/<slug>             the editor (`/e/new` for a new one)
//	POST /save                 write the file (no network)
//	POST /publish              POST a new post or PATCH an existing one
//	POST /unpublish            set published_at empty, which mataroa reads as draft
//	POST /pull                 copy posts that exist only on the blog into files
//	GET  /api/state            the same ledger as JSON
//	GET  /api/post/<slug>      one post as JSON
//	PUT  /api/post/<slug>      save it as JSON (this is the curl path)
//	POST /api/publish/<slug>   publish it
//	POST /api/unpublish/<slug> unpublish it
//	POST /api/pull             import remote-only posts
//
// There is no authentication of its own: the listener is loopback and the only
// route in is the host's `tailscale serve` mount, so "on the tailnet" is the
// fence. A write also needs `X-Mataroa-Write: 1` and, when the browser sends one,
// an Origin equal to --origin: a page somewhere else can send a request to a
// tailnet address without reading the answer, and this is what makes that
// request not a write.
//
// The token never leaves this process: it is read from LoadCredential, sent as a
// bearer header, and never rendered, logged or written into a post file.
package main

import (
	"context"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"net/url"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
	"time"
)

type config struct {
	state   string
	origin  string
	apiBase string
	blogURL string
	comrak  string
	commit  bool
	token   string
	cache   remoteCache
}

type refused struct {
	status int
	msg    string
}

func (r refused) Error() string { return r.msg }

func refuse(status int, format string, args ...any) error {
	return refused{status: status, msg: fmt.Sprintf(format, args...)}
}

func main() {
	state := flag.String("state", "", "directory holding posts/ and .git")
	port := flag.Int("port", 0, "loopback port")
	origin := flag.String("origin", "", "exact tailnet origin a browser posts from")
	apiBase := flag.String("api-base", "https://mataroa.blog/api", "mataroa API base")
	blogURL := flag.String("blog-url", "", "the blog this console edits")
	comrak := flag.String("comrak", lookComrak(), "markdown renderer")
	noCommit := flag.Bool("no-commit", false, "do not commit posts to the state dir's git")
	flag.Parse()

	if *state == "" || *port == 0 || *origin == "" {
		log.Fatal("mataroa-console: --state, --port and --origin are required")
	}

	c := &config{
		state: *state, origin: strings.TrimRight(*origin, "/"), apiBase: *apiBase,
		blogURL: *blogURL, comrak: *comrak, commit: !*noCommit, token: token(),
	}
	if _, err := c.postsDir(); err != nil {
		log.Fatalf("mataroa-console: state dir: %v", err)
	}

	addr := net.JoinHostPort("127.0.0.1", strconv.Itoa(*port))
	srv := &http.Server{Addr: addr, Handler: c, ReadHeaderTimeout: 10 * time.Second}
	stop := make(chan os.Signal, 1)
	signal.Notify(stop, syscall.SIGTERM, syscall.SIGINT)
	go func() {
		<-stop
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		srv.Shutdown(ctx)
	}()

	rendered := "missing"
	if c.comrak != "" {
		rendered = c.comrak
	}
	loaded := "MISSING"
	if c.token != "" {
		loaded = "loaded"
	}
	log.Printf("mataroa-console: http://%s · state %s · token %s · comrak %s", addr, c.state, loaded, rendered)
	if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
		log.Fatal(err)
	}
}

// token reads LoadCredential first and the environment second: the credential
// directory is the path the unit declares, and the env fallback is for a shell.
func lookComrak() string {
	path, err := exec.LookPath("comrak")
	if err != nil {
		return ""
	}
	return path
}

func token() string {
	if dir := os.Getenv("CREDENTIALS_DIRECTORY"); dir != "" {
		if raw, err := os.ReadFile(filepath.Join(dir, "mataroa-token")); err == nil {
			return strings.TrimSpace(string(raw))
		}
	}
	return strings.TrimSpace(os.Getenv("MATAROA_TOKEN"))
}

func (c *config) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	path, err := url.PathUnescape(r.URL.EscapedPath())
	if err != nil {
		path = r.URL.Path
	}
	if err := c.route(w, r, path); err != nil {
		var rejection refused
		status, message := 500, err.Error()
		if errors.As(err, &rejection) {
			status, message = rejection.status, rejection.msg
		} else {
			log.Printf("mataroa-console: %T: %v", err, err)
		}
		// The JSON surfaces answer JSON; a page answers a page, because a
		// browser posting a form cannot read JSON.
		if strings.HasPrefix(path, "/api/") || r.Method == "PUT" || r.Method == "DELETE" {
			c.writeJSON(w, status, map[string]any{"ok": false, "error": message})
			return
		}
		body := `<h1>` + strconv.Itoa(status) + `</h1><p class="err">` + esc(message) + `</p>`
		c.writeBody(w, status, c.page("error", body), "text/html; charset=utf-8")
	}
}

func (c *config) route(w http.ResponseWriter, r *http.Request, path string) error {
	method := r.Method

	switch {
	case method == "GET" && path == "/":
		c.writeBody(w, 200, c.ledgerPage(c.ledger(false)), "text/html; charset=utf-8")
		return nil
	case method == "GET" && path == "/api/state":
		data := c.ledger(true)
		c.writeJSON(w, 200, map[string]any{
			"ok": true, "posts": data.Posts, "error": data.Error, "remote_count": data.RemoteCount,
		})
		return nil
	case method == "GET" && strings.HasPrefix(path, "/api/post/"):
		current, err := c.readPost(lastSegment(path))
		if err != nil {
			return err
		}
		c.writeJSON(w, 200, map[string]any{"ok": true, "post": current})
		return nil
	case method == "GET" && strings.HasPrefix(path, "/p/"):
		current, err := c.readPost(strings.TrimPrefix(path, "/p/"))
		if err != nil {
			return err
		}
		c.writeBody(w, 200, c.postPage(current), "text/html; charset=utf-8")
		return nil
	case method == "GET" && strings.HasPrefix(path, "/e/"):
		slug := strings.TrimPrefix(path, "/e/")
		if slug == "new" {
			c.writeBody(w, 200, c.editorPage(nil, slug), "text/html; charset=utf-8")
			return nil
		}
		current, err := c.readPost(slug)
		if err != nil {
			return err
		}
		c.writeBody(w, 200, c.editorPage(&current, slug), "text/html; charset=utf-8")
		return nil

	case method == "PUT" && strings.HasPrefix(path, "/api/post/"):
		if err := c.guardWrite(r); err != nil {
			return err
		}
		slug := lastSegment(path)
		body, err := c.jsonBody(r)
		if err != nil {
			return err
		}
		title := stringField(body, "title")
		if title == "" {
			title = slug
		}
		saved, err := c.writePost(slug, title, stringField(body, "body"), stringField(body, "published_at"))
		if err != nil {
			return err
		}
		c.writeJSON(w, 200, map[string]any{"ok": true, "post": saved})
		return nil

	case method == "POST" && strings.HasPrefix(path, "/api/publish/"):
		if err := c.guardWrite(r); err != nil {
			return err
		}
		body, err := c.jsonBody(r)
		if err != nil {
			return err
		}
		var when *string
		if value, ok := body["published_at"]; ok {
			text, _ := value.(string)
			when = &text
		}
		result, err := c.publish(lastSegment(path), when)
		if err != nil {
			return err
		}
		result["ok"] = true
		c.writeJSON(w, 200, result)
		return nil

	case method == "POST" && strings.HasPrefix(path, "/api/unpublish/"):
		if err := c.guardWrite(r); err != nil {
			return err
		}
		result, err := c.unpublish(lastSegment(path))
		if err != nil {
			return err
		}
		result["ok"] = true
		c.writeJSON(w, 200, result)
		return nil

	case method == "POST" && path == "/api/pull":
		if err := c.guardWrite(r); err != nil {
			return err
		}
		result, err := c.pull()
		if err != nil {
			return err
		}
		result["ok"] = true
		c.writeJSON(w, 200, result)
		return nil

	case method == "DELETE" && strings.HasPrefix(path, "/api/post/"):
		if err := c.guardWrite(r); err != nil {
			return err
		}
		file, err := c.postPath(lastSegment(path))
		if err != nil {
			return err
		}
		os.Remove(file)
		c.gitCommit("delete a local post")
		c.writeJSON(w, 200, map[string]any{"ok": true})
		return nil

	case method == "POST" && (path == "/save" || path == "/publish" || path == "/unpublish" || path == "/pull"):
		if err := c.guardForm(r); err != nil {
			return err
		}
		fields, err := c.form(r)
		if err != nil {
			return err
		}
		if path == "/pull" {
			result, err := c.pull()
			if err != nil {
				return err
			}
			imported, _ := result["imported"].([]string)
			c.redirect(w, "/?pulled="+strings.Join(imported, ","))
			return nil
		}
		slug := fields.Get("slug")
		if slug == "new" {
			slug = ""
		}
		if path == "/save" || path == "/publish" {
			title := fields.Get("title")
			if title == "" {
				title = "untitled"
			}
			published := fields.Get("published_at")
			saved, err := c.writePost(slug, title, fields.Get("body"), published)
			if err != nil {
				return err
			}
			slug = saved.Slug
			if path == "/publish" {
				if _, err := c.publish(slug, &published); err != nil {
					return err
				}
			}
		} else if path == "/unpublish" {
			if _, err := c.unpublish(slug); err != nil {
				return err
			}
		}
		c.redirect(w, "/e/"+url.PathEscape(slug))
		return nil

	default:
		return refuse(404, "no route for %s %s", method, path)
	}
}

// guardWrite is the curl path: an explicit header, plus the origin when one is
// sent.
func (c *config) guardWrite(r *http.Request) error {
	if r.Header.Get("X-Mataroa-Write") != "1" {
		return refuse(403, "writes need X-Mataroa-Write: 1")
	}
	if origin := r.Header.Get("Origin"); origin != "" && origin != c.origin {
		return refuse(403, "origin %s is not %s", origin, c.origin)
	}
	return nil
}

// guardForm is the browser path: a form cannot set a header, so the Origin is
// the guard. Browsers send Origin on every form POST, so a page on another site
// cannot post here; a request with no Origin at all is not a browser form, and
// the documented scriptable path is the JSON API next to it.
func (c *config) guardForm(r *http.Request) error {
	if r.Header.Get("Origin") != c.origin {
		return refuse(403, "form posts must come from the console's own origin")
	}
	return nil
}

func (c *config) bodyBytes(r *http.Request) ([]byte, error) {
	length := r.ContentLength
	if length > maxBody*2 || length < 0 {
		return nil, refuse(413, "request body too large")
	}
	if length == 0 {
		return nil, nil
	}
	return io.ReadAll(io.LimitReader(r.Body, maxBody*2))
}

func (c *config) jsonBody(r *http.Request) (map[string]any, error) {
	raw, err := c.bodyBytes(r)
	if err != nil {
		return nil, err
	}
	if len(raw) == 0 {
		return map[string]any{}, nil
	}
	var decoded any
	decoder := json.NewDecoder(strings.NewReader(string(raw)))
	decoder.UseNumber()
	if err := decoder.Decode(&decoded); err != nil {
		return nil, refuse(400, "body is not JSON")
	}
	body, ok := decoded.(map[string]any)
	if !ok {
		return nil, refuse(400, "body must be a JSON object")
	}
	return body, nil
}

func (c *config) form(r *http.Request) (url.Values, error) {
	raw, err := c.bodyBytes(r)
	if err != nil {
		return nil, err
	}
	fields, err := url.ParseQuery(string(raw))
	if err != nil {
		return nil, refuse(400, "body is not a form")
	}
	return fields, nil
}

func lastSegment(path string) string {
	if i := strings.LastIndex(path, "/"); i >= 0 {
		return path[i+1:]
	}
	return path
}

func stringField(body map[string]any, key string) string {
	switch value := body[key].(type) {
	case nil:
		return ""
	case string:
		return value
	case json.Number:
		return value.String()
	default:
		return fmt.Sprint(value)
	}
}

func (c *config) writeBody(w http.ResponseWriter, status int, payload []byte, ctype string) {
	w.Header().Set("Content-Type", ctype)
	w.Header().Set("Content-Length", strconv.Itoa(len(payload)))
	w.Header().Set("Cache-Control", "no-store")
	w.WriteHeader(status)
	w.Write(payload)
}

func (c *config) writeJSON(w http.ResponseWriter, status int, value map[string]any) {
	payload, err := json.MarshalIndent(value, "", " ")
	if err != nil {
		http.Error(w, "encoding failed", http.StatusInternalServerError)
		return
	}
	c.writeBody(w, status, payload, "application/json")
}

func (c *config) redirect(w http.ResponseWriter, location string) {
	w.Header().Set("Location", location)
	w.Header().Set("Content-Length", "0")
	w.WriteHeader(http.StatusSeeOther)
}
