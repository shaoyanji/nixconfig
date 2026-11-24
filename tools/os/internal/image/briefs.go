package image

// The queue reads that plan, run, status, judge and publish asked of jq in
// image-daily-lib.sh: which lanes are selected, a lane's budget and settings,
// the bank-readiness guard, the due rows, and the parked check. One ledger
// pass per call, same TSV shapes the shell printed.

import (
	"bufio"
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

// lanesDefault is the shard order when LANES is unset — moved from
// image-daily-lib.sh's LANES_ORDER now that the Go tool owns the read.
var lanesDefault = []string{"site", "wall", "blog", "fleet", "badge"}

// `image-daily lanes` — the selected lanes, one per line: the LANES env list
// or the shard order, exactly what select_lanes built into lane_list.
func cmdLanes(args []string) {
	_ = args
	if l := os.Getenv("LANES"); l != "" {
		for _, lane := range strings.Fields(l) {
			fmt.Println(lane)
		}
		return
	}
	for _, lane := range lanesDefault {
		fmt.Println(lane)
	}
}

// `image-daily budget --lane L` — .lanes[L].budget // 0.
func cmdBudget(args []string) {
	fs := flag.NewFlagSet("budget", flag.ExitOnError)
	lane := fs.String("lane", "", "lane name")
	_ = fs.Parse(args)
	var v struct {
		Lanes map[string]struct {
			Budget int `json:"budget"`
		} `json:"lanes"`
	}
	if data, err := os.ReadFile(briefsPath(os.Getenv("REPO"))); err == nil {
		_ = json.Unmarshal(data, &v)
	}
	fmt.Println(v.Lanes[*lane].Budget)
}

// `image-daily setting --lane L --key K` — .lanes[L][K] // empty.
func cmdSetting(args []string) {
	fs := flag.NewFlagSet("setting", flag.ExitOnError)
	lane := fs.String("lane", "", "lane name")
	key := fs.String("key", "", "setting key")
	_ = fs.Parse(args)
	var v struct {
		Lanes map[string]map[string]any `json:"lanes"`
	}
	if data, err := os.ReadFile(briefsPath(os.Getenv("REPO"))); err == nil {
		_ = json.Unmarshal(data, &v)
	}
	if s, ok := v.Lanes[*lane][*key]; ok {
		fmt.Println(s)
	}
}

// `image-daily guard` — briefs_guard: refuse to spend on a brief that is not
// bank-ready. Three classes, same say() diagnostics, rc = bad.
//
// A character plate needs the character described, not just named. The
// generator does not know these people, so `Fern, 4k, realistic, neumorphism`
// is an instruction to draw the word: on 2026-11-10 seven of eight such
// briefs came back as a fern leaf, a power symbol, a periodic-table tile, a
// sky, a dashboard, a devil and a settings row, and every one of them was
// judged `keep` because the judge was holding the same weak prompt. A badge
// is a profile picture, so the same rule holds there. And a wall prompt that
// names no style renders as a photograph and is refused at judging — a 42-
// plate burst on 2026-11-12 spent nine refusals on exactly that.
func cmdGuard(args []string) {
	_ = args
	bad := false
	for _, b := range readBriefs(os.Getenv("REPO")) {
		words := len(strings.Split(b.Prompt, " "))
		switch {
		case strings.HasPrefix(b.ID, "wall-char-"):
			if b.Expect == "" {
				say("briefs: %s has no expect line", b.ID)
				bad = true
			}
			if !strings.Contains(b.Prompt, "anime") {
				say("briefs: %s does not name the anime", b.ID)
				bad = true
			}
			if words < 25 {
				say("briefs: %s prompt is %d words — describe the character, not the name", b.ID, words)
				bad = true
			}
		case strings.HasPrefix(b.ID, "badge-"):
			if b.Expect == "" {
				say("briefs: %s has no expect line", b.ID)
				bad = true
			}
			if words < 25 {
				say("briefs: %s prompt is %d words — describe the subject, not the name", b.ID, words)
				bad = true
			}
		}
		// The wall loop in the shell ran `startswith("wall-")`, which covers
		// wall-char- too — both rule sets apply to a character brief.
		if strings.HasPrefix(b.ID, "wall-") {
			if b.Expect == "" {
				say("briefs: %s has no expect line", b.ID)
				bad = true
			}
			if !strings.Contains(b.Prompt, "illustration") &&
				!strings.Contains(b.Prompt, "illustrated") &&
				!strings.Contains(b.Prompt, "cel-shaded") {
				say("briefs: %s names no illustrative style — the judge refuses a photographic plate", b.ID)
				bad = true
			}
			if !strings.Contains(b.Prompt, "one clear focal point") {
				say("briefs: %s names no focal point", b.ID)
				bad = true
			}
		}
	}
	if bad {
		os.Exit(1)
	}
}

// `image-daily due [--lane L]` — the TSV the shell printed: id, lane, size,
// name, prompt, rev, expect. Lane order is brief order; a fresh ledger row
// moves a brief out without any state file.
func cmdDue(args []string) {
	fs := flag.NewFlagSet("due", flag.ExitOnError)
	lane := fs.String("lane", "", "lane filter")
	root := fs.String("root", os.Getenv("IMAGES_ROOT"), "image tree root")
	repo := fs.String("repo", os.Getenv("REPO"), "checkout root")
	_ = fs.Parse(args)
	for _, r := range dueRows(*root, *repo, *lane) {
		fmt.Printf("%s\t%s\t%s\t%s\t%s\t%d\t%s\n",
			r.id, r.lane, r.size, r.name, r.prompt, r.rev, r.expect)
	}
}

// `image-daily parked --id X [--rev N]` — rc 0 when the brief is parked:
// strikes >= PARK_AFTER and its last attempt is inside PARK_DAYS.
func cmdParked(args []string) {
	fs := flag.NewFlagSet("parked", flag.ExitOnError)
	id := fs.String("id", "", "brief id")
	rev := fs.Int("rev", 1, "brief revision")
	root := fs.String("root", os.Getenv("IMAGES_ROOT"), "image tree root")
	_ = fs.Parse(args)

	strikes, lastTry := 0, ""
	for _, e := range readLedger(*root) {
		if e.Brief != *id || e.Rev != *rev {
			continue
		}
		if e.Day > lastTry {
			lastTry = e.Day
		}
		switch e.Verdict {
		case "keep":
			strikes = 0
		case "reroll", "reject":
			strikes++
		}
	}
	if strikes < envInt("PARK_AFTER", 3) || lastTry == "" {
		os.Exit(1)
	}
	now, _ := epoch(today())
	if t, ok := epoch(lastTry); ok && (now-t)/86400 < int64(envInt("PARK_DAYS", 7)) {
		return
	}
	os.Exit(1)
}

// `image-daily record` — one ledger row. The shell appended via jq; the row
// keeps the same key order and the same unescaped UTF-8.
func cmdRecord(args []string) {
	fs := flag.NewFlagSet("record", flag.ExitOnError)
	day := fs.String("day", "", "day")
	lane := fs.String("lane", "", "lane")
	brief := fs.String("brief", "", "brief id")
	path := fs.String("path", "", "plate path")
	verdict := fs.String("verdict", "", "verdict")
	reason := fs.String("reason", "", "reason")
	prompt := fs.String("prompt", "", "prompt")
	attempt := fs.Int("attempt", 1, "attempt number")
	rev := fs.Int("rev", 1, "brief revision")
	root := fs.String("root", os.Getenv("IMAGES_ROOT"), "image tree root")
	_ = fs.Parse(args)
	if *root == "" {
		die("record needs --root (or IMAGES_ROOT)")
	}
	_ = os.MkdirAll(*root, 0755)
	record(*root, *day, *lane, *brief, *path, *verdict, *reason, *prompt, *attempt, *rev)
}

// `image-daily index` — build_index: refresh the shape cache, write the
// manifest beside the served one and move it into place, then refresh the
// deployable copy. A redirect that fails truncates its target, and a
// truncated manifest.json reads as "0 assets served" (2026-11-22).
// The deployable is the frontend plus the manifest, both small: the bytes are
// on Cloudinary, and the page fetches the manifest and searches it. Nothing
// copies an image into the deployed tree, so a deploy is a few KB however
// many plates the bank holds.
func cmdIndex(args []string) {
	fs := flag.NewFlagSet("index", flag.ExitOnError)
	root := fs.String("root", os.Getenv("IMAGES_ROOT"), "image tree root")
	repo := fs.String("repo", os.Getenv("REPO"), "checkout root")
	_ = fs.Parse(args)
	if *root == "" || *repo == "" {
		die("index needs --root and --repo (or IMAGES_ROOT and REPO)")
	}
	shell := *repo + "/lib/image-daily/site/index.html"
	if _, err := os.Stat(shell); err != nil {
		die("missing the asset frontend at %s", shell)
	}
	urls := *root + "/published/urls.tsv"
	if st, err := os.Stat(urls); err != nil || st.Size() == 0 {
		die("no urls.tsv yet — the manifest is built from it")
	}
	dist := *root + "/site-dist"
	_ = os.MkdirAll(dist, 0755)

	shapesPass(*root)

	out := *root + "/published/manifest.json"
	// Beside the target, so the rename stays on one filesystem — a $TMPDIR
	// scratch on another device made mv copy, and os.Rename refuses that.
	tmp, err := os.CreateTemp(filepath.Dir(out), ".manifest-*.json")
	if err != nil {
		die("no temp file for the manifest")
	}
	defer os.Remove(tmp.Name())
	if _, err := tmp.Write(manifestJSON(*root, *repo)); err != nil {
		_ = tmp.Close()
		die("build_index: the manifest did not build (the served one is untouched)")
	}
	_ = tmp.Close()
	if err := os.Rename(tmp.Name(), out); err != nil {
		die("build_index: %v", err)
	}
	copyFile(shell, dist+"/index.html")
	copyFile(out, dist+"/manifest.json")

	var m struct {
		Count int `json:"count"`
	}
	if data, err := os.ReadFile(out); err == nil {
		_ = json.Unmarshal(data, &m)
	}
	size := "?"
	if du, err := exec0("du", "-sh", dist); err == nil {
		size = strings.Fields(du)[0]
	}
	say("manifest: %d asset(s), %s of frontend", m.Count, size)
}

// `image-daily shrink-guard --backup PATH` — publish_shrink_guard: the served
// row count is the floor. A rebuild that would serve fewer rows restores the
// backup, rebuilds, and dies with the publish-refused message.
func cmdShrinkGuard(args []string) {
	fs := flag.NewFlagSet("shrink-guard", flag.ExitOnError)
	backup := fs.String("backup", "", "pre-merge urls.tsv backup")
	root := fs.String("root", os.Getenv("IMAGES_ROOT"), "image tree root")
	repo := fs.String("repo", os.Getenv("REPO"), "checkout root")
	_ = fs.Parse(args)
	shrinkGuard(*root, *repo, *backup)
}

// shrinkGuard is the guard body, callable from cmdPublish without a flag
// round-trip.
func shrinkGuard(root, repo, backup string) {
	if backup == "" {
		return
	}
	now := 0
	var m struct {
		Count int `json:"count"`
	}
	if data, err := os.ReadFile(root + "/published/manifest.json"); err == nil {
		_ = json.Unmarshal(data, &m)
		now = m.Count
	}
	served := 0
	if f, err := os.Open(backup); err == nil {
		sc := bufio.NewScanner(f)
		for sc.Scan() {
			if len(sc.Text()) > 0 {
				served++
			}
		}
		_ = f.Close()
	}
	if now >= served {
		return
	}
	copyFile(backup, root+"/published/urls.tsv")
	indexBody(root, repo)
	_ = os.Remove(backup)
	die("publish refused: this host sees %d asset(s) but %d are being served — publish where IMAGES_ROOT holds the whole bank (frieren: /Volumes/data/pics/generated), or FORCE=1 to shrink on purpose", now, served)
}

// indexBody is cmdIndex's work without the flag parse, so shrink-guard can
// rebuild after restoring rows.
func indexBody(root, repo string) {
	cmdIndex([]string{"--root", root, "--repo", repo})
}

func copyFile(src, dst string) {
	data, err := os.ReadFile(src)
	if err != nil {
		die("copy %s: %v", src, err)
	}
	_ = os.MkdirAll(filepath.Dir(dst), 0755)
	if err := os.WriteFile(dst, data, 0644); err != nil {
		die("copy %s: %v", dst, err)
	}
}

func exec0(name string, args ...string) (string, error) {
	out, err := exec.Command(name, args...).Output()
	return string(out), err
}
