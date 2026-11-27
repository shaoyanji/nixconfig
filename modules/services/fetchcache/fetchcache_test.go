package fetchcache

import (
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync/atomic"
	"testing"
)

func TestNormalizeAndKey(t *testing.T) {
	normalized, err := Normalize("HTTPS://EXAMPLE.COM:443/path?b=2&a=1&a=0#fragment")
	if err != nil {
		t.Fatal(err)
	}
	if normalized != "https://example.com/path?a=0&a=1&b=2" {
		t.Fatalf("normalized %q", normalized)
	}
	keyA, _, err := Key("https://example.com/path?a=0&a=1&b=2")
	if err != nil {
		t.Fatal(err)
	}
	keyB, _, err := Key("HTTPS://EXAMPLE.COM:443/path?b=2&a=1&a=0#other")
	if err != nil {
		t.Fatal(err)
	}
	if keyA != keyB || len(keyA) != 64 {
		t.Fatalf("keys %q %q", keyA, keyB)
	}
}

func TestConditional304ReturnsCachedBodyAndLogsZeroUpstreamBytes(t *testing.T) {
	var calls atomic.Int32
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		calls.Add(1)
		if calls.Load() == 2 {
			if r.Header.Get("If-None-Match") != `"v1"` || r.Header.Get("If-Modified-Since") == "" {
				t.Errorf("conditional headers %#v", r.Header)
			}
			w.WriteHeader(http.StatusNotModified)
			return
		}
		w.Header().Set("ETag", `"v1"`)
		w.Header().Set("Last-Modified", "Fri, 27 Nov 2026 12:00:00 GMT")
		w.Header().Set("Content-Type", "text/plain")
		_, _ = io.WriteString(w, "cached body")
	}))
	defer server.Close()

	logs := []string{}
	transport := New(t.TempDir(), 1024, http.DefaultTransport, func(format string, args ...any) {
		logs = append(logs, fmt.Sprintf(format, args...))
	})
	client := &http.Client{Transport: transport}
	var second *http.Response
	for i := 0; i < 2; i++ {
		res, err := client.Get(server.URL + "/feed?x=1")
		if err != nil {
			t.Fatal(err)
		}
		body, err := io.ReadAll(res.Body)
		if err != nil {
			_ = res.Body.Close()
			t.Fatal(err)
		}
		if string(body) != "cached body" || res.StatusCode != 200 {
			_ = res.Body.Close()
			t.Fatalf("pass %d: status %d body %q", i, res.StatusCode, body)
		}
		if i == 1 {
			second = res
		} else {
			_ = res.Body.Close()
		}
	}
	if calls.Load() != 2 {
		t.Fatalf("calls %d", calls.Load())
	}
	res := second
	_ = res.Body.Close()
	if got := res.Header.Get(HeaderState); got != StateRevalidated {
		t.Fatalf("cache state %q headers %#v", got, res.Header)
	}
	if got := res.Header.Get(HeaderUpstreamBytes); got != "0" {
		t.Fatalf("upstream bytes %q", got)
	}
	joined := strings.Join(logs, "\n")
	if !strings.Contains(joined, "304 revalidated") || !strings.Contains(joined, "upstream_bytes=0") {
		t.Fatalf("logs %q", joined)
	}
}

func TestValidatorlessAndOversizedResponsesAreNotStored(t *testing.T) {
	var calls atomic.Int32
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		calls.Add(1)
		if r.Header.Get("If-None-Match") != "" {
			t.Errorf("unexpected conditional header")
		}
		_, _ = io.WriteString(w, "0123456789")
	}))
	defer server.Close()
	transport := New(t.TempDir(), 5, http.DefaultTransport, nil)
	client := &http.Client{Transport: transport}
	for i := 0; i < 2; i++ {
		res, err := client.Get(server.URL)
		if err != nil {
			t.Fatal(err)
		}
		body, _ := io.ReadAll(res.Body)
		_ = res.Body.Close()
		if string(body) != "01234" || res.Header.Get(HeaderState) != StateTruncated {
			t.Fatalf("body %q state %q", body, res.Header.Get(HeaderState))
		}
	}
	if calls.Load() != 2 {
		t.Fatalf("calls %d", calls.Load())
	}
}
