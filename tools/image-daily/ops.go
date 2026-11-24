package main

// The remaining engine helpers: verdict-to-reason, prior-render archiving,
// plate resolution, the ffprobe reads, the blog crop, the frontend deploy and
// the detached round. Same contracts as the shell functions they replace —
// say() on stderr, paths on stdout, and the same exit codes.

import (
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"time"
)

// `image-daily reason --json '<verdict>'` — one ledger column: the judge's
// sentence plus the named defect, so a re-roll's cause reads in one field.
func cmdReason(args []string) {
	fs := flag.NewFlagSet("reason", flag.ExitOnError)
	j := fs.String("json", "", "verdict JSON")
	_ = fs.Parse(args)
	if s := reasonOf(*j); s != "" {
		fmt.Println(s)
	}
}

// `image-daily archive --file PATH` — copy a plate into variants/ before a
// re-render overwrites it; a same-second collision gets a counter so neither
// copy wins.
func cmdArchive(args []string) {
	fs := flag.NewFlagSet("archive", flag.ExitOnError)
	file := fs.String("file", "", "plate to archive")
	root := fs.String("root", os.Getenv("IMAGES_ROOT"), "image tree root")
	_ = fs.Parse(args)
	if *file == "" || *root == "" {
		die("archive needs --file and --root (or IMAGES_ROOT)")
	}
	archivePrior(*root, *file)
}

// `image-daily resolve --id X --taste-root PATH` — where a plate lives.
// taste/* sits beside generated/ (it never entered the bank); anything else
// is published first, then src — a re-served plate beats its original.
func cmdResolve(args []string) {
	fs := flag.NewFlagSet("resolve", flag.ExitOnError)
	want := fs.String("id", "", "plate id")
	taste := fs.String("taste-root", "", "taste-test folder")
	root := fs.String("root", os.Getenv("IMAGES_ROOT"), "image tree root")
	_ = fs.Parse(args)
	if *want == "" {
		die("resolve needs --id")
	}
	var candidates []string
	if strings.HasPrefix(*want, "taste/") {
		candidates = []string{*taste + "/" + strings.TrimPrefix(*want, "taste/")}
	} else {
		candidates = []string{
			*root + "/published/wall/" + *want,
			*root + "/src/wall/" + *want,
		}
	}
	for _, c := range candidates {
		if _, err := os.Stat(c); err == nil {
			fmt.Println(c)
			return
		}
	}
	os.Exit(1)
}

// `image-daily dimensions --file F` — WxH on stdout, empty (rc 0) when ffprobe
// cannot read the file: the shell printed nothing either, so `|| echo
// unknown` fallbacks in callers behave identically.
func cmdDimensions(args []string) {
	fs := flag.NewFlagSet("dimensions", flag.ExitOnError)
	file := fs.String("file", "", "image file")
	_ = fs.Parse(args)
	if *file == "" {
		die("dimensions needs --file")
	}
	if d := dimensions(*file); d != "" {
		fmt.Println(d)
	}
}

// `image-daily landscape --file F` — rc 0 when w*10/h >= 12, the same ratio
// the wallpaper picker enforced.
func cmdLandscape(args []string) {
	fs := flag.NewFlagSet("landscape", flag.ExitOnError)
	file := fs.String("file", "", "image file")
	_ = fs.Parse(args)
	if *file == "" {
		die("landscape needs --file")
	}
	d := dimensions(*file)
	if d == "" {
		os.Exit(1)
	}
	parts := strings.SplitN(d, "x", 2)
	w, _ := strconv.Atoi(parts[0])
	h, _ := strconv.Atoi(parts[1])
	if h > 0 && w*10/h >= 12 {
		return
	}
	os.Exit(1)
}

// `image-daily crop --png P --jpg J` — the 1200x630 blog banner.
func cmdCrop(args []string) {
	fs := flag.NewFlagSet("crop", flag.ExitOnError)
	png := fs.String("png", "", "source plate")
	jpg := fs.String("jpg", "", "banner output")
	_ = fs.Parse(args)
	if *png == "" || *jpg == "" {
		die("crop needs --png and --jpg")
	}
	if !bannerCrop(*png, *jpg) {
		os.Exit(1)
	}
}

// `image-daily deploy` — the Pages frontend. PAGES=0 short-circuits like the
// shell; a deploy failure is a diagnostic, not a fatal — the manifest is
// already written and the site keeps serving the last one.
func cmdDeploy(args []string) {
	fs := flag.NewFlagSet("deploy", flag.ExitOnError)
	root := fs.String("root", os.Getenv("IMAGES_ROOT"), "image tree root")
	repo := fs.String("repo", os.Getenv("REPO"), "checkout root")
	_ = fs.Parse(args)
	if p := os.Getenv("PAGES"); p != "" && p != "1" {
		say("PAGES=0: frontend not deployed")
		return
	}
	if *root == "" || *repo == "" {
		die("deploy needs --root and --repo (or IMAGES_ROOT and REPO)")
	}
	project := os.Getenv("PROJECT")
	if project == "" {
		project = "bountystash-assets"
	}
	err := exec.Command("nix-shell", "-p", "wrangler", "--run",
		fmt.Sprintf("bash '%s' '%s' --project-name=%s --branch=main",
			*repo+"/scripts/task/pages-deploy.sh", *root+"/site-dist", project)).Run()
	if err != nil {
		say("publish: the frontend deploy failed; the manifest is written locally and the site still serves the last one")
	}
}

// `image-daily round --roster PATH` — detach a plates round under systemd-run
// and write .round.json, exactly what launch_round did: the env is passed
// explicitly because a unit inherits nothing, and the state file is what a
// later `round status` reads.
func cmdRound(args []string) {
	fs := flag.NewFlagSet("round", flag.ExitOnError)
	roster := fs.String("roster", "", "roster file")
	root := fs.String("root", os.Getenv("IMAGES_ROOT"), "image tree root")
	repo := fs.String("repo", os.Getenv("REPO"), "checkout root")
	_ = fs.Parse(args)
	if *roster == "" || *root == "" || *repo == "" {
		die("round needs --roster, --root and --repo (or IMAGES_ROOT and REPO)")
	}
	if _, err := exec.LookPath("systemd-run"); err != nil {
		die("systemd-run is required to detach a round (run it in the foreground with DETACH=0)")
	}

	unit := "image-plates-" + time.Now().Format("20060102-150405")
	if err := os.MkdirAll(*root, 0755); err != nil {
		die("round: %v", err)
	}
	env := func(name, def string) string { return "--setenv=" + name + "=" + getenvDef(name, def) }
	runArgs := []string{
		"--user", "--unit", unit, "--collect",
		"--working-directory=" + *repo,
		"--setenv=PATH=" + os.Getenv("PATH"),
		"--setenv=REPO=" + *repo,
		"--setenv=IMAGES_ROOT=" + *root,
		"--setenv=ROSTER=" + *roster,
		"--setenv=DETACH=0",
		env("ONLY", ""), env("MAX_GEN", "0"), env("SIZE", "1536x1024"),
		env("FORCE", "0"), env("PUBLISH", "1"), env("APPROVE", "1"),
		env("PAGES", "1"), env("DRY", "0"), env("XS_SUMMARY", "1"),
		env("RATE_TRIES", "8"), env("RATE_WAIT", "300"),
		env("RATE_WAIT_MAX", "900"), env("RATE_WAIT_TOTAL", "3600"),
		"--", "bash", *repo + "/scripts/task/image-daily.sh", "plates",
	}
	cmd := exec.Command("systemd-run", runArgs...)
	if out, err := cmd.CombinedOutput(); err != nil {
		die("systemd-run: %v\n%s", err, out)
	}

	pending, _ := strconv.Atoi(pendingCount(*root, *roster))
	left, _ := strconv.Atoi(strings.TrimSpace(remaining()))
	blob, _ := json.Marshal(struct {
		State   string `json:"state"`
		Unit    string `json:"unit"`
		Roster  string `json:"roster"`
		Started string `json:"started"`
		Pending int    `json:"pending"`
		Left    int    `json:"left"`
	}{
		State: "started", Unit: unit, Roster: *roster,
		Started: time.Now().UTC().Format("2006-01-02T15:04:05Z"),
		Pending: pending, Left: left,
	})
	state := string(blob) + "\n"
	if err := os.WriteFile(filepath.Join(*root, ".round.json"), []byte(state), 0644); err != nil {
		die("round: %v", err)
	}
	fmt.Print(state)
}

func getenvDef(name, def string) string {
	if v := os.Getenv(name); v != "" {
		return v
	}
	return def
}

// pendingCount is cmdPending's logic as a string result so `round` can reuse
// it without a subprocess.
func pendingCount(root, roster string) string {
	want := map[string]bool{}
	if data, err := os.ReadFile(roster); err == nil {
		for _, line := range strings.Split(string(data), "\n") {
			if strings.HasPrefix(line, "#") {
				continue
			}
			f := strings.Split(line, "|")
			if len(f) < 2 || strings.HasPrefix(f[1], "hold:") {
				continue
			}
			want["photoreal-"+f[0]] = true
		}
	}
	kept := map[string]bool{}
	for _, e := range readLedger(root) {
		if e.Verdict == "keep" {
			kept[e.Brief] = true
		}
	}
	n := 0
	for id := range want {
		if !kept[id] {
			n++
		}
	}
	return strconv.Itoa(n)
}
