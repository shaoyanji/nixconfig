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
	"syscall"
	"time"
)

type Config struct {
	BindAddr             string
	LLMUpstreamURL       string
	TypeSafeEndpoint     string
	LayaEndpoint         string
	DefaultDecisionModel string
	FallbackToLocal      bool
}

func getEnv(key, fallback string) string {
	if val := os.Getenv(key); val != "" {
		return val
	}
	return fallback
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
		FallbackToLocal:      getEnv("FALLBACK_TO_LOCAL", "true") == "true",
	}

	llmURL, err := url.Parse(cfg.LLMUpstreamURL)
	if err != nil {
		log.Fatalf("Invalid LLM_UPSTREAM URL: %v", err)
	}

	llmProxy := httputil.NewSingleHostReverseProxy(llmURL)
	originalDirector := llmProxy.Director
	llmProxy.Director = func(req *http.Request) {
		originalDirector(req)
		req.Host = llmURL.Host
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
		llmProxy.ServeHTTP(w, r)
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
