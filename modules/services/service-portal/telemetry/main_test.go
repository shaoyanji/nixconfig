package main

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

func testTarget(base string) targetConfig {
	return targetConfig{
		Name:       "job-db",
		BaseURL:    base,
		HealthPath: "/api/health",
		StatsPath:  "/api/stats",
		Metrics: []metricSpec{
			{Key: "active_postings", Label: "active postings"},
			{Key: "companies", Label: "companies"},
		},
	}
}

func TestProbeCollectsHealthStatsAndMetrics(t *testing.T) {
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		switch r.URL.Path {
		case "/api/health":
			_, _ = w.Write([]byte(`{"ok":true,"service":"job-db-scraper"}`))
		case "/api/stats":
			_, _ = w.Write([]byte(`{"active_postings":42,"companies":17,"ignored":99}`))
		default:
			http.NotFound(w, r)
		}
	}))
	defer upstream.Close()
	agg := newAggregator(upstream.Client(), []targetConfig{testTarget(upstream.URL)})
	agg.pollOnce(context.Background())
	snapshot := agg.snapshot()
	state := snapshot.Services["job-db"]
	if state.Status != "online" {
		t.Fatalf("state %#v", state)
	}
	if len(state.Metrics) != 2 || state.Metrics[0].Label != "active postings" || state.Metrics[0].Value.(float64) != 42 {
		t.Fatalf("metrics %#v", state.Metrics)
	}
	if state.Stats["companies"].(float64) != 17 {
		t.Fatalf("stats %#v", state.Stats)
	}
	if state.Health["service"] != "job-db-scraper" || state.LatencyMS < 0 || state.CheckedAt.IsZero() {
		t.Fatalf("state %#v", state)
	}
}

func TestProbeOfflineIsGraceful(t *testing.T) {
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {}))
	base := upstream.URL
	upstream.Close()
	agg := newAggregator(&http.Client{Timeout: 100 * time.Millisecond}, []targetConfig{testTarget(base)})
	agg.pollOnce(context.Background())
	state := agg.snapshot().Services["job-db"]
	if state.Status != "offline" || state.Error == "" || len(state.Metrics) != 0 {
		t.Fatalf("offline state %#v", state)
	}
}

func TestStatsFailureMarksDegraded(t *testing.T) {
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		if r.URL.Path == "/api/health" {
			_, _ = w.Write([]byte(`{"ok":true}`))
			return
		}
		http.Error(w, "missing", http.StatusBadGateway)
	}))
	defer upstream.Close()
	agg := newAggregator(upstream.Client(), []targetConfig{testTarget(upstream.URL)})
	agg.pollOnce(context.Background())
	state := agg.snapshot().Services["job-db"]
	if state.Status != "degraded" || !strings.Contains(state.Error, "stats:") {
		t.Fatalf("degraded state %#v", state)
	}
}

func TestTelemetryHandlerShape(t *testing.T) {
	agg := newAggregator(&http.Client{}, []targetConfig{testTarget("http://127.0.0.1:1")})
	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, http.StatusOK, agg.snapshot())
	})
	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, httptest.NewRequest(http.MethodGet, "/api/telemetry", nil))
	if recorder.Code != http.StatusOK {
		t.Fatalf("status %d", recorder.Code)
	}
	var payload telemetryResponse
	if err := json.NewDecoder(recorder.Body).Decode(&payload); err != nil {
		t.Fatal(err)
	}
	state, ok := payload.Services["job-db"]
	if !ok || state.Status != "unknown" || payload.GeneratedAt.IsZero() {
		t.Fatalf("payload %#v", payload)
	}
}

func TestLinkVaultMetricsUsePortalOrder(t *testing.T) {
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		switch r.URL.Path {
		case "/api/health":
			_, _ = w.Write([]byte(`{"ok":true,"service":"link-vault"}`))
		case "/api/stats":
			_, _ = w.Write([]byte(`{"bookmarks":9,"unread":5,"read":4,"archived":1,"collections":2,"tags":7}`))
		default:
			http.NotFound(w, r)
		}
	}))
	defer upstream.Close()
	target := targetConfig{
		Name:       "link-vault",
		BaseURL:    upstream.URL,
		HealthPath: "/api/health",
		StatsPath:  "/api/stats",
		Metrics: []metricSpec{
			{Key: "bookmarks", Label: "bookmarks"},
			{Key: "read", Label: "read"},
			{Key: "tags", Label: "tags"},
		},
	}
	agg := newAggregator(upstream.Client(), []targetConfig{target})
	agg.pollOnce(context.Background())
	state := agg.snapshot().Services["link-vault"]
	if state.Status != "online" {
		t.Fatalf("state %#v", state)
	}
	if len(state.Metrics) != 3 {
		t.Fatalf("metrics %#v", state.Metrics)
	}
	want := []struct {
		key   string
		value float64
	}{
		{"bookmarks", 9},
		{"read", 4},
		{"tags", 7},
	}
	for i, row := range want {
		if state.Metrics[i].Key != row.key || state.Metrics[i].Value.(float64) != row.value {
			t.Fatalf("metric %d = %#v, want %s=%v in portal order; all %#v", i, state.Metrics[i], row.key, row.value, state.Metrics)
		}
	}
}

func TestHistoryRingSummaryAndEndpoint(t *testing.T) {
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		if r.URL.Path == "/api/health" {
			_, _ = w.Write([]byte(`{"ok":true}`))
			return
		}
		_, _ = w.Write([]byte(`{"active_postings":1,"companies":1}`))
	}))
	defer upstream.Close()
	agg := newAggregatorWithOptions(upstream.Client(), []targetConfig{testTarget(upstream.URL)}, 2, alertConfig{Threshold: 2, Cooldown: time.Minute})
	for i := 0; i < 3; i++ {
		agg.pollOnce(context.Background())
	}
	history := agg.historySnapshot().Services["job-db"]
	if len(history.Samples) != 2 {
		t.Fatalf("ring samples %d, want bounded 2", len(history.Samples))
	}
	state := agg.snapshot().Services["job-db"]
	if state.UptimePercent != 100 || state.P50LatencyMS < 0 || state.P95LatencyMS < state.P50LatencyMS || len(state.LatencySamples) != 2 {
		t.Fatalf("decorated state %#v", state)
	}
	if len(state.History) != 2 || state.History[0].Status != "online" || state.History[1].CheckedAt.IsZero() {
		t.Fatalf("embedded status history %#v", state.History)
	}

	recorder := httptest.NewRecorder()
	routes(agg, 1).ServeHTTP(recorder, httptest.NewRequest(http.MethodGet, "/api/telemetry/history", nil))
	if recorder.Code != http.StatusOK {
		t.Fatalf("history status %d", recorder.Code)
	}
	var payload historyResponse
	if err := json.NewDecoder(recorder.Body).Decode(&payload); err != nil {
		t.Fatal(err)
	}
	if payload.Services["job-db"].Summary.Samples != 2 || len(payload.Services["job-db"].Samples) != 2 {
		t.Fatalf("history payload %#v", payload.Services["job-db"])
	}
}

func TestSummarizeSamplesPercentilesUptimeAndErrors(t *testing.T) {
	transition := time.Date(2026, 1, 2, 3, 4, 5, 0, time.UTC)
	summary := summarizeSamples([]sample{
		{Status: "online", LatencyMS: 10},
		{Status: "online", LatencyMS: 20},
		{Status: "offline", LatencyMS: 100, Error: "connection refused"},
		{Status: "degraded", LatencyMS: 40, Error: "stats missing"},
	}, transition, 2)
	if summary.UptimePercent != 50 || summary.OnlineSamples != 2 || summary.AvgLatencyMS != 42 {
		t.Fatalf("summary %#v", summary)
	}
	if summary.P50LatencyMS != 20 || summary.P95LatencyMS != 100 {
		t.Fatalf("percentiles %#v", summary)
	}
	if summary.LastError != "stats missing" || summary.LastTransitionAt != transition.Format(time.RFC3339) || summary.ConsecutiveFailures != 2 {
		t.Fatalf("summary %#v", summary)
	}
}

func TestTelemetryExportFormats(t *testing.T) {
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		if r.URL.Path == "/api/health" {
			_, _ = w.Write([]byte(`{"ok":true}`))
			return
		}
		_, _ = w.Write([]byte(`{"active_postings":1,"companies":1}`))
	}))
	defer upstream.Close()
	agg := newAggregator(upstream.Client(), []targetConfig{testTarget(upstream.URL)})
	agg.pollOnce(context.Background())
	handler := routes(agg, 1)

	csvRecorder := httptest.NewRecorder()
	handler.ServeHTTP(csvRecorder, httptest.NewRequest(http.MethodGet, "/api/telemetry/export?format=csv", nil))
	if csvRecorder.Code != http.StatusOK || !strings.Contains(csvRecorder.Body.String(), "job-db,online") || !strings.Contains(csvRecorder.Header().Get("Content-Type"), "text/csv") {
		t.Fatalf("csv export code=%d headers=%v body=%q", csvRecorder.Code, csvRecorder.Header(), csvRecorder.Body.String())
	}

	mdRecorder := httptest.NewRecorder()
	handler.ServeHTTP(mdRecorder, httptest.NewRequest(http.MethodGet, "/api/telemetry/export?format=markdown", nil))
	if mdRecorder.Code != http.StatusOK || !strings.Contains(mdRecorder.Body.String(), "| job-db | online |") || !strings.Contains(mdRecorder.Header().Get("Content-Type"), "text/markdown") {
		t.Fatalf("markdown export code=%d body=%q", mdRecorder.Code, mdRecorder.Body.String())
	}

	jsonRecorder := httptest.NewRecorder()
	handler.ServeHTTP(jsonRecorder, httptest.NewRequest(http.MethodGet, "/api/telemetry/export?format=json", nil))
	if jsonRecorder.Code != http.StatusOK || !strings.Contains(jsonRecorder.Body.String(), `"history"`) {
		t.Fatalf("json export code=%d body=%q", jsonRecorder.Code, jsonRecorder.Body.String())
	}

	badRecorder := httptest.NewRecorder()
	handler.ServeHTTP(badRecorder, httptest.NewRequest(http.MethodGet, "/api/telemetry/export?format=xml", nil))
	if badRecorder.Code != http.StatusBadRequest {
		t.Fatalf("bad export status %d", badRecorder.Code)
	}
}

func TestAlertDebounceRecoveryAndCooldown(t *testing.T) {
	var upstreamMode string
	upstreamMode = "fail"
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		if r.URL.Path == "/api/stats" {
			_, _ = w.Write([]byte(`{"active_postings":1,"companies":1}`))
			return
		}
		if upstreamMode == "fail" {
			_, _ = w.Write([]byte(`{"ok":false}`))
			return
		}
		_, _ = w.Write([]byte(`{"ok":true}`))
	}))
	defer upstream.Close()
	var alerts []alertEvent
	ntfy := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			t.Errorf("alert method %s", r.Method)
		}
		var event alertEvent
		if err := json.NewDecoder(r.Body).Decode(&event); err != nil {
			t.Errorf("alert decode: %v", err)
		}
		alerts = append(alerts, event)
		w.WriteHeader(http.StatusOK)
	}))
	defer ntfy.Close()
	current := time.Date(2026, 1, 2, 3, 4, 5, 0, time.UTC)
	agg := newAggregatorWithOptions(upstream.Client(), []targetConfig{testTarget(upstream.URL)}, 10, alertConfig{
		Webhook:   ntfy.URL,
		Cooldown:  time.Minute,
		Threshold: 2,
		Recovery:  true,
	})
	agg.now = func() time.Time { return current }

	agg.pollOnce(context.Background())
	if len(alerts) != 0 {
		t.Fatalf("first failure alerted: %#v", alerts)
	}
	agg.pollOnce(context.Background())
	if len(alerts) != 1 || alerts[0].Kind != "degraded" || alerts[0].Status != "degraded" {
		t.Fatalf("degraded alert %#v", alerts)
	}
	agg.pollOnce(context.Background())
	if len(alerts) != 1 {
		t.Fatalf("ongoing degradation spammed: %#v", alerts)
	}

	upstreamMode = "ok"
	agg.pollOnce(context.Background())
	if len(alerts) != 2 || alerts[1].Kind != "recovery" {
		t.Fatalf("recovery alert %#v", alerts)
	}

	upstreamMode = "fail"
	agg.pollOnce(context.Background())
	agg.pollOnce(context.Background())
	if len(alerts) != 2 {
		t.Fatalf("flap inside cooldown spammed: %#v", alerts)
	}
	current = current.Add(2 * time.Minute)
	agg.pollOnce(context.Background())
	if len(alerts) != 3 || alerts[2].Kind != "degraded" {
		t.Fatalf("post-cooldown alert %#v", alerts)
	}
}
