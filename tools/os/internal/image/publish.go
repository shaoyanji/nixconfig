package image

import (
	"bytes"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"time"
)

// The upload leg's read half: stage_publish copies kept plates into published/
// (cropping blog banners to 1200x630), and adopt_cloudinary merges rows for
// uploads that have none. The upload loop itself stays in
// image-daily-publish.sh — it owns the merge, shrink guard and deploy.

// bannerCrop: ffmpeg is the only image tool on this host, and it is enough for
// the one transform the pipeline needs — cover-crop to 1200x630.
func bannerCrop(png, jpg string) bool {
	if _, err := exec.LookPath("ffmpeg"); err != nil {
		say("ffmpeg is not on PATH")
		return false
	}
	_ = os.MkdirAll(filepath.Dir(jpg), 0755)
	return exec.Command("ffmpeg", "-loglevel", "error", "-y", "-i", png,
		"-vf", "scale=1200:630:force_original_aspect_ratio=increase,crop=1200:630",
		"-q:v", "3", jpg).Run() == nil
}

// stagePublish is stage_publish for one lane. Returns (shifted, gone): a stale
// ledger path that resolves under another day in published/ shifted; one that
// resolves nowhere is gone. Neither fails the pass — one old row must not stop
// the manifest — but the caller counts and says them once.
func stagePublish(root, lane string) (shifted, gone int) {
	var paths []string
	seen := map[string]bool{}
	for _, e := range readLedger(root) {
		if e.Verdict != "keep" || e.Lane != lane {
			continue
		}
		if !seen[e.Path] {
			seen[e.Path] = true
			paths = append(paths, e.Path)
		}
	}
	sort.Strings(paths) // | sort -u

	for _, file := range paths {
		// A legacy row can carry a log line before its path; the path is the
		// last line either way.
		if i := strings.LastIndex(file, "\n"); i >= 0 {
			file = file[i+1:]
		}
		rel := strings.TrimPrefix(file, root+"/src/")
		if _, err := os.Stat(file); err != nil {
			base := filepath.Base(rel)
			laneDir := rel
			if i := strings.Index(rel, "/"); i >= 0 {
				laneDir = rel[:i]
			}
			matches, _ := filepath.Glob(root + "/published/" + laneDir + "/*/" + base)
			if len(matches) > 0 {
				shifted++
			} else {
				gone++
			}
			continue
		}
		if lane == "blog" {
			// 3:2 out of the generator, 1200x630 in the page.
			out := root + "/published/blog/" +
				strings.TrimSuffix(filepath.Base(file), ".png") + ".jpg"
			if !bannerCrop(file, out) {
				say("blog: could not crop %s", file)
			}
			continue
		}
		dest := filepath.Join(root, "published", filepath.FromSlash(rel))
		_ = os.MkdirAll(filepath.Dir(dest), 0755)
		data, err := os.ReadFile(file)
		if err == nil {
			_ = os.WriteFile(dest, data, 0644)
		}
	}
	return shifted, gone
}

// adoptCloudinary is adopt_cloudinary: a manifest row for every upload that
// has none. Adoption never rewrites a row that exists — the URL already being
// served is the one consumers have — and never deletes from the account.
func adoptCloudinary(root, repo string) {
	rows := root + "/published/urls.tsv"
	existing, err := os.ReadFile(rows)
	if err != nil || len(existing) == 0 {
		return
	}

	prefix := os.Getenv("ADOPT_PREFIX")
	if prefix == "" {
		prefix = "assets/"
	}
	cmd := exec.Command("bash", repo+"/scripts/task/cloudinary.sh",
		"list", "--prefix", prefix, "--json")
	var outBuf, errBuf bytes.Buffer
	cmd.Stdout, cmd.Stderr = &outBuf, &errBuf
	if cmd.Run() != nil {
		first := strings.SplitN(errBuf.String(), "\n", 2)[0]
		say("adopt: Cloudinary listing unreadable (%s); the rows stay the manifest", first)
		return
	}
	list := outBuf.String()

	have := map[string]bool{}
	for _, line := range strings.Split(string(existing), "\n") {
		if i := strings.Index(line, "\t"); i >= 0 {
			have[line[:i]] = true
		}
	}

	// The id is the path without its extension: wall|site|blog keep the
	// relative id, fleet/<host> adopts as badge/<host>. Everything else is not
	// gallery work and stays off the manifest.
	var skipRe *regexp.Regexp
	if skip, ok := os.LookupEnv("ADOPT_SKIP"); ok && skip == "" {
		skipRe = nil // ADOPT_SKIP= (empty) adopts everything
	} else if ok {
		skipRe = regexp.MustCompile(skip)
	} else {
		skipRe = regexp.MustCompile(`wallpaper-[0-9]+`)
	}

	n := 0
	var add []string
	for _, line := range strings.Split(list, "\n") {
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}
		n++
		var r struct {
			PublicID  string `json:"public_id"`
			SecureURL string `json:"secure_url"`
			Bytes     int64  `json:"bytes"`
			Format    string `json:"format"`
		}
		if err := json.Unmarshal([]byte(line), &r); err != nil {
			continue
		}
		if r.PublicID == "" || r.SecureURL == "" {
			continue
		}
		format := r.Format
		if format == "" {
			format = "png"
		}
		rel := strings.TrimPrefix(r.PublicID, "assets/")
		parts := strings.Split(rel, "/")
		var path string
		switch {
		case (parts[0] == "wall" || parts[0] == "site" || parts[0] == "blog") && len(parts) > 1:
			path = rel + "." + format
		case parts[0] == "fleet" && len(parts) == 2:
			path = "badge/" + parts[1] + "." + format
		default:
			continue
		}
		if have[path] || (skipRe != nil && skipRe.MatchString(path)) {
			continue
		}
		add = append(add, fmt.Sprintf("%s\t%s\t%d", path, r.SecureURL, r.Bytes))
	}

	if len(add) > 0 && os.Getenv("DRY") != "1" {
		merged := strings.Split(string(existing), "\n")
		if len(merged) > 0 && merged[len(merged)-1] == "" {
			merged = merged[:len(merged)-1]
		}
		merged = append(merged, add...)
		sort.Slice(merged, func(i, j int) bool {
			a, b := merged[i], merged[j]
			ka, kb := a, b
			if t := strings.Index(ka, "\t"); t >= 0 {
				ka = ka[:t]
			}
			if t := strings.Index(kb, "\t"); t >= 0 {
				kb = kb[:t]
			}
			if ka != kb {
				return ka < kb
			}
			return a < b // sort's last-resort whole-line compare on equal keys
		})
		tmp := rows + ".merged"
		if err := os.WriteFile(tmp, []byte(strings.Join(merged, "\n")+"\n"), 0644); err == nil {
			_ = os.Rename(tmp, rows)
		}
	}
	say("adopt: %d upload(s) with no row, out of %d on Cloudinary", len(add), n)
}

func cmdStage(args []string) {
	fs := flag.NewFlagSet("stage", flag.ExitOnError)
	root := fs.String("root", os.Getenv("IMAGES_ROOT"), "image tree root")
	lane := fs.String("lane", "", "lane")
	_ = fs.Parse(args)
	if *root == "" || *lane == "" {
		die("stage needs --lane and --root")
	}
	shifted, gone := stagePublish(*root, *lane)
	fmt.Printf("%d\t%d\n", shifted, gone)
}

// Cloudinary is the bank. The manifest is a view of the account, not of the
// disk: an upload with no row is an asset the gallery cannot show, and the
// ways to get one are ordinary — a publish from a host holding a slice of the
// tree, or a render written by `images:gen` that no round picked up. Measured
// 2026-11-21: 796 uploads, 195 with no row, 118 of them real plates that
// nothing could serve. The id is the path without its extension, so the row
// is derivable both ways, and a badge is addressed by host rather than by
// day. Adoption never rewrites a row that exists: the URL already being
// served is the one consumers have.
func cmdAdopt(args []string) {
	fs := flag.NewFlagSet("adopt", flag.ExitOnError)
	root := fs.String("root", os.Getenv("IMAGES_ROOT"), "image tree root")
	repo := fs.String("repo", os.Getenv("REPO"), "checkout root")
	_ = fs.Parse(args)
	if *root == "" || *repo == "" {
		die("adopt needs --root and --repo")
	}
	adoptCloudinary(*root, *repo)
}

// `image-daily shapes` — the ffprobe shape-cache loop build_index used to run:
// every urls.tsv rel gets one `rel\tWxH` row in published/shapes.tsv, measured
// once and cached. Published wins over src for the same rel; a file that is
// gone contributes nothing, and a rel already in the cache is never re-probed
// (exact-key match — the shell's substring grep could false-positive on a
// prefix collision).
func cmdShapes(args []string) {
	fs := flag.NewFlagSet("shapes", flag.ExitOnError)
	root := fs.String("root", os.Getenv("IMAGES_ROOT"), "image tree root")
	_ = fs.Parse(args)
	if *root == "" {
		die("shapes needs --root (or IMAGES_ROOT)")
	}

	shapesPass(*root)
}

// shapesPass extends published/shapes.tsv with one row per urls.tsv rel that
// is not already cached — the shape-cache loop build_index used to run.
func shapesPass(root string) {
	shapesPath := root + "/published/shapes.tsv"
	cached := map[string]bool{}
	if data, err := os.ReadFile(shapesPath); err == nil {
		for _, line := range strings.Split(string(data), "\n") {
			if f := strings.SplitN(line, "\t", 2); f[0] != "" {
				cached[f[0]] = true
			}
		}
	}
	f, err := os.OpenFile(shapesPath, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o644)
	if err != nil {
		die("shapes.tsv: %v", err)
	}
	defer f.Close()

	urls, err := os.ReadFile(root + "/published/urls.tsv")
	if err != nil {
		return // the caller guards urls.tsv; nothing cached to extend
	}
	for _, line := range strings.Split(string(urls), "\n") {
		rel := strings.SplitN(line, "\t", 2)[0]
		if rel == "" || cached[rel] {
			continue
		}
		file := root + "/published/" + rel
		if _, err := os.Stat(file); err != nil {
			file = root + "/src/" + rel
		}
		if _, err := os.Stat(file); err != nil {
			continue
		}
		if dim := dimensions(file); dim != "" {
			fmt.Fprintf(f, "%s\t%s\n", rel, dim)
		}
	}
}

// --- publish ---------------------------------------------------------------

// mergeServedURLs is merge_served_urls: a manifest is a union, not a
// snapshot. Publishing from a host that holds a slice of the bank rewrote the
// served gallery down to that slice — 2026-11-21 on delphi, 597 assets became
// 144 with every upload intact — and refusing the shrink only turned that
// into a blocked publish. The served manifest is the prior: a row that is
// already being served names an asset, and `path` is what makes two rows one.
// The rows on this host win, so a re-upload's URL replaces the old one; a
// path only the served manifest knows is carried forward untouched. An
// unreachable manifest leaves the local rows to publish alone, and
// shrinkGuard then decides. FORCE=1 skips the merge, because a deliberate
// purge is the one publish that means to drop assets.
func mergeServedURLs(root string) {
	rows := root + "/published/urls.tsv"
	if os.Getenv("FORCE") == "1" {
		say("merge: FORCE=1, publishing this host's rows only")
		return
	}
	if v := os.Getenv("MERGE"); v != "" && v != "1" {
		say("merge: MERGE=0, publishing this host's rows only")
		return
	}
	local, err := os.ReadFile(rows)
	if err != nil || len(strings.TrimSpace(string(local))) == 0 {
		return
	}
	from := os.Getenv("MERGE_FROM")
	if from == "" {
		from = "https://" + getenvDef("PROJECT", "bountystash-assets") + ".pages.dev/manifest.json"
	}
	client := &http.Client{Timeout: 25 * time.Second}
	resp, err := client.Get(from)
	if err != nil {
		say("merge: %s answered nothing — publishing this host's rows only", from)
		return
	}
	defer resp.Body.Close()
	var m struct {
		Assets []struct {
			Path  string `json:"path"`
			URL   string `json:"url"`
			Bytes int64  `json:"bytes"`
		} `json:"assets"`
	}
	body, err := io.ReadAll(resp.Body)
	if err != nil || resp.StatusCode != 200 || json.Unmarshal(body, &m) != nil {
		say("merge: %s is not a manifest — publishing this host's rows only", from)
		return
	}
	have := map[string]bool{}
	localN := 0
	for _, line := range strings.Split(strings.TrimRight(string(local), "\n"), "\n") {
		if f := strings.SplitN(line, "\t", 2); len(f) == 2 {
			have[f[0]] = true
			localN++
		}
	}
	var added []string
	for _, a := range m.Assets {
		if a.Path != "" && a.URL != "" && !have[a.Path] {
			added = append(added, fmt.Sprintf("%s\t%s\t%d", a.Path, a.URL, a.Bytes))
		}
	}
	if len(added) > 0 {
		merged := append(strings.Split(strings.TrimRight(string(local), "\n"), "\n"), added...)
		sort.Strings(merged) // sort -t$'\t' -k1,1 — rows are path-prefixed
		if err := os.WriteFile(rows, []byte(strings.Join(merged, "\n")+"\n"), 0644); err != nil {
			die("merge: cannot write %s: %v", rows, err)
		}
	}
	total := len(strings.Split(strings.TrimSpace(string(mustRead(rows))), "\n"))
	say("merge: %d local + %d from the served manifest = %d asset(s)", localN, len(added), total)
}

func mustRead(path string) []byte {
	b, _ := os.ReadFile(path)
	return b
}

// `image-daily publish` — cmd_publish: gate, stage, union-merge the served
// manifest, upload every restaged file, shrink-guard, deploy. Cloudinary is
// the asset plane, not a deployed gallery: the delivery URL carries its own
// resize (`f_auto,q_auto,w_1200`), so a consumer picks the size it needs from
// one upload and this tree never becomes a website.
func cmdPublish(args []string) {
	fs := flag.NewFlagSet("publish", flag.ExitOnError)
	root := fs.String("root", os.Getenv("IMAGES_ROOT"), "image tree root")
	repo := fs.String("repo", os.Getenv("REPO"), "checkout root")
	_ = fs.Parse(args)
	if *root == "" || *repo == "" {
		die("publish needs --root and --repo (or IMAGES_ROOT and REPO)")
	}
	// The publish gate runs first: a manifest rewrite from a family that lost
	// a file or a breaker is the mistake it exists to catch (43 generations,
	// 0 keeps, 2026-11-22–23). GATE=0 skips it for a deliberate one-off repair.
	if os.Getenv("GATE") != "0" {
		if err := exec.Command("bash", *repo+"/scripts/task/image-daily-gate.sh").Run(); err != nil {
			die("publish gate failed — refusing to ship (GATE=0 overrides)")
		}
	}
	// A publish with no local tree is still a publish: the rows are the
	// manifest and the account completes them. Only an empty manifest beside
	// no ledger is a publish with nothing to say.
	rows := *root + "/published/urls.tsv"
	_, srcErr := os.Stat(*root + "/src")
	local, lerr := os.ReadFile(rows)
	hasRows := lerr == nil && len(strings.TrimSpace(string(local))) > 0
	if srcErr != nil && !hasRows {
		die("nothing to publish: no %s/src and no rows in %s", *root, rows)
	}
	// A publish on a host that does not hold the bank rewrites the manifest
	// down to the batch it can see: 2026-11-21 on delphi, 556 assets became
	// 144 with every upload still intact. Remember what was being served
	// before staging, and refuse to shrink it without FORCE=1.
	backup := ""
	if hasRows && os.Getenv("FORCE") != "1" {
		backup = *root + "/published/.urls.served"
		copyFile(rows, backup)
	}
	shifted, gone := 0, 0
	for _, lane := range []string{"site", "wall", "blog", "badge"} {
		if laneSetting(*repo, lane, "publish") != "true" {
			continue
		}
		s, g := stagePublish(*root, lane)
		shifted += s
		gone += g
	}
	if shifted > 0 || gone > 0 {
		say("publish: %d keep row(s) already served under another day, %d with no file left", shifted, gone)
	}
	mergeServedURLs(*root)
	adoptCloudinary(*root, *repo)
	indexBody(*root, *repo)
	staged := 0
	_ = filepath.Walk(*root+"/published", func(p string, fi os.FileInfo, err error) error {
		if err == nil && !fi.IsDir() && (strings.HasSuffix(p, ".png") || strings.HasSuffix(p, ".jpg")) {
			staged++
		}
		return nil
	})
	say("%d asset(s) staged", staged)
	shrinkGuard(*root, *repo, backup)
	if os.Getenv("DRY") == "1" {
		say("dry run: not uploading")
		return
	}

	// A public id is derived from the path and a kept plate is never
	// re-rendered, so a path the manifest already carries is already served.
	// Uploading it again is the difference between a thirty-second round
	// publish and a ten-minute one. REUPLOAD=1 puts every staged file back
	// over the wire, which is what a forced re-render of an existing slug
	// needs.
	known := map[string]bool{}
	if os.Getenv("REUPLOAD") != "1" && hasRows {
		if b, err := os.ReadFile(rows); err == nil {
			for _, line := range strings.Split(string(b), "\n") {
				if f := strings.SplitN(line, "\t", 2); len(f) == 2 {
					known[f[0]] = true
				}
			}
		}
	}
	// A publish replaces only the rows it restaged. Truncating the manifest
	// deletes every asset whose file is not on this host, so a publish from a
	// machine that does not hold the bank rewrites the frontend down to that
	// one batch.
	var restaged []string
	_ = filepath.Walk(*root+"/published", func(p string, fi os.FileInfo, err error) error {
		if err == nil && !fi.IsDir() && (strings.HasSuffix(p, ".png") || strings.HasSuffix(p, ".jpg")) {
			restaged = append(restaged, p)
		}
		return nil
	})
	sort.Strings(restaged)
	current, _ := os.ReadFile(rows)
	var fresh []string
	restagedRel := map[string]bool{}
	for _, file := range restaged {
		rel := strings.TrimPrefix(file, *root+"/published/")
		restagedRel[rel] = true
		id := "assets/" + strings.TrimSuffix(rel, filepath.Ext(rel))
		if strings.HasPrefix(rel, "badge/") {
			// A badge is addressed by host, not by day: the site map names
			// `assets/fleet/<host>`, so a re-render replaces the mark in place.
			id = "assets/fleet/" + strings.TrimSuffix(filepath.Base(rel), filepath.Ext(rel))
		}
		// Copy the existing row forward instead of skipping the file silently:
		// the merge below would otherwise read the file as restaged-but-
		// unwritten and delete an asset that is still being served.
		if known[rel] {
			for _, line := range strings.Split(string(current), "\n") {
				if strings.HasPrefix(line, rel+"\t") {
					fresh = append(fresh, line)
				}
			}
			continue
		}
		out, err := exec0("bash", *repo+"/scripts/task/cloudinary.sh", "upload", file, "--public-id", id)
		if err != nil {
			say("publish: upload failed for %s", rel)
			os.Exit(1)
		}
		url := strings.TrimSpace(out)
		fi, _ := os.Stat(file)
		fresh = append(fresh, fmt.Sprintf("%s\t%s\t%d", rel, url, fi.Size()))
		say("uploaded %s", rel)
	}
	for _, line := range strings.Split(string(current), "\n") {
		if f := strings.SplitN(line, "\t", 2); len(f) == 2 && !restagedRel[f[0]] {
			fresh = append(fresh, line)
		}
	}
	if err := os.WriteFile(rows, []byte(strings.Join(fresh, "\n")+"\n"), 0644); err != nil {
		die("publish: cannot write %s: %v", rows, err)
	}
	say("%d asset(s) on Cloudinary", len(fresh))
	indexBody(*root, *repo)
	shrinkGuard(*root, *repo, backup)
	cmdDeploy([]string{"--root", *root, "--repo", *repo})
}
