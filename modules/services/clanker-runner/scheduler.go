package main

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"
)

type Schedule struct {
	ID              int64           `json:"id"`
	Name            string          `json:"name"`
	PresetID        string          `json:"preset_id"`
	Machine         string          `json:"machine"`
	Params          json.RawMessage `json:"params"`
	IntervalSeconds int             `json:"interval_seconds"`
	Enabled         bool            `json:"enabled"`
	NextRunAt       time.Time       `json:"next_run_at"`
	LastRunAt       *time.Time      `json:"last_run_at,omitempty"`
	LastJobID       string          `json:"last_job_id,omitempty"`
	LastError       string          `json:"last_error,omitempty"`
	CreatedAt       time.Time       `json:"created_at"`
	UpdatedAt       time.Time       `json:"updated_at"`
}

type scheduleInput struct {
	Name             string          `json:"name"`
	PresetID         string          `json:"preset_id"`
	Machine          string          `json:"machine"`
	Params           json.RawMessage `json:"params"`
	IntervalSeconds  int             `json:"interval_seconds"`
	Enabled          *bool           `json:"enabled"`
	StartImmediately bool            `json:"start_immediately"`
}

func dbTime(value time.Time) string { return value.UTC().Format(time.RFC3339) }

func scanSchedule(row interface{ Scan(...any) error }) (Schedule, error) {
	var schedule Schedule
	var params string
	var enabled int
	var next, last, created, updated string
	err := row.Scan(&schedule.ID, &schedule.Name, &schedule.PresetID, &schedule.Machine, &params, &schedule.IntervalSeconds,
		&enabled, &next, &last, &schedule.LastJobID, &schedule.LastError, &created, &updated)
	if err != nil {
		return schedule, err
	}
	schedule.Params = json.RawMessage(params)
	schedule.Enabled = enabled != 0
	schedule.NextRunAt, _ = time.Parse(time.RFC3339, next)
	if last != "" {
		if parsed, err := time.Parse(time.RFC3339, last); err == nil {
			schedule.LastRunAt = &parsed
		}
	}
	schedule.CreatedAt, _ = time.Parse(time.RFC3339, created)
	schedule.UpdatedAt, _ = time.Parse(time.RFC3339, updated)
	return schedule, nil
}

const scheduleColumns = `id,name,preset_id,machine,params_json,interval_seconds,enabled,next_run_at,last_run_at,last_job_id,last_error,created_at,updated_at`

func validateScheduleInput(input *scheduleInput) error {
	input.Name = strings.TrimSpace(input.Name)
	input.PresetID = strings.TrimSpace(input.PresetID)
	preset, ok := presetByID(input.PresetID)
	if !ok {
		return fmt.Errorf("preset_id must be one of the validated presets")
	}
	if input.Name == "" {
		input.Name = preset.Name
	}
	if len(input.Name) > 120 {
		return errors.New("schedule name is too long")
	}
	machine, err := validateMachineName(input.Machine)
	if err != nil {
		return err
	}
	input.Machine = machine
	if input.IntervalSeconds < 15 || input.IntervalSeconds > 7*24*3600 {
		return errors.New("interval_seconds must be between 15 and 604800")
	}
	if len(input.Params) == 0 {
		input.Params = json.RawMessage(`{}`)
	}
	presetValues, err := presetInputFromParams(input.Params)
	if err != nil {
		return fmt.Errorf("params: %w", err)
	}
	presetValues.Machine = input.Machine
	if _, err := buildPresetJob(input.PresetID, presetValues); err != nil {
		return fmt.Errorf("params: %w", err)
	}
	return nil
}

func (s *Store) CreateSchedule(ctx context.Context, input scheduleInput) (Schedule, error) {
	enabled := true
	if input.Enabled != nil {
		enabled = *input.Enabled
	}
	now := time.Now().UTC()
	next := now.Add(time.Duration(input.IntervalSeconds) * time.Second)
	if input.StartImmediately {
		next = now
	}
	result, err := s.db.ExecContext(ctx, `INSERT INTO schedules
		(name,preset_id,machine,params_json,interval_seconds,enabled,next_run_at,created_at,updated_at)
		VALUES (?,?,?,?,?,?,?,?,?)`, input.Name, input.PresetID, input.Machine, string(input.Params), input.IntervalSeconds,
		boolInt(enabled), dbTime(next), dbTime(now), dbTime(now))
	if err != nil {
		return Schedule{}, err
	}
	id, err := result.LastInsertId()
	if err != nil {
		return Schedule{}, err
	}
	return s.GetSchedule(ctx, id)
}

func boolInt(value bool) int {
	if value {
		return 1
	}
	return 0
}

func (s *Store) GetSchedule(ctx context.Context, id int64) (Schedule, error) {
	return scanSchedule(s.db.QueryRowContext(ctx, `SELECT `+scheduleColumns+` FROM schedules WHERE id=?`, id))
}

func (s *Store) ListSchedules(ctx context.Context) ([]Schedule, error) {
	rows, err := s.db.QueryContext(ctx, `SELECT `+scheduleColumns+` FROM schedules ORDER BY enabled DESC,next_run_at,id`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	items := []Schedule{}
	for rows.Next() {
		item, err := scanSchedule(rows)
		if err != nil {
			return nil, err
		}
		items = append(items, item)
	}
	return items, rows.Err()
}

func (s *Store) DeleteSchedule(ctx context.Context, id int64) error {
	result, err := s.db.ExecContext(ctx, `DELETE FROM schedules WHERE id=?`, id)
	if err != nil {
		return err
	}
	affected, _ := result.RowsAffected()
	if affected == 0 {
		return sql.ErrNoRows
	}
	return nil
}

func (s *Store) dueSchedules(ctx context.Context, now time.Time) ([]Schedule, error) {
	rows, err := s.db.QueryContext(ctx, `SELECT `+scheduleColumns+` FROM schedules WHERE enabled=1 AND next_run_at <= ? ORDER BY next_run_at,id LIMIT 20`, dbTime(now))
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	items := []Schedule{}
	for rows.Next() {
		item, err := scanSchedule(rows)
		if err != nil {
			return nil, err
		}
		items = append(items, item)
	}
	return items, rows.Err()
}

func (s *Store) markScheduleRun(ctx context.Context, schedule Schedule, ranAt time.Time, jobID string, runErr error) error {
	message := ""
	if runErr != nil {
		message = runErr.Error()
		if len(message) > 400 {
			message = message[:400]
		}
	}
	next := ranAt.Add(time.Duration(schedule.IntervalSeconds) * time.Second)
	_, err := s.db.ExecContext(ctx, `UPDATE schedules SET last_run_at=?,next_run_at=?,last_job_id=?,last_error=?,updated_at=? WHERE id=?`,
		dbTime(ranAt), dbTime(next), jobID, message, dbTime(ranAt), schedule.ID)
	return err
}

func (s *server) runDueSchedules(ctx context.Context, now time.Time) (int, error) {
	due, err := s.store.dueSchedules(ctx, now)
	if err != nil {
		return 0, err
	}
	ran := 0
	for _, schedule := range due {
		jobID := ""
		runErr := s.runScheduleOnce(ctx, schedule, &jobID)
		if runErr == nil {
			ran++
		}
		if err := s.store.markScheduleRun(ctx, schedule, now, jobID, runErr); err != nil {
			return ran, err
		}
	}
	return ran, nil
}

func (s *server) runScheduleOnce(ctx context.Context, schedule Schedule, jobID *string) error {
	values, err := presetInputFromParams(schedule.Params)
	if err != nil {
		return err
	}
	values.Machine = schedule.Machine
	input, err := buildPresetJob(schedule.PresetID, values)
	if err != nil {
		return err
	}
	kind, command, err := buildJobCommand(input)
	if err != nil {
		return err
	}
	machine, err := s.client.ResolveMachine(ctx, input.Machine)
	if err != nil {
		return err
	}
	job, err := s.queuePreparedJob(ctx, machine, kind, command, input.Machine)
	if err != nil {
		return err
	}
	*jobID = job.ID
	return nil
}
