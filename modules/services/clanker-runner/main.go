package main

import (
	"context"
	"crypto/rand"
	"embed"
	"encoding/hex"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"
)

//go:embed web/*
var webFiles embed.FS

type server struct {
	store          *Store
	client         *instaboxClient
	adminToken     string
	expectedOrigin string
	started        time.Time
	jobs           chan struct{}
	pollInterval   time.Duration
}

type errorResponse struct {
	Error string `json:"error"`
}

func main() {
	addr := flag.String("addr", "127.0.0.1:8104", "loopback address to listen on")
	dbPath := flag.String("db", "clanker-runner.sqlite", "SQLite database path")
	envFile := flag.String("env-file", "", "optional KEY=VALUE file for credentials")
	instaboxBase := flag.String("instabox-url", "", "InstaBox API base URL; INSTABOX_API_URL is the fallback")
	adminTokenEnv := flag.String("admin-token-env", "CLANKER_RUNNER_ADMIN_TOKEN", "environment variable naming the optional write bearer token")
	expectedOrigin := flag.String("origin", "", "expected browser Origin for state-changing requests; empty disables the check")
	flag.Parse()

	if *envFile != "" {
		if err := loadEnvFile(*envFile); err != nil {
			log.Fatalf("clanker-runner: env file: %v", err)
		}
	}
	baseURL := *instaboxBase
	if baseURL == "" {
		baseURL = os.Getenv("INSTABOX_API_URL")
	}
	store, err := OpenStore(*dbPath)
	if err != nil {
		log.Fatalf("clanker-runner: open db: %v", err)
	}
	defer store.Close()
	s := &server{
		store:          store,
		client:         newInstaboxClient(baseURL, os.Getenv("INSTABOX_API_KEY")),
		adminToken:     strings.TrimSpace(os.Getenv(*adminTokenEnv)),
		expectedOrigin: strings.TrimRight(*expectedOrigin, "/"),
		started:        time.Now().UTC(),
		jobs:           make(chan struct{}, 3),
	}

	mux := http.NewServeMux()
	mux.HandleFunc("GET /", s.index)
	mux.HandleFunc("GET /index.html", s.index)
	mux.HandleFunc("GET /style.css", s.static("web/style.css", "text/css; charset=utf-8"))
	mux.HandleFunc("GET /app.js", s.static("web/app.js", "text/javascript; charset=utf-8"))
	mux.HandleFunc("GET /favicon.svg", s.static("web/favicon.svg", "image/svg+xml"))
	mux.HandleFunc("GET /api/health", s.health)
	mux.HandleFunc("GET /api/stats", s.stats)
	mux.HandleFunc("GET /api/machines", s.machines)
	mux.HandleFunc("GET /api/machines/{machine}", s.machine)
	mux.HandleFunc("POST /api/machines/{machine}/wake", s.wakeMachine)
	mux.HandleFunc("POST /api/machines/{machine}/exec", s.execMachine)
	mux.HandleFunc("GET /api/jobs", s.jobList)
	mux.HandleFunc("POST /api/jobs", s.createJob)
	mux.HandleFunc("GET /api/jobs/{id}", s.jobDetail)
	mux.HandleFunc("GET /api/jobs/{id}/artifacts", s.artifactList)
	mux.HandleFunc("GET /api/jobs/{id}/artifacts/{artifact_id}", s.artifactDownload)
	mux.HandleFunc("GET /api/presets", s.presetList)
	mux.HandleFunc("POST /api/presets/{id}/run", s.runPreset)
	mux.HandleFunc("GET /api/schedules", s.scheduleList)
	mux.HandleFunc("POST /api/schedules", s.createSchedule)
	mux.HandleFunc("DELETE /api/schedules/{id}", s.deleteSchedule)

	go s.scheduleLoop()

	log.Printf("clanker-runner: listening on %s, db %s, instabox_configured=%t", *addr, *dbPath, s.client.configured())
	if err := http.ListenAndServe(*addr, mux); err != nil {
		log.Fatalf("clanker-runner: %v", err)
	}
}

func loadEnvFile(path string) error {
	raw, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	for number, line := range strings.Split(string(raw), "\n") {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		key, value, ok := strings.Cut(line, "=")
		if !ok || strings.TrimSpace(key) == "" {
			return fmt.Errorf("line %d is not KEY=VALUE", number+1)
		}
		key = strings.TrimSpace(key)
		value = strings.Trim(strings.TrimSpace(value), `"'`)
		if os.Getenv(key) == "" {
			if err := os.Setenv(key, value); err != nil {
				return err
			}
		}
	}
	return nil
}

func writeJSON(w http.ResponseWriter, status int, value any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.Header().Set("Cache-Control", "no-store")
	w.WriteHeader(status)
	enc := json.NewEncoder(w)
	enc.SetIndent("", "  ")
	_ = enc.Encode(value)
}

func writeError(w http.ResponseWriter, status int, err error) {
	writeJSON(w, status, errorResponse{Error: err.Error()})
}

func (s *server) index(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != "/" && r.URL.Path != "/index.html" {
		http.NotFound(w, r)
		return
	}
	s.static("web/index.html", "text/html; charset=utf-8")(w, r)
}

func (s *server) static(path, contentType string) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		raw, err := webFiles.ReadFile(path)
		if err != nil {
			http.NotFound(w, r)
			return
		}
		w.Header().Set("Content-Type", contentType)
		w.Header().Set("Cache-Control", "no-store")
		_, _ = w.Write(raw)
	}
}

func (s *server) health(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, map[string]any{
		"ok": true, "service": "clanker-runner", "version": "0.3.0", "instabox_configured": s.client.configured(),
		"uptime_seconds": int(time.Since(s.started).Seconds()), "time": time.Now().UTC().Format(time.RFC3339),
	})
}

func (s *server) stats(w http.ResponseWriter, r *http.Request) {
	stats, err := s.store.Stats(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, stats)
}

func (s *server) machines(w http.ResponseWriter, r *http.Request) {
	machines, err := s.client.ListMachines(r.Context())
	if err != nil {
		writeError(w, http.StatusBadGateway, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": machines, "total": len(machines)})
}

func (s *server) machine(w http.ResponseWriter, r *http.Request) {
	machine, err := s.client.ResolveMachine(r.Context(), r.PathValue("machine"))
	if err != nil {
		writeError(w, http.StatusBadGateway, err)
		return
	}
	writeJSON(w, http.StatusOK, machine)
}

func (s *server) wakeMachine(w http.ResponseWriter, r *http.Request) {
	if !s.writeAllowed(w, r) {
		return
	}
	machine, err := s.client.ResolveMachine(r.Context(), r.PathValue("machine"))
	if err != nil {
		writeError(w, http.StatusBadGateway, err)
		return
	}
	if err := s.client.MachineAction(r.Context(), machine.ID, "wake"); err != nil {
		writeError(w, http.StatusBadGateway, err)
		return
	}
	writeJSON(w, http.StatusAccepted, map[string]any{"ok": true, "machine": machine, "action": "wake"})
}

func (s *server) execMachine(w http.ResponseWriter, r *http.Request) {
	if !s.writeAllowed(w, r) {
		return
	}
	var body struct {
		Command string `json:"command"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	if strings.TrimSpace(body.Command) == "" {
		writeError(w, http.StatusBadRequest, errors.New("command is required"))
		return
	}
	machine, err := s.client.ResolveMachine(r.Context(), r.PathValue("machine"))
	if err != nil {
		writeError(w, http.StatusBadGateway, err)
		return
	}
	result, err := s.client.Exec(r.Context(), machine.ID, body.Command)
	if err != nil {
		writeError(w, http.StatusBadGateway, err)
		return
	}
	writeJSON(w, http.StatusOK, result)
}

func (s *server) jobList(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query()
	limit, _ := strconv.Atoi(q.Get("limit"))
	offset, _ := strconv.Atoi(q.Get("offset"))
	page, err := s.store.QueryJobs(r.Context(), queryOptions{Q: q.Get("q"), Machine: q.Get("machine"), Kind: q.Get("kind"), Status: q.Get("status"), Limit: limit, Offset: offset})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, page)
}

func shellQuote(value string) string {
	return "'" + strings.ReplaceAll(value, "'", "'\\''") + "'"
}

func buildJobCommand(input jobInput) (string, string, error) {
	kind := strings.TrimSpace(strings.ToLower(input.Kind))
	if kind == "" {
		kind = "shell"
	}
	switch kind {
	case "shell", "exec":
		kind = "shell"
		if strings.TrimSpace(input.Command) == "" {
			return "", "", errors.New("shell jobs require command")
		}
		return kind, strings.TrimSpace(input.Command), nil
	case "nix":
		attr := strings.TrimSpace(input.Attr)
		if attr == "" {
			attr = strings.TrimSpace(input.Command)
		}
		if attr == "" {
			return "", "", errors.New("nix jobs require attr")
		}
		command := `set -euo pipefail
export PATH="$HOME/.nix-profile/bin:$PATH"
if [ -d /data/nixconfig ]; then cd /data/nixconfig; fi
nix build -L ` + shellQuote(attr) + ` --no-link`
		if extra := strings.TrimSpace(input.Args); extra != "" {
			command += " " + extra
		}
		return kind, command, nil
	case "agent-browser":
		args := strings.TrimSpace(input.Args)
		if args == "" {
			args = strings.TrimSpace(input.Command)
		}
		if args == "" {
			return "", "", errors.New("agent-browser jobs require args")
		}
		return kind, `export PATH="$HOME/.nix-profile/bin:$PATH"
agent-browser ` + args, nil
	default:
		return "", "", fmt.Errorf("unsupported job kind %q", input.Kind)
	}
}

func newJobID() string {
	raw := make([]byte, 8)
	if _, err := rand.Read(raw); err != nil {
		return fmt.Sprintf("job-%d", time.Now().UnixNano())
	}
	return "job-" + hex.EncodeToString(raw)
}

func (s *server) createJob(w http.ResponseWriter, r *http.Request) {
	if !s.writeAllowed(w, r) {
		return
	}
	var input jobInput
	if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	kind, command, err := buildJobCommand(input)
	if err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	machineName := strings.TrimSpace(input.Machine)
	if machineName == "" {
		machineName = "clanker"
	}
	machine, err := s.client.ResolveMachine(r.Context(), machineName)
	if err != nil {
		writeError(w, http.StatusBadGateway, err)
		return
	}
	job, err := s.queuePreparedJob(r.Context(), machine, kind, command, machineName)
	if err != nil {
		if errors.Is(err, errRunnerBusy) {
			writeError(w, http.StatusTooManyRequests, err)
		} else {
			writeError(w, http.StatusInternalServerError, err)
		}
		return
	}
	writeJSON(w, http.StatusAccepted, job)
}

var errRunnerBusy = errors.New("runner concurrency limit reached")

func (s *server) queuePreparedJob(ctx context.Context, machine Machine, kind, command, machineName string) (Job, error) {
	id := newJobID()
	if err := s.store.CreateJob(ctx, id, machine.Name, machine.ID, kind, command); err != nil {
		return Job{}, err
	}
	_ = s.store.AppendJobLog(ctx, id, "control", "job accepted for "+machine.Name+" ("+machine.ID+")")
	select {
	case s.jobs <- struct{}{}:
		go func() {
			defer func() { <-s.jobs }()
			s.runJob(id, machineName)
		}()
	default:
		_ = s.store.FinishJob(ctx, id, "failed", nil, "", "", errRunnerBusy.Error())
		return Job{}, errRunnerBusy
	}
	job, _, err := s.store.GetJob(ctx, id)
	return job, err
}

func (s *server) runJob(id, machineName string) {
	ctx, cancel := context.WithTimeout(context.Background(), 115*time.Minute)
	defer cancel()
	if err := s.store.StartJob(ctx, id); err != nil {
		return
	}
	_ = s.store.AppendJobLog(ctx, id, "control", "resolving machine "+machineName)
	machine, err := s.client.ResolveMachine(ctx, machineName)
	if err == nil {
		if machine.State != "running" {
			_ = s.store.AppendJobLog(ctx, id, "control", "machine state "+machine.State+"; requesting wake")
		}
		machine, err = s.waitMachineRunning(ctx, machine)
	}
	var result execResponse
	var exitCode *int
	remoteStarted := false
	if err == nil {
		_ = s.store.AppendJobLog(ctx, id, "control", "detached remote job starting through InstaBox API")
		err = s.startRemoteJob(ctx, machine, id, mustJobCommand(ctx, s.store, id))
		remoteStarted = err == nil
	}
	if err == nil {
		_ = s.store.AppendJobLog(ctx, id, "control", "remote job started; polling exit marker and log")
		result, err = s.pollRemoteJob(ctx, machine, id)
	}
	status := "finished"
	runErr := ""
	if err != nil {
		status = "failed"
		runErr = err.Error()
	} else {
		exitCode = &result.ExitCode
		if result.ExitCode != 0 {
			status = "failed"
			runErr = fmt.Sprintf("remote command exited %d", result.ExitCode)
		}
	}
	if remoteStarted {
		s.captureArtifacts(ctx, machine, id, result.Stdout, result.Stderr)
	}
	if result.Stdout != "" {
		_ = s.store.AppendJobLog(ctx, id, "stdout", result.Stdout)
	}
	if result.Stderr != "" {
		_ = s.store.AppendJobLog(ctx, id, "stderr", result.Stderr)
	}
	_ = s.store.AppendJobLog(ctx, id, "control", "job "+status)
	_ = s.store.FinishJob(ctx, id, status, exitCode, result.Stdout, result.Stderr, runErr)
}

func mustJobCommand(ctx context.Context, store *Store, id string) string {
	job, _, err := store.GetJob(ctx, id)
	if err != nil {
		return "false"
	}
	return job.Command
}

func (s *server) jobDetail(w http.ResponseWriter, r *http.Request) {
	job, logs, err := s.store.GetJob(r.Context(), r.PathValue("id"))
	if err != nil {
		writeError(w, http.StatusNotFound, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"job": job, "logs": logs})
}

func (s *server) artifactList(w http.ResponseWriter, r *http.Request) {
	items, err := s.store.ListArtifacts(r.Context(), r.PathValue("id"))
	if err != nil {
		writeError(w, http.StatusNotFound, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": items, "total": len(items)})
}

func (s *server) artifactDownload(w http.ResponseWriter, r *http.Request) {
	artifactID, err := strconv.ParseInt(r.PathValue("artifact_id"), 10, 64)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("artifact id must be numeric"))
		return
	}
	artifact, content, err := s.store.GetArtifact(r.Context(), r.PathValue("id"), artifactID)
	if err != nil {
		writeError(w, http.StatusNotFound, err)
		return
	}
	w.Header().Set("Content-Type", artifact.Mime)
	w.Header().Set("Content-Length", strconv.Itoa(len(content)))
	w.Header().Set("Content-Disposition", "attachment; filename="+strconv.Quote(artifact.Name))
	w.Header().Set("X-Artifact-SHA256", artifact.SHA256)
	if r.URL.Query().Get("preview") == "1" && strings.HasPrefix(artifact.Mime, "text/") {
		w.Header().Set("Content-Disposition", "inline; filename="+strconv.Quote(artifact.Name))
	}
	_, _ = w.Write(content)
}

func (s *server) scheduleLoop() {
	ticker := time.NewTicker(15 * time.Second)
	defer ticker.Stop()
	for range ticker.C {
		ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
		if _, err := s.runDueSchedules(ctx, time.Now().UTC()); err != nil {
			log.Printf("clanker-runner: schedule tick: %v", err)
		}
		cancel()
	}
}

func (s *server) presetList(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, map[string]any{"items": jobPresets, "total": len(jobPresets)})
}

func (s *server) runPreset(w http.ResponseWriter, r *http.Request) {
	if !s.writeAllowed(w, r) {
		return
	}
	var input presetInput
	decoder := json.NewDecoder(r.Body)
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(&input); err != nil && !errors.Is(err, io.EOF) {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	presetID := r.PathValue("id")
	jobInputValue, err := buildPresetJob(presetID, input)
	if err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	kind, command, err := buildJobCommand(jobInputValue)
	if err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	machine, err := s.client.ResolveMachine(r.Context(), jobInputValue.Machine)
	if err != nil {
		writeError(w, http.StatusBadGateway, err)
		return
	}
	job, err := s.queuePreparedJob(r.Context(), machine, kind, command, jobInputValue.Machine)
	if err != nil {
		if errors.Is(err, errRunnerBusy) {
			writeError(w, http.StatusTooManyRequests, err)
		} else {
			writeError(w, http.StatusInternalServerError, err)
		}
		return
	}
	writeJSON(w, http.StatusAccepted, job)
}

func (s *server) scheduleList(w http.ResponseWriter, r *http.Request) {
	items, err := s.store.ListSchedules(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": items, "total": len(items)})
}

func (s *server) createSchedule(w http.ResponseWriter, r *http.Request) {
	if !s.writeAllowed(w, r) {
		return
	}
	var input scheduleInput
	decoder := json.NewDecoder(r.Body)
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(&input); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	if err := validateScheduleInput(&input); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	schedule, err := s.store.CreateSchedule(r.Context(), input)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusCreated, schedule)
}

func (s *server) deleteSchedule(w http.ResponseWriter, r *http.Request) {
	if !s.writeAllowed(w, r) {
		return
	}
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("schedule id must be numeric"))
		return
	}
	if err := s.store.DeleteSchedule(r.Context(), id); err != nil {
		writeError(w, http.StatusNotFound, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"ok": true})
}

func (s *server) writeAllowed(w http.ResponseWriter, r *http.Request) bool {
	if origin := strings.TrimRight(r.Header.Get("Origin"), "/"); origin != "" && s.expectedOrigin != "" && origin != s.expectedOrigin {
		writeError(w, http.StatusForbidden, errors.New("origin is not the configured tailnet origin"))
		return false
	}
	if s.adminToken == "" {
		return true
	}
	auth := strings.TrimSpace(r.Header.Get("Authorization"))
	if auth != "Bearer "+s.adminToken {
		w.Header().Set("WWW-Authenticate", `Bearer realm="clanker-runner"`)
		writeError(w, http.StatusUnauthorized, errors.New("bearer token required"))
		return false
	}
	return true
}
