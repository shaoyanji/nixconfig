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
