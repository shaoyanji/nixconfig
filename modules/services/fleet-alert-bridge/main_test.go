package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"net"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

// stubSimpleX is the smallest server that behaves like the SimpleX WebSocket
// API for this bridge: accept the handshake, read one text frame, answer with
// a text frame, and report the command it received.
func stubSimpleX(t *testing.T, received chan<- string) *httptest.Server {
	t.Helper()
	srv := httptest.NewUnstartedServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if !strings.EqualFold(r.Header.Get("Upgrade"), "websocket") {
			http.Error(w, "not a websocket", http.StatusBadRequest)
			return
		}
		conn, brw, err := w.(http.Hijacker).Hijack()
		if err != nil {
			t.Errorf("hijack: %v", err)
			return
		}
		defer conn.Close()

		key := r.Header.Get("Sec-WebSocket-Key")
		fmt.Fprintf(conn, "HTTP/1.1 101 Switching Protocols\r\n"+
			"Upgrade: websocket\r\nConnection: Upgrade\r\n"+
			"Sec-WebSocket-Accept: %s\r\n\r\n", acceptKey(key))

		opcode, _, payload, err := readFrame(brw.Reader)
		if err != nil {
			t.Errorf("read client frame: %v", err)
			return
		}
		if opcode != opText {
			t.Errorf("opcode = %#x, want text", opcode)
			return
		}
		received <- string(payload)
		if err := writeFrame(conn, opText, []byte(`{"corrId":"x"}`), false); err != nil {
			t.Errorf("reply: %v", err)
		}
	}))
	srv.Listener = mustListen(t)
	srv.Start()
	return srv
}

func mustListen(t *testing.T) net.Listener {
	t.Helper()
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("listen: %v", err)
	}
	return ln
}

func TestAlertReachesSimpleX(t *testing.T) {
	received := make(chan string, 1)
	stub := stubSimpleX(t, received)
	defer stub.Close()

	b := &bridge{wsURL: "ws" + strings.TrimPrefix(stub.URL, "http")}
	mux := http.NewServeMux()
	mux.HandleFunc("/alert", b.handleAlert)
	alertSrv := httptest.NewServer(mux)
	defer alertSrv.Close()

	body := `{"endpoint":"gatus","group":"fleet","description":"3 consecutive failures"}`
	resp, err := http.Post(alertSrv.URL+"/alert", "application/json", strings.NewReader(body))
	if err != nil {
		t.Fatalf("post: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("status = %d, want 200", resp.StatusCode)
	}

	select {
	case frame := <-received:
		var req struct {
			CorrID string `json:"corrId"`
			Cmd    string `json:"cmd"`
		}
		if err := json.Unmarshal([]byte(frame), &req); err != nil {
			t.Fatalf("frame is not JSON: %v (%q)", err, frame)
		}
		want := "#Fleet 🚨 [Fleet Alert] gatus (fleet): 3 consecutive failures"
		if req.Cmd != want {
			t.Errorf("cmd = %q, want %q", req.Cmd, want)
		}
		if len(req.CorrID) != 8 {
			t.Errorf("corrId = %q, want 8 hex chars", req.CorrID)
		}
	case <-time.After(5 * time.Second):
		t.Fatal("SimpleX stub never received the command")
	}
}

func TestDeliveryFailureIsNotOK(t *testing.T) {
	// Nothing is listening here: the bridge must not tell gatus the alert landed.
	ln := mustListen(t)
	addr := ln.Addr().String()
	ln.Close()

	b := &bridge{wsURL: "ws://" + addr}
	mux := http.NewServeMux()
	mux.HandleFunc("/alert", b.handleAlert)
	alertSrv := httptest.NewServer(mux)
	defer alertSrv.Close()

	resp, err := http.Post(alertSrv.URL+"/alert", "application/json",
		strings.NewReader(`{"endpoint":"gatus"}`))
	if err != nil {
		t.Fatalf("post: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusBadGateway {
		t.Fatalf("status = %d, want 502", resp.StatusCode)
	}
}

func TestRejectsGET(t *testing.T) {
	b := &bridge{wsURL: "ws://127.0.0.1:1"}
	mux := http.NewServeMux()
	mux.HandleFunc("/alert", b.handleAlert)
	alertSrv := httptest.NewServer(mux)
	defer alertSrv.Close()

	resp, err := http.Get(alertSrv.URL + "/alert")
	if err != nil {
		t.Fatalf("get: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusMethodNotAllowed {
		t.Fatalf("status = %d, want 405", resp.StatusCode)
	}
}

func TestFrameRoundTrip(t *testing.T) {
	// A masked client frame read back through the same parser, including the
	// 16-bit length form.
	for _, size := range []int{0, 5, 125, 126, 4096} {
		payload := make([]byte, size)
		for i := range payload {
			payload[i] = byte(i)
		}
		var buf strings.Builder
		rec := &writerFunc{w: &buf}
		if err := writeFrame(rec, opText, payload, true); err != nil {
			t.Fatalf("size %d: write: %v", size, err)
		}
		opcode, fin, got, err := readFrame(bufio.NewReader(strings.NewReader(buf.String())))
		if err != nil {
			t.Fatalf("size %d: read: %v", size, err)
		}
		if !fin || opcode != opText {
			t.Errorf("size %d: fin=%v opcode=%#x", size, fin, opcode)
		}
		if string(got) != string(payload) {
			t.Errorf("size %d: payload mismatch", size)
		}
	}
}

type writerFunc struct{ w *strings.Builder }

func (f *writerFunc) Write(p []byte) (int, error) { return f.w.Write(p) }
