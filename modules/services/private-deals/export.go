package main

import (
	"encoding/xml"
	"fmt"
	"net/http"
	"strings"
	"time"
)

type rssFeed struct {
	XMLName xml.Name   `xml:"rss"`
	Version string     `xml:"version,attr"`
	Channel rssChannel `xml:"channel"`
}

type rssChannel struct {
	Title       string    `xml:"title"`
	Link        string    `xml:"link"`
	Description string    `xml:"description"`
	Items       []rssItem `xml:"item"`
}

type rssItem struct {
	Title       string   `xml:"title"`
	Link        string   `xml:"link"`
	GUID        string   `xml:"guid"`
	PubDate     string   `xml:"pubDate"`
	Description string   `xml:"description"`
	Categories  []string `xml:"category,omitempty"`
}

type atomFeed struct {
	XMLName xml.Name    `xml:"feed"`
	Xmlns   string      `xml:"xmlns,attr"`
	Title   string      `xml:"title"`
	ID      string      `xml:"id"`
	Updated string      `xml:"updated"`
	Links   []atomLink  `xml:"link"`
	Entries []atomEntry `xml:"entry"`
}

type atomLink struct {
	Href string `xml:"href,attr"`
	Rel  string `xml:"rel,attr,omitempty"`
}

type atomEntry struct {
	Title   string     `xml:"title"`
	ID      string     `xml:"id"`
	Updated string     `xml:"updated"`
	Links   []atomLink `xml:"link"`
	Summary string     `xml:"summary"`
}

func exportDealPage(r *http.Request, store *Store, limit int) (dealPage, error) {
	q := r.URL.Query()
	if limit <= 0 || limit > 500 {
		limit = 100
	}
	return store.QueryDeals(r.Context(), dealQueryOptions{
		Q: q.Get("q"), Source: q.Get("source"), Merchant: q.Get("merchant"), Category: q.Get("category"),
		Active: q.Get("active") != "0", MinDiscount: floatQuery(r, "min_discount"), MaxPrice: floatQuery(r, "max_price"), Limit: limit,
	})
}

func dealFeedText(deal Deal) string {
	parts := []string{deal.Title}
	if deal.Price != nil {
		parts = append(parts, fmt.Sprintf("%.2f %s", *deal.Price, deal.Currency))
	}
	if deal.ListPrice != nil {
		parts = append(parts, fmt.Sprintf("was %.2f %s", *deal.ListPrice, deal.Currency))
	}
	if deal.DiscountPct > 0 {
		parts = append(parts, fmt.Sprintf("%.0f%% off", deal.DiscountPct))
	}
	if deal.Description != "" {
		parts = append(parts, deal.Description)
	}
	return strings.Join(parts, " — ")
}

func dealLink(deal Deal) string {
	if deal.URL != "" {
		return deal.URL
	}
	return fmt.Sprintf("/api/deals/%d", deal.ID)
}

func writeXML(w http.ResponseWriter, contentType string, value any) {
	raw, err := xml.MarshalIndent(value, "", "  ")
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	w.Header().Set("Content-Type", contentType)
	w.Header().Set("Cache-Control", "no-store")
	_, _ = w.Write([]byte(xml.Header + string(raw)))
}

func (s *server) exportDealsJSON(w http.ResponseWriter, r *http.Request) {
	page, err := exportDealPage(r, s.store, intQuery(r, "limit"))
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, page)
}

func (s *server) exportDealsRSS(w http.ResponseWriter, r *http.Request) {
	page, err := exportDealPage(r, s.store, 50)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	feed := rssFeed{Version: "2.0", Channel: rssChannel{
		Title: "Private Deals", Link: "/", Description: "Tailnet private deal watchlist",
		Items: make([]rssItem, 0, len(page.Items)),
	}}
	for _, deal := range page.Items {
		item := rssItem{
			Title: deal.Title, Link: dealLink(deal), GUID: fmt.Sprintf("private-deals-%d", deal.ID),
			PubDate: deal.LastSeen.UTC().Format(http.TimeFormat), Description: dealFeedText(deal), Categories: deal.Tags,
		}
		feed.Channel.Items = append(feed.Channel.Items, item)
	}
	writeXML(w, "application/rss+xml; charset=utf-8", feed)
}

func (s *server) exportDealsAtom(w http.ResponseWriter, r *http.Request) {
	page, err := exportDealPage(r, s.store, 50)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	updated := time.Now().UTC()
	if len(page.Items) > 0 {
		updated = page.Items[0].LastSeen.UTC()
	}
	feed := atomFeed{Xmlns: "http://www.w3.org/2005/Atom", Title: "Private Deals", ID: "private-deals", Updated: updated.Format(time.RFC3339), Links: []atomLink{{Href: "/", Rel: "self"}}}
	for _, deal := range page.Items {
		feed.Entries = append(feed.Entries, atomEntry{
			Title: deal.Title, ID: fmt.Sprintf("private-deals-%d", deal.ID), Updated: deal.LastSeen.UTC().Format(time.RFC3339),
			Links: []atomLink{{Href: dealLink(deal), Rel: "alternate"}}, Summary: dealFeedText(deal),
		})
	}
	writeXML(w, "application/atom+xml; charset=utf-8", feed)
}
