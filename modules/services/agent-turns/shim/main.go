// agent-turns-shim: the only network surface in front of the local xs store.
//
// xs itself has no authentication and does have DELETE and POST /import, so the
// append-only promise cannot be made by the store: it is made here, by exposing
// exactly two routes and answering 405 to every other method.
//
//	POST /v1/events   append one agent turn       -> 201 {"id": <frame id>}
//	GET  /v1/events   query recent turns          -> 200 {"count": n, "events": [...]}
//	GET  /healthz     liveness, no auth           -> 200 {"ok": true}
//
// Everything else is 404 (unknown path) or 405 (update/delete). The store is
// reached over its Unix socket only; this process never speaks TCP to xs.
//
// One token per holder, never one shared token: a revoked agent must not take the
// fleet's credential with it. AGENT_TURNS_TOKENS is `name=/path` pairs, colon
// separated, and the access log names the token that authenticated.
package main

import (
	"bytes"
	"context"
	"crypto/subtle"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"strings"
	"syscall"
	"time"
)

const topic = "agent.turns"

type shim struct {
	store  *xsStore
	dedup  *dedup
	tokens map[string]string
	writes chan struct{} // one append at a time, like the Python shim's lock
}

func main() {
	socket := os.Getenv("XS_SOCKET")
	if socket == "" {
		fatal("xs socket not found at %q", socket)
	}
	if _, err := os.Stat(socket); err != nil {
		fatal("xs socket not found at %q", socket)
	}
	dbPath := os.Getenv("AGENT_TURNS_DB")
	if dbPath == "" {
		fatal("AGENT_TURNS_DB is not set")
	}
	tokens := loadTokens(os.Getenv("AGENT_TURNS_TOKENS"), os.Getenv("AGENT_TURNS_TOKEN_FILE"))
	store, err := openDedup(dbPath)
	if err != nil {
		fatal("opening the dedup store %s: %v", dbPath, err)
	}

	host := os.Getenv("AGENT_TURNS_BIND")
	if host == "" {
		host = "127.0.0.1"
	}
	port := 8093
	if raw := os.Getenv("AGENT_TURNS_PORT"); raw != "" {
		n, err := strconv.Atoi(raw)
		if err != nil || n <= 0 || n > 65535 {
			fatal("AGENT_TURNS_PORT is not a port: %q", raw)
		}
		port = n
	}

	s := &shim{
		store:  newXSStore(socket),
		dedup:  store,
		tokens: tokens,
		writes: make(chan struct{}, 1),
	}

	srv := &http.Server{
		Addr:              net.JoinHostPort(host, strconv.Itoa(port)),
		Handler:           s.routes(),
		ReadHeaderTimeout: 10 * time.Second,
	}

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGTERM, syscall.SIGINT)
	defer stop()
	go func() {
		<-ctx.Done()
		shutdown, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		srv.Shutdown(shutdown)
	}()

	log.Printf("agent-turns shim listening on %s, store socket %s", srv.Addr, socket)
	if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
		fatal("serving: %v", err)
	}
}

func fatal(format string, args ...any) {
	fmt.Fprintf(os.Stderr, "agent-turns shim: "+format+"\n", args...)
	os.Exit(1)
}

// loadTokens reads `name=/path` pairs, plus the single-token variable an older
// `agents:xs:post` used.
func loadTokens(spec, legacy string) map[string]string {
	var items []string
	if spec != "" {
		items = append(items, strings.Split(spec, ":")...)
	}
	if legacy != "" {
		items = append(items, legacy)
	}
	tokens := map[string]string{}
	for _, item := range items {
		item = strings.TrimSpace(item)
		if item == "" {
			continue
		}
		name, path, ok := strings.Cut(item, "=")
		if !ok {
			path = item
			name = path[strings.LastIndex(path, "/")+1:]
		}
		raw, err := os.ReadFile(path)
		if err != nil {
			fatal("cannot read token file %s: %v", path, err)
		}
		value := strings.TrimSpace(string(raw))
		if len(value) < 32 {
			fatal("token in %s is empty or too short; refusing to start", path)
		}
		tokens[name] = value
	}
	if len(tokens) == 0 {
		fatal("no tokens configured (AGENT_TURNS_TOKENS); refusing to start")
	}
	return tokens
}

func (s *shim) routes() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, _ *http.Request) {
		writeJSON(w, http.StatusOK, map[string]any{"ok": true}, nil)
	})
	mux.HandleFunc("GET /v1/events", s.getEvents)
	mux.HandleFunc("POST /v1/events", s.postEvent)
	// Registered for every other method and every path: xs has DELETE, so the
	// refusal has to be the shim's, not the store's.
	mux.HandleFunc("PUT /", s.readonly)
	mux.HandleFunc("PATCH /", s.readonly)
	mux.HandleFunc("DELETE /", s.readonly)
	mux.HandleFunc("/", func(w http.ResponseWriter, _ *http.Request) {
		writeJSON(w, http.StatusNotFound, map[string]any{"error": "not found"}, nil)
	})
	return logRequests(mux)
}

func (s *shim) readonly(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusMethodNotAllowed,
		map[string]any{"error": "this endpoint is append-only"},
		map[string]string{"Allow": "GET, POST"})
}

// authenticate checks the bearer token against every holder without an early
// exit: a constant-time miss on each slot does not leak which one matched, which
// matters once more than one holder exists.
func (s *shim) authenticate(r *http.Request) (string, error) {
	header := r.Header.Get("Authorization")
	if !strings.HasPrefix(header, "Bearer ") {
		return "", errors.New("missing bearer token")
	}
	presented := strings.TrimSpace(strings.TrimPrefix(header, "Bearer "))
	matched := ""
	for name, token := range s.tokens {
		if subtle.ConstantTimeCompare([]byte(presented), []byte(token)) == 1 {
			matched = name
		}
	}
	if matched == "" {
		return "", errors.New("bad bearer token")
	}
	return matched, nil
}

func (s *shim) getEvents(w http.ResponseWriter, r *http.Request) {
	if _, err := s.authenticate(r); err != nil {
		writeJSON(w, http.StatusUnauthorized, map[string]any{"error": err.Error()}, nil)
		return
	}

	query := r.URL.Query()
	limit := defaultLimit
	if raw := query.Get("limit"); raw != "" {
		n, err := strconv.Atoi(strings.TrimSpace(raw))
		if err != nil {
			writeJSON(w, http.StatusBadRequest, map[string]any{"error": "limit must be an integer"}, nil)
			return
		}
		limit = n
	}
	if limit < 1 {
		limit = 1
	}
	if limit > maxLimit {
		limit = maxLimit
	}
	wantSubject := query.Get("subject")
	wantRepo := query.Get("repo")
	wantSource := query.Get("source")

	filtered := wantSubject != "" || wantRepo != "" || wantSource != ""
	// Unfiltered stays one page; filtered scans the log so an old subject is
	// found. `truncated` is the honest answer when the scan hit its cap.
	scan := limit
	if filtered {
		scan = maxScan
	}
	frames, err := s.store.last(topic, scan)
	if err != nil {
		writeJSON(w, http.StatusBadGateway, map[string]any{"error": "store unavailable: " + err.Error()}, nil)
		return
	}

	events := make([]map[string]any, 0, len(frames))
	for _, f := range frames {
		if f.Hash == nil {
			continue
		}
		entry, err := s.store.content(*f.Hash)
		if err != nil || entry == nil {
			continue
		}
		if wantSubject != "" && text(entry["subject"]) != wantSubject {
			continue
		}
		if wantRepo != "" && subjectRepo(text(entry["subject"])) != wantRepo {
			continue
		}
		if wantSource != "" && text(entry["source"]) != wantSource {
			continue
		}
		entry["_frame"] = f.ID
		events = append(events, entry)
	}

	// The store answers oldest first; the contract is newest first, and `limit`
	// is the newest of the matches, not the first page of them.
	for i, j := 0, len(events)-1; i < j; i, j = i+1, j-1 {
		events[i], events[j] = events[j], events[i]
	}
	matches := len(events)
	if len(events) > limit {
		events = events[:limit]
	}

	writeJSON(w, http.StatusOK, map[string]any{
		"count":     matches,
		"scanned":   len(frames),
		"truncated": filtered && len(frames) >= maxScan,
		"events":    events,
	}, nil)
}

func (s *shim) postEvent(w http.ResponseWriter, r *http.Request) {
	tokenName, err := s.authenticate(r)
	if err != nil {
		writeJSON(w, http.StatusUnauthorized, map[string]any{"error": err.Error()}, nil)
		return
	}

	raw, err := readBody(r)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]any{"error": err.Error()}, nil)
		return
	}
	entry, err := decodeEntry(raw)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]any{"error": err.Error()}, nil)
		return
	}
	if err := validate(entry); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]any{"error": err.Error()}, nil)
		return
	}

	clientUUID := text(entry["id"])
	payload, err := canonical(entry)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]any{"error": "malformed JSON"}, nil)
		return
	}

	s.writes <- struct{}{}
	defer func() { <-s.writes }()

	if frameID, found, err := s.dedup.lookup(clientUUID); err != nil {
		writeJSON(w, http.StatusBadGateway, map[string]any{"error": "append failed: " + err.Error()}, nil)
		return
	} else if found {
		// Logged separately from a real append, so a replay does not read like a
		// second turn when an operator counts the log.
		log.Printf("dedup token=%s client=%s frame=%s", tokenName, clientUUID, frameID)
		writeJSON(w, http.StatusOK, map[string]any{
			"id": frameID, "client_uuid": clientUUID, "duplicate": true,
		}, nil)
		return
	}

	if err := s.dedup.reserve(clientUUID); err != nil {
		writeJSON(w, http.StatusBadGateway, map[string]any{"error": "append failed: " + err.Error()}, nil)
		return
	}
	frameID, err := s.store.append(topic, payload)
	if err != nil {
		// The placeholder must not outlive a failed append, or the retry would
		// answer 200 for a turn that was never stored.
		if forgetErr := s.dedup.forget(clientUUID); forgetErr != nil {
			log.Printf("append token=%s client=%s rollback failed: %v", tokenName, clientUUID, forgetErr)
		}
		writeJSON(w, http.StatusBadGateway, map[string]any{"error": "append failed: " + err.Error()}, nil)
		return
	}
	if err := s.dedup.fill(clientUUID, frameID); err != nil {
		log.Printf("append token=%s client=%s fill failed: %v", tokenName, clientUUID, err)
		writeJSON(w, http.StatusBadGateway, map[string]any{"error": "append failed: " + err.Error()}, nil)
		return
	}

	log.Printf("append token=%s source=%s client=%s", tokenName, entry["source"], clientUUID)
	writeJSON(w, http.StatusCreated, map[string]any{
		"id": frameID, "client_uuid": clientUUID, "duplicate": false,
	}, nil)
}

func readBody(r *http.Request) ([]byte, error) {
	if r.ContentLength <= 0 {
		return nil, errors.New("empty body")
	}
	if r.ContentLength > maxBody {
		return nil, fmt.Errorf("body larger than %d bytes", maxBody)
	}
	body, err := io.ReadAll(io.LimitReader(r.Body, maxBody))
	if err != nil {
		return nil, errors.New("bad Content-Length")
	}
	if len(body) == 0 {
		return nil, errors.New("empty body")
	}
	return body, nil
}

// decodeEntry keeps numbers as their literal text and refuses anything that is
// not exactly one JSON object, because the store is append-only: a body that is
// half-valid is not a body to store and then explain.
func decodeEntry(raw []byte) (map[string]any, error) {
	decoder := json.NewDecoder(bytes.NewReader(raw))
	decoder.UseNumber()
	var entry map[string]any
	if err := decoder.Decode(&entry); err != nil || entry == nil {
		if err == nil {
			return nil, errors.New("body must be a JSON object")
		}
		return nil, errors.New("malformed JSON")
	}
	if decoder.More() {
		return nil, errors.New("malformed JSON")
	}
	return entry, nil
}

// canonical is the stored body: sorted keys, no spaces, no HTML escaping — the
// same bytes the Python shim wrote, so a frame's content reads identically
// whichever implementation appended it.
func canonical(entry map[string]any) ([]byte, error) {
	var buf bytes.Buffer
	encoder := json.NewEncoder(&buf)
	encoder.SetEscapeHTML(false)
	if err := encoder.Encode(entry); err != nil {
		return nil, err
	}
	return bytes.TrimRight(buf.Bytes(), "\n"), nil
}

func writeJSON(w http.ResponseWriter, status int, payload any, headers map[string]string) {
	var buf bytes.Buffer
	encoder := json.NewEncoder(&buf)
	encoder.SetEscapeHTML(false)
	if err := encoder.Encode(payload); err != nil {
		http.Error(w, "encoding failed", http.StatusInternalServerError)
		return
	}
	body := bytes.TrimRight(buf.Bytes(), "\n")
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Content-Length", strconv.Itoa(len(body)))
	for key, value := range headers {
		w.Header().Set(key, value)
	}
	w.WriteHeader(status)
	w.Write(body)
}

type statusRecorder struct {
	http.ResponseWriter
	status int
}

func (s *statusRecorder) WriteHeader(status int) {
	s.status = status
	s.ResponseWriter.WriteHeader(status)
}

func logRequests(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		recorder := &statusRecorder{ResponseWriter: w, status: http.StatusOK}
		next.ServeHTTP(recorder, r)
		log.Printf("%s %s %s %d", r.RemoteAddr, r.Method, r.URL.RequestURI(), recorder.status)
	})
}
