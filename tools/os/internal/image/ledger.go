package image

import (
	"bufio"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"time"
)

// Shared internals for the generation and publish legs. Every function here is
// the Go replica of the shell it replaces in scripts/task/image-daily-lib.sh
// and image-daily-engine.sh — same semantics, same edge cases, because the
// wrappers that call these subcommands are the same ones that called the
// functions.

var reDigitsOnly = regexp.MustCompile(`^[0-9]+$`)

func say(format string, args ...any) {
	fmt.Fprintf(os.Stderr, "image-daily: "+format+"\n", args...)
}

func today() string {
	return time.Now().Format("2006-01-02")
}

// epoch is `date -d "$1" +%s`: a YYYY-MM-DD parsed at local midnight.
func epoch(day string) (int64, bool) {
	t, err := time.ParseInLocation("2006-01-02", day, time.Local)
	if err != nil {
		return 0, false
	}
	return t.Unix(), true
}

func envInt(name string, def int) int {
	if v := os.Getenv(name); v != "" {
		if n, err := strconv.Atoi(v); err == nil {
			return n
		}
	}
	return def
}

func ledgerPath(root string) string { return root + "/ledger.jsonl" }

func briefsPath(repo string) string {
	if b := os.Getenv("BRIEFS"); b != "" {
		return b
	}
	return repo + "/lib/image-daily/briefs.json"
}

// record appends one ledger row: append-only, a re-roll is a new row, never an
// edit. Key order matches the jq -nc row the shell wrote.
type ledgerRow struct {
	TS      string `json:"ts"`
	Day     string `json:"day"`
	Lane    string `json:"lane"`
	Brief   string `json:"brief"`
	Path    string `json:"path"`
	Verdict string `json:"verdict"`
	Reason  string `json:"reason"`
	Prompt  string `json:"prompt"`
	Attempt int    `json:"attempt"`
	Rev     int    `json:"rev"`
}

func record(root, day, lane, brief, path, verdict, reason, prompt string, attempt, rev int) {
	f, err := os.OpenFile(ledgerPath(root), os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil {
		say("record: %v", err)
		return
	}
	defer f.Close()
	row := ledgerRow{
		TS:  time.Now().UTC().Format("2006-01-02T15:04:05Z"),
		Day: day, Lane: lane, Brief: brief, Path: path, Verdict: verdict,
		Reason: reason, Prompt: prompt, Attempt: attempt, Rev: rev,
	}
	enc := json.NewEncoder(f)
	enc.SetEscapeHTML(false) // jq wrote UTF-8 and <>& unescaped
	_ = enc.Encode(row)      // Encode writes the trailing newline
}

// One ledger row for reads — only the fields the queue and stage legs inspect.
type ledgerEntry struct {
	Brief   string `json:"brief"`
	Lane    string `json:"lane"`
	Day     string `json:"day"`
	Path    string `json:"path"`
	Verdict string `json:"verdict"`
	Rev     int    `json:"rev"`
}

func readLedger(root string) []ledgerEntry {
	f, err := os.Open(ledgerPath(root))
	if err != nil {
		return nil
	}
	defer f.Close()
	var out []ledgerEntry
	sc := bufio.NewScanner(f)
	sc.Buffer(make([]byte, 1<<20), 1<<20)
	for sc.Scan() {
		line := strings.TrimSpace(sc.Text())
		if line == "" {
			continue
		}
		var e ledgerEntry
		if err := json.Unmarshal([]byte(line), &e); err != nil {
			continue
		}
		if e.Rev == 0 {
			e.Rev = 1 // .rev // 1
		}
		out = append(out, e)
	}
	return out
}

// jq prints integral numbers without a fraction; the usage JSON can carry a
// float, so normalize before comparing or echoing back.
func jqNum(n float64) string {
	if n == float64(int64(n)) {
		return strconv.FormatInt(int64(n), 10)
	}
	return strconv.FormatFloat(n, 'f', -1, 64)
}

func cpgRemaining() string {
	out, err := exec.Command("cpg", "usage", "--json").Output()
	if err != nil {
		return ""
	}
	var u map[string]any
	if err := json.Unmarshal(out, &u); err != nil {
		return ""
	}
	num := func(v any) (float64, bool) {
		f, ok := v.(float64)
		return f, ok
	}
	ent, _ := u["entitlement"].(map[string]any)
	limits, _ := ent["limits"].(map[string]any)
	usage, _ := u["usage"].(map[string]any)
	images, _ := usage["images"].(map[string]any)
	if per, ok := num(limits["imagesPerDay"]); ok {
		used, _ := num(images["used"])
		return jqNum(per - used)
	}
	switch r := images["remaining"].(type) {
	case float64:
		return jqNum(r)
	case string:
		return r
	}
	return ""
}

// remaining is the pool read with its one refresh retry; "" means the pool is
// unreadable — the caller must say so, not spend nothing and call it a day.
func remaining() string {
	n := cpgRemaining()
	if n == "" || n == "null" {
		_ = exec.Command("cpg", "refresh").Run()
		n = cpgRemaining()
	}
	switch {
	case n == "" || n == "null":
		return ""
	case strings.HasPrefix(n, "-"):
		return "0"
	case !reDigitsOnly.MatchString(n):
		return "1000" // "unlimited" reads as a number the arithmetic can use
	default:
		return n
	}
}

type brief struct {
	ID     string  `json:"id"`
	Lane   string  `json:"lane"`
	Size   string  `json:"size"`
	Name   string  `json:"name"`
	Prompt string  `json:"prompt"`
	Every  float64 `json:"every"`
	Rev    int     `json:"rev"`
	Expect string  `json:"expect"`
}

func readBriefs(repo string) []brief {
	b, err := os.ReadFile(briefsPath(repo))
	if err != nil {
		return nil
	}
	var v struct {
		Briefs []brief `json:"briefs"`
	}
	if err := json.Unmarshal(b, &v); err != nil {
		return nil
	}
	for i := range v.Briefs {
		if v.Briefs[i].Rev == 0 {
			v.Briefs[i].Rev = 1 // .rev // 1
		}
	}
	return v.Briefs
}

func laneSetting(repo, lane, key string) string {
	b, err := os.ReadFile(briefsPath(repo))
	if err != nil {
		return ""
	}
	var v struct {
		Lanes map[string]map[string]any `json:"lanes"`
	}
	if err := json.Unmarshal(b, &v); err != nil {
		return ""
	}
	l, ok := v.Lanes[lane]
	if !ok {
		return ""
	}
	switch x := l[key].(type) {
	case string:
		return x
	case bool:
		return strconv.FormatBool(x)
	case float64:
		return jqNum(x)
	default:
		return ""
	}
}

type dueRow struct {
	id, lane, size, name, prompt string
	rev                          int
	expect                       string
}

// dueRows is `due "$lane"`: briefs in lane order whose freshness promise has
// expired, minus parked ones. One ledger pass answers last_keep, last_attempt
// and strikes for every brief at once — the shell asked per row.
func dueRows(root, repo, lane string) []dueRow {
	entries := readLedger(root)

	type stats struct {
		lastKeep string
		lastTry  string
		strikes  int
	}
	key := func(id string, rev int) string { return id + "\x00" + strconv.Itoa(rev) }
	st := map[string]*stats{}
	for _, e := range entries {
		k := key(e.Brief, e.Rev)
		s := st[k]
		if s == nil {
			s = &stats{}
			st[k] = s
		}
		if e.Day > s.lastTry {
			s.lastTry = e.Day
		}
		switch e.Verdict {
		case "keep":
			if e.Day > s.lastKeep {
				s.lastKeep = e.Day
			}
			s.strikes = 0
		case "reroll", "reject":
			s.strikes++
		}
	}

	now, _ := epoch(today())
	parkAfter := envInt("PARK_AFTER", 3)
	parkDays := envInt("PARK_DAYS", 7)
	force := os.Getenv("FORCE") == "1"

	var rows []dueRow
	for _, b := range readBriefs(repo) {
		if lane != "" && b.Lane != lane {
			continue
		}
		s := st[key(b.ID, b.Rev)]
		var lastKeep string
		var parked bool
		if s != nil {
			lastKeep = s.lastKeep
			if s.strikes >= parkAfter && s.lastTry != "" {
				if t, ok := epoch(s.lastTry); ok {
					parked = (now-t)/86400 < int64(parkDays)
				}
			}
		}
		if !force && parked {
			continue
		}
		var lastS int64
		if lastKeep != "" {
			if t, ok := epoch(lastKeep); ok {
				lastS = t
			}
		}
		if force || lastKeep == "" || lastS == 0 || float64((now-lastS)/86400) >= b.Every {
			rows = append(rows, dueRow{
				id: b.ID, lane: b.Lane, size: b.Size, name: b.Name,
				prompt: b.Prompt, rev: b.Rev, expect: b.Expect,
			})
		}
	}
	return rows
}

// dimensions is the ffprobe read: the size in the request is not the size in
// the file, so the plate is measured before it counts. The probe itself is a
// host dependency, not a per-file outcome — its absence is a broken PATH, so
// name it rather than reading every plate as shapeless.
func dimensions(file string) string {
	if _, err := exec.LookPath("ffprobe"); err != nil {
		die("ffprobe is required to check a plate's shape (pkgs.ffmpeg)")
	}
	out, err := exec.Command("ffprobe", "-v", "error",
		"-select_streams", "v:0", "-show_entries", "stream=width,height",
		"-of", "csv=p=0", file).Output()
	if err != nil {
		return ""
	}
	fields := strings.Split(strings.TrimSpace(string(out)), ",")
	if len(fields) == 2 {
		return fields[0] + "x" + fields[1]
	}
	return ""
}

// archivePrior copies a plate a re-render is about to overwrite into variants/,
// stamped; a same-second collision gets a counter so neither copy wins.
func archivePrior(root, file string) {
	if _, err := os.Stat(file); err != nil {
		return
	}
	rel := strings.TrimPrefix(file, root+"/src/")
	rel = strings.TrimPrefix(rel, root+"/published/")
	stamp := time.Now().UTC().Format("20060102T150405Z")
	ext := filepath.Ext(rel)
	dest := filepath.Join(root, "variants", strings.TrimSuffix(rel, ext)+"."+stamp+ext)
	for n := 1; ; n++ {
		if _, err := os.Stat(dest); os.IsNotExist(err) {
			break
		}
		dest = filepath.Join(root, "variants",
			fmt.Sprintf("%s.%s-%d%s", strings.TrimSuffix(rel, ext), stamp, n+1, ext))
	}
	if err := os.MkdirAll(filepath.Dir(dest), 0755); err != nil {
		return
	}
	src, err := os.ReadFile(file)
	if err != nil {
		return
	}
	if err := os.WriteFile(dest, src, 0644); err != nil {
		return
	}
	say("archived prior render: variants/%s", dest[len(root)+len("/variants/"):])
}

// reasonOf: the judge's sentence plus the named defect, one ledger column.
func reasonOf(verdictJSON string) string {
	var v struct {
		Reason string `json:"reason"`
		Defect string `json:"defect"`
	}
	if err := json.Unmarshal([]byte(verdictJSON), &v); err != nil {
		return ""
	}
	if v.Defect != "" {
		return v.Reason + " | " + v.Defect
	}
	return v.Reason
}
