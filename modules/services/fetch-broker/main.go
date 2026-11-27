// fetch-broker is the tailnet's lane-aware fetch API. Delphi serves the API,
// while the us and local lanes are forward proxies on lumi and frieren.
package main

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"strings"
	"time"
	"unicode/utf8"

	"nixconfig.local/fetchcache"
)

type broker struct {
	clients       map[string]laneClients
	timeout       time.Duration
	maxBodyBytes  int64
	renderDoorURL string
}

type laneClients struct {
	cached   *http.Client
	direct   *http.Client
	proxy    string
	hasProxy bool
}

type fetchRequest struct {
	URL   string `json:"url"`
	Lane  string `json:"lane"`
	Want  string `json:"want"`
	Cache *bool  `json:"cache"`
}

type fetchResponse struct {
	URL           string      `json:"url"`
	Lane          string      `json:"lane"`
	UpstreamLane  string      `json:"upstream_lane"`
	Want          string      `json:"want"`
	Status        int         `json:"status"`
	Headers       http.Header `json:"headers,omitempty"`
	Body          string      `json:"body,omitempty"`
	BodyBase64    string      `json:"body_base64,omitempty"`
	BodyBytes     int         `json:"body_bytes"`
	Truncated     bool        `json:"truncated"`
	Cache         bool        `json:"cache"`
	CacheState    string      `json:"cache_state,omitempty"`
	UpstreamBytes int64       `json:"upstream_bytes"`
	Fallback      bool        `json:"fallback"`
	Rendered      bool        `json:"rendered"`
	ContentType   string      `json:"content_type,omitempty"`
	FetchedAt     time.Time   `json:"fetched_at"`
}

type errorResponse struct {
	Error string `json:"error"`
}

func main() {
	addr := flag.String("addr", "127.0.0.1:8107", "loopback address to listen on")
	cacheDir := flag.String("cache-dir", "", "directory for per-lane conditional fetch caches; empty disables validation caching")
	usProxy := flag.String("us-proxy", "http://lumi.cloudforest-kardashev.ts.net:8470", "HTTP/CONNECT proxy URL for the US lane")
	localProxy := flag.String("local-proxy", "http://frieren.cloudforest-kardashev.ts.net:8471", "HTTP/CONNECT proxy URL for the local residential lane")
	renderDoor := flag.String("render-door", "http://127.0.0.1:3002", "firecrawl-local base URL as reachable through the local lane proxy")
	timeout := flag.Duration("timeout", 45*time.Second, "upstream fetch timeout")
	maxBody := flag.Int64("max-body-bytes", 8<<20, "maximum response body returned or stored")
	flag.Parse()

	b, err := newBroker(*cacheDir, *usProxy, *localProxy, *renderDoor, *timeout, *maxBody)
	if err != nil {
		log.Fatalf("fetch-broker: %v", err)
	}
	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, 200, map[string]bool{"ok": true})
	})
	mux.HandleFunc("GET /", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, 200, map[string]any{
			"service": "fetch-broker",
			"fetch":   "POST /v1/fetch {url, lane, want, cache}",
			"lanes":   []string{"bulk", "us", "local"},
		})
	})
	mux.HandleFunc("POST /v1/fetch", b.handleFetch)
	log.Printf("fetch-broker: listening on %s us_proxy=%s local_proxy=%s cache=%t", *addr, *usProxy, *localProxy, *cacheDir != "")
	if err := http.ListenAndServe(*addr, mux); err != nil {
		log.Fatalf("fetch-broker: %v", err)
	}
}

func newBroker(cacheDir, usProxy, localProxy, renderDoor string, timeout time.Duration, maxBody int64) (*broker, error) {
	if timeout <= 0 {
		return nil, errors.New("timeout must be positive")
	}
	if maxBody <= 0 {
		return nil, errors.New("max body must be positive")
	}
	clients := map[string]laneClients{}
	for lane, proxy := range map[string]string{"bulk": "", "us": usProxy, "local": localProxy} {
		lc, err := makeLaneClients(lane, proxy, cacheDir, timeout, maxBody)
		if err != nil {
			return nil, err
		}
		clients[lane] = lc
	}
	return &broker{clients: clients, timeout: timeout, maxBodyBytes: maxBody, renderDoorURL: strings.TrimRight(renderDoor, "/")}, nil
}

func makeLaneClients(lane, proxyURL, cacheDir string, timeout time.Duration, maxBody int64) (laneClients, error) {
	newTransport := func() (http.RoundTripper, error) {
		base := http.DefaultTransport.(*http.Transport).Clone()
		if proxyURL != "" {
			parsed, err := url.Parse(proxyURL)
			if err != nil {
				return nil, fmt.Errorf("%s proxy URL: %w", lane, err)
			}
			if parsed.Scheme != "http" && parsed.Scheme != "https" {
				return nil, fmt.Errorf("%s proxy must be http or https", lane)
			}
			base.Proxy = http.ProxyURL(parsed)
		}
		return base, nil
	}
	directBase, err := newTransport()
	if err != nil {
		return laneClients{}, err
	}
	cachedBase, err := newTransport()
	if err != nil {
		return laneClients{}, err
	}
	dir := ""
	if cacheDir != "" {
		dir = cacheDir + "/" + lane
	}
	return laneClients{
		cached:   &http.Client{Timeout: timeout, Transport: fetchcache.New(dir, maxBody, cachedBase, log.Printf)},
		direct:   &http.Client{Timeout: timeout, Transport: directBase},
		proxy:    proxyURL,
		hasProxy: proxyURL != "",
	}, nil
}

func (b *broker) handleFetch(w http.ResponseWriter, r *http.Request) {
	var in fetchRequest
	decoder := json.NewDecoder(io.LimitReader(r.Body, 1<<20))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(&in); err != nil {
		writeError(w, 400, "bad json: "+err.Error())
		return
	}
	in.Lane = strings.ToLower(strings.TrimSpace(in.Lane))
	if in.Lane == "" {
		in.Lane = "bulk"
	}
	if in.Lane != "bulk" && in.Lane != "us" && in.Lane != "local" {
		writeError(w, 400, "lane must be bulk, us or local")
		return
	}
	in.Want = strings.ToLower(strings.TrimSpace(in.Want))
	if in.Want == "" {
		in.Want = "body"
	}
	if _, _, err := fetchcache.Key(in.URL); err != nil {
		writeError(w, 400, err.Error())
		return
	}
	useCache := true
	if in.Cache != nil {
		useCache = *in.Cache
	}
	ctx, cancel := context.WithTimeout(r.Context(), b.timeout)
	defer cancel()

	var out fetchResponse
	var err error
	switch in.Want {
	case "body", "text", "html", "raw", "metadata", "headers":
		out, err = b.fetchRaw(ctx, in, useCache)
	case "render", "rendered", "markdown":
		if in.Lane != "local" {
			writeError(w, 400, "render is only available on the local lane")
			return
		}
		out, err = b.fetchRendered(ctx, in)
	default:
		writeError(w, 400, "want must be body, metadata, headers or render")
		return
	}
	if err != nil {
		writeError(w, 502, err.Error())
		return
	}
	writeJSON(w, 200, out)
}

func (b *broker) fetchRaw(ctx context.Context, in fetchRequest, useCache bool) (fetchResponse, error) {
	res, upstreamLane, fallback, err := b.doLane(ctx, in.URL, in.Lane, useCache)
	if err != nil {
		return fetchResponse{}, err
	}
	defer res.Body.Close()
	body, truncated, err := readCapped(res.Body, b.maxBodyBytes)
	if err != nil {
		return fetchResponse{}, err
	}
	normalized, _ := fetchcache.Normalize(in.URL)
	out := responseFor(in, upstreamLane, res, body, truncated, normalized)
	out.Truncated = out.Truncated || out.CacheState == fetchcache.StateTruncated
	if !useCache {
		out.UpstreamBytes = int64(len(body))
	}
	out.Fallback = fallback
	out.Cache = useCache
	return out, nil
}

func (b *broker) doLane(ctx context.Context, rawurl, lane string, useCache bool) (*http.Response, string, bool, error) {
	do := func(which string) (*http.Response, error) {
		lc := b.clients[which]
		client := lc.direct
		if useCache {
			client = lc.cached
		}
		req, err := http.NewRequestWithContext(ctx, http.MethodGet, rawurl, nil)
		if err != nil {
			return nil, err
		}
		req.Header.Set("User-Agent", "fetch-broker/0.1 (+https://delphi.cloudforest-kardashev.ts.net:8469)")
		req.Header.Set("Accept", "text/html,application/xhtml+xml,application/rss+xml,application/atom+xml,application/json,text/plain;q=0.8,*/*;q=0.5")
		return client.Do(req)
	}
	res, err := do(lane)
	if err == nil || lane != "us" {
		return res, lane, false, err
	}
	bulkErr := err
	res, err = do("bulk")
	if err != nil {
		return nil, "bulk", true, fmt.Errorf("us lane failed (%v); bulk fallback failed (%w)", bulkErr, err)
	}
	log.Printf("fetch-broker: us lane failed for %s (%v); retried bulk", rawurl, bulkErr)
	return res, "bulk", true, nil
}

func responseFor(in fetchRequest, upstreamLane string, res *http.Response, body []byte, truncated bool, normalized string) fetchResponse {
	out := fetchResponse{
		URL:          normalized,
		Lane:         in.Lane,
		UpstreamLane: upstreamLane,
		Want:         in.Want,
		Status:       res.StatusCode,
		BodyBytes:    len(body),
		Truncated:    truncated,
		CacheState:   res.Header.Get(fetchcache.HeaderState),
		ContentType:  res.Header.Get("Content-Type"),
		FetchedAt:    time.Now().UTC(),
	}
	if n := res.Header.Get(fetchcache.HeaderUpstreamBytes); n != "" {
		fmt.Sscanf(n, "%d", &out.UpstreamBytes)
	}
	if in.Want != "metadata" && in.Want != "headers" {
		if utf8.Valid(body) {
			out.Body = string(body)
		} else {
			out.BodyBase64 = base64.StdEncoding.EncodeToString(body)
		}
	}
	if in.Want == "metadata" || in.Want == "headers" {
		out.Headers = res.Header.Clone()
	}
	return out
}

func (b *broker) fetchRendered(ctx context.Context, in fetchRequest) (fetchResponse, error) {
	lc := b.clients["local"]
	payload, _ := json.Marshal(map[string]any{"url": in.URL, "formats": []string{"markdown", "html"}, "onlyMainContent": true})
	var lastErr error
	for _, path := range []string{"/v2/scrape", "/scrape"} {
		endpoint := b.renderDoorURL + path
		req, err := http.NewRequestWithContext(ctx, http.MethodPost, endpoint, bytes.NewReader(payload))
		if err != nil {
			return fetchResponse{}, err
		}
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("Accept", "application/json")
		res, err := lc.direct.Do(req)
		if err != nil {
			lastErr = err
			continue
		}
		raw, truncated, readErr := readCapped(res.Body, b.maxBodyBytes)
		_ = res.Body.Close()
		if readErr != nil {
			return fetchResponse{}, readErr
		}
		if res.StatusCode == http.StatusNotFound {
			lastErr = fmt.Errorf("render door %s: HTTP 404", endpoint)
			continue
		}
		if res.StatusCode < 200 || res.StatusCode > 299 {
			return fetchResponse{}, fmt.Errorf("render door %s: HTTP %s", endpoint, res.Status)
		}
		body := renderedBody(raw)
		normalized, _ := fetchcache.Normalize(in.URL)
		out := fetchResponse{
			URL:          normalized,
			Lane:         in.Lane,
			UpstreamLane: "local",
			Want:         in.Want,
			Status:       res.StatusCode,
			Body:         body,
			BodyBytes:    len(body),
			Truncated:    truncated,
			Rendered:     true,
			CacheState:   fetchcache.StateUncached,
			ContentType:  "text/markdown; charset=utf-8",
			FetchedAt:    time.Now().UTC(),
		}
		return out, nil
	}
	if lastErr == nil {
		lastErr = errors.New("render door did not answer")
	}
	return fetchResponse{}, lastErr
}

func renderedBody(raw []byte) string {
	var doc map[string]any
	if json.Unmarshal(raw, &doc) != nil {
		return string(raw)
	}
	for _, root := range []any{doc["data"], doc} {
		m, ok := root.(map[string]any)
		if !ok {
			continue
		}
		for _, key := range []string{"markdown", "html", "content", "rawHtml"} {
			if s, ok := m[key].(string); ok && s != "" {
				return s
			}
		}
	}
	return string(raw)
}

func readCapped(body io.Reader, max int64) ([]byte, bool, error) {
	raw, err := io.ReadAll(io.LimitReader(body, max+1))
	if err != nil {
		return nil, false, err
	}
	if int64(len(raw)) <= max {
		return raw, false, nil
	}
	return raw[:max], true, nil
}

func writeJSON(w http.ResponseWriter, status int, value any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(value)
}

func writeError(w http.ResponseWriter, status int, message string) {
	writeJSON(w, status, errorResponse{Error: message})
}
