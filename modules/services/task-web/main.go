// task-web: the nixconfig Taskfile surface as a tailnet page — browse the
// whole `task --list-all` catalog, fuzzy-find a recipe, run it on this host
// and stream the output. Tailnet membership is the entire auth model by
// design: POST /api/run and /api/shell execute as the login user with no
// second gate. The process therefore listens on loopback only; the single
// way out is services.servicePortal.mounts (tailscale serve).
package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"os/exec"
	"regexp"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"
)

var (
	addr    = flag.String("addr", "127.0.0.1:8490", "loopback listen address")
	repo    = flag.String("repo", ".", "nixconfig checkout tasks run in")
	site    = flag.String("site", "web", "static asset directory")
	taskBin = flag.String("task-bin", "task", "go-task binary")
	maxConc = flag.Int("max-concurrent", 8, "concurrent run cap")
)

// maxBuf caps a run's replayable output; past it we stop recording (the
// process keeps going) and append a marker — a 700-task fleet has runs no
// browser wants in full.
const maxBuf = 1 << 20

type run struct {
	id      string
	cmd     string
	started time.Time
	done    bool
	exit    int
	pgid    int

	mu     sync.Mutex
	buf    []byte
	notify chan struct{}
}

var (
	runsMu sync.Mutex
	runs   = map[string]*run{}
	order  []string
	active int
)

var (
	taskName = regexp.MustCompile(`^[A-Za-z0-9][A-Za-z0-9:_/-]{0,79}$`)
	argOK    = regexp.MustCompile(`^[A-Za-z0-9_./:+*@%=-]{1,160}$`)
)

func (r *run) append(p []byte) {
	r.mu.Lock()
	defer r.mu.Unlock()
	if len(r.buf) < maxBuf {
		room := maxBuf - len(r.buf)
		if len(p) > room {
			p = p[:room]
		}
		r.buf = append(r.buf, p...)
		if len(r.buf) == maxBuf {
			r.buf = append(r.buf, []byte("\n[… output capped at 1MiB]\n")...)
		}
	}
	close(r.notify)
	r.notify = make(chan struct{})
}

func (r *run) finish(code int) {
	r.mu.Lock()
	r.done = true
	r.exit = code
	close(r.notify)
	r.notify = make(chan struct{})
	r.mu.Unlock()
	runsMu.Lock()
	active--
	runsMu.Unlock()
}

func startRun(bin string, argv []string, label string) (*run, error) {
	runsMu.Lock()
	if active >= *maxConc {
		runsMu.Unlock()
		return nil, fmt.Errorf("concurrency cap %d reached", *maxConc)
	}
	active++
	id := fmt.Sprintf("%d-%02d", time.Now().Unix(), len(order)+1)
	r := &run{id: id, cmd: label, started: time.Now(), notify: make(chan struct{}), exit: -1}
	runs[id] = r
	order = append(order, id)
	for len(order) > 50 {
		old := order[0]
		order = order[1:]
		if o := runs[old]; o != nil && o.done {
			delete(runs, old)
			continue
		}
		order = append(order, old)
		break
	}
	runsMu.Unlock()

	ctx, cancel := context.WithTimeout(context.Background(), 4*time.Hour)
	cmd := exec.CommandContext(ctx, bin, argv...)
	cmd.Dir = *repo
	cmd.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}
	pr, pw := io.Pipe()
	cmd.Stdout = pw
	cmd.Stderr = pw
	if err := cmd.Start(); err != nil {
		cancel()
		pw.Close()
		r.finish(-1)
		return nil, err
	}
	r.pgid = cmd.Process.Pid

	go func() {
		buf := make([]byte, 4096)
		for {
			n, err := pr.Read(buf)
			if n > 0 {
				r.append(buf[:n])
			}
			if err != nil {
				return
			}
		}
	}()
	go func() {
		err := cmd.Wait()
		pw.Close()
		cancel()
		code := 0
		if ee, ok := err.(*exec.ExitError); ok {
			code = ee.ExitCode()
		} else if err != nil {
			code = -1
		}
		r.finish(code)
	}()
	return r, nil
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(v)
}

// --- task catalog (cached proxy of `task --list-all --json`) ----------------

var (
	catMu   sync.Mutex
	catBody []byte
	catAt   time.Time
	catErr  string
)

func tasksHandler(w http.ResponseWriter, r *http.Request) {
	catMu.Lock()
	defer catMu.Unlock()
	if time.Since(catAt) > 15*time.Second {
		ctx, cancel := context.WithTimeout(r.Context(), 20*time.Second)
		c := exec.CommandContext(ctx, *taskBin, "--list-all", "--json")
		c.Dir = *repo
		out, err := c.CombinedOutput()
		cancel()
		if err == nil {
			catBody, catErr = out, ""
		} else {
			catErr = string(out)
		}
		catAt = time.Now()
	}
	if catErr != "" && catBody == nil {
		writeJSON(w, http.StatusBadGateway, map[string]string{"error": catErr})
		return
	}
	w.Header().Set("Content-Type", "application/json")
	w.Write(catBody)
}

// --- runs -------------------------------------------------------------------

type runReq struct {
	Task string   `json:"task"`
	Args []string `json:"args"`
}

type shellReq struct {
	Cmd string `json:"cmd"`
}

func runHandler(w http.ResponseWriter, r *http.Request) {
	var q runReq
	if err := json.NewDecoder(r.Body).Decode(&q); err != nil {
		writeJSON(w, 400, map[string]string{"error": "bad json"})
		return
	}
	if !taskName.MatchString(q.Task) {
		writeJSON(w, 400, map[string]string{"error": "task name rejected"})
		return
	}
	if len(q.Args) > 8 {
		writeJSON(w, 400, map[string]string{"error": "too many args"})
		return
	}
	for _, a := range q.Args {
		if !argOK.MatchString(a) {
			writeJSON(w, 400, map[string]string{"error": "arg rejected: " + a})
			return
		}
	}
	argv := append([]string{q.Task}, q.Args...)
	label := *taskBin + " " + strings.Join(argv, " ")
	rn, err := startRun(*taskBin, argv, label)
	if err != nil {
		writeJSON(w, 429, map[string]string{"error": err.Error()})
		return
	}
	writeJSON(w, 200, map[string]string{"id": rn.id})
}

func shellHandler(w http.ResponseWriter, r *http.Request) {
	var q shellReq
	if err := json.NewDecoder(r.Body).Decode(&q); err != nil {
		writeJSON(w, 400, map[string]string{"error": "bad json"})
		return
	}
	q.Cmd = strings.TrimSpace(q.Cmd)
	if q.Cmd == "" || len(q.Cmd) > 4000 {
		writeJSON(w, 400, map[string]string{"error": "empty or oversized cmd"})
		return
	}
	rn, err := startRun("bash", []string{"-lc", q.Cmd}, "$ "+q.Cmd)
	if err != nil {
		writeJSON(w, 429, map[string]string{"error": err.Error()})
		return
	}
	writeJSON(w, 200, map[string]string{"id": rn.id})
}

func runsHandler(w http.ResponseWriter, r *http.Request) {
	runsMu.Lock()
	out := make([]map[string]any, 0, len(order))
	for i := len(order) - 1; i >= 0; i-- {
		rn := runs[order[i]]
		if rn == nil {
			continue
		}
		rn.mu.Lock()
		out = append(out, map[string]any{
			"id": rn.id, "cmd": rn.cmd, "started": rn.started.Unix(),
			"done": rn.done, "exit": rn.exit,
		})
		rn.mu.Unlock()
	}
	runsMu.Unlock()
	writeJSON(w, 200, map[string]any{"runs": out})
}

func findRun(id string) *run {
	runsMu.Lock()
	defer runsMu.Unlock()
	return runs[id]
}

func eventsHandler(w http.ResponseWriter, r *http.Request, id string) {
	rn := findRun(id)
	if rn == nil {
		http.Error(w, "no such run", 404)
		return
	}
	w.Header().Set("Content-Type", "text/event-stream")
	w.Header().Set("Cache-Control", "no-cache")
	fl, ok := w.(http.Flusher)
	if !ok {
		http.Error(w, "streaming unsupported", 500)
		return
	}
	off := 0
	for {
		rn.mu.Lock()
		n, done, code, ch := len(rn.buf), rn.done, rn.exit, rn.notify
		var chunk []byte
		if n > off {
			chunk = append([]byte(nil), rn.buf[off:n]...)
		}
		rn.mu.Unlock()
		if chunk != nil {
			fmt.Fprintf(w, "data: %s\n\n", strconv.Quote(string(chunk)))
			off = n
			fl.Flush()
		}
		if done {
			fmt.Fprintf(w, "event: done\ndata: {\"exit\":%d}\n\n", code)
			fl.Flush()
			return
		}
		select {
		case <-r.Context().Done():
			return
		case <-ch:
		}
	}
}

func killHandler(w http.ResponseWriter, r *http.Request, id string) {
	rn := findRun(id)
	if rn == nil {
		http.Error(w, "no such run", 404)
		return
	}
	rn.mu.Lock()
	dead, pg := rn.done, rn.pgid
	rn.mu.Unlock()
	if dead {
		writeJSON(w, 200, map[string]string{"status": "already finished"})
		return
	}
	if err := syscall.Kill(-pg, syscall.SIGKILL); err != nil {
		writeJSON(w, 500, map[string]string{"error": err.Error()})
		return
	}
	writeJSON(w, 200, map[string]string{"status": "killed"})
}

// --- dashboard --------------------------------------------------------------

func quickOut(secs int, name string, args ...string) string {
	ctx, cancel := context.WithTimeout(context.Background(), time.Duration(secs)*time.Second)
	defer cancel()
	// Non-zero exit still returns captured stdout — `systemctl
	// is-system-running` exits 1 with "degraded" on it, and that word is the
	// answer, not an error.
	out, _ := exec.CommandContext(ctx, name, args...).Output()
	return strings.TrimSpace(strings.SplitN(string(out), "\n", 2)[0])
}

func fieldOf(path string, want string) float64 {
	b, err := os.ReadFile(path)
	if err != nil {
		return 0
	}
	for _, ln := range strings.Split(string(b), "\n") {
		if strings.HasPrefix(ln, want) {
			f := strings.Fields(ln)
			if len(f) >= 2 {
				v, _ := strconv.ParseFloat(f[1], 64)
				return v
			}
		}
	}
	return 0
}

func dashHandler(w http.ResponseWriter, r *http.Request) {
	var st syscall.Statfs_t
	disk := 0.0
	if syscall.Statfs("/", &st) == nil && st.Blocks > 0 {
		disk = 100 * (1 - float64(st.Bavail)/float64(st.Blocks))
	}
	gen := ""
	if fi, err := os.Lstat("/run/current-system"); err == nil {
		gen = fi.ModTime().UTC().Format(time.RFC3339)
	}
	uptime := 0.0
	if b, err := os.ReadFile("/proc/uptime"); err == nil {
		if f := strings.Fields(string(b)); len(f) > 0 {
			uptime, _ = strconv.ParseFloat(f[0], 64)
		}
	}
	writeJSON(w, 200, map[string]any{
		"state":      quickOut(3, "systemctl", "is-system-running"),
		"load":       strings.Fields(strings.TrimSpace(func() string { b, _ := os.ReadFile("/proc/loadavg"); return string(b) }())),
		"memTotal":   fieldOf("/proc/meminfo", "MemTotal:"),
		"memAvail":   fieldOf("/proc/meminfo", "MemAvailable:"),
		"diskRoot":   disk,
		"generation": gen,
		"uptime":     uptime,
		"lanes":      quickOut(2, "tmux", "list-windows", "-a", "-F", "#{window_name} #{pane_current_command}"),
	})
}

// --- plumbing ---------------------------------------------------------------

func api(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("X-Content-Type-Options", "nosniff")
	w.Header().Set("Cache-Control", "no-store")
	switch {
	case r.URL.Path == "/api/tasks" && r.Method == http.MethodGet:
		tasksHandler(w, r)
	case r.URL.Path == "/api/run" && r.Method == http.MethodPost:
		runHandler(w, r)
	case r.URL.Path == "/api/shell" && r.Method == http.MethodPost:
		shellHandler(w, r)
	case r.URL.Path == "/api/runs" && r.Method == http.MethodGet:
		runsHandler(w, r)
	case r.URL.Path == "/api/dash" && r.Method == http.MethodGet:
		dashHandler(w, r)
	case strings.HasPrefix(r.URL.Path, "/api/runs/") && r.Method == http.MethodGet:
		eventsHandler(w, r, strings.TrimSuffix(strings.TrimPrefix(r.URL.Path, "/api/runs/"), "/events"))
	case strings.HasPrefix(r.URL.Path, "/api/kill/") && r.Method == http.MethodPost:
		killHandler(w, r, strings.TrimPrefix(r.URL.Path, "/api/kill/"))
	default:
		http.NotFound(w, r)
	}
}

func main() {
	flag.Parse()
	mux := http.NewServeMux()
	mux.HandleFunc("/api/", api)
	mux.Handle("/", http.FileServer(http.Dir(*site)))
	log.Printf("task-web: %s (repo=%s) — tailnet is the auth model, loopback only", *addr, *repo)
	log.Fatal(http.ListenAndServe(*addr, mux))
}
