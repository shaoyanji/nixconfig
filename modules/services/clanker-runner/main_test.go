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
