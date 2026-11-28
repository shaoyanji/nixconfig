package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"
)

type instaboxClient struct {
	baseURL string
	apiKey  string
	http    *http.Client
}

func newInstaboxClient(baseURL, apiKey string) *instaboxClient {
	baseURL = strings.TrimRight(strings.TrimSpace(baseURL), "/")
	if baseURL == "" {
		baseURL = "https://api.instabox.sh"
	}
	return &instaboxClient{baseURL: baseURL, apiKey: strings.TrimSpace(apiKey), http: &http.Client{Timeout: 120 * time.Second}}
}

func (c *instaboxClient) configured() bool { return c != nil && c.apiKey != "" }

func (c *instaboxClient) request(ctx context.Context, method, path string, payload any, out any) error {
	if !c.configured() {
		return fmt.Errorf("INSTABOX_API_KEY is not configured")
	}
	var body io.Reader
	if payload != nil {
		raw, err := json.Marshal(payload)
		if err != nil {
			return err
		}
		body = bytes.NewReader(raw)
	}
	req, err := http.NewRequestWithContext(ctx, method, c.baseURL+path, body)
	if err != nil {
		return err
	}
	req.Header.Set("X-API-Key", c.apiKey)
	req.Header.Set("Content-Type", "application/json")
	res, err := c.http.Do(req)
	if err != nil {
		return err
	}
	defer res.Body.Close()
	raw, _ := io.ReadAll(io.LimitReader(res.Body, 4<<20))
	if res.StatusCode < 200 || res.StatusCode > 299 {
		message := strings.TrimSpace(string(raw))
		var apiErr apiErrorBody
		if json.Unmarshal(raw, &apiErr) == nil && apiErr.Error.Message != "" {
			message = apiErr.Error.Code + ": " + apiErr.Error.Message
		}
		if len(message) > 600 {
			message = message[:600]
		}
		message = strings.ReplaceAll(message, c.apiKey, "[redacted]")
		return fmt.Errorf("instabox API %s %s: HTTP %s: %s", method, path, res.Status, message)
	}
	if out == nil || len(raw) == 0 {
		return nil
	}
	if err := json.Unmarshal(raw, out); err != nil {
		return fmt.Errorf("decode instabox API response: %w", err)
	}
	return nil
}

func machineFromWire(w machineWire) Machine {
	return Machine{ID: w.ID, Name: w.Name, State: w.State, VCPUs: w.Spec.VCPUs, MemMiB: w.Spec.MemMiB, PersistentDiskGiB: w.Spec.PersistentDiskGiB, AutoSuspendAfterSeconds: w.AutoSuspendAfterSeconds}
}

func (c *instaboxClient) ListMachines(ctx context.Context) ([]Machine, error) {
	var payload machineListResponse
	if err := c.request(ctx, http.MethodGet, "/v1/machines", nil, &payload); err != nil {
		return nil, err
	}
	out := make([]Machine, 0, len(payload.Machines))
	for _, machine := range payload.Machines {
		out = append(out, machineFromWire(machine))
	}
	return out, nil
}

func (c *instaboxClient) GetMachine(ctx context.Context, id string) (Machine, error) {
	var wire machineWire
	if err := c.request(ctx, http.MethodGet, "/v1/machines/"+id, nil, &wire); err != nil {
		return Machine{}, err
	}
	return machineFromWire(wire), nil
}

func (c *instaboxClient) ResolveMachine(ctx context.Context, nameOrID string) (Machine, error) {
	nameOrID = strings.TrimSpace(nameOrID)
	if nameOrID == "" {
		nameOrID = "clanker"
	}
	if strings.HasPrefix(nameOrID, "m_") {
		return c.GetMachine(ctx, nameOrID)
	}
	machines, err := c.ListMachines(ctx)
	if err != nil {
		return Machine{}, err
	}
	for _, machine := range machines {
		if machine.Name == nameOrID {
			return machine, nil
		}
	}
	return Machine{}, fmt.Errorf("no machine named %q in this workspace", nameOrID)
}

func (c *instaboxClient) MachineAction(ctx context.Context, id, action string) error {
	switch action {
	case "wake", "start", "stop", "suspend", "resume":
	default:
		return fmt.Errorf("unsupported machine action %q", action)
	}
	return c.request(ctx, http.MethodPost, "/v1/machines/"+id+"/"+action, map[string]any{}, nil)
}

func (c *instaboxClient) Exec(ctx context.Context, id, command string) (execResponse, error) {
	var out execResponse
	err := c.request(ctx, http.MethodPost, "/v1/machines/"+id+"/exec", map[string]string{"cmd": command}, &out)
	return out, err
}
