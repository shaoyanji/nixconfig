package main

import (
	"context"
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"encoding/xml"
	"errors"
	"fmt"
	"html"
	"io"
	"net/http"
	"net/url"
	"sort"
	"strconv"
	"strings"
	"time"
)

type parsedFeedItem struct {
	Title   string
	URL     string
	Summary string
	Content string
	GUID    string
}

type parsedFeed struct {
	Title string
	Items []parsedFeedItem
}

type xmlAtomLink struct {
	Href string `xml:"href,attr"`
	Rel  string `xml:"rel,attr"`
}

type xmlFeed struct {
	XMLName xml.Name
	Channel struct {
		Title string `xml:"title"`
		Items []struct {
			Title          string `xml:"title"`
			Link           string `xml:"link"`
			Description    string `xml:"description"`
			EncodedContent string `xml:"encoded"`
			GUID           string `xml:"guid"`
		} `xml:"item"`
	} `xml:"channel"`
	Title   string `xml:"title"`
	Entries []struct {
		Title   string        `xml:"title"`
		Links   []xmlAtomLink `xml:"link"`
		ID      string        `xml:"id"`
		Summary string        `xml:"summary"`
		Content string        `xml:"content"`
	} `xml:"entry"`
}

func feedText(raw string) string {
	return cleanSpace(html.UnescapeString(tagRE.ReplaceAllString(raw, " ")))
}

func parseFeed(raw []byte) (parsedFeed, error) {
	var document xmlFeed
	if err := xml.Unmarshal(raw, &document); err != nil {
		return parsedFeed{}, fmt.Errorf("parse feed XML: %w", err)
	}
	out := parsedFeed{Title: cleanSpace(firstNonEmptyString(document.Channel.Title, document.Title))}
	for _, item := range document.Channel.Items {
		content := firstNonEmptyString(item.EncodedContent, item.Description)
		out.Items = append(out.Items, parsedFeedItem{
			Title:   cleanSpace(item.Title),
			URL:     strings.TrimSpace(item.Link),
			Summary: feedText(item.Description),
			Content: feedText(content),
			GUID:    strings.TrimSpace(item.GUID),
		})
	}
	for _, entry := range document.Entries {
		link := ""
		fallback := ""
		for _, candidate := range entry.Links {
			if candidate.Href == "" {
				continue
			}
			if candidate.Rel == "" || candidate.Rel == "alternate" {
				link = candidate.Href
				break
			}
			if fallback == "" {
				fallback = candidate.Href
			}
		}
		if link == "" {
			link = fallback
		}
		content := firstNonEmptyString(entry.Content, entry.Summary)
		out.Items = append(out.Items, parsedFeedItem{
			Title:   cleanSpace(entry.Title),
			URL:     strings.TrimSpace(link),
			Summary: feedText(entry.Summary),
			Content: feedText(content),
			GUID:    strings.TrimSpace(entry.ID),
		})
	}
	items := make([]parsedFeedItem, 0, len(out.Items))
	for _, item := range out.Items {
		if strings.TrimSpace(item.URL) != "" {
			if item.Title == "" {
				item.Title = item.URL
			}
			items = append(items, item)
		}
	}
	out.Items = items
	if len(out.Items) == 0 {
		return parsedFeed{}, errors.New("feed contained no RSS items or Atom entries with links")
	}
	return out, nil
}

func resolveFeedURL(base, raw string) (string, error) {
	parsed, err := canonicalURL(raw)
	if err == nil {
		return parsed, nil
	}
	baseURL, baseErr := url.Parse(base)
	relative, relErr := url.Parse(raw)
	if baseErr != nil || relErr != nil || !relative.IsAbs() && baseURL.Scheme == "" {
		return "", err
	}
	return canonicalURL(baseURL.ResolveReference(relative).String())
}

func feedItemKey(item parsedFeedItem, canonical string) string {
	identity := strings.TrimSpace(item.GUID)
	if identity == "" {
		identity = canonical
	}
	sum := sha256.Sum256([]byte(identity))
	return hex.EncodeToString(sum[:])
}

func scanFeed(row interface{ Scan(...any) error }) (Feed, error) {
	var feed Feed
	var tags, created, updated string
	var extract, enabled int
	err := row.Scan(&feed.ID, &feed.URL, &feed.Title, &feed.Collection, &tags, &extract, &feed.Provider, &enabled, &feed.LastPolledAt, &feed.LastSuccessAt, &feed.LastError, &feed.LastItemCount, &created, &updated)
	if err != nil {
		return Feed{}, err
	}
	feed.Tags = parseTags(tags)
	feed.Extract = extract != 0
	feed.Enabled = enabled != 0
	feed.CreatedAt = parseDBTime(created)
	feed.UpdatedAt = parseDBTime(updated)
	return feed, nil
}

const feedSelect = `SELECT id,url,title,collection,tags,extract,provider,enabled,last_polled_at,last_success_at,last_error,last_item_count,created_at,updated_at FROM feeds`

func (s *Store) UpsertFeed(ctx context.Context, input FeedInput) (Feed, bool, error) {
	if err := validateFeedInput(&input); err != nil {
		return Feed{}, false, err
	}
	now := nowString()
	extract := 0
	if input.Extract {
		extract = 1
	}
	result, err := s.db.ExecContext(ctx, `INSERT INTO feeds(url,title,collection,tags,extract,provider,created_at,updated_at)
		VALUES(?,?,?,?,?,?,?,?)
		ON CONFLICT(url) DO UPDATE SET
			title=CASE WHEN excluded.title!='' THEN excluded.title ELSE feeds.title END,
			collection=excluded.collection,
			tags=excluded.tags,
			extract=excluded.extract,
			provider=excluded.provider,
			updated_at=excluded.updated_at`,
		input.URL, input.Title, input.Collection, tagsJSON(input.Tags), extract, input.Provider, now, now)
	if err != nil {
		return Feed{}, false, err
	}
	var createdAt, updatedAt string
	var id int64
	if err := s.db.QueryRowContext(ctx, `SELECT id,created_at,updated_at FROM feeds WHERE url=?`, input.URL).Scan(&id, &createdAt, &updatedAt); err != nil {
		return Feed{}, false, err
	}
	created := createdAt == updatedAt
	if affected, _ := result.RowsAffected(); affected == 0 {
		created = false
	}
	feed, err := s.Feed(ctx, id)
	return feed, created, err
}

func (s *Store) Feed(ctx context.Context, id int64) (Feed, error) {
	return scanFeed(s.db.QueryRowContext(ctx, feedSelect+` WHERE id=?`, id))
}

func (s *Store) Feeds(ctx context.Context) ([]Feed, error) {
	rows, err := s.db.QueryContext(ctx, feedSelect+` ORDER BY lower(COALESCE(NULLIF(title,''), url))`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []Feed{}
	for rows.Next() {
		feed, err := scanFeed(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, feed)
	}
	return out, rows.Err()
}

func (s *Store) DeleteFeed(ctx context.Context, id int64) error {
	result, err := s.db.ExecContext(ctx, `DELETE FROM feeds WHERE id=?`, id)
	if err != nil {
		return err
	}
	if affected, _ := result.RowsAffected(); affected == 0 {
		return sql.ErrNoRows
	}
	return nil
}

func (s *Store) feedItemLink(ctx context.Context, feedID int64, key string) (int64, bool, error) {
	var linkID sql.NullInt64
	err := s.db.QueryRowContext(ctx, `SELECT link_id FROM feed_items WHERE feed_id=? AND item_key=?`, feedID, key).Scan(&linkID)
	if errors.Is(err, sql.ErrNoRows) {
		return 0, false, nil
	}
	if err != nil {
		return 0, false, err
	}
	if !linkID.Valid {
		return 0, true, nil
	}
	return linkID.Int64, true, nil
}

func (s *Store) recordFeedItem(ctx context.Context, feedID int64, key string, linkID int64) error {
	now := nowString()
	_, err := s.db.ExecContext(ctx, `INSERT INTO feed_items(feed_id,item_key,link_id,first_seen_at,last_seen_at) VALUES(?,?,?,?,?)
		ON CONFLICT(feed_id,item_key) DO UPDATE SET link_id=excluded.link_id,last_seen_at=excluded.last_seen_at`, feedID, key, linkID, now, now)
	return err
}

func (s *Store) finishFeedPoll(ctx context.Context, feedID int64, itemCount int, errText string) error {
	now := nowString()
	success := ""
	if errText == "" {
		success = now
	}
	_, err := s.db.ExecContext(ctx, `UPDATE feeds SET last_polled_at=?,last_success_at=CASE WHEN ?!='' THEN ? ELSE last_success_at END,last_error=?,last_item_count=?,updated_at=? WHERE id=?`, now, success, success, errText, itemCount, now, feedID)
	return err
}

var defaultFeedHTTPClient = &http.Client{Timeout: 15 * time.Second}

type feedPollResult struct {
	FeedID  int64   `json:"feed_id"`
	URL     string  `json:"url"`
	Status  string  `json:"status"`
	Items   int     `json:"items"`
	Created int     `json:"created"`
	Updated int     `json:"updated"`
	Skipped int     `json:"skipped"`
	Failed  int     `json:"failed"`
	LinkIDs []int64 `json:"link_ids,omitempty"`
	Error   string  `json:"error,omitempty"`
}

func (s *server) feedHTTPClient() *http.Client {
	if s.feedClient != nil {
		return s.feedClient
	}
	return defaultFeedHTTPClient
}

func (s *server) fetchFeed(ctx context.Context, rawurl string) (parsedFeed, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, rawurl, nil)
	if err != nil {
		return parsedFeed{}, err
	}
	req.Header.Set("User-Agent", "link-vault-feed-poller/0.2 (+https://delphi.cloudforest-kardashev.ts.net:8468)")
	req.Header.Set("Accept", "application/rss+xml,application/atom+xml,application/xml,text/xml;q=0.9,*/*;q=0.5")
	res, err := s.feedHTTPClient().Do(req)
	if err != nil {
		return parsedFeed{}, err
	}
	defer res.Body.Close()
	if res.StatusCode < 200 || res.StatusCode > 299 {
		return parsedFeed{}, fmt.Errorf("HTTP %s", res.Status)
	}
	raw, err := io.ReadAll(io.LimitReader(res.Body, 4<<20))
	if err != nil {
		return parsedFeed{}, err
	}
	return parseFeed(raw)
}

func (s *server) pollOneFeed(ctx context.Context, feed Feed) feedPollResult {
	result := feedPollResult{FeedID: feed.ID, URL: feed.URL, Status: "ok", LinkIDs: []int64{}}
	if !feed.Enabled {
		result.Status = "disabled"
		return result
	}
	pollCtx, cancel := context.WithTimeout(ctx, 45*time.Second)
	defer cancel()
	parsed, err := s.fetchFeed(pollCtx, feed.URL)
	if err != nil {
		result.Status = "error"
		result.Error = err.Error()
		result.Failed = 1
		_ = s.store.finishFeedPoll(context.Background(), feed.ID, 0, err.Error())
		return result
	}
	result.Items = len(parsed.Items)
	if feed.Title == "" && parsed.Title != "" {
		_, _ = s.store.db.ExecContext(ctx, `UPDATE feeds SET title=? WHERE id=? AND title=''`, parsed.Title, feed.ID)
	}
	for _, item := range parsed.Items {
		canonical, err := resolveFeedURL(feed.URL, item.URL)
		if err != nil {
			result.Failed++
			continue
		}
		key := feedItemKey(item, canonical)
		if linkID, seen, err := s.store.feedItemLink(ctx, feed.ID, key); err != nil {
			result.Failed++
			continue
		} else if seen {
			result.Skipped++
			if linkID != 0 {
				result.LinkIDs = append(result.LinkIDs, linkID)
			}
			continue
		}
		input := LinkInput{
			URL:         canonical,
			Title:       item.Title,
			Description: item.Summary,
			Content:     item.Content,
			SiteName:    firstNonEmptyString(parsed.Title, feed.Title),
			Source:      "feed",
			State:       "unread",
			Tags:        feed.Tags,
			Collection:  feed.Collection,
		}
		link, created, err := s.store.UpsertLink(ctx, input)
		if err != nil {
			result.Failed++
			continue
		}
		if feed.Extract {
			s.extractSavedLink(pollCtx, link.ID, feed.Provider)
		}
		if err := s.store.recordFeedItem(ctx, feed.ID, key, link.ID); err != nil {
			result.Failed++
			continue
		}
		result.LinkIDs = append(result.LinkIDs, link.ID)
		if created {
			result.Created++
		} else {
			result.Updated++
		}
	}
	if result.Failed > 0 {
		result.Status = "partial"
		result.Error = fmt.Sprintf("%d feed item(s) failed", result.Failed)
	}
	errText := result.Error
	if result.Status == "ok" {
		errText = ""
	}
	if err := s.store.finishFeedPoll(context.Background(), feed.ID, result.Items, errText); err != nil {
		result.Status = "error"
		result.Error = err.Error()
		result.Failed++
	}
	return result
}

func (s *server) pollFeeds(ctx context.Context, onlyID int64) map[string]any {
	s.feedMu.Lock()
	defer s.feedMu.Unlock()
	feeds, err := s.store.Feeds(ctx)
	if err != nil {
		return map[string]any{"error": err.Error()}
	}
	results := []feedPollResult{}
	created, updated, skipped, failed := 0, 0, 0, 0
	matched := false
	for _, feed := range feeds {
		if onlyID != 0 && feed.ID != onlyID {
			continue
		}
		matched = true
		if !feed.Enabled {
			continue
		}
		result := s.pollOneFeed(ctx, feed)
		results = append(results, result)
		created += result.Created
		updated += result.Updated
		skipped += result.Skipped
		failed += result.Failed
	}
	if onlyID != 0 && !matched {
		return map[string]any{"missing": true}
	}
	sort.Slice(results, func(i, j int) bool { return results[i].FeedID < results[j].FeedID })
	return map[string]any{
		"polled":  len(results),
		"created": created,
		"updated": updated,
		"skipped": skipped,
		"failed":  failed,
		"results": results,
	}
}

func (s *server) feedLoop(interval time.Duration) {
	ticker := time.NewTicker(interval)
	defer ticker.Stop()
	for range ticker.C {
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
		s.pollFeeds(ctx, 0)
		cancel()
	}
}

func (s *server) feeds(w http.ResponseWriter, r *http.Request) {
	feeds, err := s.store.Feeds(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"feeds": feeds, "count": len(feeds)})
}

func (s *server) createFeed(w http.ResponseWriter, r *http.Request) {
	if !s.writeAllowed(w, r) {
		return
	}
	var input FeedInput
	if err := decodeJSON(r, &input); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	feed, created, err := s.store.UpsertFeed(r.Context(), input)
	if err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	status := http.StatusOK
	if created {
		status = http.StatusCreated
	}
	writeJSON(w, status, map[string]any{"feed": feed, "created": created})
}

func (s *server) deleteFeed(w http.ResponseWriter, r *http.Request) {
	if !s.writeAllowed(w, r) {
		return
	}
	id, err := strconvParseID(r.PathValue("id"))
	if err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	if err := s.store.DeleteFeed(r.Context(), id); err != nil {
		writeError(w, http.StatusNotFound, errors.New("feed not found"))
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"deleted": true, "id": id})
}

func strconvParseID(raw string) (int64, error) {
	id, err := strconv.ParseInt(raw, 10, 64)
	if err != nil {
		return 0, errors.New("id must be numeric")
	}
	return id, nil
}

func (s *server) pollFeedsEndpoint(w http.ResponseWriter, r *http.Request) {
	if !s.writeAllowed(w, r) {
		return
	}
	var input struct {
		ID int64 `json:"id"`
	}
	raw, err := io.ReadAll(io.LimitReader(r.Body, 1<<20))
	if err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	if len(strings.TrimSpace(string(raw))) > 0 {
		decoder := json.NewDecoder(strings.NewReader(string(raw)))
		decoder.DisallowUnknownFields()
		if err := decoder.Decode(&input); err != nil {
			writeError(w, http.StatusBadRequest, err)
			return
		}
	}
	result := s.pollFeeds(r.Context(), input.ID)
	if errText, ok := result["error"].(string); ok && errText != "" {
		writeError(w, http.StatusInternalServerError, errors.New(errText))
		return
	}
	if missing, ok := result["missing"].(bool); ok && missing {
		writeError(w, http.StatusNotFound, errors.New("feed not found"))
		return
	}
	writeJSON(w, http.StatusOK, result)
}
