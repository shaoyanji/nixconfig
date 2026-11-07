package main

import (
	"bytes"
	"encoding/json"
	"io"
	"net/http"
	"net/url"
	"os"
	"sort"
	"strings"
	"sync"
	"time"
)

type remoteCache struct {
	mu    sync.Mutex
	at    time.Time
	posts map[string]map[string]any
	err   string
}

func (c *config) api(method, path string, payload map[string]any) (map[string]any, error) {
	if c.token == "" {
		return nil, refuse(503, "no mataroa token in the environment")
	}
	var body io.Reader
	if payload != nil {
		raw, err := json.Marshal(payload)
		if err != nil {
			return nil, refuse(502, "mataroa %s %s failed: %v", method, path, err)
		}
		body = bytes.NewReader(raw)
	}
	req, err := http.NewRequest(method, strings.TrimRight(c.apiBase, "/")+path, body)
	if err != nil {
		return nil, refuse(502, "mataroa %s %s failed: %v", method, path, err)
	}
	req.Header.Set("Authorization", "Bearer "+c.token)
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json")

	client := &http.Client{Timeout: 25 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return nil, refuse(502, "mataroa %s %s failed: %v", method, path, err)
	}
	defer resp.Body.Close()
	raw, _ := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	if resp.StatusCode >= 400 {
		detail := string(raw)
		if len(detail) > 300 {
			detail = detail[:300]
		}
		return nil, refuse(502, "mataroa %s %s -> %d: %s", method, path, resp.StatusCode, detail)
	}
	if len(bytes.TrimSpace(raw)) == 0 {
		return map[string]any{}, nil
	}
	var decoded map[string]any
	if err := json.Unmarshal(raw, &decoded); err != nil {
		return nil, refuse(502, "mataroa %s %s failed: %v", method, path, err)
	}
	return decoded, nil
}

// remotePosts is the blog listing, cached for 30 seconds: a ledger render is a
// page load, not a sync.
func (c *config) remotePosts(refresh bool) map[string]map[string]any {
	c.cache.mu.Lock()
	defer c.cache.mu.Unlock()
	if !refresh && time.Since(c.cache.at) < 30*time.Second {
		return c.cache.posts
	}
	c.cache.at = time.Now()
	listing, err := c.api("GET", "/posts/", nil)
	if err != nil {
		c.cache.posts = map[string]map[string]any{}
		c.cache.err = err.Error()
		return c.cache.posts
	}
	posts := map[string]map[string]any{}
	if raw, ok := listing["post_list"].([]any); ok {
		for _, item := range raw {
			entry, ok := item.(map[string]any)
			if !ok {
				continue
			}
			slug, _ := entry["slug"].(string)
			if slug != "" {
				posts[slug] = entry
			}
		}
	}
	c.cache.posts = posts
	c.cache.err = ""
	return posts
}

func (c *config) cacheErr() string {
	c.cache.mu.Lock()
	defer c.cache.mu.Unlock()
	return c.cache.err
}

type ledgerRow struct {
	Slug        string `json:"slug"`
	Title       string `json:"title"`
	PublishedAt string `json:"published_at"`
	Local       bool   `json:"local"`
	Remote      bool   `json:"remote"`
	State       string `json:"state"`
	URL         string `json:"url"`
}

type ledgerData struct {
	Posts       []ledgerRow `json:"posts"`
	Error       string      `json:"error"`
	RemoteCount int         `json:"remote_count"`
}

func (c *config) ledger(refresh bool) ledgerData {
	local := map[string]post{}
	for _, p := range c.listLocal() {
		local[p.Slug] = p
	}
	remote := c.remotePosts(refresh)

	slugs := map[string]bool{}
	for slug := range local {
		slugs[slug] = true
	}
	for slug := range remote {
		slugs[slug] = true
	}
	ordered := make([]string, 0, len(slugs))
	for slug := range slugs {
		ordered = append(ordered, slug)
	}
	sort.Strings(ordered)

	rows := make([]ledgerRow, 0, len(ordered))
	for _, slug := range ordered {
		lp, hasLocal := local[slug]
		rp := remote[slug]
		row := ledgerRow{Slug: slug, Local: hasLocal, Remote: rp != nil}
		switch {
		case hasLocal && rp != nil:
			remoteBody, _ := rp["body"].(string)
			remotePublished, _ := rp["published_at"].(string)
			if strings.TrimSpace(lp.Body) == strings.TrimSpace(remoteBody) && lp.PublishedAt == remotePublished {
				row.State = "in-sync"
			} else {
				row.State = "differs"
			}
		case hasLocal:
			row.State = "local-only"
		default:
			row.State = "remote-only"
		}
		if hasLocal {
			row.Title = lp.Title
			row.PublishedAt = lp.PublishedAt
		} else {
			row.Title, _ = rp["title"].(string)
			if row.Title == "" {
				row.Title = slug
			}
			row.PublishedAt, _ = rp["published_at"].(string)
		}
		if rp != nil {
			row.URL, _ = rp["url"].(string)
		}
		rows = append(rows, row)
	}
	sort.SliceStable(rows, func(i, j int) bool {
		if rows[i].PublishedAt != rows[j].PublishedAt {
			return rows[i].PublishedAt > rows[j].PublishedAt
		}
		return strings.ToLower(rows[i].Title) > strings.ToLower(rows[j].Title)
	})
	return ledgerData{Posts: rows, Error: c.cacheErr(), RemoteCount: len(remote)}
}

// publish posts a new file or patches an existing one, and writes the slug the
// blog answered with back into the file — a new post gets its slug from mataroa.
func (c *config) publish(slug string, publishedAt *string) (map[string]any, error) {
	current, err := c.readPost(slug)
	if err != nil {
		return nil, err
	}
	when := current.PublishedAt
	if publishedAt != nil {
		when = *publishedAt
	}
	payload := map[string]any{"title": current.Title, "body": current.Body}
	if when != "" {
		payload["published_at"] = when
	}

	known := c.remotePosts(true)
	var result map[string]any
	if _, exists := known[slug]; exists {
		result, err = c.api("PATCH", "/posts/"+url.PathEscape(slug)+"/", payload)
	} else {
		if when == "" {
			payload["published_at"] = time.Now().Format("2006-01-02")
		}
		result, err = c.api("POST", "/posts/", payload)
	}
	if err != nil {
		return nil, err
	}

	newSlug := slug
	if answer, ok := result["slug"].(string); ok && answer != "" {
		newSlug = answer
	}
	if newSlug != slug {
		if old, pathErr := c.postPath(slug); pathErr == nil {
			os.Remove(old)
		}
	}
	newWhen, _ := payload["published_at"].(string)
	if _, writeErr := c.writePost(newSlug, current.Title, current.Body, newWhen); writeErr != nil {
		return nil, writeErr
	}
	c.remotePosts(true)
	answerURL, _ := result["url"].(string)
	return map[string]any{"slug": newSlug, "url": answerURL, "published_at": newWhen}, nil
}

func (c *config) unpublish(slug string) (map[string]any, error) {
	if _, err := c.readPost(slug); err != nil {
		return nil, err
	}
	result, err := c.api("PATCH", "/posts/"+url.PathEscape(slug)+"/", map[string]any{"published_at": ""})
	if err != nil {
		return nil, err
	}
	current, err := c.readPost(slug)
	if err != nil {
		return nil, err
	}
	if _, err := c.writePost(slug, current.Title, current.Body, ""); err != nil {
		return nil, err
	}
	c.remotePosts(true)
	answerURL, _ := result["url"].(string)
	return map[string]any{"slug": slug, "url": answerURL}, nil
}

func (c *config) pull() (map[string]any, error) {
	remote := c.remotePosts(true)
	var imported []string
	for slug, rp := range remote {
		if !slugRe.MatchString(slug) {
			continue
		}
		if file, err := c.postPath(slug); err != nil {
			_ = file
			continue
		} else if _, statErr := os.Stat(file); statErr == nil {
			continue
		}
		title, _ := rp["title"].(string)
		if title == "" {
			title = slug
		}
		body, _ := rp["body"].(string)
		published, _ := rp["published_at"].(string)
		if _, err := c.writePost(slug, title, body, published); err != nil {
			return nil, err
		}
		imported = append(imported, slug)
	}
	// Also on a pull that imported nothing: a repo whose earlier commits failed
	// still has files and no history, and this is the one call that repairs it.
	c.gitCommit("pull: import remote posts")
	sort.Strings(imported)
	if imported == nil {
		imported = []string{}
	}
	return map[string]any{"imported": imported}, nil
}

