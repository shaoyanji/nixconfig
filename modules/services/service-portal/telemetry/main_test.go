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
