// turns-dashboard: a live reading surface over the agent-turn store. It reads
// the xs store through the authenticated shim, renders each turn once, and
// pushes it to every open browser as a Datastar SSE patch. A turn can carry a
// prompt for Hermes; the reply lands in that row, never in a page reload.
package main

import (
	"bufio"
	"context"
	"embed"
	"encoding/json"
	"flag"
	"fmt"
	"html/template"
	"io"
	"log"
	"net/http"
	"os"
	"os/exec"
	"regexp"
	"strings"
	"sync"
	"time"
)

//go:embed web/row.html.tmpl
var templates embed.FS

type turn struct {
	ID           string   `json:"id"`
	TS           string   `json:"ts"`
	Source       string   `json:"source"`
	Kind         string   `json:"kind"`
	Subject      string   `json:"subject"`
	Action       string   `json:"action"`
	Outcome      string   `json:"outcome"`
	Rationale    *string  `json:"rationale"`
	BaseCommit   *string  `json:"base_commit"`
	Branch       *string  `json:"branch"`
	FilesChanged []string `json:"files_changed"`
	Commits      []string `json:"commits"`
	Claims       []string `json:"claims"`
}

type envelope struct {
	Count  int    `json:"count"`
	Events []turn `json:"events"`
}

type rowView struct {
	turn
	When         string
	OutcomeClass string
	Rationale    string
	Files        []string
	FilesMore    int
	Branch       string
	Commit       string
}

type promptRequest struct {
	Row    string `json:"row"`
	Prompt string `json:"prompt"`
}

type promptRecord struct {
	TS      string `json:"ts"`
	Row     string `json:"row"`
	Prompt  string `json:"prompt"`
	Status  string `json:"status"`
	Output  string `json:"output,omitempty"`
	Seconds int    `json:"seconds,omitempty"`
}

type server struct {
	shim       string
	token      string
	limit      int
	hermes     string
	hermesHome string
	promptLog  string
	site       string
	row        *template.Template

	// One lock for the log: the poller is the only writer, and a stream handler
	// takes a snapshot and subscribes in the same critical section so a turn
	// that lands between the two is neither missed nor sent twice.
	mu    sync.Mutex
	seen  map[string]bool
	turns map[string]turn
	rows  []rowView
	subs  map[chan string]bool

	slots chan struct{}
}

func main() {
	addr := flag.String("addr", "127.0.0.1:8099", "loopback address to listen on")
	shim := flag.String("shim", "http://127.0.0.1:8093", "base URL of the authenticated agent-turn shim")
	tokenFile := flag.String("token-file", "/run/secrets/agent-turns-token", "file holding the shim bearer token")
	limit := flag.Int("limit", 120, "turns rendered on connect")
	hermes := flag.String("hermes", "", "hermes binary for a row prompt; empty disables the prompt form")
	hermesHome := flag.String("hermes-home", "", "HOME for the hermes child, which reads its credentials there")
	promptLog := flag.String("prompt-log", "prompts.jsonl", "append-only record of prompts and their outcomes")
	site := flag.String("site", "", "directory holding index.html, style.css, app.js and datastar.js")
	flag.Parse()

	if *site == "" {
		log.Fatal("turns-dashboard: -site is required")
	}
	token, err := os.ReadFile(*tokenFile)
	if err != nil {
		log.Fatalf("turns-dashboard: reading the shim token: %v", err)
	}

	tmpl, err := template.ParseFS(templates, "web/row.html.tmpl")
	if err != nil {
		log.Fatalf("turns-dashboard: parsing the row template: %v", err)
	}

	s := &server{
		shim:       strings.TrimSuffix(*shim, "/"),
		token:      strings.TrimSpace(string(token)),
		limit:      *limit,
		hermes:     *hermes,
		hermesHome: *hermesHome,
		promptLog:  *promptLog,
		site:       *site,
		row:        tmpl,
		seen:       map[string]bool{},
		turns:      map[string]turn{},
		subs:       map[chan string]bool{},
		slots:      make(chan struct{}, 2),
	}

	mux := http.NewServeMux()
	mux.HandleFunc("GET /api/stream", s.stream)
	mux.HandleFunc("GET /api/prompts", s.prompts)
	mux.HandleFunc("POST /api/prompt", s.prompt)
	mux.HandleFunc("GET /api/health", func(w http.ResponseWriter, _ *http.Request) {
		io.WriteString(w, "ok\n")
	})
	mux.Handle("/", http.FileServer(http.Dir(*site)))

	go s.watch()
	log.Printf("turns-dashboard: %s, shim %s, hermes %q", *addr, s.shim, s.hermes)
	srv := &http.Server{Addr: *addr, Handler: mux, ReadHeaderTimeout: 10 * time.Second}
	log.Fatal(srv.ListenAndServe())
}

// poll reads the newest turns from the shim. The shim answers newest-first, so
// the walk stops at the first id already rendered and never re-sends history.
func (s *server) poll() ([]rowView, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	url := fmt.Sprintf("%s/v1/events?limit=%d", s.shim, 40)
	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("Authorization", "Bearer "+s.token)
	client := &http.Client{Timeout: 10 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(io.LimitReader(resp.Body, 200))
		return nil, fmt.Errorf("shim %s: %s", resp.Status, strings.TrimSpace(string(body)))
	}
	var env envelope
	if err := json.NewDecoder(resp.Body).Decode(&env); err != nil {
		return nil, err
	}

	var fresh []rowView
	for _, t := range env.Events {
		if s.seen[t.ID] {
			break
		}
		s.seen[t.ID] = true
		s.turns[t.ID] = t
		fresh = append(fresh, s.view(t))
	}
	// Newest first is both the render order on connect and the order a prompt's
	// context is looked up in; the patches go out reversed.
	s.rows = append(fresh, s.rows...)
	return fresh, nil
}

func (s *server) watch() {
	// A failure here is not fatal: the shim may start after this unit, and a
	// dashboard that exits on the first refused read never shows the reason.
	backoff := time.Second
	// Poll first, sleep after: a page opened during a quiet hour must not wait
	// for the first tick to learn that the log already has turns in it.
	for {
		fresh, err := s.poll()
		if err != nil {
			log.Printf("turns-dashboard: read: %v", err)
			time.Sleep(backoff)
			if backoff < 30*time.Second {
				backoff *= 2
			}
			continue
		}
		backoff = time.Second
		for i := len(fresh) - 1; i >= 0; i-- {
			html, err := s.render(fresh[i])
			if err != nil {
				log.Printf("turns-dashboard: render %s: %v", fresh[i].ID, err)
				continue
			}
			s.broadcast(patch("prepend", "#log", html))
		}
		time.Sleep(time.Second)
	}
}

func (s *server) render(v rowView) (string, error) {
	var b strings.Builder
	if err := s.row.Execute(&b, v); err != nil {
		return "", err
	}
	// A patch carries one `data:` line per element line, so the fragment must
	// not keep newlines of its own; collapsing whitespace would edit the text.
	return strings.ReplaceAll(strings.TrimSpace(b.String()), "\n", " "), nil
}

func (s *server) broadcast(chunk string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	for ch := range s.subs {
		select {
		case ch <- chunk:
		default: // a stalled client loses a frame, not the feed for everyone
		}
	}
}

// patch formats one element patch for web/app.js, which is the only reader of
// this format: every line of the HTML needs its own `data: elements` line, and
// the block ends with a blank line. It is deliberately plain text — the client
// parses it in forty lines and no library version can silently disagree with
// the writer.
func patch(mode, selector, html string) string {
	var b strings.Builder
	b.WriteString("event: patch\n")
	if selector != "" {
		fmt.Fprintf(&b, "data: selector %s\n", selector)
	}
	fmt.Fprintf(&b, "data: mode %s\n", mode)
	if html != "" {
		for _, line := range strings.Split(html, "\n") {
			fmt.Fprintf(&b, "data: elements %s\n", line)
		}
	}
	b.WriteString("\n")
	return b.String()
}

func (s *server) view(t turn) rowView {
	when := t.TS
	if parsed, err := time.Parse(time.RFC3339, t.TS); err == nil {
		when = parsed.Local().Format("02 Jan 15:04")
	}
	v := rowView{
		turn:         t,
		When:         when,
		OutcomeClass: outcomeClass(t.Outcome),
	}
	if t.Rationale != nil {
		v.Rationale = *t.Rationale
	}
	if t.Branch != nil {
		v.Branch = *t.Branch
	}
	if t.BaseCommit != nil && len(*t.BaseCommit) >= 7 {
		v.Commit = (*t.BaseCommit)[:7]
	}
	v.Files = t.FilesChanged
	if len(v.Files) > 5 {
		v.FilesMore = len(v.Files) - 5
		v.Files = v.Files[:5]
	}
	return v
}

func outcomeClass(outcome string) string {
	switch {
	case outcome == "done":
		return "done"
	case outcome == "in_progress", strings.HasPrefix(outcome, "blocked"):
		return "wait"
	default:
		return "bad"
	}
}

func (s *server) stream(w http.ResponseWriter, r *http.Request) {
	flusher, ok := w.(http.Flusher)
	if !ok {
		http.Error(w, "streaming unsupported", http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "text/event-stream")
	w.Header().Set("Cache-Control", "no-cache")
	w.Header().Set("Connection", "keep-alive")
	w.Header().Set("X-Accel-Buffering", "no")

	ch := make(chan string, 32)
	defer func() {
		s.mu.Lock()
		delete(s.subs, ch)
		s.mu.Unlock()
	}()

	// The whole history in one patch: the page is static and carries no turn
	// markup of its own, so the first frame is the entire log.
	var history []rowView
	s.mu.Lock()
	history = append(history, s.rows...)
	s.subs[ch] = true
	s.mu.Unlock()

	var b strings.Builder
	// Newest first, top of the DOM: a later turn arrives by prepend, so the
	// first paint must read the same way or the log jumps on the next event.
	for _, v := range history {
		html, err := s.render(v)
		if err != nil {
			continue
		}
		b.WriteString(html)
	}
	// An empty `elements` line is not a no-op to parse: it is a patch with no
	// fragment, and Datastar drops the stream after one. A reader that arrives
	// before the first poll therefore gets no frame here and keeps the page's
	// own placeholder until the first turn is prepended.
	if b.Len() > 0 {
		io.WriteString(w, patch("inner", "#log", b.String()))
		flusher.Flush()
	}

	ticker := time.NewTicker(15 * time.Second)
	defer ticker.Stop()
	waiting := b.Len() == 0
	for {
		select {
		case <-r.Context().Done():
			return
		case chunk := <-ch:
			// The page's placeholder is a child of #log, so a prepend would
			// leave it stranded at the bottom of a log that is no longer
			// empty. One remove, then never again on this connection.
			if waiting {
				io.WriteString(w, patch("remove", "#waiting", ""))
				waiting = false
			}
			io.WriteString(w, chunk)
			flusher.Flush()
		case <-ticker.C:
			// A comment keeps the connection alive through an idle proxy.
			io.WriteString(w, ": ping\n\n")
			flusher.Flush()
		}
	}
}

var rowPattern = regexp.MustCompile(`^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$`)

func (s *server) prompt(w http.ResponseWriter, r *http.Request) {
	var req promptRequest
	if err := json.NewDecoder(io.LimitReader(r.Body, 16<<10)).Decode(&req); err != nil {
		http.Error(w, "bad json", http.StatusBadRequest)
		return
	}
	req.Prompt = strings.TrimSpace(req.Prompt)
	if !rowPattern.MatchString(req.Row) || req.Prompt == "" || len(req.Prompt) > 4000 {
		http.Error(w, "row or prompt rejected", http.StatusBadRequest)
		return
	}
	if s.hermes == "" {
		http.Error(w, "no hermes configured on this host", http.StatusNotImplemented)
		return
	}

	w.Header().Set("Content-Type", "text/event-stream")
	w.Header().Set("Cache-Control", "no-cache")
	target := "#req-" + req.Row

	io.WriteString(w, patch("inner", target, `<span class="live">▸ dispatched</span>`))
	if f, ok := w.(http.Flusher); ok {
		f.Flush()
	}

	go s.runHermes(req)
}

// withContext is the per-row injection: the turn the reader is looking at
// travels with the instruction, the way a mail-atlas prompt carries its
// message. Without it the agent answers about nothing (measured 2026-11-06:
// "no specific task has been introduced yet").
func (s *server) withContext(id, instruction string) string {
	s.mu.Lock()
	t, ok := s.turns[id]
	s.mu.Unlock()
	if !ok {
		return instruction
	}

	var b strings.Builder
	b.WriteString("One turn from the fleet's agent-turn log (nixconfig).\n")
	fmt.Fprintf(&b, "subject: %s\nsource: %s\nrecorded: %s\noutcome: %s\n", t.Subject, t.Source, t.TS, t.Outcome)
	fmt.Fprintf(&b, "action: %s\n", t.Action)
	if t.Rationale != nil && *t.Rationale != "" {
		fmt.Fprintf(&b, "rationale: %s\n", *t.Rationale)
	}
	if t.Branch != nil && *t.Branch != "" {
		fmt.Fprintf(&b, "branch: %s\n", *t.Branch)
	}
	if t.BaseCommit != nil && *t.BaseCommit != "" {
		fmt.Fprintf(&b, "base commit: %s\n", *t.BaseCommit)
	}
	if len(t.FilesChanged) > 0 {
		fmt.Fprintf(&b, "files: %s\n", strings.Join(t.FilesChanged, ", "))
	}
	b.WriteString("\nAnswer about this turn, and say so plainly when the log does not contain what is asked.\n\ninstruction: ")
	b.WriteString(instruction)
	return b.String()
}

// runHermes is the same call the operator would type: one prompt, one agent
// turn, no shell. It runs as the dashboard's user because that is whose
// credentials Hermes reads, and its output is the row's answer.
func (s *server) runHermes(req promptRequest) {
	s.slots <- struct{}{}
	defer func() { <-s.slots }()

	start := time.Now()
	ctx, cancel := context.WithTimeout(context.Background(), 4*time.Minute)
	defer cancel()

	cmd := exec.CommandContext(ctx, s.hermes, "-z", s.withContext(req.Row, req.Prompt))
	cmd.Dir = workdir(s.hermesHome)
	if s.hermesHome != "" {
		cmd.Env = append(os.Environ(), "HOME="+s.hermesHome, "HERMES_HOME="+s.hermesHome+"/.hermes")
	}
	out, err := cmd.CombinedOutput()

	text := strings.TrimSpace(string(out))
	status := "done"
	if ctx.Err() == context.DeadlineExceeded {
		status, text = "timeout", "no answer within 4 minutes"
	} else if err != nil {
		status = "failed"
		if text == "" {
			text = err.Error()
		}
	}
	if len(text) > 4000 {
		text = text[:4000] + "\n… truncated"
	}
	secs := int(time.Since(start).Seconds())

	rec := promptRecord{
		TS:      time.Now().UTC().Format(time.RFC3339),
		Row:     req.Row,
		Prompt:  req.Prompt,
		Status:  status,
		Output:  text,
		Seconds: secs,
	}
	if err := appendJSONL(s.promptLog, rec); err != nil {
		log.Printf("turns-dashboard: prompt log: %v", err)
	}

	inner := fmt.Sprintf(
		`<div class="answer %s"><span class="stamp">hermes · %ds</span>%s</div>`,
		template.HTMLEscapeString(status),
		secs,
		strings.ReplaceAll(template.HTMLEscapeString(text), "\n", "<br>"),
	)
	s.broadcast(patch("inner", "#req-"+req.Row, inner))
}

func workdir(home string) string {
	if home == "" {
		return "."
	}
	return home
}

func appendJSONL(path string, rec promptRecord) error {
	f, err := os.OpenFile(path, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0o640)
	if err != nil {
		return err
	}
	defer f.Close()
	line, err := json.Marshal(rec)
	if err != nil {
		return err
	}
	w := bufio.NewWriter(f)
	w.Write(append(line, '\n'))
	if err := w.Flush(); err != nil {
		return err
	}
	return f.Sync()
}

// prompts is the machine surface: an agent can read what the page asked for and
// what came back, without scraping the DOM.
func (s *server) prompts(w http.ResponseWriter, _ *http.Request) {
	f, err := os.Open(s.promptLog)
	if err != nil {
		w.Header().Set("Content-Type", "application/json")
		io.WriteString(w, "[]\n")
		return
	}
	defer f.Close()
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	io.Copy(w, f)
}
