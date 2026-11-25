package image

// The two legs image-ship.sh used to run as inline shell: the remote fetch
// that polls the deployed manifest until a new row is on it, and the
// systemd-run block that hands the whole ship pipeline to a user unit.
// Same contracts as the snippets they replace — say() on stderr, the result
// JSON on stdout, and the same exit codes (served exits 1 when the row is
// absent after the poll, because the ship's last line reads it).

import (
	"encoding/json"
	"flag"
	"fmt"
	"net/http"
	"os"
	"os/exec"
	"strings"
	"time"
)

// slugify ports the shell's tr/sed/cut chain: lower, every run of non-[a-z0-9]
// to one dash, edges trimmed, capped at 48 chars (a slug names the user unit).
func slugify(s string) string {
	var b strings.Builder
	dash := false
	for _, r := range strings.ToLower(s) {
		if r >= 'a' && r <= 'z' || r >= '0' && r <= '9' {
			b.WriteRune(r)
			dash = false
		} else if !dash {
			b.WriteByte('-')
			dash = true
		}
	}
	out := strings.Trim(b.String(), "-")
	if len(out) > 48 {
		out = out[:48]
	}
	return out
}

// shipRunArgs is the systemd-run vector launch_detached built, pure so a test
// can pin it: a same-named unit from an earlier ship is stale, so cmdShipDetach
// stops it first, and DETACH=0 in the env is what makes the unit run the
// pipeline instead of detaching again.
func shipRunArgs(unit, repo, root, script string) []string {
	env := func(name, def string) string { return "--setenv=" + name + "=" + getenvDef(name, def) }
	return []string{
		"--user", "--unit", unit, "--collect",
		"--working-directory=" + repo,
		"--setenv=PATH=" + os.Getenv("PATH"),
		env("PROMPT", ""), env("OUT", ""), env("SIZE", "1536x1024"),
		"--setenv=IMAGES_ROOT=" + root,
		env("PROJECT", "bountystash-assets"), env("PAGES", "1"),
		"--setenv=DETACH=0", "--setenv=REPO=" + repo,
		"--", "bash", script,
	}
}

// `image-daily ship-detach --repo PATH --root PATH [--log PATH]` — detach a
// ship as image-ship-<slug>, answer {"unit","log"} like launch_detached did.
// The unit's own stdout is journald's; the log file holds systemd-run's
// chatter, which is what the shell's `>log 2>&1` redirect meant.
func cmdShipDetach(args []string) {
	fs := flag.NewFlagSet("ship-detach", flag.ExitOnError)
	log := fs.String("log", "", "log file for systemd-run's output (default $root/<slug>.ship.log)")
	repo := fs.String("repo", os.Getenv("REPO"), "checkout root")
	root := fs.String("root", os.Getenv("IMAGES_ROOT"), "image tree root")
	slug := fs.String("slug", "", "unit slug (default: slugify PROMPT)")
	_ = fs.Parse(args)
	prompt := os.Getenv("PROMPT")
	if prompt == "" {
		die("ship-detach needs PROMPT")
	}
	if *repo == "" || *root == "" {
		die("ship-detach needs --repo and --root (or REPO and IMAGES_ROOT)")
	}
	if _, err := exec.LookPath("systemd-run"); err != nil {
		die("systemd-run is required to detach a ship (run it in the foreground with DETACH=0)")
	}
	s := *slug
	if s == "" {
		s = slugify(prompt)
	}
	if s == "" {
		die("ship-detach: PROMPT slugifies to nothing")
	}
	l := *log
	if l == "" {
		l = *root + "/" + s + ".ship.log"
	}
	unit := "image-ship-" + s
	_ = exec.Command("systemctl", "--user", "stop", unit).Run()

	f, err := os.Create(l)
	if err != nil {
		die("ship-detach: cannot open log %s: %v", l, err)
	}
	defer f.Close()
	cmd := exec.Command("systemd-run",
		shipRunArgs(unit, *repo, *root, *repo+"/scripts/task/image-ship.sh")...)
	cmd.Stdout, cmd.Stderr = f, f
	if err := cmd.Run(); err != nil {
		die("systemd-run: %v", err)
	}
	out, _ := json.Marshal(struct {
		Unit string `json:"unit"`
		Log  string `json:"log"`
	}{Unit: unit, Log: l})
	fmt.Println(string(out))
}

// manifestServes polls url until the manifest carries rel — the readback a
// deploy's own readiness wait cannot see: `/` answering 200 says the frontend
// attached, not that this asset is on it.
func manifestServes(url, rel string, tries int, wait time.Duration) bool {
	client := &http.Client{Timeout: 10 * time.Second}
	for i := 0; i < tries; i++ {
		if resp, err := client.Get(url); err == nil {
			var m struct {
				Assets []struct {
					Path string `json:"path"`
				} `json:"assets"`
			}
			ok := resp.StatusCode == http.StatusOK && json.NewDecoder(resp.Body).Decode(&m) == nil
			resp.Body.Close()
			if ok {
				for _, a := range m.Assets {
					if a.Path == rel {
						return true
					}
				}
			}
		}
		if i+1 < tries {
			time.Sleep(wait)
		}
	}
	return false
}

// `image-daily served --rel PATH` — exit 0 when the deployed manifest carries
// the row, 1 after the poll runs out; --from points the check at any base URL
// (the fixture and the tests use it instead of the real Pages hostname).
func cmdServed(args []string) {
	fs := flag.NewFlagSet("served", flag.ExitOnError)
	rel := fs.String("rel", "", "manifest path to wait for")
	project := fs.String("project", getenvDef("PROJECT", "bountystash-assets"), "Pages project name")
	from := fs.String("from", "", "manifest URL override (default https://<project>.pages.dev/manifest.json)")
	tries := fs.Int("tries", 24, "poll count")
	wait := fs.Duration("wait", 5*time.Second, "delay between polls")
	_ = fs.Parse(args)
	if *rel == "" {
		die("served needs --rel")
	}
	url := *from
	if url == "" {
		url = "https://" + *project + ".pages.dev/manifest.json"
	}
	if manifestServes(url, *rel, *tries, *wait) {
		fmt.Println("true")
		return
	}
	fmt.Println("false")
	os.Exit(1)
}
