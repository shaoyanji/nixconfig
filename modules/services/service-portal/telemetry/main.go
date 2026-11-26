package main

import (
	"context"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"strings"
	"sync"
	"time"
)

type metricSpec struct {
	Key   string `json:"key"`
	Label string `json:"label"`
}

type targetConfig struct {
	Name       string       `json:"name"`
	BaseURL    string       `json:"base_url"`
	HealthPath string       `json:"health_path"`
	StatsPath  string       `json:"stats_path"`
	Metrics    []metricSpec `json:"metrics"`
}

type telemetryConfig struct {
	Targets []targetConfig `json:"targets"`
}

type metricValue struct {
	Key   string `json:"key"`
	Label string `json:"label"`
	Value any    `json:"value"`
}

type serviceState struct {
	Name      string         `json:"name"`
	Status    string         `json:"status"`
	Error     string         `json:"error,omitempty"`
	LatencyMS int64          `json:"latency_ms"`
	CheckedAt time.Time      `json:"checked_at"`
	Health    map[string]any `json:"health,omitempty"`
	Stats     map[string]any `json:"stats,omitempty"`
	Metrics   []metricValue  `json:"metrics"`
}

type telemetryResponse struct {
	GeneratedAt time.Time               `json:"generated_at"`
	Services    map[string]serviceState `json:"services"`
}

type aggregator struct {
	client  *http.Client
	targets []targetConfig
	mu      sync.RWMutex
	results map[string]serviceState
}

func loadConfig(path string) (telemetryConfig, error) {
	raw, err := os.ReadFile(path)
	if err != nil {
		return telemetryConfig{}, err
	}
	var cfg telemetryConfig
	decoder := json.NewDecoder(strings.NewReader(string(raw)))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(&cfg); err != nil {
		return telemetryConfig{}, err
	}
	if len(cfg.Targets) == 0 {
		return telemetryConfig{}, errors.New("telemetry config needs at least one target")
	}
	seen := map[string]bool{}
	for i := range cfg.Targets {
		target := &cfg.Targets[i]
		target.Name = strings.TrimSpace(target.Name)
		target.BaseURL = strings.TrimRight(strings.TrimSpace(target.BaseURL), "/")
		if target.Name == "" || target.BaseURL == "" {
			return telemetryConfig{}, errors.New("telemetry targets need name and base_url")
		}
		if seen[target.Name] {
			return telemetryConfig{}, fmt.Errorf("duplicate telemetry target %q", target.Name)
		}
		seen[target.Name] = true
		if target.HealthPath == "" {
			target.HealthPath = "/api/health"
		}
		if target.StatsPath == "" {
			target.StatsPath = "/api/stats"
		}
		for j := range target.Metrics {
			if target.Metrics[j].Label == "" {
				target.Metrics[j].Label = strings.ReplaceAll(target.Metrics[j].Key, "_", " ")
			}
		}
	}
	return cfg, nil
}

func newAggregator(client *http.Client, targets []targetConfig) *aggregator {
	return &aggregator{client: client, targets: targets, results: map[string]serviceState{}}
}

func getJSON(ctx context.Context, client *http.Client, url string) (map[string]any, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("Accept", "application/json")
	response, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer response.Body.Close()
	if response.StatusCode < 200 || response.StatusCode > 299 {
		_, _ = io.Copy(io.Discard, io.LimitReader(response.Body, 1024))
		return nil, fmt.Errorf("%s returned %s", url, response.Status)
	}
	var payload map[string]any
	decoder := json.NewDecoder(io.LimitReader(response.Body, 1024*1024))
	if err := decoder.Decode(&payload); err != nil {
		return nil, err
	}
	return payload, nil
}

func metricValues(specs []metricSpec, stats map[string]any) []metricValue {
	values := make([]metricValue, 0, len(specs))
	for _, spec := range specs {
		value, ok := stats[spec.Key]
		if !ok {
			continue
		}
		values = append(values, metricValue{Key: spec.Key, Label: spec.Label, Value: value})
	}
	return values
}

func (a *aggregator) probe(ctx context.Context, target targetConfig) serviceState {
	started := time.Now()
	state := serviceState{Name: target.Name, Status: "offline", CheckedAt: started.UTC(), Metrics: []metricValue{}}
	health, err := getJSON(ctx, a.client, target.BaseURL+target.HealthPath)
	state.LatencyMS = time.Since(started).Milliseconds()
	if err != nil {
		state.Error = err.Error()
		return state
	}
	state.Health = health
	state.Status = "online"
	if ok, present := health["ok"].(bool); present && !ok {
		state.Status = "degraded"
		state.Error = "health endpoint reports not ok"
	}
	stats, err := getJSON(ctx, a.client, target.BaseURL+target.StatsPath)
	if err != nil {
		state.Status = "degraded"
		if state.Error != "" {
			state.Error += "; "
		}
		state.Error += "stats: " + err.Error()
		return state
	}
	state.Stats = stats
	state.Metrics = metricValues(target.Metrics, stats)
	return state
}

func (a *aggregator) pollOnce(ctx context.Context) {
	var wg sync.WaitGroup
	results := make(chan serviceState, len(a.targets))
	for _, target := range a.targets {
		target := target
		wg.Add(1)
		go func() {
			defer wg.Done()
			results <- a.probe(ctx, target)
		}()
	}
	wg.Wait()
	close(results)
	a.mu.Lock()
	for result := range results {
		a.results[result.Name] = result
	}
	a.mu.Unlock()
}

func (a *aggregator) run(ctx context.Context, interval time.Duration) {
	a.pollOnce(ctx)
	ticker := time.NewTicker(interval)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			pollCtx, cancel := context.WithTimeout(ctx, interval)
			a.pollOnce(pollCtx)
			cancel()
		}
	}
}

func (a *aggregator) snapshot() telemetryResponse {
	a.mu.RLock()
	defer a.mu.RUnlock()
	services := make(map[string]serviceState, len(a.targets))
	for _, target := range a.targets {
		if state, ok := a.results[target.Name]; ok {
			services[target.Name] = state
		} else {
			services[target.Name] = serviceState{Name: target.Name, Status: "unknown", Metrics: []metricValue{}}
		}
	}
	return telemetryResponse{GeneratedAt: time.Now().UTC(), Services: services}
}

func writeJSON(w http.ResponseWriter, status int, payload any) {
	raw, err := json.MarshalIndent(payload, "", "  ")
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.Header().Set("Cache-Control", "no-store")
	w.WriteHeader(status)
	_, _ = w.Write(append(raw, '\n'))
}

func main() {
	addr := flag.String("addr", "127.0.0.1:8105", "loopback address to listen on")
	configPath := flag.String("config", "telemetry.json", "JSON telemetry target configuration")
	interval := flag.Duration("interval", 10*time.Second, "poll interval")
	timeout := flag.Duration("timeout", 750*time.Millisecond, "per-request target timeout")
	flag.Parse()

	cfg, err := loadConfig(*configPath)
	if err != nil {
		log.Fatalf("service-portal-telemetry: config: %v", err)
	}
	client := &http.Client{Timeout: *timeout}
	agg := newAggregator(client, cfg.Targets)
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go agg.run(ctx, *interval)

	mux := http.NewServeMux()
	mux.HandleFunc("GET /api/telemetry", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, http.StatusOK, agg.snapshot())
	})
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, http.StatusOK, map[string]any{"ok": true, "service": "service-portal-telemetry", "targets": len(cfg.Targets)})
	})
	log.Printf("service-portal-telemetry: listening on %s, targets %d, interval %s", *addr, len(cfg.Targets), *interval)
	if err := http.ListenAndServe(*addr, mux); err != nil {
		log.Fatal(err)
	}
}
