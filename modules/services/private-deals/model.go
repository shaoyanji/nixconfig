package main

import (
	"crypto/sha1"
	"encoding/hex"
	"encoding/json"
	"html"
	"net/url"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"time"
)

type Product struct {
	ID           int64     `json:"id"`
	Fingerprint  string    `json:"fingerprint"`
	CanonicalURL string    `json:"canonical_url"`
	URL          string    `json:"url"`
	Source       string    `json:"source"`
	Merchant     string    `json:"merchant"`
	Brand        string    `json:"brand"`
	Name         string    `json:"name"`
	Category     string    `json:"category"`
	ImageURL     string    `json:"image_url,omitempty"`
	Currency     string    `json:"currency"`
	ListPrice    *float64  `json:"list_price,omitempty"`
	CurrentPrice *float64  `json:"current_price,omitempty"`
	TargetPrice  *float64  `json:"target_price,omitempty"`
	DiscountPct  float64   `json:"discount_pct"`
	Notes        string    `json:"notes,omitempty"`
	Tags         []string  `json:"tags"`
	Active       bool      `json:"active"`
	FirstSeen    time.Time `json:"first_seen"`
	LastSeen     time.Time `json:"last_seen"`
	CreatedAt    time.Time `json:"created_at"`
	UpdatedAt    time.Time `json:"updated_at"`
}

type Deal struct {
	ID           int64     `json:"id"`
	ProductID    *int64    `json:"product_id,omitempty"`
	Fingerprint  string    `json:"fingerprint"`
	CanonicalURL string    `json:"canonical_url"`
	URL          string    `json:"url"`
	Source       string    `json:"source"`
	Merchant     string    `json:"merchant"`
	Title        string    `json:"title"`
	Description  string    `json:"description"`
	Category     string    `json:"category"`
	Currency     string    `json:"currency"`
	Price        *float64  `json:"price,omitempty"`
	ListPrice    *float64  `json:"list_price,omitempty"`
	DiscountPct  float64   `json:"discount_pct"`
	CouponCode   string    `json:"coupon_code,omitempty"`
	ExpiresAt    string    `json:"expires_at,omitempty"`
	Score        float64   `json:"score"`
	Tags         []string  `json:"tags"`
	Active       bool      `json:"active"`
	FirstSeen    time.Time `json:"first_seen"`
	LastSeen     time.Time `json:"last_seen"`
	SeenCount    int       `json:"seen_count"`
	CreatedAt    time.Time `json:"created_at"`
	UpdatedAt    time.Time `json:"updated_at"`
	Snippet      string    `json:"snippet,omitempty"`
}

type PricePoint struct {
	ID          int64     `json:"id"`
	ProductID   *int64    `json:"product_id,omitempty"`
	DealID      *int64    `json:"deal_id,omitempty"`
	Price       *float64  `json:"price,omitempty"`
	ListPrice   *float64  `json:"list_price,omitempty"`
	DiscountPct float64   `json:"discount_pct"`
	Currency    string    `json:"currency"`
	Source      string    `json:"source"`
	Note        string    `json:"note,omitempty"`
	CapturedAt  time.Time `json:"captured_at"`
}

type Watchlist struct {
	ID          int64     `json:"id"`
	Name        string    `json:"name"`
	Description string    `json:"description,omitempty"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
	ItemCount   int       `json:"item_count"`
}

type WatchlistItem struct {
	WatchlistID int64     `json:"watchlist_id"`
	ProductID   int64     `json:"product_id"`
	Position    int       `json:"position"`
	Notes       string    `json:"notes,omitempty"`
	AddedAt     time.Time `json:"added_at"`
	Product     *Product  `json:"product,omitempty"`
}

type dealInput struct {
	ProductID   *int64   `json:"product_id"`
	URL         string   `json:"url"`
	Source      string   `json:"source"`
	Merchant    string   `json:"merchant"`
	Title       string   `json:"title"`
	Description string   `json:"description"`
	Category    string   `json:"category"`
	Currency    string   `json:"currency"`
	Price       *float64 `json:"price"`
	ListPrice   *float64 `json:"list_price"`
	DiscountPct *float64 `json:"discount_pct"`
	CouponCode  string   `json:"coupon_code"`
	ExpiresAt   string   `json:"expires_at"`
	Score       *float64 `json:"score"`
	Tags        []string `json:"tags"`
}

type productInput struct {
	URL          string   `json:"url"`
	Source       string   `json:"source"`
	Merchant     string   `json:"merchant"`
	Brand        string   `json:"brand"`
	Name         string   `json:"name"`
	Category     string   `json:"category"`
	ImageURL     string   `json:"image_url"`
	Currency     string   `json:"currency"`
	ListPrice    *float64 `json:"list_price"`
	CurrentPrice *float64 `json:"current_price"`
	TargetPrice  *float64 `json:"target_price"`
	Notes        string   `json:"notes"`
	Tags         []string `json:"tags"`
}

type DealAlert struct {
	ID          int64      `json:"id"`
	DealID      int64      `json:"deal_id"`
	ProductID   int64      `json:"product_id"`
	WatchlistID int64      `json:"watchlist_id"`
	Reason      string     `json:"reason"`
	Price       float64    `json:"price"`
	Currency    string     `json:"currency"`
	Title       string     `json:"title"`
	Message     string     `json:"message"`
	Status      string     `json:"status"`
	Attempts    int        `json:"attempts"`
	NotifyError string     `json:"notify_error,omitempty"`
	FirstSeen   time.Time  `json:"first_seen"`
	LastSeen    time.Time  `json:"last_seen"`
	NotifiedAt  *time.Time `json:"notified_at,omitempty"`
	Watchlist   string     `json:"watchlist,omitempty"`
	ProductName string     `json:"product_name,omitempty"`
}

type alertEvaluation struct {
	Matched  int         `json:"matched"`
	Created  int         `json:"created"`
	Existing int         `json:"existing"`
	Alerts   []DealAlert `json:"alerts,omitempty"`
}

type notifySummary struct {
	Matched  int `json:"matched"`
	Created  int `json:"created"`
	Existing int `json:"existing"`
	Notified int `json:"notified"`
	Failed   int `json:"failed"`
}

type batchDealsResponse struct {
	Created int              `json:"created"`
	Updated int              `json:"updated"`
	Skipped int              `json:"skipped"`
	Failed  int              `json:"failed"`
	Total   int              `json:"total"`
	Errors  []batchDealError `json:"errors,omitempty"`
	Alerts  *notifySummary   `json:"alerts,omitempty"`
}

type batchDealError struct {
	Index int    `json:"index"`
	Error string `json:"error"`
}

type ingestResult struct {
	Deals    []dealInput `json:"deals"`
	Warnings []string    `json:"warnings"`
}

var (
	spaceRE       = regexp.MustCompile(`\s+`)
	htmlTagRE     = regexp.MustCompile(`<[^>]*>`)
	nonAlnumRE    = regexp.MustCompile(`[^a-z0-9]+`)
	tagNoiseRE    = regexp.MustCompile(`[^a-z0-9+#./ -]+`)
	percentRE     = regexp.MustCompile(`(?i)(\d{1,2})\s*%\s*(?:off|rabatt|discount|sparen|save|less)`)
	anyPercentRE  = regexp.MustCompile(`(\d{1,2})\s*%`)
	priceTokenRE  = regexp.MustCompile(`(?i)(€\s*\d+(?:[.,]\d{1,2})?|\d+(?:[.,]\d{1,2})?\s*(?:€|eur|euro)|(?:usd|\$)\s*\d+(?:[.,]\d{1,2})?|\d+(?:[.,]\d{1,2})?\s*(?:usd|\$)|£\s*\d+(?:[.,]\d{1,2})?|\d+(?:[.,]\d{1,2})?\s*(?:gbp|£))`)
	currencyNumRE = regexp.MustCompile(`\d+(?:[.,]\d{1,2})?`)
)

func cleanText(s string) string {
	s = html.UnescapeString(strings.TrimSpace(s))
	s = htmlTagRE.ReplaceAllString(s, " ")
	return spaceRE.ReplaceAllString(s, " ")
}

func foldUmlauts(s string) string {
	return strings.NewReplacer(
		"ä", "ae", "ö", "oe", "ü", "ue", "ß", "ss", "Ä", "ae", "Ö", "oe", "Ü", "ue",
		"á", "a", "à", "a", "â", "a", "é", "e", "è", "e", "ê", "e", "í", "i", "ì", "i",
		"ó", "o", "ò", "o", "ô", "o", "ú", "u", "ù", "u",
	).Replace(s)
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
	u.Host = strings.TrimPrefix(strings.ToLower(u.Host), "www.")
	if u.Path != "/" {
		u.Path = strings.TrimRight(u.Path, "/")
	}
	q := u.Query()
	for key := range q {
		lk := strings.ToLower(key)
		if strings.HasPrefix(lk, "utm_") || lk == "fbclid" || lk == "gclid" || lk == "ref" || lk == "aff" || lk == "affiliate" {
			q.Del(key)
		}
	}
	u.RawQuery = q.Encode()
	return strings.TrimRight(u.String(), "/")
}

func merchantFromURL(raw string) string {
	u, err := url.Parse(raw)
	if err != nil {
		return ""
	}
	host := strings.TrimPrefix(strings.ToLower(u.Hostname()), "www.")
	if host == "" {
		return ""
	}
	parts := strings.Split(host, ".")
	if len(parts) >= 2 {
		host = parts[len(parts)-2]
	}
	return strings.ToUpper(host[:1]) + host[1:]
}

func hashParts(parts ...string) string {
	sum := sha1.Sum([]byte(strings.Join(parts, "|")))
	return hex.EncodeToString(sum[:])
}

func dealFingerprint(canonical, merchant, title string) string {
	if canonical != "" {
		return hashParts("url", canonical)
	}
	return hashParts("deal", compactKey(merchant), compactKey(title))
}

func productFingerprint(canonical, merchant, name string) string {
	if canonical != "" {
		return hashParts("url", canonical)
	}
	return hashParts("product", compactKey(merchant), compactKey(name))
}

func normalizeCurrency(s string) string {
	s = strings.ToUpper(strings.TrimSpace(s))
	switch s {
	case "", "€", "EUR", "EURO":
		return "EUR"
	case "$", "USD":
		return "USD"
	case "£", "GBP":
		return "GBP"
	default:
		if len(s) > 5 {
			return s[:5]
		}
		return s
	}
}

func normalizeDate(s string) string {
	s = strings.TrimSpace(s)
	if s == "" {
		return ""
	}
	layouts := []string{time.RFC3339, time.RFC1123Z, time.RFC1123, time.RFC822Z, time.RFC822, "2006-01-02T15:04:05", "2006-01-02 15:04:05", "2006-01-02"}
	for _, layout := range layouts {
		if t, err := time.Parse(layout, s); err == nil {
			return t.UTC().Format(time.RFC3339)
		}
	}
	return s
}

func parseAmount(raw string) (float64, bool) {
	m := currencyNumRE.FindString(raw)
	if m == "" {
		return 0, false
	}
	m = strings.ReplaceAll(m, ",", ".")
	value, err := strconv.ParseFloat(m, 64)
	if err != nil || value <= 0 || value > 1000000 {
		return 0, false
	}
	return value, true
}

func moneyPtr(value float64, ok bool) *float64 {
	if !ok {
		return nil
	}
	return &value
}

func extractPricing(text string) (price, list *float64, discount float64) {
	matches := priceTokenRE.FindAllString(text, 8)
	values := []float64{}
	seen := map[float64]bool{}
	for _, match := range matches {
		if value, ok := parseAmount(match); ok && !seen[value] {
			seen[value] = true
			values = append(values, value)
		}
	}
	if len(values) > 0 {
		low, high := values[0], values[0]
		for _, value := range values[1:] {
			if value < low {
				low = value
			}
			if value > high {
				high = value
			}
		}
		price = moneyPtr(low, true)
		if high > low {
			list = moneyPtr(high, true)
			discount = (high - low) / high * 100
		}
	}
	if m := percentRE.FindStringSubmatch(text); len(m) == 2 {
		if pct, err := strconv.ParseFloat(m[1], 64); err == nil && pct >= 0 && pct <= 99 {
			discount = pct
		}
	} else if discount == 0 {
		if m := anyPercentRE.FindStringSubmatch(text); len(m) == 2 {
			if pct, err := strconv.ParseFloat(m[1], 64); err == nil && pct >= 5 && pct <= 99 {
				discount = pct
			}
		}
	}
	return price, list, round1(discount)
}

func round1(value float64) float64 {
	return float64(int(value*10+0.5)) / 10
}

func discountFor(price, list *float64) float64 {
	if price == nil || list == nil || *list <= 0 || *price >= *list {
		return 0
	}
	return round1((*list - *price) / *list * 100)
}

func inferCategory(text string) string {
	lower := strings.ToLower(text)
	categories := []struct {
		name  string
		words []string
	}{
		{"computing", []string{"laptop", "notebook", "gpu", "graphics card", "ssd", "monitor", "keyboard", "ryzen", "intel", "macbook"}},
		{"audio", []string{"headphone", "earbud", "speaker", "soundbar", "dac", "amplifier"}},
		{"phones", []string{"iphone", "android", "smartphone", "pixel", "galaxy"}},
		{"home", []string{"vacuum", "kitchen", "coffee", "espresso", "airfryer", "furniture"}},
		{"gaming", []string{"game", "playstation", "xbox", "nintendo", "steam deck"}},
		{"fashion", []string{"jacket", "shoes", "sneaker", "shirt", "fashion"}},
	}
	for _, category := range categories {
		for _, word := range category.words {
			if strings.Contains(lower, word) {
				return category.name
			}
		}
	}
	return ""
}

func newDeal(in dealInput) Deal {
	in.Title = cleanText(in.Title)
	in.Merchant = cleanText(in.Merchant)
	in.Description = strings.TrimSpace(html.UnescapeString(htmlTagRE.ReplaceAllString(in.Description, " ")))
	in.Description = spaceRE.ReplaceAllString(in.Description, " ")
	in.Category = strings.TrimSpace(strings.ToLower(in.Category))
	in.Source = strings.TrimSpace(strings.ToLower(in.Source))
	in.URL = strings.TrimSpace(in.URL)
	in.Tags = normalizeTags(in.Tags)
	if in.Source == "" {
		in.Source = "manual"
	}
	if in.Merchant == "" {
		in.Merchant = merchantFromURL(in.URL)
	}
	if in.Category == "" {
		in.Category = inferCategory(in.Title + " " + in.Description)
	}
	if in.Currency == "" {
		in.Currency = "EUR"
	}
	if in.Price == nil {
		price, list, discount := extractPricing(in.Title + " " + in.Description)
		in.Price = price
		if in.ListPrice == nil {
			in.ListPrice = list
		}
		if in.DiscountPct == nil && discount > 0 {
			in.DiscountPct = &discount
		}
	}
	discount := 0.0
	if in.DiscountPct != nil {
		discount = round1(*in.DiscountPct)
	} else {
		discount = discountFor(in.Price, in.ListPrice)
	}
	score := discount
	if in.Score != nil {
		score = *in.Score
	}
	canonical := canonicalURL(in.URL)
	return Deal{
		ProductID:    in.ProductID,
		Fingerprint:  dealFingerprint(canonical, in.Merchant, in.Title),
		CanonicalURL: canonical,
		URL:          in.URL,
		Source:       in.Source,
		Merchant:     in.Merchant,
		Title:        in.Title,
		Description:  in.Description,
		Category:     in.Category,
		Currency:     normalizeCurrency(in.Currency),
		Price:        in.Price,
		ListPrice:    in.ListPrice,
		DiscountPct:  discount,
		CouponCode:   strings.TrimSpace(in.CouponCode),
		ExpiresAt:    normalizeDate(in.ExpiresAt),
		Score:        round1(score),
		Tags:         in.Tags,
		Active:       true,
		SeenCount:    1,
	}
}

func newProduct(in productInput) Product {
	in.Name = cleanText(in.Name)
	in.Merchant = cleanText(in.Merchant)
	in.Brand = cleanText(in.Brand)
	in.Source = strings.TrimSpace(strings.ToLower(in.Source))
	in.URL = strings.TrimSpace(in.URL)
	in.Tags = normalizeTags(in.Tags)
	in.Notes = strings.TrimSpace(in.Notes)
	if in.Source == "" {
		in.Source = "manual"
	}
	if in.Merchant == "" {
		in.Merchant = merchantFromURL(in.URL)
	}
	if in.Category == "" {
		in.Category = inferCategory(in.Name + " " + in.Notes)
	}
	if in.Currency == "" {
		in.Currency = "EUR"
	}
	canonical := canonicalURL(in.URL)
	return Product{
		Fingerprint:  productFingerprint(canonical, in.Merchant, in.Name),
		CanonicalURL: canonical,
		URL:          in.URL,
		Source:       in.Source,
		Merchant:     in.Merchant,
		Brand:        in.Brand,
		Name:         in.Name,
		Category:     strings.TrimSpace(strings.ToLower(in.Category)),
		ImageURL:     strings.TrimSpace(in.ImageURL),
		Currency:     normalizeCurrency(in.Currency),
		ListPrice:    in.ListPrice,
		CurrentPrice: in.CurrentPrice,
		TargetPrice:  in.TargetPrice,
		DiscountPct:  discountFor(in.CurrentPrice, in.ListPrice),
		Notes:        in.Notes,
		Tags:         in.Tags,
		Active:       true,
	}
}

func validDeal(d Deal) bool {
	return d.Title != "" && len(compactKey(d.Title)) >= 3 && d.Source != ""
}

func validProduct(p Product) bool {
	return p.Name != "" && len(compactKey(p.Name)) >= 3 && p.Source != ""
}

func tagsJSON(tags []string) string {
	if len(tags) == 0 {
		return "[]"
	}
	raw, _ := json.Marshal(tags)
	return string(raw)
}

func parseTagsJSON(raw string) []string {
	var tags []string
	if raw == "" || json.Unmarshal([]byte(raw), &tags) != nil {
		return nil
	}
	return tags
}

type analyticsQuery struct {
	Window int
	Limit  int
}

type analyticsDeal struct {
	ID          int64     `json:"id"`
	Title       string    `json:"title"`
	Merchant    string    `json:"merchant,omitempty"`
	Category    string    `json:"category,omitempty"`
	Price       *float64  `json:"price,omitempty"`
	ListPrice   *float64  `json:"list_price,omitempty"`
	DiscountPct float64   `json:"discount_pct"`
	Currency    string    `json:"currency"`
	URL         string    `json:"url,omitempty"`
	LastSeen    time.Time `json:"last_seen"`
}

type analyticsBucket struct {
	Name        string   `json:"name"`
	Deals       int      `json:"deals"`
	AvgDiscount float64  `json:"avg_discount"`
	MaxDiscount float64  `json:"max_discount"`
	MinPrice    *float64 `json:"min_price,omitempty"`
}

type analyticsMovement struct {
	ProductID   int64     `json:"product_id"`
	Name        string    `json:"name"`
	Merchant    string    `json:"merchant,omitempty"`
	Currency    string    `json:"currency"`
	From        float64   `json:"from"`
	To          float64   `json:"to"`
	DropPct     float64   `json:"drop_pct"`
	Points      int       `json:"points"`
	TargetPrice *float64  `json:"target_price,omitempty"`
	FirstAt     time.Time `json:"first_seen"`
	LastAt      time.Time `json:"last_seen"`
}

type historyDay struct {
	Day      string   `json:"day"`
	Points   int      `json:"points"`
	AvgPrice *float64 `json:"avg_price,omitempty"`
	MinPrice *float64 `json:"min_price,omitempty"`
}

type historySummary struct {
	WindowDays int          `json:"window_days"`
	Points     int          `json:"points"`
	Products   int          `json:"products"`
	Fell       int          `json:"fell"`
	Rose       int          `json:"rose"`
	Flat       int          `json:"flat"`
	AvgPrice   *float64     `json:"avg_price,omitempty"`
	MinPrice   *float64     `json:"min_price,omitempty"`
	MaxPrice   *float64     `json:"max_price,omitempty"`
	Currency   string       `json:"currency"`
	Daily      []historyDay `json:"daily"`
}

type analyticsReport struct {
	GeneratedAt  time.Time           `json:"generated_at"`
	WindowDays   int                 `json:"window_days"`
	TopDiscounts []analyticsDeal     `json:"top_discounts"`
	BiggestDrops []analyticsMovement `json:"biggest_drops"`
	Merchants    []analyticsBucket   `json:"merchants"`
	Categories   []analyticsBucket   `json:"categories"`
	History      historySummary      `json:"history"`
}
