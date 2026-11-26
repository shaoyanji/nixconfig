package main

import (
	"bytes"
	"context"
	"encoding/json"
	"encoding/xml"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"regexp"
	"strings"
	"sync"
	"time"
)

var defaultSources = []string{"germantechjobs", "weworkremotely", "remoteok", "berlinstartupjobs", "arbeitnow", "web-search"}

type providerConfig struct {
	FirecrawlKey  string
	TavilyKey     string
	ContextKey    string
	FirecrawlBase string
	TavilyBase    string
	ContextBase   string
	SearchQueries []string
	Enrich        bool
	MaxEnrich     int
	AllowKeyless  bool
}

type scraper struct {
	store  *Store
	client *http.Client
	cfg    providerConfig
	alerts *alertManager

	mu      sync.Mutex
	running bool
	started time.Time
	last    string
}

type scrapeSummary struct {
	Running bool        `json:"running"`
	Started time.Time   `json:"started,omitempty"`
	Message string      `json:"message"`
	Sources []runRecord `json:"sources,omitempty"`
}

type rssDocument struct {
	Channel struct {
		Items []rssItem `xml:"item"`
	} `xml:"channel"`
}

type rssItem struct {
	Title       string `xml:"title"`
	Link        string `xml:"link"`
	PubDate     string `xml:"pubDate"`
	Description string `xml:"description"`
	Region      string `xml:"region"`
}

func newScraper(store *Store, cfg providerConfig) *scraper {
	if cfg.FirecrawlBase == "" {
		cfg.FirecrawlBase = "https://api.firecrawl.dev/v2"
	}
	if cfg.TavilyBase == "" {
		cfg.TavilyBase = "https://api.tavily.com"
	}
	if cfg.ContextBase == "" {
		cfg.ContextBase = "https://api.context.dev/v1"
	}
	if cfg.MaxEnrich <= 0 {
		cfg.MaxEnrich = 4
	}
	if len(cfg.SearchQueries) == 0 {
		cfg.SearchQueries = []string{
			"DevOps Engineer Germany jobs",
			"Site Reliability Engineer remote Europe jobs",
			"Platform Engineer Kubernetes Germany jobs",
		}
	}
	return &scraper{
		store:  store,
		cfg:    cfg,
		client: &http.Client{Timeout: 45 * time.Second},
	}
}

func (s *scraper) status() scrapeSummary {
	s.mu.Lock()
	defer s.mu.Unlock()
	return scrapeSummary{Running: s.running, Started: s.started, Message: s.last}
}

func (s *scraper) startAsync(ctx context.Context, sources []string) (bool, scrapeSummary) {
	s.mu.Lock()
	if s.running {
		status := scrapeSummary{Running: true, Started: s.started, Message: s.last}
		s.mu.Unlock()
		return false, status
	}
	s.running = true
	s.started = time.Now().UTC()
	s.last = "scrape queued"
	s.mu.Unlock()
	go func() {
		s.run(ctx, sources)
	}()
	return true, s.status()
}

func (s *scraper) finishStatus(message string) {
	s.mu.Lock()
	s.running = false
	s.last = message
	s.mu.Unlock()
}

func (s *scraper) progress(message string) {
	s.mu.Lock()
	s.last = message
	s.mu.Unlock()
}

func (s *scraper) run(ctx context.Context, sources []string) {
	if len(sources) == 0 {
		sources = defaultSources
	}
	started := time.Now().UTC()
	totalFetched, totalInserted, totalUpdated := 0, 0, 0
	successful := []string{}
	errorsOut := []string{}
	for _, source := range sources {
		source = strings.TrimSpace(strings.ToLower(source))
		if source == "" {
			continue
		}
		s.progress("scraping " + source)
		runID, err := s.store.BeginRun(ctx, source)
		if err != nil {
			errorsOut = append(errorsOut, source+": run record: "+err.Error())
			continue
		}
		result, err := s.scrapeSource(ctx, source)
		inserted, updated, fetched := 0, 0, 0
		if err == nil {
			fetched = len(result.Postings)
			for _, input := range result.Postings {
				id, created, upErr := s.store.UpsertPosting(ctx, input)
				if upErr != nil {
					result.Warnings = append(result.Warnings, "upsert: "+upErr.Error())
					continue
				}
				if created {
					inserted++
				} else {
					updated++
				}
				if s.cfg.Enrich && inserted+updated <= s.cfg.MaxEnrich {
					if enriched, ok := s.enrich(ctx, input.URL); ok {
						_ = s.store.UpdateDescription(ctx, id, enriched)
					}
				}
			}
			if len(result.Warnings) > 0 {
				err = errors.New(strings.Join(result.Warnings, "; "))
			}
		}
		status := "ok"
		errText := ""
		if err != nil {
			if fetched > 0 || len(result.Warnings) > 0 {
				status = "ok_with_warnings"
			} else {
				status = "error"
				errorsOut = append(errorsOut, source+": "+err.Error())
			}
			errText = err.Error()
		}
		if status != "error" {
			successful = append(successful, source)
		}
		_ = s.store.FinishRun(ctx, runID, source, status, fetched, inserted, updated, errText)
		totalFetched += fetched
		totalInserted += inserted
		totalUpdated += updated
	}
	direct := make([]string, 0, len(successful))
	for _, source := range successful {
		if source != "web-search" && source != "tavily-search" && source != "context-search" {
			direct = append(direct, source)
		}
	}
	_ = s.store.MarkInactiveMissing(ctx, direct, started)
	message := fmt.Sprintf("fetched %d, inserted %d, updated %d", totalFetched, totalInserted, totalUpdated)
	if s.alerts != nil {
		if alerts, alertErr := s.alerts.evaluate(ctx, true); alertErr == nil && alerts.Matched > 0 {
			message += fmt.Sprintf(", alerts %d new/%d sent/%d failed", alerts.Created, alerts.Notified, alerts.Failed)
		}
	}
	if len(errorsOut) > 0 {
		message += "; " + strings.Join(errorsOut, " | ")
	}
	s.finishStatus(message)
}

func (s *scraper) scrapeSource(ctx context.Context, source string) (sourceResult, error) {
	switch source {
	case "germantechjobs":
		return s.scrapeGermanTechJobs(ctx)
	case "weworkremotely":
		return s.scrapeWeWorkRemotely(ctx)
	case "remoteok":
		return s.scrapeRemoteOK(ctx)
	case "berlinstartupjobs":
		return s.scrapeBerlinStartupJobs(ctx)
	case "arbeitnow":
		return s.scrapeArbeitnow(ctx)
	case "web-search":
		return s.scrapeWebSearch(ctx)
	default:
		return sourceResult{}, fmt.Errorf("unknown source %q", source)
	}
}

func (s *scraper) fetch(ctx context.Context, rawurl string) ([]byte, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, rawurl, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("User-Agent", "job-db-scraper/0.1 (+https://delphi.cloudforest-kardashev.ts.net:8464)")
	req.Header.Set("Accept", "application/rss+xml, application/xml, application/json, text/html;q=0.8, */*;q=0.5")
	res, err := s.client.Do(req)
	if err != nil {
		return nil, err
	}
	defer res.Body.Close()
	if res.StatusCode < 200 || res.StatusCode > 299 {
		return nil, fmt.Errorf("%s: HTTP %s", rawurl, res.Status)
	}
	return io.ReadAll(io.LimitReader(res.Body, 8<<20))
}

func parseRSS(raw []byte) (rssDocument, error) {
	var doc rssDocument
	if err := xml.Unmarshal(raw, &doc); err != nil {
		return doc, err
	}
	return doc, nil
}

var germanTitleRE = regexp.MustCompile(`^(.*?)\s*@\s*(.+?)(?:\s*\[([^\]]*)\])?$`)

func (s *scraper) scrapeGermanTechJobs(ctx context.Context) (sourceResult, error) {
	raw, err := s.fetch(ctx, "https://germantechjobs.de/rss")
	if err != nil {
		return sourceResult{}, err
	}
	doc, err := parseRSS(raw)
	if err != nil {
		return sourceResult{}, err
	}
	out := sourceResult{}
	for _, item := range doc.Channel.Items {
		m := germanTitleRE.FindStringSubmatch(strings.TrimSpace(item.Title))
		if len(m) != 4 {
			out.Warnings = append(out.Warnings, "germantechjobs title did not parse: "+item.Title)
			continue
		}
		out.Postings = append(out.Postings, postingInput{
			Source: "germantechjobs", URL: item.Link, Title: m[1], Company: m[2], Location: m[3],
			Description: item.Description, PostedAt: item.PubDate, Tags: []string{"rss", "germany"},
		})
	}
	return out, nil
}

func (s *scraper) scrapeWeWorkRemotely(ctx context.Context) (sourceResult, error) {
	raw, err := s.fetch(ctx, "https://weworkremotely.com/categories/remote-devops-sysadmin-jobs.rss")
	if err != nil {
		return sourceResult{}, err
	}
	doc, err := parseRSS(raw)
	if err != nil {
		return sourceResult{}, err
	}
	out := sourceResult{}
	for _, item := range doc.Channel.Items {
		company, title, ok := strings.Cut(item.Title, ":")
		if !ok {
			continue
		}
		loc := item.Region
		if loc == "" {
			loc = "Remote"
		}
		out.Postings = append(out.Postings, postingInput{
			Source: "weworkremotely", URL: item.Link, Title: title, Company: company, Location: loc,
			Description: item.Description, PostedAt: item.PubDate, Remote: true, Tags: []string{"rss", "remote"},
		})
	}
	return out, nil
}

type remoteOKEntry struct {
	Position    string   `json:"position"`
	Company     string   `json:"company"`
	Location    string   `json:"location"`
	URL         string   `json:"url"`
	Date        string   `json:"date"`
	Description string   `json:"description"`
	Tags        []string `json:"tags"`
	SalaryMin   int      `json:"salary_min"`
	SalaryMax   int      `json:"salary_max"`
}

func (s *scraper) scrapeRemoteOK(ctx context.Context) (sourceResult, error) {
	raw, err := s.fetch(ctx, "https://remoteok.com/api")
	if err != nil {
		return sourceResult{}, err
	}
	var entries []remoteOKEntry
	if err := json.Unmarshal(raw, &entries); err != nil {
		return sourceResult{}, err
	}
	out := sourceResult{}
	for _, entry := range entries {
		if entry.Position == "" || entry.Company == "" {
			continue
		}
		salary := ""
		if entry.SalaryMin > 0 || entry.SalaryMax > 0 {
			salary = fmt.Sprintf("$%d–$%d", entry.SalaryMin, entry.SalaryMax)
		}
		out.Postings = append(out.Postings, postingInput{
			Source: "remoteok", URL: entry.URL, Title: entry.Position, Company: entry.Company, Location: entry.Location,
			Description: entry.Description, PostedAt: entry.Date, Remote: true, Tags: entry.Tags, Salary: salary,
		})
	}
	return out, nil
}

var berlinTitleRE = regexp.MustCompile(`^(.*?)\s+(?:at|@)\s+(.+)$`)

func (s *scraper) scrapeBerlinStartupJobs(ctx context.Context) (sourceResult, error) {
	raw, err := s.fetch(ctx, "https://berlinstartupjobs.com/feed/")
	if err != nil {
		return sourceResult{}, err
	}
	doc, err := parseRSS(raw)
	if err != nil {
		return sourceResult{}, err
	}
	out := sourceResult{}
	for _, item := range doc.Channel.Items {
		m := berlinTitleRE.FindStringSubmatch(strings.TrimSpace(item.Title))
		if len(m) != 3 {
			continue
		}
		out.Postings = append(out.Postings, postingInput{
			Source: "berlinstartupjobs", URL: item.Link, Title: m[1], Company: m[2], Location: "Berlin",
			Description: item.Description, PostedAt: item.PubDate, Tags: []string{"rss", "berlin"},
		})
	}
	return out, nil
}

type arbeitnowResponse struct {
	Data []struct {
		Slug        string   `json:"slug"`
		CompanyName string   `json:"company_name"`
		Title       string   `json:"title"`
		Description string   `json:"description"`
		Remote      bool     `json:"remote"`
		URL         string   `json:"url"`
		Tags        []string `json:"tags"`
		JobTypes    []string `json:"job_types"`
		Location    string   `json:"location"`
		CreatedAt   int64    `json:"created_at"`
	} `json:"data"`
}

func (s *scraper) scrapeArbeitnow(ctx context.Context) (sourceResult, error) {
	out := sourceResult{}
	for page := 1; page <= 3; page++ {
		raw, err := s.fetch(ctx, fmt.Sprintf("https://www.arbeitnow.com/api/job-board-api?page=%d", page))
		if err != nil {
			if page == 1 {
				return out, err
			}
			out.Warnings = append(out.Warnings, err.Error())
			break
		}
		var payload arbeitnowResponse
		if err := json.Unmarshal(raw, &payload); err != nil {
			return out, err
		}
		if len(payload.Data) == 0 {
			break
		}
		for _, entry := range payload.Data {
			employment := strings.Join(entry.JobTypes, ", ")
			posted := ""
			if entry.CreatedAt > 0 {
				posted = time.Unix(entry.CreatedAt, 0).UTC().Format(time.RFC3339)
			}
			out.Postings = append(out.Postings, postingInput{
				Source: "arbeitnow", URL: entry.URL, Title: entry.Title, Company: entry.CompanyName, Location: entry.Location,
				Description: entry.Description, PostedAt: posted, Remote: entry.Remote, Tags: entry.Tags, Employment: employment,
			})
		}
	}
	return out, nil
}

func (s *scraper) scrapeWebSearch(ctx context.Context) (sourceResult, error) {
	combined := sourceResult{}
	if s.cfg.TavilyKey == "" && s.cfg.ContextKey == "" {
		combined.Warnings = append(combined.Warnings, "web-search skipped: TAVILY_API_KEY and CONTEXT_API_KEY are not configured")
		return combined, nil
	}
	for _, query := range s.cfg.SearchQueries {
		if s.cfg.TavilyKey != "" {
			result, err := s.tavilySearch(ctx, query)
			if err != nil {
				combined.Warnings = append(combined.Warnings, "tavily: "+err.Error())
			} else {
				combined.Postings = append(combined.Postings, result...)
			}
		}
		if s.cfg.ContextKey != "" {
			result, err := s.contextSearch(ctx, query)
			if err != nil {
				combined.Warnings = append(combined.Warnings, "context: "+err.Error())
			} else {
				combined.Postings = append(combined.Postings, result...)
			}
		}
	}
	return combined, nil
}

func (s *scraper) postJSON(ctx context.Context, endpoint, token string, body any, out any) error {
	payload, err := json.Marshal(body)
	if err != nil {
		return err
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, endpoint, bytes.NewReader(payload))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json")
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	res, err := s.client.Do(req)
	if err != nil {
		return err
	}
	defer res.Body.Close()
	raw, err := io.ReadAll(io.LimitReader(res.Body, 8<<20))
	if err != nil {
		return err
	}
	if res.StatusCode < 200 || res.StatusCode > 299 {
		return fmt.Errorf("%s: HTTP %s: %s", endpoint, res.Status, strings.TrimSpace(string(raw[:min(len(raw), 240)])))
	}
	return json.Unmarshal(raw, out)
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}

func (s *scraper) tavilySearch(ctx context.Context, query string) ([]postingInput, error) {
	var response struct {
		Results []struct {
			Title   string  `json:"title"`
			URL     string  `json:"url"`
			Content string  `json:"content"`
			Score   float64 `json:"score"`
		} `json:"results"`
	}
	body := map[string]any{"query": query, "max_results": 8, "search_depth": "basic", "include_answer": false}
	if err := s.postJSON(ctx, strings.TrimRight(s.cfg.TavilyBase, "/")+"/search", s.cfg.TavilyKey, body, &response); err != nil {
		return nil, err
	}
	out := []postingInput{}
	for _, result := range response.Results {
		if !joblike(result.Title+" "+result.Content) || !isSearchDetailURL(result.URL) {
			continue
		}
		company := inferCompany(result.Title, result.URL)
		if company == "" {
			continue
		}
		out = append(out, postingInput{
			Source: "tavily-search", URL: result.URL, Title: cleanSearchTitle(result.Title), Company: company,
			Location: inferLocation(result.Title), Description: result.Content, Tags: []string{"search", "tavily"},
		})
	}
	return out, nil
}

func (s *scraper) contextSearch(ctx context.Context, query string) ([]postingInput, error) {
	var response struct {
		Results []struct {
			Title       string `json:"title"`
			URL         string `json:"url"`
			Description string `json:"description"`
			Content     string `json:"content"`
		} `json:"results"`
	}
	body := map[string]any{"query": query, "numResults": 8, "freshness": "last_month"}
	if err := s.postJSON(ctx, strings.TrimRight(s.cfg.ContextBase, "/")+"/web/search", s.cfg.ContextKey, body, &response); err != nil {
		return nil, err
	}
	out := []postingInput{}
	for _, result := range response.Results {
		text := result.Description
		if result.Content != "" {
			text = result.Content
		}
		if !joblike(result.Title+" "+text) || !isSearchDetailURL(result.URL) {
			continue
		}
		company := inferCompany(result.Title, result.URL)
		if company == "" {
			continue
		}
		out = append(out, postingInput{
			Source: "context-search", URL: result.URL, Title: cleanSearchTitle(result.Title), Company: company,
			Location: inferLocation(result.Title), Description: text, Tags: []string{"search", "context"},
		})
	}
	return out, nil
}

func isSearchDetailURL(rawurl string) bool {
	u, err := url.Parse(rawurl)
	if err != nil {
		return false
	}
	host := strings.TrimPrefix(strings.ToLower(u.Hostname()), "www.")
	path := strings.ToLower(u.Path)
	// Search-result listing pages are not postings. Detail URLs almost always carry
	// a numeric requisition/id, while the aggregator roundups that polluted the
	// first live probe were bare keyword paths.
	if regexp.MustCompile(`\d`).MatchString(path) {
		return true
	}
	if strings.HasPrefix(host, "careers.") || strings.HasPrefix(host, "jobs.") || strings.HasSuffix(host, ".personio.com") {
		return true
	}
	return false
}

func stripCompanyLocation(company string) string {
	if before, _, ok := strings.Cut(company, ","); ok {
		company = before
	}
	company = regexp.MustCompile(`(?i)\s*\((?:berlin|munich|münchen|hamburg|remote|germany|deutschland|hybrid)\)\s*$`).ReplaceAllString(company, "")
	company = regexp.MustCompile(`(?i)\s+[-–—]\s+(?:berlin|munich|münchen|hamburg|cologne|köln|frankfurt|stuttgart|remote|germany|deutschland|hybrid)\s*$`).ReplaceAllString(company, "")
	return strings.Trim(company, " -–—|")
}

func brandFromSlug(slug string) string {
	slug = strings.Trim(strings.ToLower(slug), "/")
	slug = strings.ReplaceAll(slug, "-", " ")
	parts := strings.Fields(slug)
	for i, part := range parts {
		if part == "" {
			continue
		}
		if len(part) <= 4 {
			parts[i] = strings.ToUpper(part)
		} else {
			parts[i] = strings.ToUpper(part[:1]) + part[1:]
		}
	}
	return strings.Join(parts, " ")
}

func companyFromURL(u *url.URL) string {
	host := strings.TrimPrefix(strings.ToLower(u.Hostname()), "www.")
	segments := strings.Split(strings.Trim(u.Path, "/"), "/")
	if host == "join.com" && len(segments) >= 3 && segments[0] == "companies" {
		return brandFromSlug(segments[1])
	}
	if strings.HasSuffix(host, "jobs.personio.com") && len(segments) > 0 {
		return brandFromSlug(strings.Split(host, ".")[0])
	}
	for _, prefix := range []string{"careers.", "jobs."} {
		if strings.HasPrefix(host, prefix) {
			rest := strings.TrimPrefix(host, prefix)
			return brandFromSlug(strings.Split(rest, ".")[0])
		}
	}
	if strings.HasSuffix(host, "greenhouse.io") && len(segments) > 0 && segments[0] != "" {
		return brandFromSlug(segments[0])
	}
	if strings.HasSuffix(host, "lever.co") && len(segments) > 0 && segments[0] != "" {
		return brandFromSlug(segments[0])
	}
	return ""
}

func inferCompany(title, rawurl string) string {
	title = cleanText(title)
	patterns := []*regexp.Regexp{
		regexp.MustCompile(`(?i)^(.+?)\s+(?:at|@)\s+([^|–—]+)`),
		regexp.MustCompile(`^([^:|–—]{3,60})\s*:`),
		regexp.MustCompile(`(?i)^(.+?)\s+[-–—]\s+([^|]{3,80})(?:\s*\([^)]*\))?$`),
	}
	for _, re := range patterns {
		if m := re.FindStringSubmatch(title); len(m) > 0 {
			candidate := strings.TrimSpace(m[len(m)-1])
			candidate = stripCompanyLocation(candidate)
			if len(candidate) >= 3 && !joblike(candidate) {
				return candidate
			}
		}
	}
	u, err := url.Parse(rawurl)
	if err != nil {
		return ""
	}
	return companyFromURL(u)
}

var searchLocationRE = regexp.MustCompile(`(?i)\b(berlin|munich|münchen|hamburg|cologne|köln|frankfurt|stuttgart|remote|hybrid|germany|deutschland)\b`)

func inferLocation(title string) string {
	loc := searchLocationRE.FindString(title)
	if loc == "" {
		return ""
	}
	return strings.ToUpper(loc[:1]) + strings.ToLower(loc[1:])
}

func cleanSearchTitle(title string) string {
	title = cleanText(title)
	lower := strings.ToLower(title)
	if at := strings.Index(lower, " at "); at > 0 {
		title = title[:at]
		lower = strings.ToLower(title)
	}
	for _, sep := range []string{" | ", " – ", " — "} {
		if at := strings.Index(title, sep); at > 0 {
			title = title[:at]
		}
	}
	if re := regexp.MustCompile(`(?i)^(.+?)\s+-\s+[^-]{3,80}(?:\s*\([^)]*\))?$`); re.MatchString(title) {
		title = re.FindStringSubmatch(title)[1]
	}
	title = regexp.MustCompile(`(?i)\s+job details\s*$`).ReplaceAllString(title, "")
	return strings.Trim(title, " -–—|")
}

func (s *scraper) enrich(ctx context.Context, rawurl string) (string, bool) {
	if rawurl == "" {
		return "", false
	}
	if s.cfg.TavilyKey != "" {
		if text, err := s.tavilyExtract(ctx, rawurl); err == nil && len(text) >= 240 {
			return text, true
		}
	}
	if s.cfg.FirecrawlKey != "" || s.cfg.AllowKeyless {
		if text, err := s.firecrawlScrape(ctx, rawurl); err == nil && len(text) >= 240 {
			return text, true
		}
	}
	if s.cfg.ContextKey != "" {
		if text, err := s.contextScrape(ctx, rawurl); err == nil && len(text) >= 240 {
			return text, true
		}
	}
	return "", false
}

func (s *scraper) tavilyExtract(ctx context.Context, rawurl string) (string, error) {
	var response struct {
		Results []struct {
			URL        string `json:"url"`
			RawContent string `json:"raw_content"`
		} `json:"results"`
		Failed []any `json:"failed_results"`
	}
	body := map[string]any{"urls": []string{rawurl}, "extract_depth": "basic", "format": "markdown"}
	if err := s.postJSON(ctx, strings.TrimRight(s.cfg.TavilyBase, "/")+"/extract", s.cfg.TavilyKey, body, &response); err != nil {
		return "", err
	}
	if len(response.Results) == 0 {
		return "", errors.New("tavily extract returned no results")
	}
	return cleanText(response.Results[0].RawContent), nil
}

func (s *scraper) firecrawlScrape(ctx context.Context, rawurl string) (string, error) {
	var response struct {
		Success bool `json:"success"`
		Data    struct {
			Markdown string `json:"markdown"`
		} `json:"data"`
	}
	body := map[string]any{"url": rawurl, "formats": []string{"markdown"}, "onlyMainContent": true}
	if err := s.postJSON(ctx, strings.TrimRight(s.cfg.FirecrawlBase, "/")+"/scrape", s.cfg.FirecrawlKey, body, &response); err != nil {
		return "", err
	}
	if !response.Success || response.Data.Markdown == "" {
		return "", errors.New("firecrawl returned no markdown")
	}
	return cleanText(response.Data.Markdown), nil
}

func (s *scraper) contextScrape(ctx context.Context, rawurl string) (string, error) {
	endpoint := strings.TrimRight(s.cfg.ContextBase, "/") + "/web/scrape/markdown?url=" + url.QueryEscape(rawurl)
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, endpoint, nil)
	if err != nil {
		return "", err
	}
	req.Header.Set("Accept", "application/json, text/markdown")
	req.Header.Set("Authorization", "Bearer "+s.cfg.ContextKey)
	res, err := s.client.Do(req)
	if err != nil {
		return "", err
	}
	defer res.Body.Close()
	raw, err := io.ReadAll(io.LimitReader(res.Body, 8<<20))
	if err != nil {
		return "", err
	}
	if res.StatusCode < 200 || res.StatusCode > 299 {
		return "", fmt.Errorf("context scrape: HTTP %s", res.Status)
	}
	contentType := res.Header.Get("Content-Type")
	if strings.Contains(contentType, "markdown") || strings.Contains(contentType, "text/plain") {
		return cleanText(string(raw)), nil
	}
	var payload any
	if err := json.Unmarshal(raw, &payload); err != nil {
		return "", err
	}
	if text := findTextKey(payload, "markdown", "content", "text"); text != "" {
		return cleanText(text), nil
	}
	return "", errors.New("context scrape returned no markdown")
}

func findTextKey(v any, keys ...string) string {
	switch value := v.(type) {
	case map[string]any:
		for _, key := range keys {
			if text, ok := value[key].(string); ok && text != "" {
				return text
			}
		}
		for _, child := range value {
			if text := findTextKey(child, keys...); text != "" {
				return text
			}
		}
	case []any:
		for _, child := range value {
			if text := findTextKey(child, keys...); text != "" {
				return text
			}
		}
	}
	return ""
}
