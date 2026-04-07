package main

import (
	"bufio"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"os"
	"sort"
	"strings"
	"time"
)

type frame struct {
	ID        string         `json:"id"`
	Topic     string         `json:"topic"`
	Meta      map[string]any `json:"meta"`
	Payload   map[string]any
	Timestamp string
}

type packEnvelope struct {
	Pack       packHeader `json:"pack"`
	Budget     packBudget `json:"budget"`
	Payload    packBody   `json:"payload"`
	Provenance provenance `json:"provenance"`
}

type packHeader struct {
	ID            string `json:"id"`
	PackType      string `json:"pack_type"`
	SpecID        string `json:"spec_id"`
	SpecVersion   string `json:"spec_version"`
	TargetID      string `json:"target_id"`
	GraphRevision string `json:"graph_revision"`
	GeneratedAt   string `json:"generated_at"`
	Checksum      string `json:"checksum"`
}

type packBudget struct {
	MaxBytes        int  `json:"max_bytes"`
	MaxTokensEst    int  `json:"max_tokens_est"`
	HardFailOnOverf bool `json:"hard_fail_on_overflow"`
}

type packBody struct {
	Format   string         `json:"format"`
	Sections map[string]any `json:"sections"`
}

type provenance struct {
	SourceClaimIDs []string       `json:"source_claim_ids"`
	SourceEventIDs []string       `json:"source_event_ids"`
	OmittedSummary omittedSummary `json:"omitted_summary"`
	PolicyProfile  string         `json:"policy_profile"`
}

type omittedSummary struct {
	Count   int      `json:"count"`
	Reasons []string `json:"reasons"`
}

func main() {
	var topic string
	var targetID string
	var graphRevision string
	var specID string
	var specVersion string
	var policyProfile string

	flag.StringVar(&topic, "topic", "", "topic to project")
	flag.StringVar(&targetID, "target", "", "target entity/task identifier")
	flag.StringVar(&graphRevision, "graph-revision", "", "logical graph revision id")
	flag.StringVar(&specID, "spec-id", "task_view", "projection spec id")
	flag.StringVar(&specVersion, "spec-version", "0.1.0", "projection spec version")
	flag.StringVar(&policyProfile, "policy-profile", "default", "policy profile name")
	flag.Parse()

	if strings.TrimSpace(topic) == "" || strings.TrimSpace(targetID) == "" {
		fmt.Fprintln(os.Stderr, "usage: xs-materializer --topic <topic> --target <target-id> [--graph-revision <rev>] [--spec-id <id>] [--spec-version <ver>] [--policy-profile <profile>]")
		os.Exit(2)
	}

	frames, err := readFrames(os.Stdin, topic)
	if err != nil {
		fmt.Fprintf(os.Stderr, "read frames: %v\n", err)
		os.Exit(1)
	}

	if graphRevision == "" {
		graphRevision = deriveRevision(frames)
	}

	pack := buildPack(topic, targetID, graphRevision, specID, specVersion, policyProfile, frames)
	enc := json.NewEncoder(os.Stdout)
	enc.SetIndent("", "  ")
	if err := enc.Encode(pack); err != nil {
		fmt.Fprintf(os.Stderr, "encode pack: %v\n", err)
		os.Exit(1)
	}
}

func readFrames(r io.Reader, topic string) ([]frame, error) {
	out := make([]frame, 0, 64)
	s := bufio.NewScanner(r)
	s.Buffer(make([]byte, 0, 64*1024), 8*1024*1024)
	for s.Scan() {
		line := strings.TrimSpace(s.Text())
		if line == "" {
			continue
		}
		var raw map[string]any
		if err := json.Unmarshal([]byte(line), &raw); err != nil {
			continue
		}
		f := normalizeFrame(raw)
		if f.Topic == "" {
			continue
		}
		if f.Topic != topic {
			continue
		}
		out = append(out, f)
	}
	if err := s.Err(); err != nil {
		return nil, err
	}
	return out, nil
}

func normalizeFrame(raw map[string]any) frame {
	f := frame{Payload: map[string]any{}}
	f.ID = asString(raw["id"])
	f.Topic = asString(raw["topic"])
	f.Timestamp = asString(raw["timestamp"])
	if f.Timestamp == "" {
		f.Timestamp = asString(raw["ts"])
	}
	if meta, ok := raw["meta"].(map[string]any); ok {
		f.Meta = meta
		if f.Topic == "" {
			f.Topic = asString(meta["topic"])
		}
	}
	if payload, ok := raw["payload"].(map[string]any); ok {
		f.Payload = payload
	} else if body, ok := raw["body"].(map[string]any); ok {
		f.Payload = body
	} else {
		f.Payload = raw
	}
	if f.Timestamp == "" {
		f.Timestamp = asString(f.Payload["timestamp"])
	}
	if f.Topic == "" {
		f.Topic = asString(f.Payload["topic"])
	}
	return f
}

func deriveRevision(frames []frame) string {
	h := sha256.New()
	for _, f := range frames {
		_, _ = io.WriteString(h, f.ID)
		_, _ = io.WriteString(h, "|")
		_, _ = io.WriteString(h, f.Timestamp)
		_, _ = io.WriteString(h, "|")
	}
	sum := hex.EncodeToString(h.Sum(nil))
	if len(sum) > 16 {
		sum = sum[:16]
	}
	if sum == "" {
		sum = "empty"
	}
	return "rev-xs-" + sum
}

func buildPack(topic, targetID, graphRevision, specID, specVersion, policyProfile string, frames []frame) packEnvelope {
	nextActions := make([]string, 0, 8)
	constraints := make([]string, 0, 8)
	risks := make([]string, 0, 8)
	openQuestions := make([]string, 0, 8)
	currentState := make([]string, 0, 16)
	eventIDs := make([]string, 0, len(frames))
	seenEventID := map[string]struct{}{}
	kindCount := map[string]int{}

	for _, f := range frames {
		if f.ID != "" {
			if _, ok := seenEventID[f.ID]; !ok {
				eventIDs = append(eventIDs, f.ID)
				seenEventID[f.ID] = struct{}{}
			}
		}
		kind := asString(f.Payload["kind"])
		if kind == "" {
			kind = asString(f.Meta["type"])
		}
		if kind == "" {
			kind = "unknown"
		}
		kindCount[kind]++

		summary := summarizeFrame(f, kind)
		if summary != "" {
			currentState = append(currentState, summary)
		}

		switch kind {
		case "record.fail":
			risks = append(risks, summary)
		case "contract.define":
			constraints = append(constraints, summary)
		case "packet.emit":
			openQuestions = append(openQuestions, summary)
		case "record.append":
			nextActions = append(nextActions, summary)
		}
	}

	sort.Strings(eventIDs)

	if len(nextActions) == 0 {
		nextActions = append(nextActions, "No actionable record.append events captured yet")
	}
	if len(constraints) == 0 {
		constraints = append(constraints, "No explicit contract.define constraints observed")
	}
	if len(currentState) == 0 {
		currentState = append(currentState, "No matching frames observed for requested topic")
	}

	objective := map[string]any{
		"topic": topic,
		"target_id": targetID,
		"summary": fmt.Sprintf("Materialized from xs stream with %d frames", len(frames)),
		"kinds": kindCount,
	}

	sections := map[string]any{
		"objective": objective,
		"current_state": currentState,
		"constraints": constraints,
		"active_risks": risks,
		"next_actions": nextActions,
		"open_questions": openQuestions,
	}

	payloadBytes, _ := json.Marshal(sections)
	payloadDigest := sha256.Sum256(payloadBytes)
	checksum := "sha256:" + hex.EncodeToString(payloadDigest[:])

	now := time.Now().UTC().Format(time.RFC3339)
	packID := "ctx_" + shortHash(topic+"|"+targetID+"|"+graphRevision+"|"+now)

	return packEnvelope{
		Pack: packHeader{
			ID:            packID,
			PackType:      "task_view",
			SpecID:        specID,
			SpecVersion:   specVersion,
			TargetID:      targetID,
			GraphRevision: graphRevision,
			GeneratedAt:   now,
			Checksum:      checksum,
		},
		Budget: packBudget{
			MaxBytes:        14336,
			MaxTokensEst:    2600,
			HardFailOnOverf: true,
		},
		Payload: packBody{
			Format:   "json",
			Sections: sections,
		},
		Provenance: provenance{
			SourceClaimIDs: []string{},
			SourceEventIDs: eventIDs,
			OmittedSummary: omittedSummary{Count: 0, Reasons: []string{}},
			PolicyProfile:  policyProfile,
		},
	}
}

func summarizeFrame(f frame, kind string) string {
	parts := []string{kind}
	if v := asString(f.Payload["record_id"]); v != "" {
		parts = append(parts, "record="+v)
	}
	if v := asString(f.Payload["artifact_id"]); v != "" {
		parts = append(parts, "artifact="+v)
	}
	if v := asString(f.Payload["packet_type"]); v != "" {
		parts = append(parts, "packet_type="+v)
	}
	if v := asString(f.Payload["contract_id"]); v != "" {
		parts = append(parts, "contract="+v)
	}
	if v := asString(f.Payload["content"]); v != "" {
		if len(v) > 120 {
			v = v[:117] + "..."
		}
		parts = append(parts, "content="+v)
	}
	if f.Timestamp != "" {
		parts = append(parts, "ts="+f.Timestamp)
	}
	return strings.Join(parts, " ")
}

func shortHash(s string) string {
	d := sha256.Sum256([]byte(s))
	h := hex.EncodeToString(d[:])
	if len(h) > 16 {
		return h[:16]
	}
	return h
}

func asString(v any) string {
	s, ok := v.(string)
	if !ok {
		return ""
	}
	return strings.TrimSpace(s)
}
