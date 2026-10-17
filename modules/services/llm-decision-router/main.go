package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/http/httputil"
	"net/url"
	"os"
	"os/signal"
	"strings"
	"sync"
	"syscall"
	"time"
)

type contextKey string

const contextKeyWantedJSON contextKey = "wanted_json"

func normalizeMessages(rawMsgs []interface{}) []interface{} {
	var systemParts []string
	var nonSystemMsgs []map[string]interface{}

	for _, item := range rawMsgs {
		msgMap, ok := item.(map[string]interface{})
		if !ok {
			continue
		}
		role, _ := msgMap["role"].(string)
		content, _ := msgMap["content"].(string)

		if role == "system" {
			if strings.TrimSpace(content) != "" {
				systemParts = append(systemParts, content)
			}
		} else {
			nonSystemMsgs = append(nonSystemMsgs, msgMap)
		}
	}

	var result []interface{}
	if len(systemParts) > 0 {
		mergedSystem := strings.Join(systemParts, "\n\n")
		result = append(result, map[string]interface{}{
			"role":    "system",
			"content": mergedSystem,
		})
	}

	for _, m := range nonSystemMsgs {
		result = append(result, m)
	}

	return result
}

func cleanResponseContent(content string, requestedJSON bool) string {
	// 1. Strip <think>...</think> reasoning traces
	for {
		startIdx := strings.Index(content, "<think>")
		if startIdx == -1 {
			break
		}
		endIdx := strings.Index(content, "</think>")
		if endIdx == -1 {
			content = content[:startIdx]
			break
		}
		content = content[:startIdx] + content[endIdx+len("</think>"):]
	}
	content = strings.TrimSpace(content)

	// 2. If client asked for JSON or model enclosed output in markdown code blocks
	if requestedJSON || strings.HasPrefix(content, "```") {
		// Strip markdown code fences ```json ... ``` or ``` ... ```
		if strings.HasPrefix(content, "```") {
			if firstLineEnd := strings.Index(content, "\n"); firstLineEnd != -1 {
				content = content[firstLineEnd+1:]
			}
			if lastFence := strings.LastIndex(content, "```"); lastFence != -1 {
				content = content[:lastFence]
			}
			content = strings.TrimSpace(content)
		}

		// Extract first valid JSON object { ... }
		startBrace := strings.Index(content, "{")
		endBrace := strings.LastIndex(content, "}")
		if startBrace != -1 && endBrace != -1 && endBrace > startBrace {
			candidate := content[startBrace : endBrace+1]
			var js json.RawMessage
			if json.Unmarshal([]byte(candidate), &js) == nil {
				content = candidate
			}
		}
	}

	return content
}

type Config struct {
	BindAddr             string
	LLMUpstreamURL       string
	TypeSafeEndpoint     string
	LayaEndpoint         string
	DefaultDecisionModel string
	DefaultModel         string
	FallbackToLocal      bool
}

func getEnv(key, fallback string) string {
	if val := os.Getenv(key); val != "" {
		return val
	}
	return fallback
}

// llmGateway serializes generative requests and bounds them.
//
// llama-server runs --parallel 1, so a second concurrent request would
// only queue behind the first. SubZeroClaw's curl caps each request at
// 120 s and retries twice, so a queued request times out, gets retried
// behind the orphaned generation, and the queue cascades (Oct 16: repeated
// `http: proxy error: context canceled`, 6-min stall). Fail fast with 429
// instead: subzeroclaw is a dynamic task agent, not a long runtime loop —
// a task that cannot complete within bounds should fail cleanly, not loop.
//
// The request context is derived from the incoming request and never
// detached, so a client disconnect still cancels the upstream generation.
const (
	llmProxyTimeout = 110 * time.Second // just under the client's 120 s cap
)

type llmGateway struct {
	proxy   *httputil.ReverseProxy
	slot    chan struct{} // capacity 1: one generation at a time
	timeout time.Duration
}

func newLLMGateway(proxy *httputil.ReverseProxy, timeout time.Duration) *llmGateway {
	return &llmGateway{proxy: proxy, slot: make(chan struct{}, 1), timeout: timeout}
}

// tryAcquire takes the single generation slot, non-blocking.
func (g *llmGateway) tryAcquire() bool {
	select {
	case g.slot <- struct{}{}:
		return true
	default:
		return false
	}
}

func (g *llmGateway) release() { <-g.slot }

// writeJSONError writes an OpenAI-shaped error envelope so clients can parse
// the failure instead of seeing a killed connection.
func writeJSONError(w http.ResponseWriter, status int, code, message string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(map[string]interface{}{
		"error": map[string]interface{}{
			"message": message,
			"type":    code,
			"code":    code,
		},
	})
}

// llmErrorHandler replaces ReverseProxy's default (plain-text 502): a timed-out
// upstream returns a parseable 504, and a client disconnect just logs.
func llmErrorHandler(w http.ResponseWriter, r *http.Request, err error) {
	if r.Context().Err() == context.DeadlineExceeded {
		log.Printf("[CHAT-TIMEOUT] upstream did not answer within %v", llmProxyTimeout)
		writeJSONError(w, http.StatusGatewayTimeout, "upstream_timeout",
			fmt.Sprintf("LLM upstream timed out after %v", llmProxyTimeout))
		return
	}
	log.Printf("[CHAT-ERROR] proxy error: %v", err)
	writeJSONError(w, http.StatusBadGateway, "upstream_error", "LLM upstream error")
}

// serveChat enforces the slot + timeout, then proxies.
func (g *llmGateway) serveChat(w http.ResponseWriter, r *http.Request, wantedJSON bool) {
	if !g.tryAcquire() {
		log.Printf("[CHAT-BUSY] rejecting %s: generation slot busy", r.URL.Path)
		writeJSONError(w, http.StatusTooManyRequests, "llm_busy",
			"LLM generation slot busy; retry later")
		return
	}
	// Release exactly once, even if the upstream proxy blocks past
	// client disconnect: a dead client must not hold the single slot
	// until the upstream answers or the 110s timeout fires (observed:
	// a disconnected SubZeroClaw held the slot ~90s, 429ing its retry).
	var once sync.Once
	release := func() { once.Do(g.release) }
	defer release()
	ctx, cancel := context.WithTimeout(r.Context(), g.timeout)
	defer cancel()
	go func() {
		<-ctx.Done()
		release()
	}()
	r = r.WithContext(context.WithValue(ctx, contextKeyWantedJSON, wantedJSON))
	g.proxy.ServeHTTP(w, r)
}

func main() {
	port := getEnv("PORT", "8000")
	bind := getEnv("BIND", "127.0.0.1")

	cfg := Config{
		BindAddr:             bind + ":" + port,
		LLMUpstreamURL:       getEnv("LLM_UPSTREAM", "http://127.0.0.1:8080"),
		TypeSafeEndpoint:     getEnv("TYPESAFE_ENDPOINT", "https://api.typesafe.ai/v1/systemone"),
		LayaEndpoint:         getEnv("LAYA_ENDPOINT", "http://127.0.0.1:8090/v1/systemone"),
		DefaultDecisionModel: getEnv("DEFAULT_DECISION_MODEL", "jev-latest"),
		DefaultModel:         getEnv("DEFAULT_MODEL", "qwen3.6-35b-a3b"),
		FallbackToLocal:      getEnv("FALLBACK_TO_LOCAL", "true") == "true",
	}

	llmURL, err := url.Parse(cfg.LLMUpstreamURL)
	if err != nil {
		log.Fatalf("Invalid LLM_UPSTREAM URL: %v", err)
	}

	llmProxy := httputil.NewSingleHostReverseProxy(llmURL)
	llmProxy.ErrorHandler = llmErrorHandler
	gateway := newLLMGateway(llmProxy, llmProxyTimeout)
	originalDirector := llmProxy.Director
	llmProxy.Director = func(req *http.Request) {
		originalDirector(req)
		req.Host = llmURL.Host
	}

	llmProxy.ModifyResponse = func(resp *http.Response) error {
		if resp.StatusCode != http.StatusOK {
			body, _ := io.ReadAll(resp.Body)
			log.Printf("[CHAT-ERROR] upstream %s returned %d: %s", resp.Request.URL.Path, resp.StatusCode, string(body))
			resp.Body = io.NopCloser(bytes.NewReader(body))
			return nil
		}

		bodyBytes, err := io.ReadAll(resp.Body)
		if err != nil {
			return err
		}

		var chatResp map[string]interface{}
		if err := json.Unmarshal(bodyBytes, &chatResp); err == nil {
			modified := false
			if choices, ok := chatResp["choices"].([]interface{}); ok && len(choices) > 0 {
				if firstChoice, ok := choices[0].(map[string]interface{}); ok {
					if msg, ok := firstChoice["message"].(map[string]interface{}); ok {
						if content, ok := msg["content"].(string); ok {
							reqWantedJSON := false
							if val, ok := resp.Request.Context().Value(contextKeyWantedJSON).(bool); ok {
								reqWantedJSON = val
							}
							cleaned := cleanResponseContent(content, reqWantedJSON)
							if cleaned != content {
								msg["content"] = cleaned
								modified = true
							}
						}
					}
				}
			}

			if modified {
				newBytes, err := json.Marshal(chatResp)
				if err == nil {
					bodyBytes = newBytes
				}
			}
		}

		resp.Body = io.NopCloser(bytes.NewReader(bodyBytes))
		resp.ContentLength = int64(len(bodyBytes))
		resp.Header.Set("Content-Length", fmt.Sprintf("%d", len(bodyBytes)))
		return nil
	}

	httpClient := &http.Client{
		Timeout: 25 * time.Second,
	}

	mux := http.NewServeMux()

	// Health check
	mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]interface{}{
			"status":            "ok",
			"router":            "llm-decision-router",
			"llm_upstream":      cfg.LLMUpstreamURL,
			"typesafe_endpoint": cfg.TypeSafeEndpoint,
			"laya_endpoint":     cfg.LayaEndpoint,
			"default_model":     cfg.DefaultDecisionModel,
		})
	})

	// Chat completions & models -> proxy to local llama-swap
	mux.HandleFunc("/v1/chat/completions", func(w http.ResponseWriter, r *http.Request) {
		log.Printf("[CHAT] %s %s from %s", r.Method, r.URL.Path, r.RemoteAddr)

		wantedJSON := false
		if r.Method == http.MethodPost && r.Body != nil {
			bodyBytes, err := io.ReadAll(r.Body)
			if err == nil && len(bodyBytes) > 0 {
				var req map[string]interface{}
				if err := json.Unmarshal(bodyBytes, &req); err == nil {
					modified := false

					// Normalize policy:auto or missing model to local default
					if m, ok := req["model"].(string); !ok || m == "" || strings.HasPrefix(m, "policy:") {
						req["model"] = cfg.DefaultModel
						modified = true
					}

					// Strip response_format if present to prevent llama-server sampler crash with <think> reasoning tokens
					if _, hasFormat := req["response_format"]; hasFormat {
						wantedJSON = true
						delete(req, "response_format")
						modified = true
					}

					// Consolidate multiple system messages into a single system message at the beginning
					// This prevents llama-server Jinja exceptions ("System message must be at the beginning")
					if msgs, ok := req["messages"].([]interface{}); ok && len(msgs) > 0 {
						normalized := normalizeMessages(msgs)
						req["messages"] = normalized
						modified = true
					}

					if modified {
						newBytes, err := json.Marshal(req)
						if err == nil {
							bodyBytes = newBytes
						}
					}
				}
				r.Body = io.NopCloser(bytes.NewReader(bodyBytes))
				r.ContentLength = int64(len(bodyBytes))
				r.Header.Set("Content-Length", fmt.Sprintf("%d", len(bodyBytes)))
			}
		}

		gateway.serveChat(w, r, wantedJSON)
	})

	mux.HandleFunc("/v1/models", func(w http.ResponseWriter, r *http.Request) {
		llmProxy.ServeHTTP(w, r)
	})

	// Decisions endpoint for SubZeroClaw / Jev
	handleDecisions := func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
			return
		}

		bodyBytes, err := io.ReadAll(r.Body)
		if err != nil {
			http.Error(w, "Failed to read request body", http.StatusBadRequest)
			return
		}

		var payload map[string]interface{}
		if err := json.Unmarshal(bodyBytes, &payload); err != nil {
			http.Error(w, "Invalid JSON payload", http.StatusBadRequest)
			return
		}

		// Ensure model is set for TypeSafe Jev if missing or unhardcoded policy placeholder
		modelVal, hasModel := payload["model"].(string)
		if !hasModel || modelVal == "" || strings.HasPrefix(modelVal, "policy:") {
			payload["model"] = cfg.DefaultDecisionModel
		}

		forwardBytes, err := json.Marshal(payload)
		if err != nil {
			http.Error(w, "Failed to serialize payload", http.StatusInternalServerError)
			return
		}

		authHeader := r.Header.Get("Authorization")
		triedTypeSafe := false

		// 1. If an API key is present, attempt TypeSafe Jev first
		if authHeader != "" && strings.Contains(authHeader, "apikey_") {
			triedTypeSafe = true
			req, err := http.NewRequestWithContext(r.Context(), http.MethodPost, cfg.TypeSafeEndpoint, bytes.NewReader(forwardBytes))
			if err == nil {
				req.Header.Set("Content-Type", "application/json")
				req.Header.Set("Authorization", authHeader)

				start := time.Now()
				resp, err := httpClient.Do(req)
				if err == nil {
					respBody, readErr := io.ReadAll(resp.Body)
					resp.Body.Close()

					if readErr == nil && resp.StatusCode == http.StatusOK {
						log.Printf("[DECISION] TypeSafe Jev OK in %v (status %d)", time.Since(start), resp.StatusCode)
						w.Header().Set("Content-Type", "application/json")
						w.WriteHeader(http.StatusOK)
						w.Write(respBody)
						return
					}
					log.Printf("[DECISION-WARN] TypeSafe returned status %d: %s", resp.StatusCode, string(respBody))
				} else {
					log.Printf("[DECISION-WARN] TypeSafe network error: %v", err)
				}
			}
		}

		// 2. Fallback to local Laya if TypeSafe failed or no key provided
		if !triedTypeSafe || cfg.FallbackToLocal {
			log.Printf("[DECISION] Routing to local Laya (%s)", cfg.LayaEndpoint)
			req, err := http.NewRequestWithContext(r.Context(), http.MethodPost, cfg.LayaEndpoint, bytes.NewReader(forwardBytes))
			if err != nil {
				http.Error(w, fmt.Sprintf("Failed to construct fallback request: %v", err), http.StatusInternalServerError)
				return
			}
			req.Header.Set("Content-Type", "application/json")

			start := time.Now()
			resp, err := httpClient.Do(req)
			if err != nil {
				http.Error(w, fmt.Sprintf("Fallback Laya unreachable: %v", err), http.StatusBadGateway)
				return
			}
			defer resp.Body.Close()

			respBody, err := io.ReadAll(resp.Body)
			if err != nil {
				http.Error(w, "Failed to read fallback response", http.StatusInternalServerError)
				return
			}

			log.Printf("[DECISION] Local Laya responded in %v (status %d)", time.Since(start), resp.StatusCode)
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(resp.StatusCode)
			w.Write(respBody)
			return
		}

		http.Error(w, "Decision service unavailable", http.StatusBadGateway)
	}

	mux.HandleFunc("/v1/decisions", handleDecisions)
	mux.HandleFunc("/v1/systemone", handleDecisions)

	server := &http.Server{
		Addr:    cfg.BindAddr,
		Handler: mux,
	}

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, os.Interrupt, syscall.SIGTERM)

	go func() {
		log.Printf("llm-decision-router listening on %s (LLM: %s, Jev: %s, Laya: %s)",
			cfg.BindAddr, cfg.LLMUpstreamURL, cfg.TypeSafeEndpoint, cfg.LayaEndpoint)
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("Server listen failed: %v", err)
		}
	}()

	<-stop
	log.Println("Shutting down llm-decision-router gracefully...")
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := server.Shutdown(ctx); err != nil {
		log.Printf("Server shutdown error: %v", err)
	}
	log.Println("llm-decision-router stopped")
}
