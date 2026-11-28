package main

import (
	"context"
	"fmt"
	"strings"
	"time"
)

type assetEvent struct {
	ID           int64     `json:"id"`
	ItemID       int64     `json:"item_id"`
	Kind         string    `json:"kind"`
	Summary      string    `json:"summary"`
	Actor        string    `json:"actor,omitempty"`
	FromLocation string    `json:"from_location,omitempty"`
	ToLocation   string    `json:"to_location,omitempty"`
	Note         string    `json:"note,omitempty"`
	CreatedAt    time.Time `json:"created_at"`
}

type assetEventInput struct {
	Kind     string `json:"kind"`
	Summary  string `json:"summary"`
	Actor    string `json:"actor"`
	Location string `json:"location"`
	Note     string `json:"note"`
}

func validEventKind(kind string) bool {
	switch kind {
	case "create", "update", "location-move", "checkout", "checkin", "return", "maintenance", "note", "audit":
		return true
	default:
		return false
	}
}

func validateAssetEvent(input *assetEventInput) error {
	input.Kind = strings.ToLower(clean(input.Kind))
	input.Summary = clean(input.Summary)
	input.Actor = clean(input.Actor)
	input.Location = clean(input.Location)
	input.Note = strings.TrimSpace(input.Note)
	if !validEventKind(input.Kind) {
		return fmt.Errorf("kind must be checkout, checkin, return, maintenance, note or audit")
	}
	if input.Actor == "" {
		input.Actor = "manual"
	}
	if input.Summary == "" {
		switch input.Kind {
		case "checkout":
			input.Summary = "asset checked out"
		case "checkin", "return":
			input.Summary = "asset returned"
		case "maintenance":
			input.Summary = "maintenance recorded"
		case "note":
			input.Summary = "note recorded"
		default:
			input.Summary = "audit event recorded"
		}
	}
	if len(input.Summary) > 240 {
		return fmt.Errorf("summary is too long")
	}
	return nil
}

func (s *Store) insertAssetEvent(ctx context.Context, event assetEvent) (int64, error) {
	if event.Kind == "" || event.ItemID == 0 {
		return 0, fmt.Errorf("asset event requires item_id and kind")
	}
	now := nowString()
	result, err := s.db.ExecContext(ctx, `INSERT INTO asset_events
		(item_id, kind, summary, actor, from_location, to_location, note, created_at)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
		event.ItemID, event.Kind, event.Summary, event.Actor, event.FromLocation, event.ToLocation, event.Note, now)
	if err != nil {
		return 0, err
	}
	return result.LastInsertId()
}

func (s *Store) AddAssetEvent(ctx context.Context, itemID int64, input assetEventInput) (assetEvent, error) {
	if err := validateAssetEvent(&input); err != nil {
		return assetEvent{}, err
	}
	item, err := s.GetItem(ctx, itemID)
	if err != nil {
		return assetEvent{}, err
	}
	fromLocation := item.Location
	toLocation := input.Location
	if toLocation != "" && toLocation != item.Location {
		inputCopy := inputFromItem(item)
		inputCopy.Location = toLocation
		now := nowString()
		if _, err := s.db.ExecContext(ctx, `UPDATE items SET location = ?, updated_at = ? WHERE id = ?`, toLocation, now, itemID); err != nil {
			return assetEvent{}, err
		}
		if err := s.replaceTagsAndFTS(ctx, itemID, inputCopy); err != nil {
			return assetEvent{}, err
		}
		if err := s.UpsertMeta(ctx, "locations", toLocation, ""); err != nil {
			return assetEvent{}, err
		}
	}
	event := assetEvent{
		ItemID: itemID, Kind: input.Kind, Summary: input.Summary, Actor: input.Actor,
		FromLocation: fromLocation, ToLocation: toLocation, Note: input.Note,
	}
	id, err := s.insertAssetEvent(ctx, event)
	if err != nil {
		return assetEvent{}, err
	}
	event.ID = id
	event.CreatedAt = time.Now().UTC()
	return event, nil
}

func (s *Store) ListAssetEvents(ctx context.Context, itemID int64, limit int) ([]assetEvent, error) {
	if limit <= 0 {
		limit = 100
	}
	if limit > 500 {
		limit = 500
	}
	rows, err := s.db.QueryContext(ctx, `SELECT id, item_id, kind, summary, actor, from_location, to_location, note, created_at
		FROM asset_events WHERE item_id = ? ORDER BY id DESC LIMIT ?`, itemID, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	events := []assetEvent{}
	for rows.Next() {
		var event assetEvent
		var created string
		if err := rows.Scan(&event.ID, &event.ItemID, &event.Kind, &event.Summary, &event.Actor,
			&event.FromLocation, &event.ToLocation, &event.Note, &created); err != nil {
			return nil, err
		}
		event.CreatedAt = parseDBTime(created)
		events = append(events, event)
	}
	return events, rows.Err()
}

func sameStrings(a, b []string) bool {
	if len(a) != len(b) {
		return false
	}
	for i := range a {
		if a[i] != b[i] {
			return false
		}
	}
	return true
}

func changedItemFields(before itemInput, after itemInput) []string {
	changed := []string{}
	fields := []struct {
		name string
		a    string
		b    string
	}{
		{"source", before.Source, after.Source}, {"source_key", before.SourceKey, after.SourceKey},
		{"name", before.Name, after.Name}, {"category", before.Category, after.Category},
		{"location", before.Location, after.Location}, {"description", before.Description, after.Description},
		{"manufacturer", before.Manufacturer, after.Manufacturer}, {"model", before.Model, after.Model},
		{"serial", before.Serial, after.Serial}, {"purchase_date", before.PurchaseDate, after.PurchaseDate},
		{"warranty_until", before.WarrantyUntil, after.WarrantyUntil}, {"currency", before.Currency, after.Currency},
		{"url", before.URL, after.URL}, {"notes", before.Notes, after.Notes},
	}
	for _, field := range fields {
		if field.a != field.b {
			changed = append(changed, field.name)
		}
	}
	if before.ValueCents != after.ValueCents {
		changed = append(changed, "value")
	}
	if before.Quantity != after.Quantity {
		changed = append(changed, "quantity")
	}
	if before.Archived != after.Archived {
		changed = append(changed, "archived")
	}
	if !sameStrings(normalizeTags(before.Tags), normalizeTags(after.Tags)) {
		changed = append(changed, "tags")
	}
	return changed
}

func (s *Store) logAutomaticEvents(ctx context.Context, id int64, created bool, before itemInput, after itemInput) {
	if created {
		_, _ = s.insertAssetEvent(ctx, assetEvent{
			ItemID: id, Kind: "create", Summary: "asset created", Actor: after.Source, ToLocation: after.Location,
		})
		return
	}
	changed := changedItemFields(before, after)
	if len(changed) == 0 {
		return
	}
	if before.Location != after.Location {
		_, _ = s.insertAssetEvent(ctx, assetEvent{
			ItemID: id, Kind: "location-move", Summary: fmt.Sprintf("location changed from %s to %s", blankAsDash(before.Location), blankAsDash(after.Location)),
			Actor: after.Source, FromLocation: before.Location, ToLocation: after.Location,
		})
	}
	nonLocation := []string{}
	for _, field := range changed {
		if field != "location" {
			nonLocation = append(nonLocation, field)
		}
	}
	if len(nonLocation) > 0 {
		_, _ = s.insertAssetEvent(ctx, assetEvent{
			ItemID: id, Kind: "update", Summary: "updated " + strings.Join(nonLocation, ", "), Actor: after.Source,
		})
	}
}

func blankAsDash(value string) string {
	if strings.TrimSpace(value) == "" {
		return "unplaced"
	}
	return value
}
