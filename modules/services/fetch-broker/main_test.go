package main

import (
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	"nixconfig.local/fetchcache"
)

func testBroker(t *testing.T, usProxy, localProxy string) *broker {
	t.Helper()
	b, err := newBroker(t.TempDir(), usProxy, localProxy, "http://127.0.0.1:3002", 5*time.Second, 1024)
	if err != nil {
		t.Fatal(err)
	}
	return b
}

func postFetch(t *testing.T, b *broker, payload string) fetchResponse {
	t.Helper()
	req := httptest.NewRequest(http.MethodPost, "/v1/fetch", strings.NewReader(payload))
	w := httptest.NewRecorder()
	b.handleFetch(w, req)
	res := w.Result()
	defer res.Body.Close()
	if res.StatusCode != 200 {
		body, _ := io.ReadAll(res.Body)
		t.Fatalf("status %d body %s", res.StatusCode, body)
	}
	var out fetchResponse
	if err := json.NewDecoder(res.Body).Decode(&out); err != nil {
		t.Fatal(err)
	}
	return out
}

func TestBrokerConditionalCacheReturnsZeroUpstreamBytes(t *testing.T) {
	var calls atomic.Int32
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		calls.Add(1)
		if r.Header.Get("If-None-Match") == `"v1"` {
			w.WriteHeader(http.StatusNotModified)
			return
		}
		w.Header().Set("ETag", `"v1"`)
		_, _ = io.WriteString(w, "lane body")
	}))
	defer upstream.Close()
	b := testBroker(t, "", "")
	payload := `{"url":"` + upstream.URL + `/feed","lane":"bulk","want":"body","cache":true}`
	first := postFetch(t, b, payload)
	second := postFetch(t, b, payload)
	if first.CacheState != fetchcache.StateStored {
		t.Fatalf("first cache state %q", first.CacheState)
	}
	if second.CacheState != fetchcache.StateRevalidated || second.UpstreamBytes != 0 {
		t.Fatalf("second cache state %q upstream bytes %d", second.CacheState, second.UpstreamBytes)
	}
	if second.Body != "lane body" || calls.Load() != 2 {
		t.Fatalf("body %q calls %d", second.Body, calls.Load())
	}
}

func TestUSLaneFallsBackToBulkOnProxyFailure(t *testing.T) {
	var calls atomic.Int32
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		calls.Add(1)
		_, _ = io.WriteString(w, "bulk body")
	}))
	defer upstream.Close()
	b := testBroker(t, "http://127.0.0.1:1", "")
	out := postFetch(t, b, `{"url":"`+upstream.URL+`","lane":"us","cache":false}`)
	if !out.Fallback || out.UpstreamLane != "bulk" || out.Body != "bulk body" {
		t.Fatalf("out %#v", out)
	}
	if calls.Load() != 1 {
		t.Fatalf("bulk calls %d", calls.Load())
	}
}

func TestLocalLaneNeverFallsBackToBulk(t *testing.T) {
	var calls atomic.Int32
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		calls.Add(1)
	}))
	defer upstream.Close()
	b := testBroker(t, "", "http://127.0.0.1:1")
	req := httptest.NewRequest(http.MethodPost, "/v1/fetch", strings.NewReader(`{"url":"`+upstream.URL+`","lane":"local","cache":false}`))
	w := httptest.NewRecorder()
	b.handleFetch(w, req)
	if w.Code != 502 {
		t.Fatalf("status %d", w.Code)
	}
	if calls.Load() != 0 {
		t.Fatalf("bulk was tried %d times", calls.Load())
	}
}

func TestMetadataOmitsBodyAndIncludesHeaders(t *testing.T) {
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("X-Test", "yes")
		_, _ = io.WriteString(w, "hidden")
	}))
	defer upstream.Close()
	b := testBroker(t, "", "")
	out := postFetch(t, b, `{"url":"`+upstream.URL+`","want":"metadata","cache":false}`)
	if out.Body != "" || out.Headers.Get("X-Test") != "yes" {
		t.Fatalf("out %#v", out)
	}
}

type roundTripFunc func(*http.Request) (*http.Response, error)

func (f roundTripFunc) RoundTrip(r *http.Request) (*http.Response, error) { return f(r) }

func TestRenderUsesLocalRenderDoor(t *testing.T) {
	render := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost || r.URL.Path != "/v2/scrape" {
			t.Errorf("%s %s", r.Method, r.URL.Path)
		}
		w.Header().Set("Content-Type", "application/json")
		_, _ = io.WriteString(w, `{"data":{"markdown":"rendered markdown"}}`)
	}))
	defer render.Close()
	b := testBroker(t, "", "http://127.0.0.1:1")
	lc := b.clients["local"]
	lc.direct = &http.Client{Transport: roundTripFunc(func(r *http.Request) (*http.Response, error) {
		r.URL.Scheme = "http"
		r.URL.Host = render.Listener.Addr().String()
		r.Host = r.URL.Host
		r.RequestURI = ""
		return http.DefaultTransport.RoundTrip(r)
	})}
	b.clients["local"] = lc
	out := postFetch(t, b, `{"url":"https://example.com","lane":"local","want":"render"}`)
	if !out.Rendered || out.UpstreamLane != "local" || out.Body != "rendered markdown" {
		t.Fatalf("out %#v", out)
	}
}

func TestRenderIsLocalOnly(t *testing.T) {
	b := testBroker(t, "", "")
	req := httptest.NewRequest(http.MethodPost, "/v1/fetch", strings.NewReader(`{"url":"https://example.com","lane":"us","want":"render"}`))
	w := httptest.NewRecorder()
	b.handleFetch(w, req)
	if w.Code != 400 {
		t.Fatalf("status %d", w.Code)
	}
}
