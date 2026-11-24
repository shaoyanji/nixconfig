package image

// `image-daily plates` — the roster round that lived in image-daily-plates.sh.
// Same contracts: the knobs are env (ROSTER/SIZE/ONLY/FORCE/DRY/MAX_GEN/
// PUBLISH/APPROVE/XS_SUMMARY/PLATE_ARCH_FILE, plus the RATE_* window attempt
// reads), say() on stderr, and attempt's rc drives the early exits — 2 burst
// window closed, 3 allowance spent. The tail (publish/approve/xs summary)
// execs the shell wrappers, which are still the scripts that own those jobs.

// A requested character plate is not a brief and cannot be one: a brief is a
// freshness promise (`every`), and nobody wants the same person redrawn on a
// schedule. It also cannot ride the wall lane, whose intent is illustrated
// art — a photographic plate is refused by that intent at judging time, which
// is how the 2026-11-12 burst lost plates it had already paid for. So the
// round has its own intent (`.intents.photoreal`), its own roster, and one
// property that makes it the go-to spend: a row whose plate the judge kept is
// skipped, so re-running the round renders nothing twice and a half-finished
// round resumes for free.
//
// Roster lines are `<slug>|<prompt>|<expect>`; `|` is not otherwise used in a
// prompt, and `expect` is what lets the judge call a literal reading of a
// name a reroll. A fourth field is that row's own size — the default is a
// landscape plate, and a phone wallpaper is 1024x1536: asking for the default
// crops it silently, and attempt then discards the answer for being the size
// it was not asked for. An empty field means the roster default.
//
// The guards the engine enforces before any allowance is touched:
//   - Every row on this roster is an adult woman (plateMale). `duncan-idaho`
//     was on the roster until 2026-11-16 and spent an image drawing a man as
//     a woman, which is wrong however well the plate is made. The judge
//     cannot know canon, so the row is refused, never judged.
//   - A row that names only garments and coverage is drawn as a broad,
//     heavy-jawed figure (the 2026-11-16 seraph round came back looking like
//     men in armour). plateForm must appear in the expanded prompt.
//   - Villain and armour rows kept failing without an archetype (a villain
//     came back a gaunt mask, a knight a bulky torso), so archRequired
//     families must name arch:<name> — a requirement, not advice.
//   - A row the provider refuses is held, not deleted: `hold: <reason> :: `
//     on the prompt field is the skip the round reads at the top of the
//     loop. Re-casting rewrites the row by hand; the engine never releases a
//     hold on its own.

import (
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"os/exec"
	"regexp"
	"strconv"
	"strings"
	"syscall"
)

var (
	plateForm      = "soft feminine facial features"
	plateArchRe    = regexp.MustCompile(`arch:[a-z0-9-]+`)
	plateArchNeed  = regexp.MustCompile(`(?i)armour|armored|armoured|pauldron|breastplate|knight|knightess|valkyrie|villain|villainess|witch|sorceress|empress|huntress|assassin|swordswoman|nemesis`)
	plateMale      = regexp.MustCompile(`(?i)(^|[^a-z])(an adult man|adult male|a man|male character|the man|he is|his face|his hair|his eyes|his jaw)([^a-z]|$)`)
	plateSizeRe    = regexp.MustCompile(`^[0-9]+x[0-9]+$`)
	plateSpaceRun  = regexp.MustCompile(`\s+`)
	plateHoldRe    = regexp.MustCompile(`^hold: `)
	plateHoldSplit = " :: "
)

type plateRow struct {
	slug, prompt, expect, size string
}

// keptPlate is kept_plate: the newest `keep` ledger entry for the brief whose
// file is still on disk. The ledger is append-only and read while a round can
// still be writing it, so a torn line reads as "no kept plate" — readLedger
// already drops unparseable rows, which is the same answer. An empty result
// is an answer, not an error (the torn-read week: 2026-11-16, five parked
// plates).
func keptPlate(root, briefID string) string {
	entries := readLedger(root)
	for i := len(entries) - 1; i >= 0; i-- {
		e := entries[i]
		if e.Brief == briefID && e.Verdict == "keep" {
			if _, err := os.Stat(e.Path); err == nil {
				return e.Path
			}
		}
	}
	return ""
}

// plateExpand is plate_expand: every arch:<name> in the prompt resolved from
// the archetype TSV before the row is sent — the expanded sentence is what
// the ledger records, and a row naming an archetype still cannot skip the
// form clause. An unknown name refuses the row; it never falls back to a
// bare word.
func plateExpand(archFile, prompt string) (string, bool) {
	names := map[string]bool{}
	for _, m := range plateArchRe.FindAllString(prompt, -1) {
		names[m] = true
	}
	if len(names) == 0 {
		return prompt, true
	}
	data, err := os.ReadFile(archFile)
	if err != nil {
		say("no archetype file at %s", archFile)
		return "", false
	}
	traits := map[string]string{}
	var known []string
	for _, line := range strings.Split(string(data), "\n") {
		if strings.HasPrefix(line, "#") {
			continue
		}
		f := strings.SplitN(line, "|", 2)
		if len(f) == 2 {
			traits[f[0]] = f[1]
			known = append(known, f[0])
		}
	}
	for arch := range names {
		name := strings.TrimPrefix(arch, "arch:")
		t, ok := traits[name]
		if !ok {
			say("arch:%s is not in %s — known: %s", name, archFile, strings.Join(known, " "))
			return "", false
		}
		prompt = strings.ReplaceAll(prompt, arch, t)
	}
	return prompt, true
}

// holdRosterRow is hold_roster_row: rewrite one row's prompt in place as
// `hold: <reason> :: <prompt>` — sanitized so the reason stays one field and
// the row keeps parsing. Rows already held are untouched.
func holdRosterRow(roster, slug, reason string) {
	reason = plateSpaceRun.ReplaceAllString(strings.NewReplacer("|", " ", "\t", " ", "\n", " ").Replace(reason), " ")
	reason = strings.TrimSpace(reason)
	if len(reason) > 140 {
		reason = reason[:140]
	}
	if reason == "" {
		reason = "judge refused it"
	}
	data, err := os.ReadFile(roster)
	if err != nil {
		say("hold: cannot read roster %s: %v", roster, err)
		return
	}
	var out []string
	for _, line := range strings.Split(string(data), "\n") {
		f := strings.SplitN(line, "|", 2)
		if len(f) == 2 && f[0] == slug && !plateHoldRe.MatchString(f[1]) {
			f[1] = "hold: " + reason + plateHoldSplit + f[1]
			line = f[0] + "|" + f[1]
		}
		out = append(out, line)
	}
	tmp := roster + ".hold.tmp"
	if err := os.WriteFile(tmp, []byte(strings.Join(out, "\n")), 0644); err != nil {
		say("hold: cannot write %s: %v", tmp, err)
		return
	}
	_ = os.Rename(tmp, roster)
}

func briefsIntent(repo, name string) string {
	b, err := os.ReadFile(briefsPath(repo))
	if err != nil {
		return ""
	}
	var v struct {
		Intents map[string]string `json:"intents"`
	}
	if err := json.Unmarshal(b, &v); err != nil {
		return ""
	}
	return v.Intents[name]
}

// `image-daily plates [--roster PATH]` — one requested round over the plate
// roster. DETACH stays the caller's problem: `round` spawns this verb under
// systemd-run, so both entry points share the loop.
func cmdPlates(args []string) {
	fs := flag.NewFlagSet("plates", flag.ExitOnError)
	roster := fs.String("roster", os.Getenv("ROSTER"), "roster file")
	root := fs.String("root", os.Getenv("IMAGES_ROOT"), "image tree root")
	repo := fs.String("repo", os.Getenv("REPO"), "checkout root")
	_ = fs.Parse(args)
	if *repo == "" || *root == "" {
		die("plates needs --repo and --root (or REPO and IMAGES_ROOT)")
	}
	if *roster == "" {
		*roster = *repo + "/lib/image-daily/plates.txt"
	}
	if _, err := os.Stat(*roster); err != nil {
		die("no roster at %s", *roster)
	}
	for _, c := range []string{"cpg", "agy", "ffprobe"} {
		if _, err := exec.LookPath(c); err != nil {
			die("%s is not on PATH", c)
		}
	}
	intent := briefsIntent(*repo, "photoreal")
	if intent == "" {
		die("briefs.json carries no .intents.photoreal")
	}
	archFile := getenvDef("PLATE_ARCH_FILE", *repo+"/lib/image-daily/archetypes.tsv")
	defSize := getenvDef("SIZE", "1536x1024")

	// A requested round is allowed to wait the burst window out: the
	// alternative is spending five plates, then abandoning the round when the
	// hourly bucket closes (measured 2026-11-17: 5 spent, 18 rows left
	// waiting). The budget is one window, not the nightly lane's 420 s.
	if os.Getenv("RATE_TRIES") == "" {
		os.Setenv("RATE_TRIES", "8")
	}
	if os.Getenv("RATE_WAIT") == "" {
		os.Setenv("RATE_WAIT", "300")
	}
	if os.Getenv("RATE_WAIT_MAX") == "" {
		os.Setenv("RATE_WAIT_MAX", "900")
	}
	if os.Getenv("RATE_WAIT_TOTAL") == "" {
		os.Setenv("RATE_WAIT_TOTAL", "3600")
	}

	stage := *root + "/.judge"
	_ = os.MkdirAll(*root, 0755)
	_ = os.MkdirAll(stage, 0755)
	lock, err := os.OpenFile(*root+"/.run.lock", os.O_CREATE|os.O_RDWR, 0644)
	if err != nil {
		die("plates: cannot open run lock: %v", err)
	}
	defer lock.Close()
	if err := syscall.Flock(int(lock.Fd()), syscall.LOCK_EX|syscall.LOCK_NB); err != nil {
		say("another run holds the lock")
		return
	}

	day := today()
	rem := remaining()
	if rem == "" {
		die("usage unreadable (401 from cpg) — run cpg refresh, or chatplayground-go login when the session itself is gone")
	}
	left, _ := strconv.Atoi(rem)
	cap := envInt("MAX_GEN", 0)
	ledgerBefore := len(readLedger(*root))
	var rows []plateRow
	data, _ := os.ReadFile(*roster)
	rowCount := 0
	for _, line := range strings.Split(string(data), "\n") {
		f := strings.SplitN(line, "|", 4)
		slug := strings.TrimSpace(f[0])
		if slug == "" || strings.HasPrefix(slug, "#") {
			continue
		}
		rowCount++
		r := plateRow{slug: slug}
		if len(f) > 1 {
			r.prompt = f[1]
		}
		if len(f) > 2 {
			r.expect = f[2]
		}
		if len(f) > 3 {
			r.size = f[3]
		}
		rows = append(rows, r)
	}
	capNote := ""
	if cap > 0 {
		capNote = fmt.Sprintf(", cap %d", cap)
	}
	say("plates: %d row(s) in the roster, %d image(s) left%s", rowCount, left, capNote)

	spent, unjudgedStreak := 0, 0 // the gate greps this name as unjudged_streak
	type heldRow struct{ slug, reason string }
	var holds []heldRow

	for _, r := range rows {
		size := r.size
		if size != "" && !plateSizeRe.MatchString(size) {
			say("%s: size '%s' is not WxH — row skipped", r.slug, size)
			continue
		}
		if size == "" {
			size = defSize
		}
		if plateHoldRe.MatchString(r.prompt) {
			reason := strings.TrimPrefix(r.prompt, "hold: ")
			if i := strings.Index(reason, plateHoldSplit); i >= 0 {
				reason = reason[:i]
			}
			say("%s: held — %s", r.slug, reason)
			continue
		}
		if only := os.Getenv("ONLY"); only != "" &&
			!strings.Contains(","+only+",", ","+r.slug+",") {
			continue
		}
		if os.Getenv("FORCE") != "1" {
			if have := keptPlate(*root, "photoreal-"+r.slug); have != "" {
				say("%s: kept already (%s)", r.slug, have)
				continue
			}
		}
		if plateMale.MatchString(r.prompt) {
			say("%s: row describes a man — this roster is adult women only (duncan-idaho was removed after it rendered a man as a woman)", r.slug)
			continue
		}
		if !strings.Contains(strings.ToLower(r.prompt), "arch:") && plateArchNeed.MatchString(r.prompt) {
			data, _ := os.ReadFile(archFile)
			var known []string
			for _, line := range strings.Split(string(data), "\n") {
				if f := strings.SplitN(line, "|", 2); len(f) == 2 && !strings.HasPrefix(line, "#") {
					known = append(known, f[0])
				}
			}
			say("%s: villain or armour row without an archetype — name one of: %s", r.slug, strings.Join(known, " "))
			continue
		}
		prompt, ok := plateExpand(archFile, r.prompt)
		if !ok {
			continue
		}
		if !strings.Contains(prompt, plateForm) {
			say("%s: no form clause — add '%s, a delicate jawline, a slender neck, a graceful feminine figure' or an arch:<name> from %s to the row", r.slug, plateForm, archFile)
			continue
		}
		if left <= 0 {
			say("allowance spent")
			break
		}
		if cap > 0 && spent >= cap {
			say("cap %d reached; the rest of the roster waits for the next round", cap)
			break
		}
		if os.Getenv("DRY") == "1" {
			say("would generate %s (%s) -> wall/%s/%s.png", r.slug, size, day, r.slug)
			spent++
			continue
		}

		id := "photoreal-" + r.slug
		retried := false
		file, arc := attempt(*root, id, "wall", size, r.slug+".png", prompt, day, 1, 1)
		if arc == 2 {
			say("burst window closed; the rest of the roster waits for the next round")
			break
		}
		if arc == 3 {
			say("allowance spent; the rest of the roster waits for the next slot")
			break
		}
		if arc != 0 {
			continue
		}
		left--
		v := judgeImage(*root, *repo, file, "wall", intent, r.expect)
		verdict, defect := verdictFields(v)
		spent++
		record(*root, day, "wall", id, file, verdict, reasonOf(v), prompt, 1, 1)

		if verdict == "reroll" && defect != "" && left > 0 && (cap == 0 || spent < cap) {
			say("%s: reroll — %s", r.slug, defect)
			_ = os.Remove(file)
			sent := prompt + " (Change only this: " + defect + ".)"
			file, arc = attempt(*root, id, "wall", size, r.slug+".png", sent, day, 2, 1)
			if arc == 2 {
				say("burst window closed; the rest of the roster waits for the next round")
				break
			}
			if arc == 3 {
				say("allowance spent; the rest of the roster waits for the next slot")
				break
			}
			if arc != 0 {
				continue
			}
			left--
			v = judgeImage(*root, *repo, file, "wall", intent, r.expect)
			verdict, defect = verdictFields(v)
			spent++
			retried = true
			record(*root, day, "wall", id, file, verdict, reasonOf(v), sent, 2, 1)
		}
		say("%s: %s", r.slug, verdict)
		// Two unjudged plates in a row is a dead judge, not a bad image: every
		// plate past this point spends a generation that can never be kept.
		if verdict == "unjudged" {
			unjudgedStreak++
			if unjudgedStreak >= 2 {
				say("judge unreachable twice — the round stops before more allowance burns unjudged")
				break
			}
		} else {
			unjudgedStreak = 0
		}
		// A refused row is parked, not re-rolled forever: `fail` is terminal on
		// the first look, `reroll` after its correction (or with no defect to
		// correct) is spent too. `unjudged` is NOT held — it is agy being down
		// or out of quota, and parking the whole roster for a judge outage is
		// the worse bug.
		switch verdict {
		case "fail":
			holds = append(holds, heldRow{r.slug, reasonOf(v)})
		case "reroll":
			if retried || defect == "" {
				holds = append(holds, heldRow{r.slug, reasonOf(v)})
			}
		}
	}
	for _, h := range holds {
		holdRosterRow(*roster, h.slug, h.reason)
		say("%s: held — %s", h.slug, h.reason)
	}

	say("%s: %d image(s) spent this round", day, spent)
	dry := os.Getenv("DRY") == "1"
	runTail := func(name string) {
		script := *repo + "/scripts/task/image-daily-" + name + ".sh"
		cmd := exec.Command("bash", script)
		cmd.Stdout, cmd.Stderr = os.Stdout, os.Stderr
		env := append(os.Environ(), "IMAGES_ROOT="+*root, "REPO="+*repo)
		cmd.Env = env
		if err := cmd.Run(); err != nil {
			say("%s failed; the plates are on disk and the next %s picks them up", name, name)
		}
	}
	// The judgement is already made, so approval is the only step between a
	// keep and a wallpaper; a round does it for its own plates.
	if os.Getenv("PUBLISH") != "0" && !dry && spent > 0 {
		runTail("publish")
	}
	if os.Getenv("APPROVE") != "0" && !dry && spent > 0 {
		runTail("approve")
	}

	// The round reports itself. It runs from a timer with nobody reading the
	// log, and xs-notify toasts a turn on the machine the person is actually
	// at, so the result travels instead of the person watching for it. Never
	// fatal: the plates are on disk and the ledger already holds the verdicts,
	// so a failed post costs a toast, not a round.
	if !dry && os.Getenv("XS_SUMMARY") != "0" {
		keeps := 0
		for _, e := range readLedger(*root)[ledgerBefore:] {
			if strings.HasPrefix(e.Brief, "photoreal-") && e.Verdict == "keep" {
				keeps++
			}
		}
		assets := 0
		if b, err := os.ReadFile(*root + "/published/urls.tsv"); err == nil {
			if s := strings.TrimSpace(string(b)); s != "" {
				assets = len(strings.Split(s, "\n"))
			}
		}
		outcome := "in_progress"
		if keeps > 0 {
			outcome = "done"
		}
		line := fmt.Sprintf("%s: %d plate(s) kept of %d spent, %s roster row(s) waiting, %d asset(s) published",
			day, keeps, spent, pendingCount(*root, *roster), assets)
		say("summary: %s", line)
		cmd := exec.Command("bash", *repo+"/scripts/task/xs-turn-post.sh")
		cmd.Env = append(os.Environ(),
			"SUBJECT=nixconfig:wall-plates", "ACTION="+line,
			"OUTCOME="+outcome, "SOURCE=image-daily")
		cmd.Stdout, cmd.Stderr = nil, nil
		if err := cmd.Run(); err != nil {
			say("xs turn not posted; the next post replays the queue")
		}
	}
}
