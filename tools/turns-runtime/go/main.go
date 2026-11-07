// The read path of the turns dashboard in Go, standard library only: static
// files, one history frame per connection, and a fan-out of new turns to every
// open stream. This is the shape the shipped service already has, kept minimal
// so the three prototypes do the same work and only the runtime differs.
package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"time"
)

type turn struct {
	ID      string `json:"id"`
	Source  string `json:"source"`
	Subject string `json:"subject"`
	Action  string `json:"action"`
	When    string `json:"when"`
	Branch  string `json:"branch"`
	Commit  string `json:"commit"`
}

var (
	site    string
	history []byte
	turns   []turn
	seq     atomic.Uint64

	mu   sync.RWMutex
	subs = map[uint64]chan string{}
	next atomic.Uint64
)

func esc(s string) string {
	r := strings.NewReplacer("&", "&amp;", "<", "&lt;", ">", "&gt;", `"`, "&quot;")
	return r.Replace(s)
}

func row(t turn) string {
	var b strings.Builder
	b.WriteString(`<article class="turn" id="turn-` + esc(t.ID) + `">`)
	b.WriteString(`<div class="shard" aria-hidden="true"></div><header class="head">`)
	b.WriteString(`<span class="out done">done</span><span class="src">` + esc(t.Source) + `</span>`)
	b.WriteString(`<span class="when">` + esc(t.When) + `</span></header>`)
	b.WriteString(`<h2 class="subject">` + esc(t.Subject) + `</h2>`)
	b.WriteString(`<p class="action">` + esc(t.Action) + `</p>`)
	b.WriteString(`<div class="meta">`)
	if t.Branch != "" {
		b.WriteString(`<span class="tag">branch ` + esc(t.Branch) + `</span>`)
	}
	if t.Commit != "" {
		b.WriteString(`<span class="tag">base ` + esc(t.Commit) + `</span>`)
	}
	b.WriteString(`</div><div class="req"></div></article>`)
	return b.String()
}

func historyFrame() []byte {
	return []byte("event: patch\ndata: selector #log\ndata: mode inner\ndata: elements " + string(history) + "\n\n")
}

func static(name string) http.HandlerFunc {
	body, err := os.ReadFile(filepath.Join(site, name))
	if err != nil {
		log.Fatalf("site: %v", err)
	}
	ctype := map[string]string{".css": "text/css", ".js": "text/javascript"}[filepath.Ext(name)]
	if ctype == "" {
		ctype = "text/html; charset=utf-8"
	}
	return func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", ctype)
		w.Header().Set("Cache-Control", "no-cache")
		_, _ = w.Write(body)
	}
}

func stream(w http.ResponseWriter, r *http.Request) {
	f, ok := w.(http.Flusher)
	if !ok {
		http.Error(w, "no flusher", 500)
		return
	}
	w.Header().Set("Content-Type", "text/event-stream")
	w.Header().Set("Cache-Control", "no-cache")
	w.Header().Set("Connection", "keep-alive")

	id := next.Add(1)
	ch := make(chan string, 64)
	mu.Lock()
	subs[id] = ch
	mu.Unlock()
	defer func() {
		mu.Lock()
		delete(subs, id)
		mu.Unlock()
	}()

	if _, err := w.Write(historyFrame()); err != nil {
		return
	}
	f.Flush()

	for {
		select {
		case frame := <-ch:
			if _, err := w.Write([]byte(frame)); err != nil {
				return
			}
			f.Flush()
		case <-r.Context().Done():
			return
		}
	}
}

// bench-only: publish one turn the way the shim relay would, so the harness can
// measure the fan-out without an upstream in the path.
func broadcast(w http.ResponseWriter, r *http.Request) {
	n := seq.Add(1)
	t := turns[int(n)%len(turns)]
	frame := fmt.Sprintf("event: patch\ndata: selector #log\ndata: mode prepend\ndata: elements %s\n: bench %d %d\n\n",
		row(t), n, time.Now().UnixMilli())
	mu.RLock()
	for _, ch := range subs {
		select {
		case ch <- frame:
		default: // a stalled reader must not stall the publisher
		}
	}
	mu.RUnlock()
	w.Header().Set("Content-Type", "application/json")
	fmt.Fprintf(w, `{"seq":%d,"clients":%d}`, n, len(subs))
}

func main() {
	addr := flag.String("addr", "127.0.0.1:9100", "listen address")
	siteDir := flag.String("site", "modules/services/turns-dashboard/web", "static site")
	fixture := flag.String("fixture", "fixture/turns.json", "turns fixture")
	flag.Parse()
	site = *siteDir

	body, err := os.ReadFile(*fixture)
	if err != nil {
		log.Fatalf("fixture: %v", err)
	}
	if err := json.Unmarshal(body, &turns); err != nil {
		log.Fatalf("fixture: %v", err)
	}
	var h strings.Builder
	for _, t := range turns {
		h.WriteString(row(t))
	}
	history = []byte(h.String())
	log.Printf("turns-runtime go: %s, %d turns, %d bytes of history", *addr, len(turns), len(history))

	mux := http.NewServeMux()
	mux.HandleFunc("/", static("index.html"))
	mux.HandleFunc("/style.css", static("style.css"))
	mux.HandleFunc("/app.js", static("app.js"))
	mux.HandleFunc("/api/stream", stream)
	mux.HandleFunc("/api/broadcast", broadcast)
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
		_, _ = w.Write([]byte(strconv.Itoa(len(turns))))
	})
	log.Fatal(http.ListenAndServe(*addr, mux))
}
