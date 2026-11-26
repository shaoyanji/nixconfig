package image

// `image-daily post` — cmd_post: one motion from a title to a post that has a
// banner. The banner is generated, judged and uploaded before the file
// exists, so a post cannot ship with a hero that 404s, and no JPEG enters
// the tree. Same env contract as the shell: SLUG, TITLE, PROMPT, ALT,
// BLOG_DIR, DRAFT, FORCE, CATEGORIES, TAGS, DESCRIPTION, AUTHOR, PUSH.

import (
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

// fmField is fm_field: one front-matter field from a draft, unquoted. A draft
// is the source of the body and of the metadata the generator never asks for
// (description, author, the toc flags); the banner, the date and the title
// are the generator's.
func fmField(file, key string) string {
	data, err := os.ReadFile(file)
	if err != nil {
		return ""
	}
	fences := 0
	for _, line := range strings.Split(string(data), "\n") {
		if line == "---" {
			fences++
			continue
		}
		if fences == 1 && strings.HasPrefix(line, key+":") {
			v := strings.TrimSpace(line[len(key)+1:])
			v = strings.Trim(v, `"`)
			return v
		}
	}
	return ""
}

// fmBody: everything after the second front-matter fence, leading blank lines
// dropped — the `n>=2` awk plus `sed '/./,$!d'` the shell used.
func fmBody(file string) string {
	data, err := os.ReadFile(file)
	if err != nil {
		return ""
	}
	fences := 0
	var body []string
	for _, line := range strings.Split(string(data), "\n") {
		if line == "---" {
			fences++
			continue
		}
		if fences >= 2 {
			body = append(body, line)
		}
	}
	for len(body) > 0 && strings.TrimSpace(body[0]) == "" {
		body = body[1:]
	}
	return strings.Join(body, "\n")
}

func escQ(s string) string { return strings.ReplaceAll(s, `"`, `\"`) }

func cmdPost(args []string) {
	fs := flag.NewFlagSet("post", flag.ExitOnError)
	root := fs.String("root", os.Getenv("IMAGES_ROOT"), "image tree root")
	repo := fs.String("repo", os.Getenv("REPO"), "checkout root")
	_ = fs.Parse(args)
	slug := os.Getenv("SLUG")
	title := os.Getenv("TITLE")
	blog := os.Getenv("BLOG_DIR")
	if blog == "" {
		blog = os.Getenv("HOME") + "/Documents/shaoyanji.is-a.dev"
	}
	if slug == "" {
		die("SLUG=<url-slug> is required")
	}
	if title == "" {
		die(`TITLE="the post title" is required`)
	}
	if *root == "" || *repo == "" {
		die("post needs --root and --repo (or IMAGES_ROOT and REPO)")
	}
	if fi, err := os.Stat(blog + "/.git"); err != nil || !fi.IsDir() {
		die("no blog checkout at %s (BLOG_DIR=...)", blog)
	}
	for _, c := range []string{"cpg", "agy", "ffmpeg", "git"} {
		if _, err := exec.LookPath(c); err != nil {
			die("%s is not on PATH", c)
		}
	}
	alt := os.Getenv("ALT")
	if alt == "" {
		alt = title
	}
	prompt := os.Getenv("PROMPT")
	if prompt == "" {
		prompt = "A blog banner for an engineering post titled \"" + title + "\". One clear subject, realistic photographic style, natural light, shallow depth of field, no text, no lettering, no logos, nothing to read."
	}
	day := today()
	post := blog + "/_posts/" + day + "-" + slug + ".md"
	if _, err := os.Stat(post); err == nil && os.Getenv("FORCE") != "1" {
		die("%s exists — FORCE=1 to rewrite its front matter (the body is kept)", post)
	}
	// A promotion starts from a draft: same slug, an older date, a body
	// already written. `DRAFT=1` finds it beside the target, `DRAFT=<path>`
	// names it.
	draft := ""
	switch d := os.Getenv("DRAFT"); {
	case d == "" || d == "0":
	case d == "1":
		matches, _ := filepath.Glob(blog + "/_posts/*-" + slug + ".md")
		for _, m := range matches {
			if !strings.Contains(m, "/"+day+"-") {
				draft = m
				break
			}
		}
		if draft == "" {
			die("DRAFT=1: no _posts/*-%s.md beside %s to promote", slug, post)
		}
	default:
		draft = strings.TrimPrefix(d, "./")
		if !filepath.IsAbs(draft) {
			draft = blog + "/" + draft
		}
	}
	if draft != "" {
		if _, err := os.Stat(draft); err != nil {
			die("no draft at %s", draft)
		}
	}
	if rem := remaining(); rem == "" || rem == "0" {
		die("no images left today")
	}

	say("%s: generating a banner", slug)
	id := "blog-" + slug
	file, rc := attempt(*root, id, "blog", "1536x1024", slug+".png", prompt, day, 1, 1)
	if rc != 0 {
		die("generation failed")
	}
	intent := laneSetting(*repo, "blog", "intent")
	verdict, defect, reason := verdictParts(judgeImage(*root, *repo, file, "blog", intent, ""))
	if verdict == "reroll" {
		if defect == "" {
			defect = "the composition"
		}
		say("%s: reroll — %s", slug, defect)
		_ = os.Remove(file)
		file, rc = attempt(*root, id, "blog", "1536x1024", slug+".png",
			prompt+" (Change only this: "+defect+".)", day, 1, 1)
		if rc != 0 {
			die("reroll failed")
		}
		verdict, _, reason = verdictParts(judgeImage(*root, *repo, file, "blog", intent, ""))
	}
	say("judge: %s — %s", verdict, reason)
	if verdict != "keep" {
		die("the judge did not keep %s; nothing was uploaded", file)
	}
	record(*root, day, "blog", id, file, "keep", reason, prompt, 1, 1)

	jpg := *root + "/published/blog/" + slug + ".jpg"
	if !bannerCrop(file, jpg) {
		die("could not crop the banner")
	}
	c, err := cloudinaryCreds(*repo)
	if err != nil {
		die("cloudinary credentials: %v", err)
	}
	url, err := cloudUpload(c, jpg, "", "assets/blog/"+slug)
	if err != nil {
		die("upload failed: %v", err)
	}
	say("cloudinary: %s", url)

	// The manifest is the reference list: a new upload of the same slug
	// replaces the old row instead of joining it, so a regenerated banner
	// does not appear twice.
	tsv := *root + "/published/urls.tsv"
	_ = os.MkdirAll(filepath.Dir(tsv), 0755)
	var kept []string
	if b, err := os.ReadFile(tsv); err == nil {
		for _, line := range strings.Split(string(b), "\n") {
			if !strings.HasPrefix(line, "blog/"+slug+".jpg\t") && line != "" {
				kept = append(kept, line)
			}
		}
	}
	fi, _ := os.Stat(jpg)
	kept = append(kept, fmt.Sprintf("blog/%s.jpg\t%s\t%d", slug, url, fi.Size()))
	if err := os.WriteFile(tsv, []byte(strings.Join(kept, "\n")+"\n"), 0644); err != nil {
		die("cannot write %s: %v", tsv, err)
	}
	indexBody(*root, *repo)
	cmdDeploy([]string{"--root", *root, "--repo", *repo})

	// The public id carries no extension; the delivery URL names the format
	// anyway, and the other fifteen posts are `.jpg`, so a scraper never has
	// to guess.
	card := fmt.Sprintf("https://res.cloudinary.com/%s/image/upload/f_jpg,q_auto,w_1200,h_630,c_fill/assets/blog/%s.jpg",
		c.name, slug)

	// Two sources for the metadata: a draft (a promotion) or an existing post
	// (`FORCE=1`). The body is everything after the second fence either way.
	fmSrc := ""
	if draft != "" {
		fmSrc = draft
	} else if _, err := os.Stat(post); err == nil {
		fmSrc = post
	}
	body := ""
	if fmSrc != "" {
		body = fmBody(fmSrc)
		if body == "" {
			die("%s has no body after its front matter", fmSrc)
		}
	}
	cats := getenvDef("CATEGORIES", "")
	tgs := getenvDef("TAGS", "")
	desc := getenvDef("DESCRIPTION", "")
	author := getenvDef("AUTHOR", "")
	pin, toc, comments, math, mermaid := "false", "true", "false", "false", "false"
	if fmSrc != "" {
		if cats == "" {
			cats = fmField(fmSrc, "categories")
		}
		if tgs == "" {
			tgs = fmField(fmSrc, "tags")
		}
		if desc == "" {
			desc = fmField(fmSrc, "description")
		}
		if author == "" {
			author = fmField(fmSrc, "author")
		}
		if v := fmField(fmSrc, "pin"); v != "" {
			pin = v
		}
		if v := fmField(fmSrc, "toc"); v != "" {
			toc = v
		}
		if v := fmField(fmSrc, "comments"); v != "" {
			comments = v
		}
		if v := fmField(fmSrc, "math"); v != "" {
			math = v
		}
		if v := fmField(fmSrc, "mermaid"); v != "" {
			mermaid = v
		}
	}
	if cats == "" {
		cats = "Blog"
	}
	if tgs == "" {
		tgs = "technology"
	}
	cats = strings.Trim(cats, "[]")
	tgs = strings.Trim(tgs, "[]")

	var b strings.Builder
	b.WriteString("---\n")
	b.WriteString("layout: post\n")
	fmt.Fprintf(&b, "title: \"%s\"\n", escQ(title))
	fmt.Fprintf(&b, "date: %s 00:00:00 +0000\n", day)
	fmt.Fprintf(&b, "categories: [%s]\n", cats)
	fmt.Fprintf(&b, "tags: [%s]\n", tgs)
	if desc != "" {
		fmt.Fprintf(&b, "description: \"%s\"\n", escQ(desc))
	}
	if author != "" {
		fmt.Fprintf(&b, "author: %s\n", author)
	}
	fmt.Fprintf(&b, "image:\n  path: %s\n  alt: \"%s\"\n", card, escQ(alt))
	if fmSrc != "" {
		fmt.Fprintf(&b, "pin: %s\ntoc: %s\ncomments: %s\nmath: %s\nmermaid: %s\n",
			pin, toc, comments, math, mermaid)
	}
	b.WriteString("---\n\n")
	if body != "" {
		b.WriteString(body + "\n")
	}
	if err := os.WriteFile(post, []byte(b.String()), 0644); err != nil {
		die("cannot write %s: %v", post, err)
	}
	say("post: %s", post)

	paths := []string{strings.TrimPrefix(post, blog+"/")}
	if draft != "" && draft != post {
		_ = os.Remove(draft)
		// A draft that was never tracked leaves nothing for git to stage, and
		// `git add --` on a path that does not exist is fatal, which aborted
		// the commit and the push after the banner had already been paid for
		// (2026-11-16). Only a tracked draft is worth naming.
		rel := strings.TrimPrefix(draft, blog+"/")
		if _, err := exec0("git", "-C", blog, "ls-files", "--error-unmatch", rel); err == nil {
			paths = append(paths, rel)
		}
	}
	addArgs := append([]string{"-C", blog, "add", "-A", "--"}, paths...)
	_, _ = exec0("git", addArgs...)
	diffArgs := append([]string{"-C", blog, "diff", "--cached", "--quiet", "--"}, paths...)
	if _, err := exec0("git", diffArgs...); err != nil {
		_, _ = exec0("git", "-C", blog, "commit", "-q", "-m", "post: "+title,
			"-m", "Banner from the image queue, on Cloudinary where the crop lives in the URL.")
	}
	log, _ := exec0("git", "-C", blog, "log", "--oneline", "-1")
	say("commit: %s", strings.TrimSpace(log))
	if os.Getenv("PUSH") == "1" {
		if _, err := exec0("git", "-C", blog, "push", "-q", "origin", "HEAD"); err == nil {
			say("pushed: the site deploys from this")
		}
	} else {
		say("not pushed — PUSH=1 lands it")
	}
}

// verdictParts parses the judge JSON once for cmd_post's three fields.
func verdictParts(v string) (verdict, defect, reason string) {
	var m struct {
		Verdict string `json:"verdict"`
		Defect  string `json:"defect"`
		Reason  string `json:"reason"`
	}
	_ = json.Unmarshal([]byte(v), &m)
	return m.Verdict, m.Defect, m.Reason
}
