// Package fetchcache is a small conditional HTTP cache for the fleet's
// repetitive public-web fetches. It deliberately implements validation, not a
// freshness policy: a stored validator is always checked upstream, and a 304
// is the one zero-body hit.
package fetchcache

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"
)

const (
	HeaderState         = "X-Fetchcache-State"
	HeaderKey           = "X-Fetchcache-Key"
	HeaderUpstreamBytes = "X-Fetchcache-Upstream-Bytes"

	StateRevalidated = "revalidated"
	StateStored      = "stored"
	StateUncached    = "uncached"
	StateTruncated   = "truncated"
)

type entry struct {
	Version      int         `json:"version"`
	Key          string      `json:"key"`
	URL          string      `json:"url"`
	Status       int         `json:"status"`
	Header       http.Header `json:"header"`
	ETag         string      `json:"etag"`
	LastModified string      `json:"last_modified"`
	FetchedAt    time.Time   `json:"fetched_at"`
	BodyBytes    int64       `json:"body_bytes"`
}

// Transport wraps a RoundTripper with validator-based caching. MaxBodyBytes is
// also the largest body the wrapped client will return for a GET, matching the
// caps the services already apply at their call sites.
type Transport struct {
	Dir          string
	MaxBodyBytes int64
	Base         http.RoundTripper
	Logf         func(format string, args ...any)

	now func() time.Time
}

func New(dir string, maxBodyBytes int64, base http.RoundTripper, logf func(string, ...any)) *Transport {
	if maxBodyBytes <= 0 {
		maxBodyBytes = 8 << 20
	}
	if base == nil {
		base = http.DefaultTransport
	}
	return &Transport{Dir: dir, MaxBodyBytes: maxBodyBytes, Base: base, Logf: logf, now: time.Now}
}

func Normalize(raw string) (string, error) {
	u, err := url.Parse(strings.TrimSpace(raw))
	if err != nil {
		return "", err
	}
	if !u.IsAbs() || (u.Scheme != "http" && u.Scheme != "https") {
		return "", fmt.Errorf("URL must be absolute http or https: %q", raw)
	}
	if u.User != nil {
		return "", errors.New("URLs with userinfo are not cacheable")
	}
	u.Scheme = strings.ToLower(u.Scheme)
	host := strings.ToLower(u.Hostname())
	if host == "" {
		return "", fmt.Errorf("URL has no host: %q", raw)
	}
	port := u.Port()
	defaultPort := (u.Scheme == "http" && port == "80") || (u.Scheme == "https" && port == "443")
	if port == "" || defaultPort {
		if strings.Contains(host, ":") {
			u.Host = "[" + host + "]"
		} else {
			u.Host = host
		}
	} else {
		u.Host = net.JoinHostPort(host, port)
	}
	u.Fragment = ""
	query := u.Query()
	for key := range query {
		sort.Strings(query[key])
	}
	u.RawQuery = query.Encode()
	return u.String(), nil
}

func Key(raw string) (string, string, error) {
	normalized, err := Normalize(raw)
	if err != nil {
		return "", "", err
	}
	sum := sha256.Sum256([]byte(normalized))
	return hex.EncodeToString(sum[:]), normalized, nil
}

func (t *Transport) RoundTrip(req *http.Request) (*http.Response, error) {
	if req.Method != http.MethodGet || t.Dir == "" || req.Header.Get("Authorization") != "" || req.Header.Get("Cookie") != "" {
		return t.Base.RoundTrip(req)
	}
	key, normalized, err := Key(req.URL.String())
	if err != nil {
		return t.Base.RoundTrip(req)
	}

	stored, _ := t.read(key)
	conditional := req.Clone(req.Context())
	conditional.Header = req.Header.Clone()
	if stored != nil {
		if stored.ETag != "" && conditional.Header.Get("If-None-Match") == "" {
			conditional.Header.Set("If-None-Match", stored.ETag)
		}
		if stored.LastModified != "" && conditional.Header.Get("If-Modified-Since") == "" {
			conditional.Header.Set("If-Modified-Since", stored.LastModified)
		}
	}

	res, err := t.Base.RoundTrip(conditional)
	if err != nil {
		return nil, err
	}
	if res.StatusCode == http.StatusNotModified && stored != nil {
		_, _ = io.Copy(io.Discard, res.Body)
		_ = res.Body.Close()
		if cached, readErr := t.cachedResponse(stored, req); readErr == nil {
			stored.FetchedAt = t.now().UTC()
			_ = t.write(stored, nil)
			mark(cached, StateRevalidated, key, 0)
			t.logf("fetchcache: 304 revalidated key=%s url=%s upstream_bytes=0", key, normalized)
			return cached, nil
		}
		// The body vanished after the validator was written. Retry once without
		// the conditional headers rather than inventing a cache hit.
		retry := req.Clone(req.Context())
		retry.Header = req.Header.Clone()
		retry.Header.Del("If-None-Match")
		retry.Header.Del("If-Modified-Since")
		res, err = t.Base.RoundTrip(retry)
		if err != nil {
			return nil, err
		}
	}

	body, truncated, readErr := readCapped(res.Body, t.MaxBodyBytes)
	closeErr := res.Body.Close()
	if readErr != nil {
		return nil, readErr
	}
	if closeErr != nil {
		return nil, closeErr
	}
	res.Body = io.NopCloser(bytes.NewReader(body))
	res.ContentLength = int64(len(body))

	state := StateUncached
	if truncated {
		state = StateTruncated
	} else if res.StatusCode >= 200 && res.StatusCode <= 299 && (res.Header.Get("ETag") != "" || res.Header.Get("Last-Modified") != "") && !noStore(res.Header) {
		fresh := &entry{
			Version:      1,
			Key:          key,
			URL:          normalized,
			Status:       res.StatusCode,
			Header:       res.Header.Clone(),
			ETag:         res.Header.Get("ETag"),
			LastModified: res.Header.Get("Last-Modified"),
			FetchedAt:    t.now().UTC(),
			BodyBytes:    int64(len(body)),
		}
		if err := t.write(fresh, body); err == nil {
			state = StateStored
			t.logf("fetchcache: stored key=%s url=%s status=%d upstream_bytes=%d", key, normalized, res.StatusCode, len(body))
		}
	}
	mark(res, state, key, int64(len(body)))
	return res, nil
}

func readCapped(body io.Reader, max int64) ([]byte, bool, error) {
	var buf bytes.Buffer
	n, err := io.CopyN(&buf, body, max+1)
	if err != nil && !errors.Is(err, io.EOF) {
		return nil, false, err
	}
	if n <= max {
		return buf.Bytes(), false, nil
	}
	out := buf.Bytes()
	return out[:max], true, nil
}

func noStore(header http.Header) bool {
	for _, directive := range strings.Split(header.Get("Cache-Control"), ",") {
		if strings.TrimSpace(strings.ToLower(directive)) == "no-store" {
			return true
		}
	}
	return false
}

func mark(res *http.Response, state, key string, upstreamBytes int64) {
	if res.Header == nil {
		res.Header = http.Header{}
	}
	res.Header.Set(HeaderState, state)
	res.Header.Set(HeaderKey, key)
	res.Header.Set(HeaderUpstreamBytes, fmt.Sprintf("%d", upstreamBytes))
}

func (t *Transport) paths(key string) (string, string) {
	return filepath.Join(t.Dir, key+".json"), filepath.Join(t.Dir, key+".body")
}

func (t *Transport) read(key string) (*entry, error) {
	metaPath, _ := t.paths(key)
	raw, err := os.ReadFile(metaPath)
	if err != nil {
		return nil, err
	}
	var out entry
	if err := json.Unmarshal(raw, &out); err != nil {
		return nil, err
	}
	if out.Key != key || out.Status < 200 || out.Status > 299 {
		return nil, errors.New("cache metadata does not match its key")
	}
	return &out, nil
}

func (t *Transport) write(e *entry, body []byte) error {
	if err := os.MkdirAll(t.Dir, 0o700); err != nil {
		return err
	}
	metaPath, bodyPath := t.paths(e.Key)
	if body != nil {
		if err := writeAtomic(bodyPath, body, 0o600); err != nil {
			return err
		}
	}
	raw, err := json.Marshal(e)
	if err != nil {
		return err
	}
	return writeAtomic(metaPath, raw, 0o600)
}

func writeAtomic(path string, raw []byte, mode os.FileMode) error {
	tmp, err := os.CreateTemp(filepath.Dir(path), filepath.Base(path)+".tmp.")
	if err != nil {
		return err
	}
	tmpName := tmp.Name()
	defer os.Remove(tmpName)
	if err := tmp.Chmod(mode); err != nil {
		_ = tmp.Close()
		return err
	}
	if _, err := tmp.Write(raw); err != nil {
		_ = tmp.Close()
		return err
	}
	if err := tmp.Close(); err != nil {
		return err
	}
	return os.Rename(tmpName, path)
}

func (t *Transport) cachedResponse(e *entry, req *http.Request) (*http.Response, error) {
	_, bodyPath := t.paths(e.Key)
	body, err := os.ReadFile(bodyPath)
	if err != nil {
		return nil, err
	}
	statusText := http.StatusText(e.Status)
	if statusText == "" {
		statusText = "Cached"
	}
	return &http.Response{
		Status:        fmt.Sprintf("%d %s", e.Status, statusText),
		StatusCode:    e.Status,
		Proto:         "HTTP/1.1",
		ProtoMajor:    1,
		ProtoMinor:    1,
		Header:        e.Header.Clone(),
		Body:          io.NopCloser(bytes.NewReader(body)),
		ContentLength: int64(len(body)),
		Request:       req,
	}, nil
}

func (t *Transport) logf(format string, args ...any) {
	if t.Logf != nil {
		t.Logf(format, args...)
	}
}
