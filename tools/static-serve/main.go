// Command static-serve serves a directory over HTTP.
//
// It replaces `python3 -m http.server` in the preview commands. Go's
// http.FileServer answers Range, HEAD and conditional requests, so a <video>
// master can be seeked; Python's http.server ignores Range and every scrub
// re-downloads the file from byte zero.
//
// Stdlib only. An ephemeral port is legitimate (`-addr 127.0.0.1:0`): the
// bound address is printed before serving, so a caller polls one line instead
// of probing for a free port and racing every other process to it.
package main

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"log"
	"mime"
	"net"
	"net/http"
	"os"
	"os/signal"
	"path/filepath"
	"syscall"
	"time"
)

// Media and text types a preview panel needs but a bare host may not carry in
// /etc/mime.types. Without these a .mp4 arrives as application/octet-stream and
// the browser refuses to play it even though the Range response is correct.
var extraTypes = map[string]string{
	".avif":  "image/avif",
	".m4a":   "audio/mp4",
	".md":    "text/plain; charset=utf-8",
	".mp3":   "audio/mpeg",
	".mp4":   "video/mp4",
	".ogg":   "audio/ogg",
	".opus":  "audio/ogg",
	".toml":  "text/plain; charset=utf-8",
	".webm":  "video/webm",
	".woff":  "font/woff",
	".woff2": "font/woff2",
	".yaml":  "text/plain; charset=utf-8",
	".yml":   "text/plain; charset=utf-8",
}

type statusWriter struct {
	http.ResponseWriter
	status int
	bytes  int64
}

func (w *statusWriter) WriteHeader(code int) {
	w.status = code
	w.ResponseWriter.WriteHeader(code)
}

func (w *statusWriter) Write(p []byte) (int, error) {
	if w.status == 0 {
		w.status = http.StatusOK
	}
	n, err := w.ResponseWriter.Write(p)
	w.bytes += int64(n)
	return n, err
}

func logRequests(next http.Handler, quiet bool) http.Handler {
	if quiet {
		return next
	}
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		sw := &statusWriter{ResponseWriter: w}
		next.ServeHTTP(sw, r)
		if sw.status == 0 {
			sw.status = http.StatusOK
		}
		log.Printf("%s %s %d %d B %.1fms", r.Method, r.URL.Path, sw.status, sw.bytes, float64(time.Since(start).Microseconds())/1000.0)
	})
}

func newHandler(root string, quiet bool) http.Handler {
	return logRequests(http.FileServer(http.Dir(root)), quiet)
}

func main() {
	dir := flag.String("dir", ".", "directory to serve")
	addr := flag.String("addr", "127.0.0.1:8000", "host:port to bind; port 0 picks a free port")
	quiet := flag.Bool("quiet", false, "do not log requests")
	flag.Parse()

	root, err := filepath.Abs(*dir)
	if err != nil {
		log.Fatalf("static-serve: %v", err)
	}
	info, err := os.Stat(root)
	if err != nil {
		log.Fatalf("static-serve: %v", err)
	}
	if !info.IsDir() {
		log.Fatalf("static-serve: %s is not a directory", root)
	}

	for ext, typ := range extraTypes {
		if err := mime.AddExtensionType(ext, typ); err != nil {
			log.Fatalf("static-serve: mime %s: %v", ext, err)
		}
	}

	ln, err := net.Listen("tcp", *addr)
	if err != nil {
		log.Fatalf("static-serve: %v", err)
	}

	// The caller parses this line: it is the only place the bound port is known
	// when -addr asked for 0.
	fmt.Fprintf(os.Stderr, "static-serve listening on http://%s (root %s)\n", ln.Addr().String(), root)

	srv := &http.Server{
		Handler:           newHandler(root, *quiet),
		ReadHeaderTimeout: 10 * time.Second,
	}

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	done := make(chan error, 1)
	go func() { done <- srv.Serve(ln) }()

	select {
	case err := <-done:
		if !errors.Is(err, http.ErrServerClosed) {
			log.Fatalf("static-serve: %v", err)
		}
	case <-ctx.Done():
		shutdownCtx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
		defer cancel()
		if err := srv.Shutdown(shutdownCtx); err != nil {
			log.Printf("static-serve: shutdown: %v", err)
		}
	}
}
