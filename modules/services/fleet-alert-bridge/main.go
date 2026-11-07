// fleet-alert-bridge: gatus custom alert -> SimpleX `#Fleet` message.
//
//	gatus POST /alert {"endpoint": ..., "group": ..., "description": ...}
//	  -> ws://127.0.0.1:5225  {"corrId": ..., "cmd": "#Fleet ..."}
//
// The whole surface is one route and one WebSocket client. Go's stdlib has the
// HTTP half; the WebSocket client is ~120 lines of RFC 6455 below so the binary
// needs no module at all (the Python it replaces needed `websockets`).
//
// `/alert` answers 200 only when the message reached SimpleX: a bridge that says
// OK while the alert sat in a failed socket is the failure this endpoint exists
// to report. A malformed body is 400, a delivery failure is 502.
package main

import (
	"bufio"
	"context"
	"crypto/rand"
	"crypto/sha1"
	"encoding/base64"
	"encoding/binary"
	"encoding/hex"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"net/url"
	"os/signal"
	"strconv"
	"sync"
	"syscall"
	"time"
)

const (
	maxBody             = 1 << 20 // gatus bodies are a few hundred bytes
	maxFrame            = 1 << 20
	wsGUID              = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
	deliveryTTL         = 5 * time.Second
	opContinuation byte = 0x0
	opText         byte = 0x1
	opBinary       byte = 0x2
	opClose        byte = 0x8
	opPing         byte = 0x9
	opPong         byte = 0xA
)

var (
	errClosedByPeer  = errors.New("closed by peer")
	errFrameTooLarge = errors.New("websocket frame too large")
)

// bridge serialises deliveries: the Python bridge was single-threaded, and one
// SimpleX client at a time keeps the corrId reply unambiguous.
type bridge struct {
	wsURL string
	mu    sync.Mutex
}

type alert struct {
	Endpoint    string `json:"endpoint"`
	Group       string `json:"group"`
	Description string `json:"description"`
}

func main() {
	addr := flag.String("addr", "127.0.0.1", "address to bind")
	port := flag.Int("port", 5226, "port to bind")
	simplex := flag.String("simplex", "ws://127.0.0.1:5225", "SimpleX WebSocket API URL")
	flag.Parse()

	b := &bridge{wsURL: *simplex}

	mux := http.NewServeMux()
	mux.HandleFunc("/alert", b.handleAlert)

	srv := &http.Server{
		Addr:              net.JoinHostPort(*addr, strconv.Itoa(*port)),
		Handler:           mux,
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       10 * time.Second,
		WriteTimeout:      deliveryTTL + 5*time.Second,
		IdleTimeout:       30 * time.Second,
	}

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	go func() {
		<-ctx.Done()
		shutdown, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		_ = srv.Shutdown(shutdown)
	}()

	log.Printf("fleet-alert-bridge: listening on %s, delivering to %s", srv.Addr, b.wsURL)
	if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
		log.Fatalf("fleet-alert-bridge: %v", err)
	}
}

func (b *bridge) handleAlert(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		w.Header().Set("Allow", http.MethodPost)
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	body, err := io.ReadAll(io.LimitReader(r.Body, maxBody))
	if err != nil {
		http.Error(w, "unreadable body", http.StatusBadRequest)
		return
	}

	var a alert
	if err := json.Unmarshal(body, &a); err != nil {
		log.Printf("fleet-alert-bridge: malformed alert: %v", err)
		http.Error(w, "malformed alert", http.StatusBadRequest)
		return
	}
	if a.Endpoint == "" {
		a.Endpoint = "Unknown Service"
	}
	if a.Group == "" {
		a.Group = "fleet"
	}
	if a.Description == "" {
		a.Description = "Failure"
	}

	msg := fmt.Sprintf("🚨 [Fleet Alert] %s (%s): %s", a.Endpoint, a.Group, a.Description)
	if err := b.deliver(msg); err != nil {
		log.Printf("fleet-alert-bridge: delivery failed for %q: %v", a.Endpoint, err)
		http.Error(w, "delivery failed", http.StatusBadGateway)
		return
	}

	w.WriteHeader(http.StatusOK)
	fmt.Fprintln(w, "OK")
}

func (b *bridge) deliver(message string) error {
	b.mu.Lock()
	defer b.mu.Unlock()

	ctx, cancel := context.WithTimeout(context.Background(), deliveryTTL)
	defer cancel()

	conn, br, err := dialWS(ctx, b.wsURL)
	if err != nil {
		return err
	}
	defer conn.Close()
	if deadline, ok := ctx.Deadline(); ok {
		_ = conn.SetDeadline(deadline)
	}

	payload, err := json.Marshal(map[string]string{
		"corrId": corrID(),
		"cmd":    "#Fleet " + message,
	})
	if err != nil {
		return err
	}
	if err := writeFrame(conn, opText, payload, true); err != nil {
		return err
	}
	// One reply is the acknowledgement; the Python bridge ignored its content.
	_, err = readMessage(br, conn)
	return err
}

func corrID() string {
	var b [4]byte
	if _, err := rand.Read(b[:]); err != nil {
		return "00000000"
	}
	return hex.EncodeToString(b[:])
}

// --- RFC 6455, client side only -------------------------------------------

func dialWS(ctx context.Context, raw string) (net.Conn, *bufio.Reader, error) {
	u, err := url.Parse(raw)
	if err != nil {
		return nil, nil, err
	}
	if u.Scheme != "ws" {
		return nil, nil, fmt.Errorf("unsupported websocket scheme %q", u.Scheme)
	}
	hostport := u.Host
	if u.Port() == "" {
		hostport = net.JoinHostPort(u.Hostname(), "80")
	}

	var d net.Dialer
	conn, err := d.DialContext(ctx, "tcp", hostport)
	if err != nil {
		return nil, nil, err
	}

	var nonce [16]byte
	if _, err := rand.Read(nonce[:]); err != nil {
		conn.Close()
		return nil, nil, err
	}
	key := base64.StdEncoding.EncodeToString(nonce[:])
	path := u.RequestURI()
	if path == "" {
		path = "/"
	}

	handshake := "GET " + path + " HTTP/1.1\r\n" +
		"Host: " + u.Host + "\r\n" +
		"Upgrade: websocket\r\n" +
		"Connection: Upgrade\r\n" +
		"Sec-WebSocket-Key: " + key + "\r\n" +
		"Sec-WebSocket-Version: 13\r\n\r\n"
	if _, err := io.WriteString(conn, handshake); err != nil {
		conn.Close()
		return nil, nil, err
	}

	br := bufio.NewReader(conn)
	resp, err := http.ReadResponse(br, nil)
	if err != nil {
		conn.Close()
		return nil, nil, err
	}
	if resp.StatusCode != http.StatusSwitchingProtocols {
		conn.Close()
		return nil, nil, fmt.Errorf("websocket handshake: %s", resp.Status)
	}
	if got, want := resp.Header.Get("Sec-WebSocket-Accept"), acceptKey(key); got != want {
		conn.Close()
		return nil, nil, fmt.Errorf("websocket handshake: bad accept key")
	}
	return conn, br, nil
}

func acceptKey(key string) string {
	sum := sha1.Sum([]byte(key + wsGUID))
	return base64.StdEncoding.EncodeToString(sum[:])
}

func writeFrame(w io.Writer, opcode byte, payload []byte, masked bool) error {
	header := make([]byte, 0, 14)
	header = append(header, 0x80|opcode) // FIN, no fragmentation on send

	// The mask bit lives in the byte that carries the 7-bit length, not in the
	// extended length bytes.
	var maskBit byte
	if masked {
		maskBit = 0x80
	}

	n := len(payload)
	switch {
	case n < 126:
		header = append(header, maskBit|byte(n))
	case n <= 0xFFFF:
		header = append(header, maskBit|126, byte(n>>8), byte(n))
	default:
		header = append(header, maskBit|127)
		var ext [8]byte
		binary.BigEndian.PutUint64(ext[:], uint64(n))
		header = append(header, ext[:]...)
	}

	body := payload
	if masked {
		var mask [4]byte
		if _, err := rand.Read(mask[:]); err != nil {
			return err
		}
		header = append(header, mask[:]...)
		body = make([]byte, n)
		for i, c := range payload {
			body[i] = c ^ mask[i%4]
		}
	}

	if _, err := w.Write(header); err != nil {
		return err
	}
	_, err := w.Write(body)
	return err
}

// readMessage returns the next data frame, answering pings on the way.
func readMessage(r *bufio.Reader, w io.Writer) ([]byte, error) {
	var message []byte
	for {
		opcode, fin, data, err := readFrame(r)
		if err != nil {
			return nil, err
		}
		switch opcode {
		case opPing:
			if err := writeFrame(w, opPong, data, true); err != nil {
				return nil, err
			}
		case opPong:
			continue
		case opClose:
			return nil, errClosedByPeer
		case opText, opBinary, opContinuation:
			message = append(message, data...)
			if fin {
				return message, nil
			}
		default:
			return nil, fmt.Errorf("websocket: unsupported opcode %#x", opcode)
		}
	}
}

func readFrame(r *bufio.Reader) (opcode byte, fin bool, payload []byte, err error) {
	var head [2]byte
	if _, err = io.ReadFull(r, head[:]); err != nil {
		return 0, false, nil, err
	}
	fin = head[0]&0x80 != 0
	opcode = head[0] & 0x0f
	masked := head[1]&0x80 != 0

	n := int64(head[1] & 0x7f)
	switch n {
	case 126:
		var ext [2]byte
		if _, err = io.ReadFull(r, ext[:]); err != nil {
			return 0, false, nil, err
		}
		n = int64(binary.BigEndian.Uint16(ext[:]))
	case 127:
		var ext [8]byte
		if _, err = io.ReadFull(r, ext[:]); err != nil {
			return 0, false, nil, err
		}
		wide := binary.BigEndian.Uint64(ext[:])
		if wide > maxFrame {
			return 0, false, nil, errFrameTooLarge
		}
		n = int64(wide)
	}
	if n < 0 || n > maxFrame {
		return 0, false, nil, errFrameTooLarge
	}

	var mask [4]byte
	if masked {
		if _, err = io.ReadFull(r, mask[:]); err != nil {
			return 0, false, nil, err
		}
	}
	payload = make([]byte, n)
	if _, err = io.ReadFull(r, payload); err != nil {
		return 0, false, nil, err
	}
	if masked {
		for i := range payload {
			payload[i] ^= mask[i%4]
		}
	}
	return opcode, fin, payload, nil
}
