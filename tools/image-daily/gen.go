package main

import (
	"bytes"
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

// The generation leg: judge_image, attempt, run_lane. Each is a subcommand
// because the wrappers call them at different grain — image-daily-run.sh takes
// whole lanes, image-daily-plates.sh and image-daily-post.sh drive attempt and
// judge one row at a time.

const judgePromptBase = `Read the image file at %s (a PNG on this machine; open it with your file tool).
Judge it as %s.
Keep only when: the subject is recognisable at a glance and there is a clear
focal point, with no garbled lettering and no malformed faces or hands. A short
prompt that lands a deliberate image is a keep: spare is not the same as
generic, so do not mark an image down for carrying few words.
A portrait of a woman must read as a woman: a heavy square jaw, a thick neck, a
flat broad brow, a masculine or androgynous face, or a torso widened and
flattened by bulky armour is a defect — name it and reroll, however well the
image is made. The same reroll applies to a harsh cold read: sunken gaunt
cheeks, an angular hollowed jaw, a hard unblinking stare, or a smooth featureless
mannequin face — a visor that has swallowed the whole face counts — because that
is an unpleasant mask rather than a woman. A plate that reads as a man at all — a
male face, a flat chest, a male build — is a reject rather than a reroll: the row
itself is wrong, so do not spend a second image on it.
Otherwise answer "reroll" and put in "defect" one concrete, actionable defect
(the thing to change, e.g. "the horizon is not level"). Use "reject" only when
the image is unusable and the prompt is wrong, not the render.
Do not write any file. Do not ask a question. Do not describe the plan.
Answer on ONE line and nothing else, exactly this JSON:
{"verdict":"keep|reroll|reject","reason":"...","defect":"..."}`

const judgePromptExpect = `
The plate must show: %s. A literal reading of a name — a plant, a chemical
element, a generic icon, a settings row, a dashboard — is a reroll even when the
image itself is well made, because it is the wrong subject.`

// agy is the judge — a different model family from the generator, reading the
// PNG with its own tools. runAgy answers the raw {status,response,usage} JSON
// or an error; stderr is discarded exactly as the shell did.
func runAgy(stage, prompt string, extra []string, env []string) (string, int) {
	args := []string{
		"--dangerously-skip-permissions", "--mode", "accept-edits",
		"--disable-slash-commands",
	}
	args = append(args, extra...)
	args = append(args,
		"--print-timeout", "180s", "--print", prompt, "--output-format", "json")
	cmd := exec.Command("agy", args...)
	cmd.Dir = stage
	if len(env) > 0 {
		cmd.Env = append(os.Environ(), env...)
	}
	out, err := cmd.Output()
	rc := 0
	if err != nil {
		if ee, ok := err.(*exec.ExitError); ok {
			rc = ee.ExitCode()
		} else {
			rc = 1
		}
	}
	return string(out), rc
}

func agyResponseOK(raw string) bool {
	var v struct {
		Response string `json:"response"`
	}
	return json.Unmarshal([]byte(raw), &v) == nil && len(v.Response) > 0
}

// judgeImage is judge_image: one verdict JSON on return — keep, reroll, reject
// or unjudged (provider failure; never publishable). Always "succeeds"; a dead
// judge is a verdict, not an error.
func judgeImage(root, repo, png, lane, intent, expect string) string {
	stage := root + "/.judge"
	_ = os.MkdirAll(stage, 0755)
	if _, err := os.Stat(stage + "/.git"); err != nil {
		_ = exec.Command("git", "-C", stage, "init", "-q").Run()
	}

	prompt := fmt.Sprintf(judgePromptBase, png, intent)
	// A name is not a subject: `expect` is the only field the judge can hold a
	// literal reading of the brief's name against.
	if expect != "" {
		prompt += fmt.Sprintf(judgePromptExpect, expect)
	}

	var modelArgs []string
	if m := os.Getenv("GEMINI_MODEL"); m != "" {
		modelArgs = []string{"--model", m}
	}

	// `--mode accept-edits` + `--disable-slash-commands`: measured ~52 s where
	// --mode plan asks the operator a question and --json-schema ran past 200 s.
	raw, rc := runAgy(stage, prompt, modelArgs, nil)

	// The account route exhausts its quota for days at a time; the provider
	// route bills the GEMINI.API key's project instead. The key is read only on
	// this path — the happy path never touches sops.
	if rc != 0 || raw == "" || !agyResponseOK(raw) {
		key := secretGet(repo, `["GEMINI"]["API"]["KEY"]`)
		if key != "" {
			raw, rc = runAgy(stage, prompt,
				[]string{"--settings", `{"modelProvider":"gemini"}`,
					"--model", envDefault("JUDGE_MODEL", "gemini-4-hydrogen-high")},
				[]string{"GEMINI_API_KEY=" + key})
		}
	}
	if rc != 0 || raw == "" {
		return fmt.Sprintf(`{"verdict":"unjudged","reason":"agy exited %d","defect":""}`, rc)
	}

	// The reply is text: lift the first {...} object out of it rather than
	// trusting the whole string to parse — grep -oE '\{.*\}' is greedy, so the
	// span runs from the first brace to the last.
	var out struct {
		Response string `json:"response"`
	}
	if err := json.Unmarshal([]byte(raw), &out); err != nil {
		out.Response = ""
	}
	text := strings.ReplaceAll(out.Response, "\n", "")
	first := strings.Index(text, "{")
	last := strings.LastIndex(text, "}")
	if first >= 0 && last > first {
		candidate := text[first : last+1]
		var v map[string]any
		var buf bytes.Buffer
		if json.Unmarshal([]byte(candidate), &v) == nil && v["verdict"] != nil &&
			json.Compact(&buf, []byte(candidate)) == nil {
			return buf.String()
		}
	}
	return `{"verdict":"unjudged","reason":"agy answered without a verdict object","defect":""}`
}

func envDefault(name, def string) string {
	if v := os.Getenv(name); v != "" {
		return v
	}
	return def
}

// secretGet asks the repo's own credential reader, exactly as the engine did:
// bash sources paths.sh and prints the value, or nothing.
func secretGet(repo, key string) string {
	script := fmt.Sprintf(`. '%s' 2>/dev/null || true; secret_get '%s' "$(apikeys_file)" 2>/dev/null || true`,
		repo+"/scripts/task/lib/paths.sh", key)
	out, _ := exec.Command("bash", "-c", script).Output()
	return strings.TrimSpace(string(out))
}

// attempt is `attempt`: one generation call, one plate. rc carries the shell's
// contract — 0 ok, 1 failed, 2 burst window closed, 3 allowance spent.
func attempt(root, id, lane, size, name, prompt, day string, n, rev int) (string, int) {
	dir := filepath.Join(root, "src", lane, day)
	_ = os.MkdirAll(dir, 0755)
	file := filepath.Join(dir, name)
	_ = os.MkdirAll(filepath.Dir(file), 0755)
	archivePrior(root, file)

	if _, err := exec.LookPath("ffprobe"); err != nil {
		say("ffprobe is required to verify a plate's size (pkgs.ffmpeg)")
		return "", 1
	}

	tries, waited := 0, 0
	triesMax := envInt("RATE_TRIES", 3)
	base := envInt("RATE_WAIT", 60)
	ceiling := envInt("RATE_WAIT_MAX", 900)
	maxWait := envInt("RATE_WAIT_TOTAL", 420)

	for {
		cmd := exec.Command("cpg", "image", "--json", "-s", size, "-o", file, prompt)
		outBytes, err := cmd.CombinedOutput()
		out := string(outBytes)
		rc := 0
		if err != nil {
			if ee, ok := err.(*exec.ExitError); ok {
				rc = ee.ExitCode()
			} else {
				rc = 1
			}
		}
		if rc == 0 {
			if fi, statErr := os.Stat(file); statErr == nil && fi.Size() > 0 {
				got := dimensions(file)
				if got == size {
					return file, 0
				}
				_ = os.Remove(file)
				reason := "asked for " + size + ", got "
				if got == "" {
					reason += "no readable png"
				} else {
					reason += got
				}
				record(root, day, lane, id, file, "failed", reason, prompt, n, rev)
				if got == "" {
					say("%s: asked for %s, got unreadable; plate discarded", id, size)
				} else {
					say("%s: asked for %s, got %s; plate discarded", id, size, got)
				}
				return "", 1
			}
		}
		if strings.Contains(out, "429") || strings.Contains(out, "RATE_LIMITED") {
			// A 429 at zero allowance is the day, not the bucket — an unreadable
			// pool is not spent, so the ladder keeps probing rather than lying.
			if rem := remaining(); rem != "" && rem == "0" {
				say("%s: allowance spent — waiting cannot reopen the bucket", id)
				return "", 3
			}
			tries++
			if tries > triesMax || waited >= maxWait {
				record(root, day, lane, id, file, "failed",
					fmt.Sprintf("burst window closed after %ds (%d attempt(s))", waited, tries),
					prompt, n, rev)
				say("%s: burst window still closed after %ds — the round stops here", id, waited)
				return "", 2
			}
			wait := base << (tries - 1)
			if wait > ceiling {
				wait = ceiling
			}
			if waited+wait > maxWait {
				wait = maxWait - waited
			}
			if wait <= 0 {
				wait = 1
			}
			say("%s: rate limited, waiting %ds", id, wait)
			time.Sleep(time.Duration(wait) * time.Second)
			waited += wait
			continue
		}
		// A size the resolved model refuses is not a defect in the row: retry
		// once at a size both models take, the crop downstream is local.
		if strings.Contains(out, "VALIDATION_FAILED") && strings.Contains(out, "size") && size != "1024x1024" {
			say("%s: %s refused by the resolved model — retrying at 1024x1024", id, size)
			size = "1024x1024"
			continue
		}
		reason := strings.ReplaceAll(out, "\n", " ")
		if len(reason) > 200 {
			reason = reason[:200]
		}
		record(root, day, lane, id, file, "failed", reason, prompt, n, rev)
		say("%s: generation failed (rc=%d)", id, rc)
		return "", 1
	}
}

// runLane is run_lane: the due rows of one lane, one judge per generation, one
// re-roll on a named defect, and the unjudged_streak breaker that stops a dead
// judge from burning the whole allowance. Returns the spent count.
func runLane(root, repo, lane string, budget int) int {
	day := today()
	intent := laneSetting(repo, lane, "intent")
	left := 0
	if rem := remaining(); rem != "" {
		fmt.Sscanf(rem, "%d", &left)
	}
	say("lane %s: budget %d (%d left)", lane, budget, left)

	rows := dueRows(root, repo, lane)
	if only := os.Getenv("ONLY"); only != "" {
		want := "," + only + ","
		var keep []dueRow
		for _, r := range rows {
			if strings.Contains(want, ","+r.id+",") {
				keep = append(keep, r)
			}
		}
		rows = keep
	}
	if len(rows) == 0 {
		say("lane %s: nothing due", lane)
		return 0
	}

	spent := 0
	unjudgedStreak := 0 // the gate greps this name as unjudged_streak
	for _, r := range rows {
		if spent >= budget {
			break
		}
		if left <= 0 {
			say("allowance spent")
			break
		}
		if os.Getenv("DRY") == "1" {
			say("would generate %s (%s) -> %s/%s/%s", r.id, r.size, lane, day, r.name)
			spent++
			continue
		}

		sent, n := r.prompt, 1
		file, rc := attempt(root, r.id, lane, r.size, r.name, sent, day, n, r.rev)
		if rc == 2 {
			say("lane %s: rate limited, stopping early", lane)
			break
		}
		if rc == 3 {
			say("lane %s: allowance spent, stopping early", lane)
			break
		}
		if rc != 0 {
			continue
		}
		left--
		v := judgeImage(root, repo, file, lane, intent, r.expect)
		verdict, defect := verdictFields(v)
		spent++
		record(root, day, lane, r.id, file, verdict, reasonOf(v), sent, n, r.rev)

		if verdict == "reroll" && defect != "" && left > 0 && spent < budget {
			say("%s: reroll — %s", r.id, defect)
			_ = os.Remove(file)
			sent = r.prompt + " (Change only this: " + defect + ".)"
			n = 2
			file, rc = attempt(root, r.id, lane, r.size, r.name, sent, day, n, r.rev)
			if rc != 0 {
				continue
			}
			left--
			v = judgeImage(root, repo, file, lane, intent, r.expect)
			verdict, _ = verdictFields(v)
			spent++
			record(root, day, lane, r.id, file, verdict, reasonOf(v), sent, n, r.rev)
		}

		say("%s: %s", r.id, verdict)
		if verdict == "unjudged" {
			unjudgedStreak++
			if unjudgedStreak >= 2 {
				say("lane %s: judge unreachable twice — stopping before more allowance burns unjudged", lane)
				break
			}
		} else {
			unjudgedStreak = 0
		}
	}
	return spent
}

func verdictFields(v string) (verdict, defect string) {
	var m struct {
		Verdict string `json:"verdict"`
		Defect  string `json:"defect"`
	}
	_ = json.Unmarshal([]byte(v), &m)
	return m.Verdict, m.Defect
}

// --- subcommand handlers -----------------------------------------------------

func cmdJudge(args []string) {
	fs := flag.NewFlagSet("judge", flag.ExitOnError)
	root := fs.String("root", os.Getenv("IMAGES_ROOT"), "image tree root")
	repo := fs.String("repo", os.Getenv("REPO"), "checkout root")
	png := fs.String("png", "", "plate to judge")
	lane := fs.String("lane", "wall", "lane")
	intent := fs.String("intent", "", "lane intent sentence")
	expect := fs.String("expect", "", "what the plate must show")
	_ = fs.Parse(args)
	if *root == "" || *repo == "" || *png == "" {
		die("judge needs --png, --root and --repo")
	}
	fmt.Print(judgeImage(*root, *repo, *png, *lane, *intent, *expect))
}

func cmdAttempt(args []string) {
	fs := flag.NewFlagSet("attempt", flag.ExitOnError)
	root := fs.String("root", os.Getenv("IMAGES_ROOT"), "image tree root")
	id := fs.String("id", "", "brief id")
	lane := fs.String("lane", "", "lane")
	size := fs.String("size", "", "WxH")
	name := fs.String("name", "", "output filename")
	prompt := fs.String("prompt", "", "generation prompt")
	day := fs.String("day", today(), "day bucket")
	n := fs.Int("n", 1, "attempt number")
	rev := fs.Int("rev", 1, "brief revision")
	_ = fs.Parse(args)
	if *root == "" || *id == "" || *lane == "" || *size == "" || *name == "" {
		die("attempt needs --id --lane --size --name --prompt and --root")
	}
	file, rc := attempt(*root, *id, *lane, *size, *name, *prompt, *day, *n, *rev)
	if rc != 0 {
		os.Exit(rc)
	}
	fmt.Print(file)
}

func cmdLane(args []string) {
	fs := flag.NewFlagSet("lane", flag.ExitOnError)
	root := fs.String("root", os.Getenv("IMAGES_ROOT"), "image tree root")
	repo := fs.String("repo", os.Getenv("REPO"), "checkout root")
	lane := fs.String("lane", "", "lane")
	budget := fs.Int("budget", 0, "spend ceiling")
	_ = fs.Parse(args)
	if *root == "" || *repo == "" || *lane == "" {
		die("lane needs --lane --budget --root --repo")
	}
	fmt.Println(runLane(*root, *repo, *lane, *budget))
}
