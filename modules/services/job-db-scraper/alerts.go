package main

import (
	"context"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"
)

type alertManager struct {
	store    *Store
	ntfyURL  string
	minScore int
	client   *http.Client
}

func newAlertManager(store *Store, ntfyURL string, minScore int) *alertManager {
	if minScore <= 0 {
		minScore = 80
	}
	if minScore > 100 {
		minScore = 100
	}
	return &alertManager{store: store, ntfyURL: strings.TrimSpace(ntfyURL), minScore: minScore, client: &http.Client{Timeout: 10 * time.Second}}
}

func (m *alertManager) enabled() bool { return m != nil && m.ntfyURL != "" }

func (m *alertManager) evaluate(ctx context.Context, notify bool) (notifySummary, error) {
	summary := notifySummary{}
	if m == nil {
		return summary, fmt.Errorf("alert manager is not configured")
	}
	evaluation, err := m.store.EvaluateHighScoreAlerts(ctx, m.minScore, 100)
	if err != nil {
		return summary, err
	}
	summary.Matched = evaluation.Matched
	summary.Created = evaluation.Created
	summary.Existing = evaluation.Existing
	if !notify || !m.enabled() {
		return summary, nil
	}
	for _, alert := range evaluation.Alerts {
		if alert.Status == "sent" {
			continue
		}
		if err := m.postNtfy(ctx, alert); err != nil {
			summary.Failed++
			_ = m.store.MarkJobAlertNotification(ctx, alert.ID, false, err.Error())
			continue
		}
		summary.Notified++
		_ = m.store.MarkJobAlertNotification(ctx, alert.ID, true, "")
	}
	return summary, nil
}

func (m *alertManager) postNtfy(ctx context.Context, alert JobAlert) error {
	body := fmt.Sprintf("%s at %s scored %d/100\n%s", alert.Title, alert.Company, alert.Score, alert.URL)
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, m.ntfyURL, strings.NewReader(body))
	if err != nil {
		return err
	}
	req.Header.Set("Title", "job-db-scraper high-score role")
	req.Header.Set("Priority", "4")
	req.Header.Set("Tags", "briefcase,star")
	res, err := m.client.Do(req)
	if err != nil {
		return err
	}
	defer res.Body.Close()
	raw, _ := io.ReadAll(io.LimitReader(res.Body, 1024))
	if res.StatusCode < 200 || res.StatusCode > 299 {
		return fmt.Errorf("notification endpoint: HTTP %s: %s", res.Status, strings.TrimSpace(string(raw)))
	}
	return nil
}
