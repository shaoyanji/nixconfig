package main

import (
	"bytes"
	"context"
	"encoding/csv"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"log"
	"math"
	"net/http"
	"os"
	"sort"
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

type sample struct {
	Status    string    `json:"status"`
	LatencyMS int64     `json:"latency_ms"`
	CheckedAt time.Time `json:"checked_at"`
	Error     string    `json:"error,omitempty"`
}

type serviceState struct {
	Name                string         `json:"name"`
	Status              string         `json:"status"`
	Error               string         `json:"error,omitempty"`
	LatencyMS           int64          `json:"latency_ms"`
	AvgLatencyMS        int64          `json:"avg_latency_ms"`
	P50LatencyMS        int64          `json:"p50_latency_ms"`
	P95LatencyMS        int64          `json:"p95_latency_ms"`
	UptimePercent       float64        `json:"uptime_percent"`
	LastError           string         `json:"last_error,omitempty"`
	LastTransitionAt    string         `json:"last_transition_at,omitempty"`
	ConsecutiveFailures int            `json:"consecutive_failures"`
	LatencySamples      []int64        `json:"latency_samples,omitempty"`
	History             []sample       `json:"history,omitempty"`
	CheckedAt           time.Time      `json:"checked_at"`
	Health              map[string]any `json:"health,omitempty"`
	Stats               map[string]any `json:"stats,omitempty"`
	Metrics             []metricValue  `json:"metrics"`
}

type telemetryResponse struct {
	GeneratedAt time.Time               `json:"generated_at"`
	Services    map[string]serviceState `json:"services"`
}

type historySummary struct {
	Samples             int     `json:"samples"`
	OnlineSamples       int     `json:"online_samples"`
	UptimePercent       float64 `json:"uptime_percent"`
	AvgLatencyMS        int64   `json:"avg_latency_ms"`
	P50LatencyMS        int64   `json:"p50_latency_ms"`
	P95LatencyMS        int64   `json:"p95_latency_ms"`
	LastError           string  `json:"last_error,omitempty"`
	LastTransitionAt    string  `json:"last_transition_at,omitempty"`
	ConsecutiveFailures int     `json:"consecutive_failures"`
}

type targetHistory struct {
	Summary historySummary `json:"summary"`
	Samples []sample       `json:"samples"`
}

type historyResponse struct {
	GeneratedAt time.Time                `json:"generated_at"`
	Services    map[string]targetHistory `json:"services"`
}

type alertConfig struct {
	Webhook   string
	Cooldown  time.Duration
	Threshold int
	Recovery  bool
}

type alertEvent struct {
	Kind           string    `json:"kind"`
	Service        string    `json:"service"`
	Status         string    `json:"status"`
	PreviousStatus string    `json:"previous_status"`
	Error          string    `json:"error,omitempty"`
	CheckedAt      time.Time `json:"checked_at"`
	Message        string    `json:"message"`
}

type aggregator struct {
	client              *http.Client
	targets             []targetConfig
	historySize         int
	alert               alertConfig
	now                 func() time.Time
	mu                  sync.RWMutex
	results             map[string]serviceState
	history             map[string][]sample
	lastStatus          map[string]string
	lastTransition      map[string]time.Time
	consecutiveFailures map[string]int
	lastAlertAt         map[string]time.Time
	alertActive         map[string]bool
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
	return newAggregatorWithOptions(client, targets, 144, alertConfig{Cooldown: 15 * time.Minute, Threshold: 2, Recovery: true})
}

func newAggregatorWithOptions(client *http.Client, targets []targetConfig, historySize int, alerts alertConfig) *aggregator {
	if historySize < 1 {
		historySize = 1
	}
	if alerts.Threshold < 1 {
		alerts.Threshold = 1
	}
	if alerts.Cooldown < 0 {
		alerts.Cooldown = 0
	}
	return &aggregator{
		client:              client,
		targets:             targets,
		historySize:         historySize,
		alert:               alerts,
		now:                 time.Now,
		results:             map[string]serviceState{},
		history:             map[string][]sample{},
		lastStatus:          map[string]string{},
		lastTransition:      map[string]time.Time{},
		consecutiveFailures: map[string]int{},
		lastAlertAt:         map[string]time.Time{},
		alertActive:         map[string]bool{},
	}
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

func percentileNearestRank(values []int64, percentile float64) int64 {
	if len(values) == 0 {
		return 0
	}
	sorted := append([]int64(nil), values...)
	sort.Slice(sorted, func(i, j int) bool { return sorted[i] < sorted[j] })
	index := int(math.Ceil(percentile/100*float64(len(sorted)))) - 1
	if index < 0 {
		index = 0
	}
	return sorted[index]
}

func summarizeSamples(samples []sample, transition time.Time, failures int) historySummary {
	summary := historySummary{Samples: len(samples), ConsecutiveFailures: failures}
	if !transition.IsZero() {
		summary.LastTransitionAt = transition.UTC().Format(time.RFC3339)
	}
	if len(samples) == 0 {
		return summary
	}
	latencies := make([]int64, 0, len(samples))
	var latencyTotal int64
	for _, item := range samples {
		latencies = append(latencies, item.LatencyMS)
		latencyTotal += item.LatencyMS
		if item.Status == "online" {
			summary.OnlineSamples++
		}
		if item.Error != "" {
			summary.LastError = item.Error
		}
	}
	summary.AvgLatencyMS = latencyTotal / int64(len(samples))
	summary.P50LatencyMS = percentileNearestRank(latencies, 50)
	summary.P95LatencyMS = percentileNearestRank(latencies, 95)
	summary.UptimePercent = math.Round(float64(summary.OnlineSamples)*1000/float64(len(samples))) / 10
	return summary
}

func (a *aggregator) recordLocked(state serviceState) (serviceState, []alertEvent) {
	name := state.Name
	now := a.now().UTC()
	previous := a.lastStatus[name]
	if previous == "" {
		previous = "unknown"
	}
	a.history[name] = append(a.history[name], sample{Status: state.Status, LatencyMS: state.LatencyMS, CheckedAt: state.CheckedAt, Error: state.Error})
	if len(a.history[name]) > a.historySize {
		a.history[name] = append([]sample(nil), a.history[name][len(a.history[name])-a.historySize:]...)
	}
	if previous != state.Status {
		a.lastTransition[name] = now
	}
	a.lastStatus[name] = state.Status
	if state.Status == "online" {
		a.consecutiveFailures[name] = 0
	} else {
		a.consecutiveFailures[name]++
	}

	summary := summarizeSamples(a.history[name], a.lastTransition[name], a.consecutiveFailures[name])
	state.AvgLatencyMS = summary.AvgLatencyMS
	state.P50LatencyMS = summary.P50LatencyMS
	state.P95LatencyMS = summary.P95LatencyMS
	state.UptimePercent = summary.UptimePercent
	state.LastError = summary.LastError
	state.LastTransitionAt = summary.LastTransitionAt
	state.ConsecutiveFailures = summary.ConsecutiveFailures
	start := 0
	if len(a.history[name]) > 20 {
		start = len(a.history[name]) - 20
	}
	state.LatencySamples = make([]int64, 0, len(a.history[name])-start)
	for _, item := range a.history[name][start:] {
		state.LatencySamples = append(state.LatencySamples, item.LatencyMS)
	}
	state.History = append([]sample(nil), a.history[name][start:]...)
	a.results[name] = state

	if a.alert.Webhook == "" {
		return state, nil
	}
	events := []alertEvent{}
	if state.Status != "online" {
		cooling := !a.lastAlertAt[name].IsZero() && now.Sub(a.lastAlertAt[name]) < a.alert.Cooldown
		if a.consecutiveFailures[name] >= a.alert.Threshold && !a.alertActive[name] && !cooling {
			a.alertActive[name] = true
			a.lastAlertAt[name] = now
			events = append(events, alertEvent{
				Kind:           "degraded",
				Service:        name,
				Status:         state.Status,
				PreviousStatus: previous,
				Error:          state.Error,
				CheckedAt:      state.CheckedAt,
				Message:        fmt.Sprintf("service-portal target %s is %s after %d consecutive failed samples", name, state.Status, a.consecutiveFailures[name]),
			})
		}
		return state, events
	}
	if a.alertActive[name] {
		a.alertActive[name] = false
		a.lastAlertAt[name] = now
		if a.alert.Recovery {
			events = append(events, alertEvent{
				Kind:           "recovery",
				Service:        name,
				Status:         state.Status,
				PreviousStatus: previous,
				CheckedAt:      state.CheckedAt,
				Message:        fmt.Sprintf("service-portal target %s recovered", name),
			})
		}
	}
	return state, events
}

func (a *aggregator) sendAlert(ctx context.Context, event alertEvent) error {
	raw, err := json.Marshal(event)
	if err != nil {
		return err
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, a.alert.Webhook, bytes.NewReader(raw))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Title", "service-portal telemetry: "+event.Service+" "+event.Kind)
	response, err := a.client.Do(req)
	if err != nil {
		return err
	}
	defer response.Body.Close()
	_, _ = io.Copy(io.Discard, io.LimitReader(response.Body, 1024))
	if response.StatusCode < 200 || response.StatusCode > 299 {
		return fmt.Errorf("alert webhook returned %s", response.Status)
	}
	return nil
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
	events := []alertEvent{}
	a.mu.Lock()
	for result := range results {
		var emitted []alertEvent
		result, emitted = a.recordLocked(result)
		events = append(events, emitted...)
	}
	a.mu.Unlock()
	for _, event := range events {
		if err := a.sendAlert(ctx, event); err != nil {
			log.Printf("service-portal-telemetry: alert %s %s: %v", event.Service, event.Kind, err)
			a.mu.Lock()
			if event.Kind == "degraded" {
				a.alertActive[event.Service] = false
			} else if event.Kind == "recovery" {
				a.alertActive[event.Service] = true
			}
			delete(a.lastAlertAt, event.Service)
			a.mu.Unlock()
		}
	}
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

func (a *aggregator) historySnapshot() historyResponse {
	a.mu.RLock()
	defer a.mu.RUnlock()
	services := make(map[string]targetHistory, len(a.targets))
	for _, target := range a.targets {
		samples := append([]sample{}, a.history[target.Name]...)
		services[target.Name] = targetHistory{
			Summary: summarizeSamples(samples, a.lastTransition[target.Name], a.consecutiveFailures[target.Name]),
			Samples: samples,
		}
	}
	return historyResponse{GeneratedAt: time.Now().UTC(), Services: services}
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

func csvExport(snapshot telemetryResponse) ([]byte, error) {
	var output bytes.Buffer
	writer := csv.NewWriter(&output)
	if err := writer.Write([]string{"service", "status", "latency_ms", "avg_latency_ms", "p50_latency_ms", "p95_latency_ms", "uptime_percent", "consecutive_failures", "checked_at", "last_error"}); err != nil {
		return nil, err
	}
	names := make([]string, 0, len(snapshot.Services))
	for name := range snapshot.Services {
		names = append(names, name)
	}
	sort.Strings(names)
	for _, name := range names {
		state := snapshot.Services[name]
		if err := writer.Write([]string{
			name,
			state.Status,
			fmt.Sprint(state.LatencyMS),
			fmt.Sprint(state.AvgLatencyMS),
			fmt.Sprint(state.P50LatencyMS),
			fmt.Sprint(state.P95LatencyMS),
			fmt.Sprintf("%.1f", state.UptimePercent),
			fmt.Sprint(state.ConsecutiveFailures),
			state.CheckedAt.UTC().Format(time.RFC3339),
			state.LastError,
		}); err != nil {
			return nil, err
		}
	}
	writer.Flush()
	return output.Bytes(), writer.Error()
}

func markdownCell(value string) string {
	return strings.ReplaceAll(value, "|", "\\|")
}

func markdownExport(snapshot telemetryResponse) []byte {
	names := make([]string, 0, len(snapshot.Services))
	for name := range snapshot.Services {
		names = append(names, name)
	}
	sort.Strings(names)
	var output strings.Builder
	output.WriteString("# Service portal telemetry\n\n")
	output.WriteString("Generated: " + snapshot.GeneratedAt.UTC().Format(time.RFC3339) + "\n\n")
	output.WriteString("| Service | Status | Latency | Avg | p50 | p95 | Uptime | Last error |\n")
	output.WriteString("| --- | --- | ---: | ---: | ---: | ---: | ---: | --- |\n")
	for _, name := range names {
		state := snapshot.Services[name]
		fmt.Fprintf(&output, "| %s | %s | %d ms | %d ms | %d ms | %d ms | %.1f%% | %s |\n",
			markdownCell(name), state.Status, state.LatencyMS, state.AvgLatencyMS, state.P50LatencyMS, state.P95LatencyMS, state.UptimePercent, markdownCell(state.LastError))
	}
	return []byte(output.String())
}

func exportHandler(agg *aggregator) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		format := strings.ToLower(strings.TrimSpace(r.URL.Query().Get("format")))
		if format == "" {
			format = "json"
		}
		snapshot := agg.snapshot()
		w.Header().Set("Cache-Control", "no-store")
		switch format {
		case "json":
			writeJSON(w, http.StatusOK, map[string]any{"generated_at": snapshot.GeneratedAt, "services": snapshot.Services, "history": agg.historySnapshot().Services})
		case "csv":
			raw, err := csvExport(snapshot)
			if err != nil {
				http.Error(w, err.Error(), http.StatusInternalServerError)
				return
			}
			w.Header().Set("Content-Type", "text/csv; charset=utf-8")
			w.Header().Set("Content-Disposition", `attachment; filename="service-portal-telemetry.csv"`)
			w.WriteHeader(http.StatusOK)
			_, _ = w.Write(raw)
		case "markdown", "md":
			w.Header().Set("Content-Type", "text/markdown; charset=utf-8")
			w.Header().Set("Content-Disposition", `attachment; filename="service-portal-telemetry.md"`)
			w.WriteHeader(http.StatusOK)
			_, _ = w.Write(markdownExport(snapshot))
		default:
			http.Error(w, "format must be json, csv, or markdown", http.StatusBadRequest)
		}
	}
}

func routes(agg *aggregator, targetCount int) *http.ServeMux {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /api/telemetry", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, http.StatusOK, agg.snapshot())
	})
	mux.HandleFunc("GET /api/telemetry/history", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, http.StatusOK, agg.historySnapshot())
	})
	mux.HandleFunc("GET /api/telemetry/export", exportHandler(agg))
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, http.StatusOK, map[string]any{"ok": true, "service": "service-portal-telemetry", "targets": targetCount})
	})
	return mux
}

func main() {
	addr := flag.String("addr", "127.0.0.1:8105", "loopback address to listen on")
	configPath := flag.String("config", "telemetry.json", "JSON telemetry target configuration")
	interval := flag.Duration("interval", 10*time.Second, "poll interval")
	timeout := flag.Duration("timeout", 750*time.Millisecond, "per-request target timeout")
	historySize := flag.Int("history", 144, "per-target ring-buffer sample count")
	alertWebhook := flag.String("alert-webhook", "", "ntfy or webhook URL for telemetry alerts")
	alertCooldown := flag.Duration("alert-cooldown", 15*time.Minute, "minimum time between alert episodes")
	alertThreshold := flag.Int("alert-threshold", 2, "consecutive non-online samples before alerting")
	alertRecovery := flag.Bool("alert-recovery", true, "send a recovery alert when an alerted target returns online")
	flag.Parse()

	cfg, err := loadConfig(*configPath)
	if err != nil {
		log.Fatalf("service-portal-telemetry: config: %v", err)
	}
	webhook := strings.TrimSpace(*alertWebhook)
	if webhook == "" {
		webhook = strings.TrimSpace(os.Getenv("SERVICE_PORTAL_ALERT_WEBHOOK"))
	}
	client := &http.Client{Timeout: *timeout}
	agg := newAggregatorWithOptions(client, cfg.Targets, *historySize, alertConfig{
		Webhook:   webhook,
		Cooldown:  *alertCooldown,
		Threshold: *alertThreshold,
		Recovery:  *alertRecovery,
	})
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go agg.run(ctx, *interval)

	log.Printf("service-portal-telemetry: listening on %s, targets %d, interval %s", *addr, len(cfg.Targets), *interval)
	if err := http.ListenAndServe(*addr, routes(agg, len(cfg.Targets))); err != nil {
		log.Fatal(err)
	}
}
