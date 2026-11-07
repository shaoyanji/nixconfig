package main

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"net/http"
	"strings"
	"time"

	_ "modernc.org/sqlite"
)

// The store is reached over its Unix socket only; this process never speaks TCP
// to xs. A Unix-socket HTTP client is five lines of DialContext, so there is no
// dependency to audit for it.
type xsStore struct {
	socket string
	client *http.Client
}

func newXSStore(socket string) *xsStore {
	transport := &http.Transport{
		DialContext: func(ctx context.Context, _, _ string) (net.Conn, error) {
			dialer := net.Dialer{Timeout: 10 * time.Second}
			return dialer.DialContext(ctx, "unix", socket)
		},
		MaxIdleConns:    4,
		IdleConnTimeout: 30 * time.Second,
	}
	return &xsStore{socket: socket, client: &http.Client{Transport: transport, Timeout: 10 * time.Second}}
}

func (s *xsStore) do(method, path string, body []byte) (int, []byte, error) {
	var reader io.Reader
	if body != nil {
		reader = strings.NewReader(string(body))
	}
	req, err := http.NewRequest(method, "http://localhost"+path, reader)
	if err != nil {
		return 0, nil, err
	}
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	resp, err := s.client.Do(req)
	if err != nil {
		return 0, nil, err
	}
	defer resp.Body.Close()
	payload, err := io.ReadAll(resp.Body)
	if err != nil {
		return resp.StatusCode, nil, err
	}
	return resp.StatusCode, payload, nil
}

// append stores one frame and answers its id. `/append` names the topic in the
// path and `ttl=forever` is the promise: a turn does not expire.
func (s *xsStore) append(topic string, payload []byte) (string, error) {
	status, body, err := s.do("POST", fmt.Sprintf("/append/%s?ttl=forever", topic), payload)
	if err != nil {
		return "", err
	}
	if status != http.StatusOK {
		return "", fmt.Errorf("xs append failed: HTTP %d", status)
	}
	var frame struct {
		ID string `json:"id"`
	}
	if err := json.Unmarshal(body, &frame); err != nil {
		return "", err
	}
	return frame.ID, nil
}

type frame struct {
	Hash *string `json:"hash"`
	ID   string  `json:"id"`
}

// last reads frames in the order the store returns them (oldest first for the
// last N), which is the order the HTTP contract reverses.
func (s *xsStore) last(topic string, limit int) ([]frame, error) {
	status, body, err := s.do("GET", fmt.Sprintf("/last/%s?last=%d", topic, limit), nil)
	if err != nil {
		return nil, err
	}
	if status == http.StatusNotFound {
		return nil, nil
	}
	if status != http.StatusOK {
		return nil, fmt.Errorf("xs read failed: HTTP %d", status)
	}
	var frames []frame
	for _, line := range strings.Split(string(body), "\n") {
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}
		var f frame
		if err := json.Unmarshal([]byte(line), &f); err != nil {
			return nil, err
		}
		frames = append(frames, f)
	}
	return frames, nil
}

// content fetches one frame's body. Raw, not percent-encoded: the store matches
// the path segment verbatim, and a base64 hash with a '/' in it still routes
// (measured against xs 0.14.2).
func (s *xsStore) content(hash string) (map[string]any, error) {
	status, body, err := s.do("GET", "/cas/"+hash, nil)
	if err != nil {
		return nil, err
	}
	if status != http.StatusOK {
		return nil, nil
	}
	var entry map[string]any
	if err := json.Unmarshal(body, &entry); err != nil {
		return nil, nil
	}
	return entry, nil
}

// dedup is the retry key: a client-generated UUID maps to the frame it produced,
// so a replay answers 200 with the stored id instead of appending a second turn.
type dedup struct {
	db *sql.DB
}

func openDedup(path string) (*dedup, error) {
	dsn := "file:" + path + "?_pragma=journal_mode(WAL)&_pragma=synchronous(FULL)&_pragma=busy_timeout(10000)"
	db, err := sql.Open("sqlite", dsn)
	if err != nil {
		return nil, err
	}
	// One writer: the append path is serialized by this connection, which is what
	// makes the placeholder-then-fill sequence safe without a second lock.
	db.SetMaxOpenConns(1)
	if _, err := db.Exec(`CREATE TABLE IF NOT EXISTS turn_dedup (
		client_uuid TEXT PRIMARY KEY, frame_id TEXT NOT NULL, created_at TEXT NOT NULL)`); err != nil {
		db.Close()
		return nil, err
	}
	return &dedup{db: db}, nil
}

func (d *dedup) lookup(clientUUID string) (string, bool, error) {
	var frameID string
	err := d.db.QueryRow("SELECT frame_id FROM turn_dedup WHERE client_uuid = ?", clientUUID).Scan(&frameID)
	if err == sql.ErrNoRows {
		return "", false, nil
	}
	if err != nil {
		return "", false, err
	}
	return frameID, true, nil
}

func (d *dedup) reserve(clientUUID string) error {
	_, err := d.db.Exec(
		"INSERT INTO turn_dedup (client_uuid, frame_id, created_at) VALUES (?, ?, ?)",
		clientUUID, "", time.Now().UTC().Format(time.RFC3339Nano),
	)
	return err
}

func (d *dedup) fill(clientUUID, frameID string) error {
	_, err := d.db.Exec("UPDATE turn_dedup SET frame_id = ? WHERE client_uuid = ?", frameID, clientUUID)
	return err
}

func (d *dedup) forget(clientUUID string) error {
	_, err := d.db.Exec("DELETE FROM turn_dedup WHERE client_uuid = ?", clientUUID)
	return err
}
