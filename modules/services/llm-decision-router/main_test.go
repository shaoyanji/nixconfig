package main

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"net/http/httputil"
	"net/url"
	"reflect"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"
)

// testGateway builds a gateway proxying to upstream with the given timeout.
func testGateway(upstream *httptest.Server, timeout time.Duration) *llmGateway {
	upstreamURL, _ := url.Parse(upstream.URL)
	proxy := httputil.NewSingleHostReverseProxy(upstreamURL)
	proxy.ErrorHandler = llmErrorHandler
	return newLLMGateway(proxy, timeout)
}

func readErrorCode(t *testing.T, body []byte) string {
	t.Helper()
	var parsed map[string]interface{}
	if err := json.Unmarshal(body, &parsed); err != nil {
		t.Fatalf("response body is not JSON: %v (body: %s)", err, body)
	}
	errObj, ok := parsed["error"].(map[string]interface{})
	if !ok {
		t.Fatalf("response body has no error object: %s", body)
	}
	code, _ := errObj["code"].(string)
	return code
}

func TestLLMGatewayBusyReturns429(t *testing.T) {
	entered := make(chan struct{})
	release := make(chan struct{})
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		close(entered)
		<-release // block until the test releases the first request
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte(`{"choices":[]}`))
	}))
	defer upstream.Close()

	gateway := testGateway(upstream, 5*time.Second)

	// First request acquires the slot and blocks in the upstream.
	var wg sync.WaitGroup
	wg.Add(1)
	go func() {
		defer wg.Done()
		req := httptest.NewRequest(http.MethodPost, "/v1/chat/completions",
			strings.NewReader(`{"model":"qwen3.6-35b-a3b"}`))
		rec := httptest.NewRecorder()
		gateway.serveChat(rec, req, false)
		if rec.Code != http.StatusOK {
			t.Errorf("first request: expected 200, got %d", rec.Code)
		}
	}()

	<-entered // upstream has the first request; the slot is held

	// Second concurrent request must fail fast, never queue.
	req2 := httptest.NewRequest(http.MethodPost, "/v1/chat/completions",
		strings.NewReader(`{"model":"qwen3.6-35b-a3b"}`))
	rec2 := httptest.NewRecorder()
	gateway.serveChat(rec2, req2, false)
	if rec2.Code != http.StatusTooManyRequests {
		t.Fatalf("second request: expected 429, got %d", rec2.Code)
	}
	if code := readErrorCode(t, rec2.Body.Bytes()); code != "llm_busy" {
		t.Fatalf("second request: expected error code llm_busy, got %q", code)
	}

	close(release)
	wg.Wait()
}

func TestLLMGatewayTimeoutReturnsJSONError(t *testing.T) {
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		time.Sleep(300 * time.Millisecond) // slower than the gateway timeout
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte(`{"choices":[]}`))
	}))
	defer upstream.Close()

	gateway := testGateway(upstream, 50*time.Millisecond)

	req := httptest.NewRequest(http.MethodPost, "/v1/chat/completions",
		strings.NewReader(`{"model":"qwen3.6-35b-a3b"}`))
	rec := httptest.NewRecorder()
	gateway.serveChat(rec, req, false)

	if rec.Code != http.StatusGatewayTimeout {
		t.Fatalf("expected 504, got %d (body: %s)", rec.Code, rec.Body.String())
	}
	if code := readErrorCode(t, rec.Body.Bytes()); code != "upstream_timeout" {
		t.Fatalf("expected error code upstream_timeout, got %q", code)
	}
}

func TestLLMGatewaySlotReleasedAfterCompletion(t *testing.T) {
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte(`{"choices":[]}`))
	}))
	defer upstream.Close()

	gateway := testGateway(upstream, 5*time.Second)

	for i := 0; i < 2; i++ {
		req := httptest.NewRequest(http.MethodPost, "/v1/chat/completions",
			strings.NewReader(`{"model":"qwen3.6-35b-a3b"}`))
		rec := httptest.NewRecorder()
		gateway.serveChat(rec, req, false)
		if rec.Code != http.StatusOK {
			t.Fatalf("request %d: expected 200, got %d", i+1, rec.Code)
		}
	}
}

func TestLLMGatewaySlotReleasedAfterCancel(t *testing.T) {
	entered := make(chan struct{})
	release := make(chan struct{})
	var calls atomic.Int32
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if calls.Add(1) == 1 {
			close(entered)
			// Return on client cancel OR test release: blocking on the
			// request context alone leaves httptest.Server.Close() hanging
			// on this handler if the context never fires in the harness.
			select {
			case <-r.Context().Done():
			case <-release:
			}
			return
		}
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte(`{"choices":[]}`))
	}))
	defer upstream.Close()

	gateway := testGateway(upstream, 5*time.Second)

	ctx, cancel := context.WithCancel(context.Background())
	done := make(chan struct{})
	go func() {
		defer close(done)
		req := httptest.NewRequestWithContext(ctx, http.MethodPost, "/v1/chat/completions",
			strings.NewReader(`{"model":"qwen3.6-35b-a3b"}`))
		rec := httptest.NewRecorder()
		gateway.serveChat(rec, req, false)
		// Result ignored: the client went away, so the write fails silently.
	}()

	<-entered      // upstream has the request; the slot is held
	cancel()       // client disconnects mid-generation
	close(release) // let the upstream handler return so Close() cannot hang
	<-done         // handler returned; the slot must be released

	req2 := httptest.NewRequest(http.MethodPost, "/v1/chat/completions",
		strings.NewReader(`{"model":"qwen3.6-35b-a3b"}`))
	rec2 := httptest.NewRecorder()
	gateway.serveChat(rec2, req2, false)
	if rec2.Code != http.StatusOK {
		t.Fatalf("second request: expected 200 (slot released after cancel), got %d", rec2.Code)
	}
}

func TestNormalizeMessages(t *testing.T) {
	input := []interface{}{
		map[string]interface{}{"role": "system", "content": "System prompt 1"},
		map[string]interface{}{"role": "system", "content": "System prompt 2"},
		map[string]interface{}{"role": "user", "content": "Hello"},
		map[string]interface{}{"role": "user", "content": "State JSON"},
	}

	expected := []interface{}{
		map[string]interface{}{"role": "system", "content": "System prompt 1\n\nSystem prompt 2"},
		map[string]interface{}{"role": "user", "content": "Hello"},
		map[string]interface{}{"role": "user", "content": "State JSON"},
	}

	output := normalizeMessages(input)
	if !reflect.DeepEqual(output, expected) {
		t.Fatalf("Expected %+v, got %+v", expected, output)
	}
}

func TestCleanResponseContent(t *testing.T) {
	// Case 1: <think> tags followed by markdown fenced JSON
	input1 := "<think>\nThinking steps here\n</think>\n\n```json\n{\"actions\":[],\"answer\":\"Hello!\"}\n```"
	expected1 := "{\"actions\":[],\"answer\":\"Hello!\"}"
	if out := cleanResponseContent(input1, true); out != expected1 {
		t.Errorf("Test 1 failed. Expected %q, got %q", expected1, out)
	}

	// Case 2: Just <think> tags with regular text
	input2 := "<think>\nSome thought\n</think>\n\nHello there!"
	expected2 := "Hello there!"
	if out := cleanResponseContent(input2, false); out != expected2 {
		t.Errorf("Test 2 failed. Expected %q, got %q", expected2, out)
	}
}

// TestSlotReleasedOnDisconnectWithStuckUpstream: the upstream ignores
// cancellation and blocks (as llama-swap can when its own backend is
// stuck). Cancelling the client must still free the slot, so a second
// request does not 429 while the first handler is still blocked.
func TestSlotReleasedOnDisconnectWithStuckUpstream(t *testing.T) {
	entered := make(chan struct{})
	release := make(chan struct{})
	var calls atomic.Int32
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if calls.Add(1) == 1 {
			close(entered)
			// Ignore r.Context().Done(): the upstream is stuck.
			<-release
		}
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte(`{"choices":[]}`))
	}))
	defer upstream.Close()

	gateway := testGateway(upstream, 5*time.Second)

	ctx, cancel := context.WithCancel(context.Background())
	go func() {
		req := httptest.NewRequestWithContext(ctx, http.MethodPost, "/v1/chat/completions",
			strings.NewReader(`{"model":"qwen3.6-35b-a3b"}`))
		rec := httptest.NewRecorder()
		gateway.serveChat(rec, req, false)
	}()

	<-entered // upstream has the request; the slot is held
	cancel() // client disconnects; upstream stays stuck (release still open)

	// The slot must already be free, even though handler 1 is blocked.
	req2 := httptest.NewRequest(http.MethodPost, "/v1/chat/completions",
		strings.NewReader(`{"model":"qwen3.6-35b-a3b"}`))
	rec2 := httptest.NewRecorder()
	done2 := make(chan struct{})
	go func() {
		defer close(done2)
		gateway.serveChat(rec2, req2, false)
	}()
	select {
	case <-done2:
		if rec2.Code == http.StatusTooManyRequests {
			t.Fatalf("second request: expected slot freed on disconnect, got 429")
		}
		if rec2.Code != http.StatusOK {
			t.Fatalf("second request: expected 200, got %d", rec2.Code)
		}
	case <-time.After(3 * time.Second):
		t.Fatalf("second request did not complete (slot still held after disconnect)")
	}
	close(release) // let the stuck upstream return; handler 1 exits
}

// --- Decision handler: lane selection, error-classed fallback, observability ---

// decisionTestRig spins up fake TypeSafe and Laya upstreams and returns a
// handler plus counters recording how many requests each upstream saw.
func decisionTestRig(t *testing.T, tsStatus int, tsBody string) (
	handler http.HandlerFunc, tsHits, layaHits *atomic.Int32,
) {
	t.Helper()
	tsHits = &atomic.Int32{}
	layaHits = &atomic.Int32{}

	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		tsHits.Add(1)
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(tsStatus)
		_, _ = w.Write([]byte(tsBody))
	}))
	t.Cleanup(ts.Close)

	laya := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		layaHits.Add(1)
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte(`{"answers":{"q":{"choice":"laya"}}}`))
	}))
	t.Cleanup(laya.Close)

	cfg := Config{
		TypeSafeEndpoint:     ts.URL,
		LayaEndpoint:         laya.URL,
		DefaultDecisionModel: "jev-latest",
		FallbackToLocal:      true,
	}
	return newDecisionHandler(cfg, ts.Client()), tsHits, layaHits
}

func postDecision(handler http.HandlerFunc, auth string) *httptest.ResponseRecorder {
	req := httptest.NewRequest(http.MethodPost, "/v1/systemone",
		strings.NewReader(`{"state":{"x":1},"questions":{"q":{"type":"choice"}}}`))
	if auth != "" {
		req.Header.Set("Authorization", auth)
	}
	rec := httptest.NewRecorder()
	handler(rec, req)
	return rec
}

func TestDecisionTypeSafeAnswers(t *testing.T) {
	handler, _, layaHits := decisionTestRig(t, http.StatusOK, `{"answers":{}}`)
	rec := postDecision(handler, "Bearer apikey_fleetkey123")
	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rec.Code)
	}
	if got := rec.Header().Get("X-Decision-Provider"); got != "typesafe" {
		t.Fatalf("expected provider typesafe, got %q", got)
	}
	if layaHits.Load() != 0 {
		t.Fatalf("local lane must not see a TypeSafe success")
	}
}

func TestDecisionNoKeyGoesLocal(t *testing.T) {
	handler, tsHits, _ := decisionTestRig(t, http.StatusOK, `{}`)
	rec := postDecision(handler, "")
	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200 from local lane, got %d", rec.Code)
	}
	if got := rec.Header().Get("X-Decision-Provider"); got != "laya" {
		t.Fatalf("expected provider laya, got %q", got)
	}
	if tsHits.Load() != 0 {
		t.Fatalf("TypeSafe must not be called without a TypeSafe-shaped key")
	}
}

func TestDecisionForeignBearerNotForwarded(t *testing.T) {
	handler, tsHits, _ := decisionTestRig(t, http.StatusOK, `{}`)
	rec := postDecision(handler, "Bearer fleet-internal-token")
	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200 from local lane, got %d", rec.Code)
	}
	if tsHits.Load() != 0 {
		t.Fatalf("non-TypeSafe bearer must not be forwarded to the cloud API")
	}
}

func TestDecisionServerErrorFallsBack(t *testing.T) {
	handler, _, layaHits := decisionTestRig(t, http.StatusBadGateway, `{"error":"down"}`)
	rec := postDecision(handler, "Bearer apikey_fleetkey123")
	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200 from fallback, got %d", rec.Code)
	}
	if got := rec.Header().Get("X-Decision-Provider"); got != "laya" {
		t.Fatalf("expected provider laya, got %q", got)
	}
	if layaHits.Load() != 1 {
		t.Fatalf("expected exactly one local call, got %d", layaHits.Load())
	}
}

func TestDecisionRequestErrorDoesNotFallBack(t *testing.T) {
	handler, _, layaHits := decisionTestRig(t, http.StatusBadRequest, `{"error":"bad payload"}`)
	rec := postDecision(handler, "Bearer apikey_fleetkey123")
	if rec.Code != http.StatusBadRequest {
		t.Fatalf("request error must pass through verbatim, got %d", rec.Code)
	}
	if got := rec.Header().Get("X-Decision-Provider"); got != "typesafe" {
		t.Fatalf("expected provider typesafe, got %q", got)
	}
	if layaHits.Load() != 0 {
		t.Fatalf("a request-side error must not re-ask the weaker model")
	}
}

func TestDecisionFallbackDisabledReturns502(t *testing.T) {
	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusInternalServerError)
	}))
	defer ts.Close()
	cfg := Config{TypeSafeEndpoint: ts.URL, LayaEndpoint: "http://127.0.0.1:1",
		DefaultDecisionModel: "jev-latest", FallbackToLocal: false}
	handler := newDecisionHandler(cfg, ts.Client())
	rec := postDecision(handler, "Bearer apikey_fleetkey123")
	if rec.Code != http.StatusBadGateway {
		t.Fatalf("expected 502 with fallback disabled, got %d", rec.Code)
	}
}

func TestDecisionMethodNotAllowed(t *testing.T) {
	handler, _, _ := decisionTestRig(t, http.StatusOK, `{}`)
	req := httptest.NewRequest(http.MethodGet, "/v1/systemone", nil)
	rec := httptest.NewRecorder()
	handler(rec, req)
	if rec.Code != http.StatusMethodNotAllowed {
		t.Fatalf("expected 405, got %d", rec.Code)
	}
}
