package image

// imagegen.go — the image-gen.sh front-end as verbs: the cpg auth dance
// (status + refresh; the token lives 60 s), the 401/429 retry, the bank
// upload that turns a session-gated render URL into a delivery URL, the
// batch loop and the systemd-run detach. Same stdout contracts as the
// shell: the merged JSON per render, the index path for a batch,
// {unit,log,path} for a detach.

import (
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

// cpgAuthOK is `cpg status --json`'s .authenticated.
func cpgAuthOK() bool {
	out, err := exec.Command("cpg", "status", "--json").Output()
	if err != nil {
		return false
	}
	var st struct {
		Authenticated bool `json:"authenticated"`
	}
	return json.Unmarshal(out, &st) == nil && st.Authenticated
}

// cpgRefresh is `cpg refresh` — cheap and idempotent; the browser login is not.
func cpgRefresh() { _ = exec.Command("cpg", "refresh").Run() }

// cpgEnsureAuth is ensure_auth: a pipeline that starts after a pause begins
// with a dead session and a bare 401, so refresh first, then ask again.
func cpgEnsureAuth() bool {
	if cpgAuthOK() {
		return true
	}
	cpgRefresh()
	return cpgAuthOK()
}

type genAction int

const (
	genFail genAction = iota
	genRefresh
	genBackoff
)

// genRetry classifies one failed render the way gen_one's case did: a 401
// buys one refresh and one retry; a 429 is the burst window and backs off
// 60 s per attempt, three tries and out. Both share the one counter — a 401
// spent one of the three.
func genRetry(result string, tries int) (genAction, int) {
	switch {
	case strings.Contains(result, "401"),
		strings.Contains(result, "UNAUTHENTICATED"),
		strings.Contains(result, "Sign in to continue"):
		if tries >= 1 {
			return genFail, 0
		}
		return genRefresh, 0
	case strings.Contains(result, "429"), strings.Contains(result, "RATE_LIMITED"):
		if tries >= 3 {
			return genFail, 0
		}
		return genBackoff, 60 * (tries + 1)
	}
	return genFail, 0
}

// bankRel is upload_bank's id derivation: a render under src/ banks as its
// tree-relative path; anywhere else it joins today's wall/ folder by
// basename — the drift that stamped plates under the wrong date when the
// default IMAGES_ROOT did not match the tree (2026-11-25).
func bankRel(root, path, day string) string {
	src := root + "/src/"
	if strings.HasPrefix(path, src) {
		return strings.TrimPrefix(path, src)
	}
	return "wall/" + day + "/" + filepath.Base(path)
}

// bankUpload is upload_bank: the bank is the account, so a render is uploaded
// before its URL is reported, under the same `assets/<rel>` id publish and
// adopt derive. A failed upload is reported, not fatal — the PNG is on disk
// and a later publish uploads it from there.
func bankUpload(repo, root, path string) (string, error) {
	if envDefault("UPLOAD", "1") != "1" {
		return "", errors.New("UPLOAD=0")
	}
	c, err := cloudinaryCreds(repo)
	if err != nil {
		return "", err
	}
	return cloudUpload(c, path, "", "assets/"+noExt(bankRel(root, path, today())))
}

// genOnce is gen_one: one prompt, one render, one banked URL or an honest
// failure. Success means the file is non-empty and the CLI's JSON answers
// .url; the merged JSON keeps .url as the delivery URL only when banked — a
// session-gated URL must never reach a manifest (images-check exists
// because one did).
func genOnce(repo, root, size, prompt, out string) (map[string]any, error) {
	tries := 0
	for {
		if !cpgEnsureAuth() {
			return nil, errors.New("image-gen: not authenticated — run chatplayground-go login")
		}
		_ = os.MkdirAll(filepath.Dir(out), 0o755)
		result, _ := exec.Command("cpg", "image", "--json", "-s", size, "-o", out, prompt).CombinedOutput()
		var payload map[string]any
		if fi, statErr := os.Stat(out); statErr == nil && fi.Size() > 0 &&
			json.Unmarshal(result, &payload) == nil {
			if u, _ := payload["url"].(string); u != "" {
				bank, berr := bankUpload(repo, root, out)
				if berr != nil {
					say("image-gen: upload failed; the render is at %s and a publish sends it", out)
					bank = ""
				}
				payload["path"] = out
				if bank == "" {
					payload["bank"] = false
				} else {
					payload["session_url"] = payload["url"]
					payload["url"] = bank
					payload["bank"] = true
					say("image-gen: in the bank, not the gallery — images:add FILE='%s' finishes it (or images:ship does both)", out)
				}
				return payload, nil
			}
		}
		action, wait := genRetry(string(result), tries)
		switch action {
		case genRefresh:
			tries++
			cpgRefresh()
			continue
		case genBackoff:
			tries++
			say("image-gen: rate limited, waiting %ds", wait)
			time.Sleep(time.Duration(wait) * time.Second)
			continue
		}
		if strings.Contains(string(result), "401") || strings.Contains(string(result), "UNAUTHENTICATED") {
			return nil, fmt.Errorf("image-gen: still unauthenticated after a refresh: %s", result)
		}
		if strings.Contains(string(result), "429") || strings.Contains(string(result), "RATE_LIMITED") {
			return nil, fmt.Errorf("image-gen: burst window closed: %s", result)
		}
		return nil, fmt.Errorf("image-gen: generation failed: %s", result)
	}
}

// `image-daily gen` — the single-prompt path of image-gen.sh: PROMPT in,
// the merged JSON line out.
func cmdGen(args []string) {
	fs := flag.NewFlagSet("gen", flag.ExitOnError)
	prompt := fs.String("prompt", os.Getenv("PROMPT"), "prompt text")
	out := fs.String("out", os.Getenv("OUT"), "output png (default $root/src/wall/<day>/<slug>.png)")
	repo := fs.String("repo", os.Getenv("REPO"), "checkout root")
	root := fs.String("root", os.Getenv("IMAGES_ROOT"), "image tree root")
	size := fs.String("size", getenvDef("SIZE", "1536x1024"), "render size")
	_ = fs.Parse(args)
	if *prompt == "" {
		die("gen needs --prompt or PROMPT")
	}
	if *repo == "" || *root == "" {
		die("gen needs --repo and --root (or REPO and IMAGES_ROOT)")
	}
	if *out == "" {
		*out = *root + "/src/wall/" + today() + "/" + slugify(*prompt) + ".png"
	}
	payload, err := genOnce(*repo, *root, *size, *prompt, *out)
	if err != nil {
		die("%v", err)
	}
	line, _ := json.Marshal(payload)
	fmt.Println(string(line))
}

// `image-daily gen-batch` — the --batch loop: one prompt per line,
// NNN-slug.png per render, the merged JSON per line appended to
// index.jsonl. A failed plate is logged and skipped, never a stop.
func cmdGenBatch(args []string) {
	fs := flag.NewFlagSet("gen-batch", flag.ExitOnError)
	prompts := fs.String("prompts", os.Getenv("PROMPTS"), "prompts file, one per line")
	outdir := fs.String("outdir", os.Getenv("OUTDIR"), "output dir (default $root/src/wall/<day>)")
	repo := fs.String("repo", os.Getenv("REPO"), "checkout root")
	root := fs.String("root", os.Getenv("IMAGES_ROOT"), "image tree root")
	size := fs.String("size", getenvDef("SIZE", "1536x1024"), "render size")
	_ = fs.Parse(args)
	if *prompts == "" {
		die("gen-batch needs --prompts or PROMPTS=<file>")
	}
	if *repo == "" || *root == "" {
		die("gen-batch needs --repo and --root (or REPO and IMAGES_ROOT)")
	}
	if *outdir == "" {
		*outdir = *root + "/src/wall/" + today()
	}
	data, err := os.ReadFile(*prompts)
	if err != nil {
		die("gen-batch: no prompts file at %s", *prompts)
	}
	if err := os.MkdirAll(*outdir, 0o755); err != nil {
		die("gen-batch: %v", err)
	}
	index := *outdir + "/index.jsonl"
	idx, err := os.OpenFile(index, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o644)
	if err != nil {
		die("gen-batch: %v", err)
	}
	n := 0
	for _, line := range strings.Split(string(data), "\n") {
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		n++
		out := fmt.Sprintf("%s/%03d-%s.png", *outdir, n, slugify(line))
		say("image-gen: [%d] %s", n, out)
		payload, err := genOnce(*repo, *root, *size, line, out)
		if err != nil {
			say("image-gen: [%d] failed, continuing", n)
			continue
		}
		row, _ := json.Marshal(payload)
		fmt.Fprintln(idx, string(row))
	}
	idx.Close()
	fmt.Println(index)
}

// genDetachArgs is launch_detached's systemd-run vector, pure for the test:
// a detached run inherits nothing, so the unit carries the variables the
// pipeline needs and the caller reads the same JSON from the log.
func genDetachArgs(unit, repo, root, prompt, out, size, script string) []string {
	return []string{
		"--user", "--unit", unit, "--collect",
		"--setenv=PROMPT=" + prompt,
		"--setenv=OUT=" + out,
		"--setenv=SIZE=" + size,
		"--setenv=IMAGES_ROOT=" + root,
		"--setenv=DETACH=0",
		"--setenv=UPLOAD=" + envDefault("UPLOAD", "1"),
		"--setenv=REPO=" + repo,
		"--", "bash", script,
	}
}

// `image-daily gen-detach` — launch_detached: the whole gen under a user
// unit, {unit,log,path} on stdout. The unit re-runs image-gen.sh itself, so
// its render, upload and bank step are one job, not a log someone reads.
func cmdGenDetach(args []string) {
	fs := flag.NewFlagSet("gen-detach", flag.ExitOnError)
	prompt := fs.String("prompt", os.Getenv("PROMPT"), "prompt text")
	out := fs.String("out", os.Getenv("OUT"), "output png")
	log := fs.String("log", os.Getenv("LOG"), "log file for systemd-run's output (default $root/<slug>.log)")
	repo := fs.String("repo", os.Getenv("REPO"), "checkout root")
	root := fs.String("root", os.Getenv("IMAGES_ROOT"), "image tree root")
	size := fs.String("size", getenvDef("SIZE", "1536x1024"), "render size")
	_ = fs.Parse(args)
	if *prompt == "" {
		die("gen-detach needs --prompt or PROMPT")
	}
	if *repo == "" || *root == "" {
		die("gen-detach needs --repo and --root (or REPO and IMAGES_ROOT)")
	}
	if _, err := exec.LookPath("systemd-run"); err != nil {
		die("systemd-run is required to detach a gen (run it in the foreground with DETACH=0)")
	}
	sl := slugify(*prompt)
	if *out == "" {
		*out = *root + "/src/wall/" + today() + "/" + sl + ".png"
	}
	if *log == "" {
		*log = *root + "/" + sl + ".log"
	}
	if err := os.MkdirAll(filepath.Dir(*out), 0o755); err != nil {
		die("gen-detach: %v", err)
	}
	unit := "image-gen-" + sl
	_ = exec.Command("systemctl", "--user", "stop", unit).Run()

	f, err := os.Create(*log)
	if err != nil {
		die("gen-detach: cannot open log %s: %v", *log, err)
	}
	defer f.Close()
	cmd := exec.Command("systemd-run",
		genDetachArgs(unit, *repo, *root, *prompt, *out, *size, *repo+"/scripts/task/image-gen.sh")...)
	cmd.Stdout, cmd.Stderr = f, f
	if err := cmd.Run(); err != nil {
		die("systemd-run: %v", err)
	}
	blob, _ := json.Marshal(struct {
		Unit string `json:"unit"`
		Log  string `json:"log"`
		Path string `json:"path"`
	}{Unit: unit, Log: *log, Path: *out})
	fmt.Println(string(blob))
}
