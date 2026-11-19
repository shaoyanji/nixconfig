// fleet-sentinel-ingest receives the status a peer host pushes.
//
// It exists because the collector is local: a host whose sentinel dies simply
// stops appearing, and absence reads the same as never having been there. One
// receiver turns that silence into a file whose mtime the central collector can
// age. Transport is a UNIX socket behind the existing vhost — no port is opened
// — and the bearer comes from a file so a sops secret is never in the store.
package main

import (
	"crypto/subtle"
	"encoding/json"
	"flag"
	"io"
	"log"
	"net"
	"net/http"
	"os"
	"os/user"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"time"
)

// A status event is a few kilobytes; anything past this is not a status.
const maxBody = 64 << 10

// The file name is derived from the host, so the host has to be a safe name.
var hostRE = regexp.MustCompile(`^[a-z0-9][a-z0-9-]{0,62}$`)

type event struct {
	Schema  *int   `json:"schema"`
	TS      string `json:"ts"`
	Host    string `json:"host"`
	State   string `json:"state"`
	Reasons []any  `json:"reasons"`
}

type ingest struct {
	tokenFile string
	incoming  string
}

func bearer(header string) string {
	const prefix = "Bearer "
	if len(header) <= len(prefix) || !strings.EqualFold(header[:len(prefix)], prefix) {
		return ""
	}
	return strings.TrimSpace(header[len(prefix):])
}

func (in *ingest) token() (string, error) {
	raw, err := os.ReadFile(in.tokenFile)
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(string(raw)), nil
}

func (in *ingest) valid(ev event) string {
	switch {
	case ev.Schema == nil || *ev.Schema != 1:
		return "schema must be 1"
	case !hostRE.MatchString(ev.Host):
		return "host is not a fleet host name"
	case ev.State != "ok" && ev.State != "degraded":
		return "state must be ok or degraded"
	case ev.TS == "":
		return "ts is missing"
	}
	if _, err := time.Parse(time.RFC3339, ev.TS); err != nil {
		return "ts is not RFC 3339"
	}
	return ""
}

func (in *ingest) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		w.Header().Set("Allow", http.MethodPost)
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	want, err := in.token()
	if err != nil || len(want) < 32 {
		// A receiver without a usable token must refuse, not accept everything.
		http.Error(w, "token unavailable", http.StatusServiceUnavailable)
		return
	}
	got := bearer(r.Header.Get("Authorization"))
	if subtle.ConstantTimeCompare([]byte(got), []byte(want)) != 1 {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	body, err := io.ReadAll(io.LimitReader(r.Body, maxBody+1))
	if err != nil {
		http.Error(w, "could not read the body", http.StatusBadRequest)
		return
	}
	if len(body) > maxBody {
		http.Error(w, "body too large", http.StatusRequestEntityTooLarge)
		return
	}

	var ev event
	if err := json.Unmarshal(body, &ev); err != nil {
		http.Error(w, "body is not JSON", http.StatusBadRequest)
		return
	}
	if why := in.valid(ev); why != "" {
		http.Error(w, why, http.StatusBadRequest)
		return
	}

	// Write beside the target and rename: the collector reads this directory on
	// its own schedule, and a half-written file would make a healthy host look
	// like a parse failure.
	tmp, err := os.CreateTemp(in.incoming, ".push-*")
	if err != nil {
		http.Error(w, "could not stage the event", http.StatusInternalServerError)
		return
	}
	name := tmp.Name()
	if _, err := tmp.Write(body); err != nil {
		_ = tmp.Close()
		_ = os.Remove(name)
		http.Error(w, "could not write the event", http.StatusInternalServerError)
		return
	}
	if err := tmp.Close(); err != nil {
		_ = os.Remove(name)
		http.Error(w, "could not close the event", http.StatusInternalServerError)
		return
	}
	if err := os.Chmod(name, 0o644); err != nil {
		_ = os.Remove(name)
		http.Error(w, "could not set the event mode", http.StatusInternalServerError)
		return
	}
	final := filepath.Join(in.incoming, ev.Host+".json")
	if err := os.Rename(name, final); err != nil {
		_ = os.Remove(name)
		http.Error(w, "could not publish the event", http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

// listen opens the socket, removes a stale one first, and hands it to the group
// nginx runs as — the socket is the whole authentication boundary for reach.
func listen(path, group string) (net.Listener, error) {
	if err := os.Remove(path); err != nil && !os.IsNotExist(err) {
		return nil, err
	}
	ln, err := net.Listen("unix", path)
	if err != nil {
		return nil, err
	}
	if err := os.Chmod(path, 0o660); err != nil {
		_ = ln.Close()
		return nil, err
	}
	if group != "" {
		g, err := user.LookupGroup(group)
		if err != nil {
			_ = ln.Close()
			return nil, err
		}
		gid, err := strconv.Atoi(g.Gid)
		if err != nil {
			_ = ln.Close()
			return nil, err
		}
		if err := os.Chown(path, -1, gid); err != nil {
			_ = ln.Close()
			return nil, err
		}
	}
	return ln, nil
}

func main() {
	socket := flag.String("socket", "", "UNIX socket to listen on")
	incoming := flag.String("incoming", "", "directory that receives <host>.json")
	tokenFile := flag.String("token-file", "", "file holding the bearer token")
	socketGroup := flag.String("socket-group", "nginx", "group allowed to connect")
	flag.Parse()

	if *socket == "" || *incoming == "" || *tokenFile == "" {
		log.Fatal("fleet-sentinel-ingest: -socket, -incoming and -token-file are required")
	}
	if err := os.MkdirAll(*incoming, 0o755); err != nil {
		log.Fatalf("fleet-sentinel-ingest: %v", err)
	}

	ln, err := listen(*socket, *socketGroup)
	if err != nil {
		log.Fatalf("fleet-sentinel-ingest: %v", err)
	}

	srv := &http.Server{
		Handler:           &ingest{tokenFile: *tokenFile, incoming: *incoming},
		ReadHeaderTimeout: 5 * time.Second,
	}
	log.Printf("fleet-sentinel-ingest: listening on %s", *socket)
	log.Fatal(srv.Serve(ln))
}
