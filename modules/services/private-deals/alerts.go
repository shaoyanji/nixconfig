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
	store   *Store
	ntfyURL string
	client  *http.Client
}

func newAlertManager(store *Store, ntfyURL string) *alertManager {
	return &alertManager{store: store, ntfyURL: strings.TrimSpace(ntfyURL), client: &http.Client{Timeout: 10 * time.Second}}
}

func (m *alertManager) enabled() bool { return m != nil && m.ntfyURL != "" }

func (m *alertManager) evaluate(ctx context.Context, notify bool) (notifySummary, error) {
	summary := notifySummary{}
	if m == nil {
		return summary, fmt.Errorf("alert manager is not configured")
	}
	evaluation, err := m.store.EvaluateWatchlistAlerts(ctx, 200)
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
		err := m.postNtfy(ctx, alert)
		if err == nil {
			summary.Notified++
			_ = m.store.MarkAlertNotification(ctx, alert.ID, true, "")
			continue
		}
		summary.Failed++
		_ = m.store.MarkAlertNotification(ctx, alert.ID, false, err.Error())
	}
	return summary, nil
}

func (m *alertManager) postNtfy(ctx context.Context, alert DealAlert) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, m.ntfyURL, strings.NewReader(alert.Message+"\n"+alert.Title))
	if err != nil {
		return err
	}
	req.Header.Set("Title", "private-deals: "+alert.ProductName)
	req.Header.Set("Priority", "4")
	req.Header.Set("Tags", "moneybag,chart_with_downwards_trend")
	req.Header.Set("X-Deal-ID", fmt.Sprintf("%d", alert.DealID))
	res, err := m.client.Do(req)
	if err != nil {
		return err
	}
	defer res.Body.Close()
	body, _ := io.ReadAll(io.LimitReader(res.Body, 1024))
	if res.StatusCode < 200 || res.StatusCode > 299 {
		return fmt.Errorf("notification endpoint: HTTP %s: %s", res.Status, strings.TrimSpace(string(body)))
	}
	return nil
}
