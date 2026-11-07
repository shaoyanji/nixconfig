package main

import (
	"encoding/json"
	"fmt"
	"regexp"
	"sort"
	"strings"
	"time"
)

const (
	maxBody      = 16 * 1024
	defaultLimit = 50
	maxLimit     = 200
	// A filter is a question about the log, not about one page of it: `subject=`
	// must find a turn older than the newest 50 or the resumability promise is
	// false (it was, measured 2026-11-03 — count 0 for a subject that exists).
	// Filtered reads therefore scan up to this many frames and say so when they
	// hit the cap.
	maxScan = 2000
)

var fields = map[string]bool{
	"id": true, "ts": true, "source": true, "kind": true, "subject": true,
	"action": true, "rationale": true, "base_commit": true, "branch": true,
	"files_changed": true, "commits": true, "outcome": true, "claims": true,
}

var required = []string{"id", "ts", "source", "kind", "subject", "action", "outcome"}

var (
	uuidRe    = regexp.MustCompile(`^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$`)
	tsRe      = regexp.MustCompile(`^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?(Z|[+-]\d{2}:\d{2})$`)
	sourceRe  = regexp.MustCompile(`^[A-Za-z0-9._-]{1,64}$`)
	commitRe  = regexp.MustCompile(`^[0-9a-f]{7,40}$`)
	branchRe  = regexp.MustCompile(`^[A-Za-z0-9._/-]{1,200}$`)
	outcomeRe = regexp.MustCompile(`^(done|in_progress|blocked|failed)(: .+)?$`)
)

// Key material is refused in every field, including paths and hashes.
var keyMaterial = []*regexp.Regexp{
	regexp.MustCompile(`-----BEGIN[A-Z ]*PRIVATE KEY`),
	regexp.MustCompile(`\bgh[pousr]_[A-Za-z0-9]{20,}`),
	regexp.MustCompile(`\bgithub_pat_[A-Za-z0-9_]{20,}`),
	regexp.MustCompile(`\bsk-[A-Za-z0-9]{16,}`),
	regexp.MustCompile(`\bxox[baprs]-[A-Za-z0-9-]{10,}`),
	regexp.MustCompile(`\bAKIA[0-9A-Z]{16}\b`),
	regexp.MustCompile(`\bage1[0-9a-z]{20,}\b`),
	regexp.MustCompile(`\bssh-(rsa|ed25519) AAAA[A-Za-z0-9+/=]{20,}`),
	regexp.MustCompile(`\beyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.`),
}

// Credential-shaped prose is refused in the free-text fields. Paths and commit
// hashes are exempt: `modules/secrets.yaml` is an honest file name, not a secret.
var sensitiveWord = regexp.MustCompile(`(?i)\b(password|passwd|passphrase|secret|api[_-]?key|apikey|access[_-]?token|refresh[_-]?token|bearer\s+[A-Za-z0-9._~+/=-]{8,}|private[_-]?key)\b`)

var freetext = []string{"source", "subject", "action", "rationale", "outcome"}

var maxFreetext = map[string]int{
	"source": 64, "subject": 200, "action": 500, "rationale": 1000, "outcome": 300,
}

// badRequest is the 400 path: the message is the response body's `error`, so the
// text an agent sees is the same text it saw from the Python shim.
type badRequest struct{ msg string }

func (b badRequest) Error() string { return b.msg }

func reject(format string, args ...any) error {
	return badRequest{msg: fmt.Sprintf(format, args...)}
}

// text is the `str(value)` of the Python shim: a non-string field is coerced
// before its regex runs, so the accept/reject outcome is unchanged.
func text(v any) string {
	switch t := v.(type) {
	case nil:
		return "None"
	case string:
		return t
	case json.Number:
		return t.String()
	default:
		return fmt.Sprintf("%v", v)
	}
}

func asString(v any) (string, bool) {
	s, ok := v.(string)
	return s, ok
}

func listOfStrings(v any) ([]string, bool) {
	raw, ok := v.([]any)
	if !ok {
		return nil, false
	}
	out := make([]string, 0, len(raw))
	for _, item := range raw {
		s, ok := item.(string)
		if !ok {
			return nil, false
		}
		out = append(out, s)
	}
	return out, true
}

// validate is the schema: one turn, every field, no extras. It runs on POST only,
// which is what makes the append-only promise a property of the code and not of
// the caller's goodwill.
func validate(entry map[string]any) error {
	var unknown []string
	for key := range entry {
		if !fields[key] {
			unknown = append(unknown, key)
		}
	}
	if len(unknown) > 0 {
		sort.Strings(unknown)
		return reject("unknown field(s): %s", strings.Join(unknown, ", "))
	}
	var missing []string
	for _, key := range required {
		if _, ok := entry[key]; !ok {
			missing = append(missing, key)
		}
	}
	if len(missing) > 0 {
		sort.Strings(missing)
		return reject("missing field(s): %s", strings.Join(missing, ", "))
	}

	if text(entry["kind"]) != "turn" {
		return reject("kind must be 'turn'")
	}
	if !uuidRe.MatchString(text(entry["id"])) {
		return reject("id must be a client-generated UUID")
	}
	ts := text(entry["ts"])
	if !tsRe.MatchString(ts) {
		return reject("ts must be an RFC 3339 timestamp with a timezone")
	}
	if _, err := time.Parse(time.RFC3339, ts); err != nil {
		return reject("ts is not a valid timestamp")
	}
	if !sourceRe.MatchString(text(entry["source"])) {
		return reject("source must be a short agent name")
	}
	if strings.TrimSpace(text(entry["subject"])) == "" {
		return reject("subject must not be empty")
	}
	if strings.TrimSpace(text(entry["action"])) == "" {
		return reject("action must not be empty")
	}

	outcome := text(entry["outcome"])
	if !outcomeRe.MatchString(outcome) {
		return reject("outcome must be done, in_progress, blocked or failed")
	}
	head, _, noted := strings.Cut(outcome, ":")
	if (head == "blocked" || head == "failed") && !noted {
		return reject("a blocked or failed outcome needs a one-line note after ': '")
	}

	for _, key := range []string{"source", "subject", "action", "rationale", "outcome"} {
		value := entry[key]
		if value == nil {
			// `rationale` is the one field that may be absent or null: an agent
			// posting the minimal body is the common case.
			if key == "rationale" {
				continue
			}
			return reject("%s must not be null", key)
		}
		s, ok := asString(value)
		if !ok {
			return reject("%s must be a string", key)
		}
		if len(s) > maxFreetext[key] {
			return reject("%s is longer than %d characters", key, maxFreetext[key])
		}
	}
	if v, present := entry["rationale"]; present && v != nil {
		if _, ok := asString(v); !ok {
			return reject("rationale must be a string or null")
		}
	}

	if base, present := entry["base_commit"]; present && base != nil {
		if !commitRe.MatchString(text(base)) {
			return reject("base_commit must be a git commit hash or null")
		}
	}
	if branch, present := entry["branch"]; present && branch != nil {
		if !branchRe.MatchString(text(branch)) {
			return reject("branch must be a branch name or null")
		}
	}

	for _, key := range []string{"files_changed", "commits", "claims"} {
		var value any = []any{}
		if v, ok := entry[key]; ok {
			value = v
		}
		items, ok := listOfStrings(value)
		if !ok {
			return reject("%s must be a list of strings", key)
		}
		if len(items) > 100 {
			return reject("%s has more than 100 entries", key)
		}
		for _, item := range items {
			if len(item) > 300 {
				return reject("%s has an entry longer than 300 characters", key)
			}
		}
	}
	if commits, ok := entry["commits"]; ok && commits != nil {
		items, _ := listOfStrings(commits)
		for _, commit := range items {
			if !commitRe.MatchString(commit) {
				return reject("commits must be git commit hashes")
			}
		}
	}

	for _, pattern := range keyMaterial {
		for key, value := range entry {
			haystack := text(value)
			if items, ok := listOfStrings(value); ok {
				haystack = strings.Join(items, " ")
			}
			if pattern.MatchString(haystack) {
				return reject("field '%s' contains key material; refusal", key)
			}
		}
	}
	for _, key := range freetext {
		if s, ok := asString(entry[key]); ok && sensitiveWord.MatchString(s) {
			return reject("field '%s' reads like it contains a credential; refusal", key)
		}
	}
	if claims, ok := entry["claims"]; ok && claims != nil {
		items, _ := listOfStrings(claims)
		for _, item := range items {
			if sensitiveWord.MatchString(item) {
				return reject("field 'claims' reads like it contains a credential; refusal")
			}
		}
	}
	return nil
}

// subjectRepo reads the repo out of `<repo>:<task>`, which is the schema's only
// place a repo is named.
func subjectRepo(subject string) string {
	head, _, ok := strings.Cut(subject, ":")
	if !ok {
		return ""
	}
	return head
}
