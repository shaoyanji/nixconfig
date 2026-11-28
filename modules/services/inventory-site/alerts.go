package main

import (
	"context"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"
)

type WarrantyAlert struct {
	ID             int64     `json:"id"`
	ItemID         int64     `json:"item_id"`
	ItemName       string    `json:"item_name"`
	WarrantyUntil  string    `json:"warranty_until"`
	Status         string    `json:"status"`
	NotifyCount    int       `json:"notify_count"`
	LastNotifiedAt string    `json:"last_notified_at,omitempty"`
	LastError      string    `json:"last_error,omitempty"`
	CreatedAt      time.Time `json:"created_at"`
	UpdatedAt      time.Time `json:"updated_at"`
}

type warrantyEvaluation struct {
	Matched  int             `json:"matched"`
	Created  int             `json:"created"`
	Existing int             `json:"existing"`
	Alerts   []WarrantyAlert `json:"alerts,omitempty"`
}

type notifySummary struct {
	Matched  int `json:"matched"`
	Created  int `json:"created"`
	Existing int `json:"existing"`
	Notified int `json:"notified"`
	Failed   int `json:"failed"`
}

func scanWarrantyAlert(row scanner) (WarrantyAlert, error) {
	var alert WarrantyAlert
	var created, updated string
	err := row.Scan(&alert.ID, &alert.ItemID, &alert.ItemName, &alert.WarrantyUntil, &alert.Status,
		&alert.NotifyCount, &alert.LastNotifiedAt, &alert.LastError, &created, &updated)
	alert.CreatedAt = parseDBTime(created)
	alert.UpdatedAt = parseDBTime(updated)
	return alert, err
}

const warrantyAlertColumns = `id, item_id, item_name, warranty_until, status, notify_count, last_notified_at, last_error, created_at, updated_at`

func (s *Store) EvaluateWarrantyAlerts(ctx context.Context, warnDays int, limit int) (warrantyEvaluation, error) {
	if warnDays <= 0 {
		warnDays = 30
	}
	if limit <= 0 {
		limit = 100
	}
	rows, err := s.db.QueryContext(ctx, `SELECT id, name, warranty_until FROM items
		WHERE archived = 0 AND warranty_until != '' AND date(warranty_until) <= date('now', '+' || ? || ' days')
		ORDER BY date(warranty_until), id LIMIT ?`, warnDays, limit)
	if err != nil {
		return warrantyEvaluation{}, err
	}
	type dueItem struct {
		id       int64
		name     string
		warranty string
	}
	due := []dueItem{}
	for rows.Next() {
		var item dueItem
		if err := rows.Scan(&item.id, &item.name, &item.warranty); err != nil {
			rows.Close()
			return warrantyEvaluation{}, err
		}
		due = append(due, item)
	}
	if err := rows.Close(); err != nil {
		return warrantyEvaluation{}, err
	}
	evaluation := warrantyEvaluation{Matched: len(due), Alerts: []WarrantyAlert{}}
	now := nowString()
	for _, item := range due {
		result, err := s.db.ExecContext(ctx, `INSERT INTO warranty_alerts
			(item_id, warranty_until, item_name, status, created_at, updated_at) VALUES (?, ?, ?, 'pending', ?, ?)
			ON CONFLICT(item_id, warranty_until) DO NOTHING`, item.id, item.warranty, item.name, now, now)
		if err != nil {
			return evaluation, err
		}
		affected, _ := result.RowsAffected()
		if affected > 0 {
			evaluation.Created++
		} else {
			evaluation.Existing++
		}
		var alert WarrantyAlert
		row := s.db.QueryRowContext(ctx, `SELECT `+warrantyAlertColumns+` FROM warranty_alerts WHERE item_id = ? AND warranty_until = ?`, item.id, item.warranty)
		alert, err = scanWarrantyAlert(row)
		if err != nil {
			return evaluation, err
		}
		if alert.ItemName != item.name {
			_, _ = s.db.ExecContext(ctx, `UPDATE warranty_alerts SET item_name = ?, updated_at = ? WHERE id = ?`, item.name, now, alert.ID)
			alert.ItemName = item.name
		}
		if alert.Status != "sent" {
			evaluation.Alerts = append(evaluation.Alerts, alert)
		}
	}
	return evaluation, nil
}

func (s *Store) MarkWarrantyAlertNotification(ctx context.Context, id int64, success bool, message string) error {
	now := nowString()
	if success {
		_, err := s.db.ExecContext(ctx, `UPDATE warranty_alerts SET status='sent', notify_count=notify_count+1, last_notified_at=?, last_error='', updated_at=? WHERE id=?`, now, now, id)
		return err
	}
	if len(message) > 400 {
		message = message[:400]
	}
	_, err := s.db.ExecContext(ctx, `UPDATE warranty_alerts SET status='failed', last_error=?, updated_at=? WHERE id=?`, message, now, id)
	return err
}

func (s *Store) ListWarrantyAlerts(ctx context.Context, limit int) ([]WarrantyAlert, error) {
	if limit <= 0 {
		limit = 100
	}
	if limit > 500 {
		limit = 500
	}
	rows, err := s.db.QueryContext(ctx, `SELECT `+warrantyAlertColumns+` FROM warranty_alerts ORDER BY date(warranty_until), id DESC LIMIT ?`, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	alerts := []WarrantyAlert{}
	for rows.Next() {
		alert, err := scanWarrantyAlert(rows)
		if err != nil {
			return nil, err
		}
		alerts = append(alerts, alert)
	}
	return alerts, rows.Err()
}

type warrantyAlertManager struct {
	store    *Store
	ntfyURL  string
	warnDays int
	client   *http.Client
}

func newWarrantyAlertManager(store *Store, ntfyURL string, warnDays int) *warrantyAlertManager {
	if warnDays <= 0 {
		warnDays = 30
	}
	return &warrantyAlertManager{store: store, ntfyURL: strings.TrimSpace(ntfyURL), warnDays: warnDays, client: &http.Client{Timeout: 10 * time.Second}}
}

func (m *warrantyAlertManager) enabled() bool { return m != nil && m.ntfyURL != "" }

func (m *warrantyAlertManager) evaluate(ctx context.Context, notify bool) (notifySummary, error) {
	summary := notifySummary{}
	if m == nil {
		return summary, fmt.Errorf("warranty alert manager is not configured")
	}
	evaluation, err := m.store.EvaluateWarrantyAlerts(ctx, m.warnDays, 100)
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
		if err := m.postNtfy(ctx, alert); err != nil {
			summary.Failed++
			_ = m.store.MarkWarrantyAlertNotification(ctx, alert.ID, false, err.Error())
			continue
		}
		summary.Notified++
		_ = m.store.MarkWarrantyAlertNotification(ctx, alert.ID, true, "")
	}
	return summary, nil
}

func (m *warrantyAlertManager) postNtfy(ctx context.Context, alert WarrantyAlert) error {
	body := fmt.Sprintf("%s warranty ends %s\nOpen the inventory detail or QR label for asset #%d.", alert.ItemName, alert.WarrantyUntil, alert.ItemID)
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, m.ntfyURL, strings.NewReader(body))
	if err != nil {
		return err
	}
	req.Header.Set("Title", "inventory-site warranty expiry")
	req.Header.Set("Priority", "4")
	req.Header.Set("Tags", "shield,warning")
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
