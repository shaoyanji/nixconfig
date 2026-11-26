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
	ID           int64     `json:"id"`
	Fingerprint  string    `json:"fingerprint"`
	CanonicalURL string    `json:"canonical_url"`
	URL          string    `json:"url"`
	Source       string    `json:"source"`
	Company      string    `json:"company"`
	CompanyKey   string    `json:"company_key"`
	Title        string    `json:"title"`
	Location     string    `json:"location"`
	Remote       bool      `json:"remote"`
	Employment   string    `json:"employment,omitempty"`
	Description  string    `json:"description"`
	Tags         []string  `json:"tags"`
	PostedAt     string    `json:"posted_at,omitempty"`
	FirstSeen    time.Time `json:"first_seen"`
	LastSeen     time.Time `json:"last_seen"`
	SeenCount    int       `json:"seen_count"`
	Active       bool      `json:"active"`
	Salary       string    `json:"salary,omitempty"`
	Score        float64   `json:"score,omitempty"`
	Snippet      string    `json:"snippet,omitempty"`
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
	return Posting{
		Fingerprint:  postingFingerprint(in.Company, in.Title, in.Location),
		CanonicalURL: canonicalURL(in.URL),
		URL:          in.URL,
		Source:       in.Source,
		Company:      in.Company,
		CompanyKey:   normalizeCompany(in.Company),
		Title:        in.Title,
		Location:     in.Location,
		Remote:       remote,
		Employment:   strings.TrimSpace(in.Employment),
		Description:  spaceRE.ReplaceAllString(in.Description, " "),
		Tags:         in.Tags,
		PostedAt:     in.PostedAt,
		Active:       true,
		Salary:       strings.TrimSpace(in.Salary),
	}
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
