package main

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func openTestStore(t *testing.T) *Store {
	t.Helper()
	store, err := OpenStore(filepath.Join(t.TempDir(), "runner.sqlite"))
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { store.Close() })
	return store
}

func machinePayload(state string) string {
	return `{"machines":[{"id":"m_clanker","name":"clanker","state":"` + state + `","spec":{"vcpus":4,"memMiB":8192,"persistentDiskGiB":20},"autoSuspendAfterSeconds":1800}]}`
}

func TestInstaboxClientUsesMockBaseAndRedactsKey(t *testing.T) {
	secret := "ibk_test_secret"
	var gotAuth, gotWake string
	api := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotAuth = r.Header.Get("X-API-Key")
		switch {
		case r.URL.Path == "/v1/machines":
			w.Write([]byte(machinePayload("running")))
		case r.URL.Path == "/v1/machines/m_clanker/wake" && r.Method == http.MethodPost:
			gotWake = r.Method + " " + r.URL.Path
			w.Write([]byte(`{"operationId":"op-1"}`))
		case r.URL.Path == "/v1/machines/m_clanker/exec":
			w.WriteHeader(http.StatusBadGateway)
			w.Write([]byte(`{"error":{"code":"failed","message":"gateway echoed ` + secret + ` loudly"}}`))
		default:
			http.NotFound(w, r)
		}
	}))
	defer api.Close()
	client := newInstaboxClient(api.URL, secret)
	machines, err := client.ListMachines(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	if len(machines) != 1 || machines[0].ID != "m_clanker" || machines[0].VCPUs != 4 || machines[0].MemMiB != 8192 {
		t.Fatalf("machines %#v", machines)
	}
	if gotAuth != secret {
		t.Fatalf("X-API-Key header %q", gotAuth)
	}
	if err := client.MachineAction(context.Background(), "m_clanker", "wake"); err != nil {
		t.Fatal(err)
	}
	if gotWake != "POST /v1/machines/m_clanker/wake" {
		t.Fatalf("wake request %q", gotWake)
	}
	_, err = client.Exec(context.Background(), "m_clanker", "false")
	if err == nil || strings.Contains(err.Error(), secret) || !strings.Contains(err.Error(), "[redacted]") {
		t.Fatalf("secret was not redacted: %v", err)
	}
}

func encodedCommand(t *testing.T, script string) string {
	t.Helper()
	marker := "printf '%s' '"
	start := strings.Index(script, marker)
	if start < 0 {
		t.Fatalf("encoded command marker missing in %q", script)
	}
	start += len(marker)
	end := strings.Index(script[start:], "' | base64 -d > \"$dir/cmd.sh\"")
	if end < 0 {
		t.Fatalf("encoded command terminator missing in %q", script)
	}
	raw, err := base64.StdEncoding.DecodeString(script[start : start+end])
	if err != nil {
		t.Fatal(err)
	}
	return string(raw)
}

func writeExec(w http.ResponseWriter, stdout, stderr string, code int) {
	payload, _ := json.Marshal(map[string]any{"stdout": stdout, "stderr": stderr, "exitCode": code})
	w.Write(payload)
}

func TestJobRunsThroughInstaboxAndPersistsLogsAndFTS(t *testing.T) {
	store := openTestStore(t)
	var remoteCommand string
	polls := 0
	api := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch {
		case r.URL.Path == "/v1/machines":
			w.Write([]byte(machinePayload("running")))
		case r.URL.Path == "/v1/machines/m_clanker/exec":
			var body struct {
				Command string `json:"cmd"`
			}
			if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
				t.Errorf("decode exec body: %v", err)
			}
			switch {
			case strings.Contains(body.Command, `base64 -d > "$dir/cmd.sh"`):
				remoteCommand = encodedCommand(t, body.Command)
				writeExec(w, "started\n", "", 0)
			case strings.Contains(body.Command, "/exit"):
				polls++
				if polls == 1 {
					writeExec(w, "running\n", "", 0)
				} else {
					writeExec(w, "0\n", "", 0)
				}
			case strings.Contains(body.Command, "/stdout"):
				writeExec(w, "built agent-browser smoke\n", "", 0)
			case strings.Contains(body.Command, "/stderr"):
				writeExec(w, "", "", 0)
			case strings.Contains(body.Command, "/artifacts"):
				writeExec(w, "", "", 0)
			default:
				t.Errorf("unexpected exec command %q", body.Command)
				writeExec(w, "", "unexpected", 1)
			}
		default:
			http.NotFound(w, r)
		}
	}))
	defer api.Close()
	s := &server{store: store, client: newInstaboxClient(api.URL, "ibk_test"), jobs: make(chan struct{}, 2), pollInterval: 5 * time.Millisecond}
	req := httptest.NewRequest(http.MethodPost, "/api/jobs", strings.NewReader(`{"machine":"clanker","kind":"agent-browser","args":"open https://example.com"}`))
	recorder := httptest.NewRecorder()
	s.createJob(recorder, req)
	if recorder.Code != http.StatusAccepted {
		t.Fatalf("status %d body %s", recorder.Code, recorder.Body.String())
	}
	var accepted Job
	if err := json.NewDecoder(recorder.Body).Decode(&accepted); err != nil {
		t.Fatal(err)
	}
	deadline := time.Now().Add(3 * time.Second)
	var job Job
	var logs []logEntry
	for time.Now().Before(deadline) {
		var err error
		job, logs, err = store.GetJob(context.Background(), accepted.ID)
		if err == nil && job.Status == "finished" {
			break
		}
		time.Sleep(20 * time.Millisecond)
	}
	if job.Status != "finished" || job.ExitCode == nil || *job.ExitCode != 0 {
		t.Fatalf("job %#v", job)
	}
	if !strings.Contains(remoteCommand, "agent-browser open https://example.com") {
		t.Fatalf("remote command %q", remoteCommand)
	}
	if !strings.Contains(job.Stdout, "agent-browser smoke") || len(logs) < 3 {
		t.Fatalf("job output/logs %#v %#v", job, logs)
	}
	page, err := store.QueryJobs(context.Background(), queryOptions{Q: "agent-browser", Limit: 10})
	if err != nil || page.Total != 1 || len(page.Items) != 1 || !strings.Contains(page.Items[0].Snippet, "<mark>") {
		t.Fatalf("fts page %#v err=%v", page, err)
	}
	stats, err := store.Stats(context.Background())
	if err != nil || stats.TotalJobs != 1 || stats.Successful != 1 || stats.FailedJobs != 0 {
		t.Fatalf("stats %#v err=%v", stats, err)
	}
	artifacts, err := store.ListArtifacts(context.Background(), accepted.ID)
	if err != nil || len(artifacts) != 1 || artifacts[0].Name != "stdout.txt" || artifacts[0].SHA256 == "" || artifacts[0].Size == 0 {
		t.Fatalf("artifacts %#v err=%v", artifacts, err)
	}
	artifact, content, err := store.GetArtifact(context.Background(), accepted.ID, artifacts[0].ID)
	if err != nil || string(content) != job.Stdout || artifact.Mime == "" {
		t.Fatalf("artifact download %#v %q err=%v", artifact, content, err)
	}
}

func TestJobFailurePersistsExitAndError(t *testing.T) {
	store := openTestStore(t)
	api := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch {
		case r.URL.Path == "/v1/machines":
			w.Write([]byte(machinePayload("running")))
		case r.URL.Path == "/v1/machines/m_clanker/exec":
			var body struct {
				Command string `json:"cmd"`
			}
			if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
				t.Errorf("decode exec body: %v", err)
			}
			switch {
			case strings.Contains(body.Command, `base64 -d > "$dir/cmd.sh"`):
				writeExec(w, "started\n", "", 0)
			case strings.Contains(body.Command, "/exit"):
				writeExec(w, "1\n", "", 0)
			case strings.Contains(body.Command, "/stdout"):
				writeExec(w, "", "", 0)
			case strings.Contains(body.Command, "/stderr"):
				writeExec(w, "nix eval failed\n", "", 0)
			case strings.Contains(body.Command, "/artifacts"):
				writeExec(w, "", "", 0)
			default:
				t.Errorf("unexpected exec command %q", body.Command)
				writeExec(w, "", "unexpected", 1)
			}
		default:
			http.NotFound(w, r)
		}
	}))
	defer api.Close()
	s := &server{store: store, client: newInstaboxClient(api.URL, "ibk_test"), jobs: make(chan struct{}, 1), pollInterval: 5 * time.Millisecond}
	req := httptest.NewRequest(http.MethodPost, "/api/jobs", strings.NewReader(`{"machine":"clanker","kind":"nix","attr":".#packages.x86_64-linux.demo"}`))
	recorder := httptest.NewRecorder()
	s.createJob(recorder, req)
	if recorder.Code != http.StatusAccepted {
		t.Fatalf("status %d body %s", recorder.Code, recorder.Body.String())
	}
	var accepted Job
	_ = json.NewDecoder(recorder.Body).Decode(&accepted)
	deadline := time.Now().Add(3 * time.Second)
	for time.Now().Before(deadline) {
		job, _, err := store.GetJob(context.Background(), accepted.ID)
		if err == nil && job.Status == "failed" {
			if job.ExitCode == nil || *job.ExitCode != 1 || !strings.Contains(job.Stderr, "nix eval failed") || !strings.Contains(job.Error, "exited 1") {
				t.Fatalf("failed job %#v", job)
			}
			return
		}
		time.Sleep(20 * time.Millisecond)
	}
	t.Fatal("job did not finish as failed")
}

func TestWriteGateRejectsWrongOriginAndMissingBearer(t *testing.T) {
	store := openTestStore(t)
	s := &server{store: store, client: newInstaboxClient("http://127.0.0.1", "ibk_test"), adminToken: "secret", expectedOrigin: "https://delphi.example:8467", jobs: make(chan struct{}, 1)}
	req := httptest.NewRequest(http.MethodPost, "/api/jobs", strings.NewReader(`{"command":"true"}`))
	req.Header.Set("Origin", "https://evil.example")
	recorder := httptest.NewRecorder()
	s.createJob(recorder, req)
	if recorder.Code != http.StatusForbidden {
		t.Fatalf("origin status %d", recorder.Code)
	}
	req = httptest.NewRequest(http.MethodPost, "/api/jobs", strings.NewReader(`{"command":"true"}`))
	recorder = httptest.NewRecorder()
	s.createJob(recorder, req)
	if recorder.Code != http.StatusUnauthorized {
		t.Fatalf("bearer status %d", recorder.Code)
	}
}

func TestPresetValidationAndBuilders(t *testing.T) {
	if len(jobPresets) != 10 {
		t.Fatalf("presets %#v", jobPresets)
	}
	for _, id := range []string{"agent-browser-dom-check", "agent-browser-screenshot", "nix-flake-check", "nix-flake-build", "nix-profile-status", "nix-store-hygiene", "clanker-disk-hygiene", "go-cli-build", "rust-cli-build", "nix-run-tool"} {
		if _, ok := presetByID(id); !ok {
			t.Fatalf("missing preset %s", id)
		}
	}
	if _, err := buildPresetJob("agent-browser-dom-check", presetInput{URL: "javascript:alert(1)"}); err == nil {
		t.Fatal("non-http URL accepted")
	}
	browserJob, err := buildPresetJob("agent-browser-dom-check", presetInput{URL: "https://example.com/inventory", Selector: "main h1"})
	if err != nil {
		t.Fatalf("browser preset: %v", err)
	}
	if browserJob.Kind != "agent-browser" || !strings.Contains(browserJob.Args, "https://example.com/inventory") || !strings.Contains(browserJob.Args, "selector_found") {
		t.Fatalf("browser job %#v", browserJob)
	}
	if _, err := buildPresetJob("nix-run-tool", presetInput{Package: "jq", Args: "--help; rm -rf /"}); err == nil {
		t.Fatal("shell metacharacter args accepted")
	}
	toolJob, err := buildPresetJob("nix-run-tool", presetInput{Package: "jq", Args: "--version"})
	if err != nil {
		t.Fatalf("nix-run-tool: %v", err)
	}
	if !strings.Contains(toolJob.Command, "nix run nixpkgs#jq -- --version") {
		t.Fatalf("tool command %q", toolJob.Command)
	}
	diskJob, err := buildPresetJob("clanker-disk-hygiene", presetInput{})
	if err != nil || !strings.Contains(diskJob.Command, "--dry-run") {
		t.Fatalf("disk job %#v err=%v", diskJob, err)
	}
	if _, err := buildPresetJob("go-cli-build", presetInput{Dir: "/etc/passwd"}); err == nil {
		t.Fatal("outside-/data go build dir accepted")
	}
	goJob, err := buildPresetJob("go-cli-build", presetInput{Dir: "/data/demo", Target: "./cmd/demo"})
	if err != nil || !strings.Contains(goJob.Command, "go test ./cmd/demo") || !strings.Contains(goJob.Command, "artifacts/cli.bin") {
		t.Fatalf("go job %#v err=%v", goJob, err)
	}
	flakeJob, err := buildPresetJob("nix-flake-build", presetInput{Attr: ".#packages.x86_64-linux.demo"})
	if err != nil || !strings.Contains(flakeJob.Command, "nix build -L") || !strings.Contains(flakeJob.Command, "--no-link") {
		t.Fatalf("flake job %#v err=%v", flakeJob, err)
	}
	shotJob, err := buildPresetJob("agent-browser-screenshot", presetInput{URL: "https://example.com"})
	if err != nil || !strings.Contains(shotJob.Args, "artifacts/page.png") || !strings.Contains(shotJob.Args, "dom-probe.json") {
		t.Fatalf("screenshot job %#v err=%v", shotJob, err)
	}
}

func testMachineAPI(t *testing.T, execCode int) *httptest.Server {
	t.Helper()
	return httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch {
		case r.URL.Path == "/v1/machines":
			w.Write([]byte(machinePayload("running")))
		case r.URL.Path == "/v1/machines/m_clanker":
			w.Write([]byte(`{"id":"m_clanker","name":"clanker","state":"running","spec":{"vcpus":4,"memMiB":8192,"persistentDiskGiB":20}}`))
		case r.URL.Path == "/v1/machines/m_clanker/exec":
			writeExec(w, "", "mock exec stops the remote job", execCode)
		default:
			http.NotFound(w, r)
		}
	}))
}

func TestPresetRunEndpointQueuesValidatedJob(t *testing.T) {
	store := openTestStore(t)
	api := testMachineAPI(t, 1)
	defer api.Close()
	s := &server{store: store, client: newInstaboxClient(api.URL, "ibk_test"), jobs: make(chan struct{}, 1), pollInterval: time.Millisecond}
	req := httptest.NewRequest(http.MethodPost, "/api/presets/nix-run-tool/run", strings.NewReader(`{"package":"jq","args":"--version"}`))
	req.SetPathValue("id", "nix-run-tool")
	recorder := httptest.NewRecorder()
	s.runPreset(recorder, req)
	if recorder.Code != http.StatusAccepted {
		t.Fatalf("run preset status %d body %s", recorder.Code, recorder.Body.String())
	}
	var job Job
	if err := json.NewDecoder(recorder.Body).Decode(&job); err != nil {
		t.Fatal(err)
	}
	if job.Kind != "shell" || !strings.Contains(job.Command, "nixpkgs#jq") {
		t.Fatalf("job %#v", job)
	}
	req = httptest.NewRequest(http.MethodPost, "/api/presets/nix-run-tool/run", strings.NewReader(`{"package":"jq","args":"--help;touch /tmp/x"}`))
	req.SetPathValue("id", "nix-run-tool")
	recorder = httptest.NewRecorder()
	s.runPreset(recorder, req)
	if recorder.Code != http.StatusBadRequest {
		t.Fatalf("invalid preset status %d body %s", recorder.Code, recorder.Body.String())
	}
}

func waitForJobTerminal(t *testing.T, store *Store, id string) Job {
	t.Helper()
	deadline := time.Now().Add(2 * time.Second)
	for time.Now().Before(deadline) {
		job, _, err := store.GetJob(context.Background(), id)
		if err == nil && (job.Status == "finished" || job.Status == "failed") {
			return job
		}
		time.Sleep(10 * time.Millisecond)
	}
	t.Fatalf("job %s did not finish", id)
	return Job{}
}

func TestArtifactEndpoints(t *testing.T) {
	store := openTestStore(t)
	ctx := context.Background()
	if err := store.CreateJob(ctx, "job-artifacts", "clanker", "m_clanker", "shell", "printf hi"); err != nil {
		t.Fatal(err)
	}
	if err := store.CreateArtifact(ctx, "job-artifacts", artifactInput{Name: "stdout.txt", Kind: "stdout", Mime: "text/plain; charset=utf-8", Content: []byte("hello artifact\n")}); err != nil {
		t.Fatal(err)
	}
	s := &server{store: store}
	req := httptest.NewRequest(http.MethodGet, "/api/jobs/job-artifacts/artifacts", nil)
	req.SetPathValue("id", "job-artifacts")
	recorder := httptest.NewRecorder()
	s.artifactList(recorder, req)
	if recorder.Code != http.StatusOK || !strings.Contains(recorder.Body.String(), "stdout.txt") || !strings.Contains(recorder.Body.String(), "sha256") {
		t.Fatalf("artifact list %d %s", recorder.Code, recorder.Body.String())
	}
	items, err := store.ListArtifacts(ctx, "job-artifacts")
	if err != nil || len(items) != 1 {
		t.Fatal(err)
	}
	req = httptest.NewRequest(http.MethodGet, "/api/jobs/job-artifacts/artifacts/1?preview=1", nil)
	req.SetPathValue("id", "job-artifacts")
	req.SetPathValue("artifact_id", "1")
	recorder = httptest.NewRecorder()
	s.artifactDownload(recorder, req)
	if recorder.Code != http.StatusOK || recorder.Body.String() != "hello artifact\n" || recorder.Header().Get("X-Artifact-SHA256") != items[0].SHA256 {
		t.Fatalf("artifact download %d %q headers %#v", recorder.Code, recorder.Body.String(), recorder.Header())
	}
}

func TestScheduleCRUDValidationAndDueRun(t *testing.T) {
	store := openTestStore(t)
	api := testMachineAPI(t, 1)
	defer api.Close()
	s := &server{store: store, client: newInstaboxClient(api.URL, "ibk_test"), jobs: make(chan struct{}, 1), pollInterval: time.Millisecond}
	body := `{"name":"disk check","preset_id":"clanker-disk-hygiene","interval_seconds":15,"start_immediately":true}`
	req := httptest.NewRequest(http.MethodPost, "/api/schedules", strings.NewReader(body))
	recorder := httptest.NewRecorder()
	s.createSchedule(recorder, req)
	if recorder.Code != http.StatusCreated {
		t.Fatalf("create schedule status %d body %s", recorder.Code, recorder.Body.String())
	}
	var schedule Schedule
	if err := json.NewDecoder(recorder.Body).Decode(&schedule); err != nil {
		t.Fatal(err)
	}
	if schedule.ID == 0 || !schedule.Enabled || schedule.NextRunAt.After(time.Now().UTC().Add(time.Second)) {
		t.Fatalf("schedule %#v", schedule)
	}
	ran, err := s.runDueSchedules(context.Background(), time.Now().UTC())
	if err != nil || ran != 1 {
		t.Fatalf("runDue ran=%d err=%v", ran, err)
	}
	updated, err := store.GetSchedule(context.Background(), schedule.ID)
	if err != nil {
		t.Fatal(err)
	}
	if updated.LastJobID == "" || updated.LastRunAt == nil || !updated.NextRunAt.After(time.Now().UTC().Add(10*time.Second)) {
		t.Fatalf("updated schedule %#v", updated)
	}
	job := waitForJobTerminal(t, store, updated.LastJobID)
	if !strings.Contains(job.Command, "nix store gc --dry-run") {
		t.Fatalf("scheduled job %#v", job)
	}
	items, err := store.ListSchedules(context.Background())
	if err != nil || len(items) != 1 {
		t.Fatalf("schedules %#v err=%v", items, err)
	}
	req = httptest.NewRequest(http.MethodDelete, "/api/schedules/1", nil)
	req.SetPathValue("id", "1")
	recorder = httptest.NewRecorder()
	s.deleteSchedule(recorder, req)
	if recorder.Code != http.StatusOK {
		t.Fatalf("delete status %d body %s", recorder.Code, recorder.Body.String())
	}
	items, err = store.ListSchedules(context.Background())
	if err != nil || len(items) != 0 {
		t.Fatalf("after delete %#v err=%v", items, err)
	}
}

func TestScheduleRejectsInvalidPresetParams(t *testing.T) {
	input := scheduleInput{PresetID: "nix-run-tool", IntervalSeconds: 60, Params: json.RawMessage(`{"package":"jq","args":"--help|cat"}`)}
	if err := validateScheduleInput(&input); err == nil {
		t.Fatal("invalid schedule params accepted")
	}
	input = scheduleInput{PresetID: "agent-browser-dom-check", IntervalSeconds: 60, Params: json.RawMessage(`{"url":"https://example.com"}`)}
	if err := validateScheduleInput(&input); err != nil {
		t.Fatalf("valid schedule rejected: %v", err)
	}
}
