package main

import (
	"context"
	"fmt"
	"html"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"time"
	"unicode"
)

const maxBody = 512 * 1024

var slugRe = regexp.MustCompile(`^[a-z0-9][a-z0-9-]{0,80}$`)

// post is one file: frontmatter plus body, which is all a blog post is here.
type post struct {
	Slug        string  `json:"slug"`
	Title       string  `json:"title"`
	PublishedAt string  `json:"published_at"`
	Body        string  `json:"body"`
	Mtime       float64 `json:"mtime"`
}

func (c *config) postsDir() (string, error) {
	dir := filepath.Join(c.state, "posts")
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return "", err
	}
	return dir, nil
}

func (c *config) postPath(slug string) (string, error) {
	if !slugRe.MatchString(slug) {
		return "", refuse(400, "bad slug %q", slug)
	}
	dir, err := c.postsDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(dir, slug+".md"), nil
}

var nonSlug = regexp.MustCompile(`[^a-z0-9]+`)

func slugify(title string) string {
	slug := strings.Trim(nonSlug.ReplaceAllString(strings.ToLower(title), "-"), "-")
	if len(slug) > 80 {
		slug = slug[:80]
	}
	if slug == "" {
		return "untitled"
	}
	return slug
}

// titleCase is Python's str.title() for the one place it is used: a slug with no
// title in its frontmatter. It splits on any non-letter, so `in-sync` is
// `In-Sync`, which is what the Python server printed.
func titleCase(s string) string {
	out := []rune(strings.ToLower(s))
	start := true
	for i, r := range out {
		if start {
			out[i] = []rune(strings.ToUpper(string(r)))[0]
		}
		start = !unicode.IsLetter(r)
		if unicode.IsLetter(r) {
			start = false
		}
	}
	return string(out)
}

// parseDoc splits frontmatter from body, and ignores a file that has none.
func parseDoc(text string) (map[string]string, string) {
	meta := map[string]string{}
	body := text
	if strings.HasPrefix(text, "---\n") {
		if end := strings.Index(text[4:], "\n---"); end != -1 {
			for _, line := range strings.Split(text[4:4+end], "\n") {
				key, value, ok := strings.Cut(line, ":")
				if !ok {
					continue
				}
				meta[strings.TrimSpace(key)] = strings.Trim(strings.TrimSpace(value), `"`)
			}
			body = strings.TrimLeft(text[4+end+4:], "\n")
		}
	}
	return meta, body
}

func (c *config) readPost(slug string) (post, error) {
	file, err := c.postPath(slug)
	if err != nil {
		return post{}, err
	}
	raw, err := os.ReadFile(file)
	if err != nil {
		return post{}, refuse(404, "no local post %s", slug)
	}
	meta, body := parseDoc(string(raw))
	title := meta["title"]
	if title == "" {
		title = titleCase(strings.ReplaceAll(slug, "-", " "))
	}
	info, statErr := os.Stat(file)
	mtime := 0.0
	if statErr == nil {
		mtime = float64(info.ModTime().UnixNano()) / 1e9
	}
	return post{
		Slug:        slug,
		Title:       title,
		PublishedAt: meta["published_at"],
		Body:        body,
		Mtime:       mtime,
	}, nil
}

func (c *config) writePost(slug, title, body, publishedAt string) (post, error) {
	if len([]byte(body)) > maxBody {
		return post{}, refuse(413, "body over %d bytes", maxBody)
	}
	slug = strings.TrimSpace(slug)
	if slug == "" {
		slug = slugify(title)
	}
	file, err := c.postPath(slug)
	if err != nil {
		return post{}, err
	}
	front := "---\ntitle: " + strings.TrimSpace(title) + "\npublished_at: " + strings.TrimSpace(publishedAt) + "\n---\n\n"
	content := front + strings.TrimLeft(body, "\n") + "\n"
	if err := os.WriteFile(file, []byte(content), 0o644); err != nil {
		return post{}, refuse(500, "writing %s: %v", slug, err)
	}
	c.gitCommit("post: " + slug)
	return c.readPost(slug)
}

func (c *config) listLocal() []post {
	dir, err := c.postsDir()
	if err != nil {
		return nil
	}
	entries, err := os.ReadDir(dir)
	if err != nil {
		return nil
	}
	var out []post
	for _, entry := range entries {
		if entry.IsDir() || filepath.Ext(entry.Name()) != ".md" {
			continue
		}
		p, err := c.readPost(strings.TrimSuffix(entry.Name(), ".md"))
		if err != nil {
			continue
		}
		out = append(out, p)
	}
	sort.SliceStable(out, func(i, j int) bool {
		if out[i].PublishedAt != out[j].PublishedAt {
			return out[i].PublishedAt > out[j].PublishedAt
		}
		return strings.ToLower(out[i].Title) > strings.ToLower(out[j].Title)
	})
	return out
}

// gitCommit keeps the file history, which is the point of files. A missing git
// is not an error: the post is already written.
func (c *config) gitCommit(message string) {
	if !c.commit {
		return
	}
	run := func(args ...string) (string, int, error) {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		cmd := exec.CommandContext(ctx, "git", args...)
		out, err := cmd.CombinedOutput()
		code := 0
		if exitErr, ok := err.(*exec.ExitError); ok {
			code = exitErr.ExitCode()
			err = nil
		}
		return string(out), code, err
	}

	if info, err := os.Stat(filepath.Join(c.state, ".git")); err != nil || !info.IsDir() {
		if _, _, err := run("init", "-q", c.state); err != nil {
			fmt.Fprintf(os.Stderr, "mataroa-console: git commit skipped (%v)\n", err)
			return
		}
	}
	// Identity on the command line, not in a config: the unit has no login shell
	// and its HOME is the state directory, so `git commit` found no user.name and
	// exited 128 — ten imported posts, an empty `git log`, and the edit trail the
	// docs promise did not exist (measured 2026-11-05).
	if out, code, err := run("-C", c.state, "add", "-A"); err != nil || code != 0 {
		fmt.Fprintf(os.Stderr, "mataroa-console: git commit skipped (add: %s %v)\n", strings.TrimSpace(out), err)
		return
	}
	if _, code, err := run("-C", c.state, "diff", "--cached", "--quiet"); err != nil || code == 0 {
		return
	}
	if out, code, err := run("-C", c.state,
		"-c", "user.name=mataroa-console", "-c", "user.email=mataroa-console@localhost",
		"-c", "commit.gpgsign=false", "commit", "-q", "-m", message); err != nil || code != 0 {
		fmt.Fprintf(os.Stderr, "mataroa-console: git commit skipped (%s %v)\n", strings.TrimSpace(out), err)
	}
}

// render is comrak when the host has it, and an honest pre-block when it does
// not: a missing renderer must not look like a post with no markdown.
func (c *config) render(markdown string) string {
	if c.comrak != "" {
		ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
		defer cancel()
		cmd := exec.CommandContext(ctx, c.comrak,
			"--unsafe", "-e", "table", "-e", "footnotes", "-e", "tasklist",
			"-e", "strikethrough", "-e", "autolink", "--smart", "--gemoji")
		cmd.Stdin = strings.NewReader(markdown)
		out, err := cmd.Output()
		if err == nil {
			return string(out)
		}
	}
	return "<pre>" + html.EscapeString(markdown) + "</pre>"
}
