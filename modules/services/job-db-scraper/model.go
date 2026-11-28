package main

import (
	"crypto/sha1"
	"encoding/hex"
	"encoding/json"
	"html"
	"net/url"
	"regexp"
	"sort"
	"strings"
	"time"
)

type Posting struct {
	ID             int64     `json:"id"`
	Fingerprint    string    `json:"fingerprint"`
	CanonicalURL   string    `json:"canonical_url"`
	CanonicalKey   string    `json:"canonical_key"`
	URL            string    `json:"url"`
	Source         string    `json:"source"`
	Company        string    `json:"company"`
	CompanyKey     string    `json:"company_key"`
	Title          string    `json:"title"`
	Location       string    `json:"location"`
	Remote         bool      `json:"remote"`
	Employment     string    `json:"employment,omitempty"`
	Description    string    `json:"description"`
	Tags           []string  `json:"tags"`
	PostedAt       string    `json:"posted_at,omitempty"`
	FirstSeen      time.Time `json:"first_seen"`
	LastSeen       time.Time `json:"last_seen"`
	SeenCount      int       `json:"seen_count"`
	Active         bool      `json:"active"`
	Salary         string    `json:"salary,omitempty"`
	Score          int       `json:"score"`
	SearchScore    float64   `json:"search_score,omitempty"`
	Lanes          []string  `json:"lanes"`
	MergedSources  []string  `json:"merged_sources"`
	DuplicateCount int       `json:"duplicate_count"`
	Stage          string    `json:"stage"`
	AppliedAt      string    `json:"applied_at,omitempty"`
	FollowUpAt     string    `json:"follow_up_at,omitempty"`
	Snippet        string    `json:"snippet,omitempty"`
}

type JobNote struct {
	ID        int64     `json:"id"`
	PostingID int64     `json:"posting_id"`
	Note      string    `json:"note"`
	CreatedAt time.Time `json:"created_at"`
}

type StageEvent struct {
	ID        int64     `json:"id"`
	PostingID int64     `json:"posting_id"`
	FromStage string    `json:"from_stage"`
	ToStage   string    `json:"to_stage"`
	Note      string    `json:"note,omitempty"`
	CreatedAt time.Time `json:"created_at"`
}

type postingInput struct {
	URL         string   `json:"url"`
	Source      string   `json:"source"`
	Company     string   `json:"company"`
	Title       string   `json:"title"`
	Location    string   `json:"location"`
	Remote      bool     `json:"remote"`
	Employment  string   `json:"employment"`
	Description string   `json:"description"`
	Tags        []string `json:"tags"`
	PostedAt    string   `json:"posted_at"`
	Salary      string   `json:"salary"`
}

type JobAlert struct {
	ID          int64      `json:"id"`
	PostingID   int64      `json:"posting_id"`
	Company     string     `json:"company"`
	Title       string     `json:"title"`
	URL         string     `json:"url"`
	Score       int        `json:"score"`
	Status      string     `json:"status"`
	Attempts    int        `json:"attempts"`
	NotifyError string     `json:"notify_error,omitempty"`
	FirstSeen   time.Time  `json:"first_seen"`
	LastSeen    time.Time  `json:"last_seen"`
	NotifiedAt  *time.Time `json:"notified_at,omitempty"`
}

type alertEvaluation struct {
	Matched  int        `json:"matched"`
	Created  int        `json:"created"`
	Existing int        `json:"existing"`
	Alerts   []JobAlert `json:"alerts,omitempty"`
}

type notifySummary struct {
	Matched  int `json:"matched"`
	Created  int `json:"created"`
	Existing int `json:"existing"`
	Notified int `json:"notified"`
	Failed   int `json:"failed"`
}

type batchPostingsResponse struct {
	Created int                 `json:"created"`
	Updated int                 `json:"updated"`
	Skipped int                 `json:"skipped"`
	Failed  int                 `json:"failed"`
	Total   int                 `json:"total"`
	Errors  []batchPostingError `json:"errors,omitempty"`
	Alerts  *notifySummary      `json:"alerts,omitempty"`
}

type batchPostingError struct {
	Index int    `json:"index"`
	Error string `json:"error"`
}

type sourceResult struct {
	Postings []postingInput `json:"postings"`
	Warnings []string       `json:"warnings"`
}

var (
	spaceRE       = regexp.MustCompile(`\s+`)
	nonAlnumRE    = regexp.MustCompile(`[^a-z0-9]+`)
	genderRE      = regexp.MustCompile(`\(?\b(?:m/w/d|w/m/d|m/f/d|f/m/d|d/m/f|d/f/m|all genders|gn)\b\)?`)
	legalSuffixRE = regexp.MustCompile(`\b(?:gmbh|ag|se|mbh|kg|ug|ohg|ev|inc|ltd|llc|plc|sarl|sas|bv|oy|ab|as|group|holding|deutschland|germany|co)\b\.?`)
	tagNoiseRE    = regexp.MustCompile(`[^a-z0-9+#./ -]+`)
)

func cleanText(s string) string {
	s = html.UnescapeString(strings.TrimSpace(s))
	s = stripTags(s)
	return spaceRE.ReplaceAllString(s, " ")
}

var htmlTagRE = regexp.MustCompile(`<[^>]*>`)

func stripTags(s string) string {
	return htmlTagRE.ReplaceAllString(s, " ")
}

func foldUmlauts(s string) string {
	replacer := strings.NewReplacer(
		"ä", "ae", "ö", "oe", "ü", "ue", "ß", "ss",
		"Ä", "ae", "Ö", "oe", "Ü", "ue",
		"á", "a", "à", "a", "â", "a", "é", "e", "è", "e", "ê", "e",
		"í", "i", "ì", "i", "ó", "o", "ò", "o", "ô", "o", "ú", "u", "ù", "u",
	)
	return replacer.Replace(s)
}

func normalizeCompany(s string) string {
	s = foldUmlauts(strings.ToLower(cleanText(s)))
	s = genderRE.ReplaceAllString(s, " ")
	s = legalSuffixRE.ReplaceAllString(s, " ")
	return nonAlnumRE.ReplaceAllString(s, "")
}

func normalizeKey(s string) string {
	s = foldUmlauts(strings.ToLower(cleanText(s)))
	return nonAlnumRE.ReplaceAllString(s, " ")
}

func compactKey(s string) string {
	return strings.ReplaceAll(normalizeKey(s), " ", "")
}

func normalizeTags(tags []string) []string {
	seen := map[string]bool{}
	out := make([]string, 0, len(tags))
	for _, tag := range tags {
		tag = strings.TrimSpace(strings.ToLower(cleanText(tag)))
		tag = tagNoiseRE.ReplaceAllString(tag, "")
		tag = strings.Trim(tag, " -")
		if tag == "" || len(tag) > 40 || seen[tag] {
			continue
		}
		seen[tag] = true
		out = append(out, tag)
	}
	sort.Strings(out)
	return out
}

func canonicalURL(raw string) string {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return ""
	}
	u, err := url.Parse(raw)
	if err != nil {
		return raw
	}
	u.Fragment = ""
	u.Scheme = strings.ToLower(u.Scheme)
	u.Host = strings.ToLower(u.Host)
	u.Host = strings.TrimPrefix(u.Host, "www.")
	if u.Path != "/" {
		u.Path = strings.TrimRight(u.Path, "/")
	}
	q := u.Query()
	for key := range q {
		lk := strings.ToLower(key)
		if strings.HasPrefix(lk, "utm_") || lk == "fbclid" || lk == "gclid" || lk == "ref" || lk == "tracking" {
			q.Del(key)
		}
	}
	u.RawQuery = q.Encode()
	return strings.TrimRight(u.String(), "/")
}

func postingFingerprint(company, title, location string) string {
	companyKey := normalizeCompany(company)
	titleKey := compactKey(genderRE.ReplaceAllString(title, " "))
	locationKey := compactKey(location)
	if locationKey == "" {
		locationKey = "unknown"
	}
	sum := sha1.Sum([]byte(companyKey + "|" + titleKey + "|" + locationKey))
	return hex.EncodeToString(sum[:])
}

func scorePosting(p Posting) (int, []string) {
	text := strings.ToLower(p.Title + " " + p.Location + " " + p.Description + " " + strings.Join(p.Tags, " "))
	type laneRule struct {
		name   string
		weight int
		re     *regexp.Regexp
	}
	rules := []laneRule{
		{"DevOps", 18, regexp.MustCompile(`\bdevops\b`)},
		{"SRE", 18, regexp.MustCompile(`\b(?:sre|site reliability engineer)\b`)},
		{"Platform", 16, regexp.MustCompile(`\bplatform\b`)},
		{"Cloud", 12, regexp.MustCompile(`\b(?:cloud|aws|azure|gcp)\b`)},
		{"Kubernetes", 14, regexp.MustCompile(`\b(?:kubernetes|k8s)\b`)},
		{"NixOS", 18, regexp.MustCompile(`\b(?:nixos|nix)\b`)},
		{"Linux", 10, regexp.MustCompile(`\blinux\b`)},
		{"Go", 10, regexp.MustCompile(`\b(?:go|golang)\b`)},
		{"Python", 8, regexp.MustCompile(`\bpython\b`)},
	}
	lanes := []string{}
	score := 0
	for _, rule := range rules {
		if rule.re.MatchString(text) {
			lanes = append(lanes, rule.name)
			score += rule.weight
		}
	}
	if len(lanes) == 0 {
		return 0, lanes
	}
	if score > 85 {
		score = 85
	}
	geo := regexp.MustCompile(`\b(?:dach|germany|deutschland|austria|switzerland|luxembourg|luxemburg|berlin|munich|münchen|hamburg|cologne|köln|frankfurt|zurich|zürich|vienna|wien)\b`).MatchString(text)
	if geo {
		score += 8
	}
	if p.Remote {
		score += 7
	}
	if score > 100 {
		score = 100
	}
	return score, lanes
}

func newPosting(in postingInput) Posting {
	in.Title = cleanText(in.Title)
	in.Company = cleanText(in.Company)
	in.Location = cleanText(in.Location)
	in.Description = strings.TrimSpace(html.UnescapeString(stripTags(in.Description)))
	in.Source = strings.TrimSpace(strings.ToLower(in.Source))
	in.URL = strings.TrimSpace(in.URL)
	in.Tags = normalizeTags(in.Tags)
	if in.PostedAt != "" {
		in.PostedAt = normalizeDate(in.PostedAt)
	}
	remote := in.Remote || strings.Contains(strings.ToLower(in.Location+" "+in.Title), "remote")
	posting := Posting{
		Fingerprint:   postingFingerprint(in.Company, in.Title, in.Location),
		CanonicalURL:  canonicalURL(in.URL),
		CanonicalKey:  canonicalPostingKey(in.Company, in.Title),
		URL:           in.URL,
		Source:        in.Source,
		Company:       in.Company,
		CompanyKey:    normalizeCompany(in.Company),
		Title:         in.Title,
		Location:      in.Location,
		Remote:        remote,
		Employment:    strings.TrimSpace(in.Employment),
		Description:   spaceRE.ReplaceAllString(in.Description, " "),
		Tags:          in.Tags,
		PostedAt:      in.PostedAt,
		Active:        true,
		MergedSources: []string{in.Source},
		Stage:         "saved",
		Salary:        strings.TrimSpace(in.Salary),
	}
	posting.Score, posting.Lanes = scorePosting(posting)
	return posting
}

func normalizeDate(s string) string {
	s = strings.TrimSpace(s)
	if s == "" {
		return ""
	}
	layouts := []string{
		time.RFC3339, time.RFC1123Z, time.RFC1123, time.RFC822Z, time.RFC822,
		"2006-01-02T15:04:05Z0700", "2006-01-02T15:04:05", "2006-01-02 15:04:05", "2006-01-02",
	}
	for _, layout := range layouts {
		if t, err := time.Parse(layout, s); err == nil {
			return t.UTC().Format(time.RFC3339)
		}
	}
	return s
}

func tagsJSON(tags []string) string {
	if len(tags) == 0 {
		return "[]"
	}
	b, _ := json.Marshal(tags)
	return string(b)
}

func parseTagsJSON(raw string) []string {
	if raw == "" {
		return nil
	}
	var tags []string
	if json.Unmarshal([]byte(raw), &tags) != nil {
		return nil
	}
	return tags
}

func validPosting(p Posting) bool {
	return p.Title != "" && p.Company != "" && len(p.CompanyKey) >= 2 && p.Source != ""
}

func joblike(text string) bool {
	text = strings.ToLower(text)
	for _, word := range []string{"engineer", "devops", "sre", "site reliability", "platform", "infrastructure", "kubernetes", "cloud", "sysadmin", "operations"} {
		if strings.Contains(text, word) {
			return true
		}
	}
	return false
}

func canonicalPostingKey(company, title string) string {
	return normalizeCompany(company) + "|" + compactKey(genderRE.ReplaceAllString(title, " "))
}
func validStage(stage string) bool {
	switch stage {
	case "saved", "applied", "interview", "offer", "rejected", "archived":
		return true
	}
	return false
}
