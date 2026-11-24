package main

import (
	"bytes"
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
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
