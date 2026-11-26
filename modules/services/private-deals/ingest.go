// Ingestion: RSS/Atom feeds and a price extractor. Providers are feed URLs in
// the feeds table; `os deals ingest` (or POST /api/ingest) walks them once.
package main

import (
	"database/sql"
	"encoding/xml"
	"fmt"
	"io"
	"net/http"
	"regexp"
	"strconv"
	"strings"
	"time"
)

type feedItem struct {
	Title string
	Link  string
	Desc  string
	Date  string
}

// rss2 and atom share just enough shape for a deals sweep: title, link,
// description, date. Both unmarshal into this flat shape — atom links carry
// the href as an attribute, rss as the element text.
type feedDoc struct {
	XMLName xml.Name
	Items   []struct {
		Title string `xml:"title"`
		Link  string `xml:"link"`
		Desc  string `xml:"description"`
		Date  string `xml:"pubDate"`
	} `xml:"channel>item"`
	Entries []struct {
		Title   string `xml:"title"`
		LinkXML struct {
			Href string `xml:"href,attr"`
		} `xml:"link"`
		Desc string `xml:"summary"`
		Date string `xml:"updated"`
	} `xml:"entry"`
}

func parseFeed(body []byte) []feedItem {
	var doc feedDoc
	if err := xml.Unmarshal(body, &doc); err != nil {
		return nil
	}
	var out []feedItem
	for _, it := range doc.Items {
		out = append(out, feedItem{Title: it.Title, Link: it.Link, Desc: it.Desc, Date: it.Date})
	}
	for _, e := range doc.Entries {
		out = append(out, feedItem{Title: e.Title, Link: e.LinkXML.Href, Desc: e.Desc, Date: e.Date})
	}
	return out
}

var priceRe = regexp.MustCompile(`(?i)(?:€\s*(\d[\d.,]*)|(\d[\d.,]*)\s*(?:€|eur)\b)`)

// extractPrice reads the first € amount in a text as cents. `1.234,56` and
// `1,234.56` both parse; a bare `299` is 29900 cents. Returns 0 when no
// amount is present — a deal without a price is still a deal.
func extractPrice(text string) int64 {
	m := priceRe.FindStringSubmatch(text)
	if m == nil {
		return 0
	}
	num := m[1]
	if num == "" {
		num = m[2]
	}
	return parseAmount(num)
}

func parseAmount(s string) int64 {
	// European 1.234,56 vs US 1,234.56: the LAST separator is decimal when it
	// is followed by exactly two digits at the end.
	s = strings.TrimSpace(s)
	lastComma := strings.LastIndex(s, ",")
	lastDot := strings.LastIndex(s, ".")
	sep := -1
	if lastComma > lastDot {
		sep = lastComma
	} else {
		sep = lastDot
	}
	if sep >= 0 && len(s)-sep-1 == 2 {
		whole := strings.NewReplacer(".", "", ",", "").Replace(s[:sep])
		frac := s[sep+1:]
		w, err1 := strconv.ParseInt(whole, 10, 64)
		f, err2 := strconv.ParseInt(frac, 10, 64)
		if err1 == nil && err2 == nil {
			return w*100 + f
		}
	}
	digits := strings.NewReplacer(".", "", ",", "").Replace(s)
	n, err := strconv.ParseInt(digits, 10, 64)
	if err != nil {
		return 0
	}
	return n * 100
}

// ingestFeed fetches one feed and upserts every item; source is the feed URL
// host so a deal can be traced back to its provider.
func ingestFeed(db *sql.DB, client *http.Client, url string) (int, error) {
	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return 0, err
	}
	req.Header.Set("User-Agent", "private-deals/0.1 (+tailnet service)")
	resp, err := client.Do(req)
	if err != nil {
		return 0, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != 200 {
		return 0, fmt.Errorf("feed %s: HTTP %d", url, resp.StatusCode)
	}
	body, err := io.ReadAll(io.LimitReader(resp.Body, 4<<20))
	if err != nil {
		return 0, err
	}
	items := parseFeed(body)
	n := 0
	for _, it := range items {
		if it.Title == "" {
			continue
		}
		price := extractPrice(it.Title + " " + it.Desc)
		notes := it.Desc
		if len(notes) > 500 {
			notes = notes[:500]
		}
		if _, _, err := upsertDeal(db, Deal{
			Title:      it.Title,
			URL:        it.Link,
			PriceCents: price,
			Source:     "rss",
			Notes:      notes,
		}); err == nil {
			n++
		}
	}
	return n, nil
}

// ingestAll walks every registered feed once and reports per-feed counts.
func ingestAll(db *sql.DB) (map[string]int, map[string]string) {
	feeds, err := listFeeds(db)
	if err != nil {
		return nil, map[string]string{"feeds": err.Error()}
	}
	client := &http.Client{Timeout: 15 * time.Second}
	ok := map[string]int{}
	failed := map[string]string{}
	for _, u := range feeds {
		n, err := ingestFeed(db, client, u)
		if err != nil {
			failed[u] = err.Error()
		} else {
			ok[u] = n
		}
	}
	return ok, failed
}
