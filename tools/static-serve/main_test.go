package main

import (
	"bytes"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

const body = "0123456789abcdef"

func serve(t *testing.T) *httptest.Server {
	t.Helper()
	root := t.TempDir()
	if err := os.WriteFile(filepath.Join(root, "clip.mp4"), []byte(body), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(filepath.Join(root, "sub"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(root, "sub", "index.html"), []byte("<h1>sub</h1>"), 0o644); err != nil {
		t.Fatal(err)
	}
	srv := httptest.NewServer(newHandler(root, true))
	t.Cleanup(srv.Close)
	return srv
}

func TestRangeServesPartialContent(t *testing.T) {
	srv := serve(t)
	req, err := http.NewRequest(http.MethodGet, srv.URL+"/clip.mp4", nil)
	if err != nil {
		t.Fatal(err)
	}
	req.Header.Set("Range", "bytes=4-9")
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusPartialContent {
		t.Fatalf("status = %d, want 206", resp.StatusCode)
	}
	if got, want := resp.Header.Get("Content-Range"), "bytes 4-9/16"; got != want {
		t.Errorf("Content-Range = %q, want %q", got, want)
	}
	got, err := io.ReadAll(resp.Body)
	if err != nil {
		t.Fatal(err)
	}
	if string(got) != body[4:10] {
		t.Errorf("body = %q, want %q", got, body[4:10])
	}
}

func TestSuffixRange(t *testing.T) {
	srv := serve(t)
	req, _ := http.NewRequest(http.MethodGet, srv.URL+"/clip.mp4", nil)
	req.Header.Set("Range", "bytes=-4")
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()

	got, _ := io.ReadAll(resp.Body)
	if resp.StatusCode != http.StatusPartialContent || string(got) != body[12:] {
		t.Fatalf("status = %d body = %q, want 206 and %q", resp.StatusCode, got, body[12:])
	}
}

func TestUnsatisfiableRange(t *testing.T) {
	srv := serve(t)
	req, _ := http.NewRequest(http.MethodGet, srv.URL+"/clip.mp4", nil)
	req.Header.Set("Range", "bytes=99-120")
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusRequestedRangeNotSatisfiable {
		t.Fatalf("status = %d, want 416", resp.StatusCode)
	}
}

func TestFullGetIsByteExact(t *testing.T) {
	srv := serve(t)
	resp, err := http.Get(srv.URL + "/clip.mp4")
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()
	got, _ := io.ReadAll(resp.Body)
	if resp.StatusCode != http.StatusOK || !bytes.Equal(got, []byte(body)) {
		t.Fatalf("status = %d body = %q", resp.StatusCode, got)
	}
	if ct := resp.Header.Get("Content-Type"); ct != "video/mp4" {
		t.Errorf("Content-Type = %q, want video/mp4", ct)
	}
}

func TestHeadHasNoBody(t *testing.T) {
	srv := serve(t)
	resp, err := http.Head(srv.URL + "/clip.mp4")
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()
	got, _ := io.ReadAll(resp.Body)
	if resp.StatusCode != http.StatusOK || len(got) != 0 {
		t.Fatalf("status = %d body length = %d, want 200 and 0", resp.StatusCode, len(got))
	}
}

func TestDirectoryRedirectsToIndex(t *testing.T) {
	srv := serve(t)
	client := &http.Client{CheckRedirect: func(*http.Request, []*http.Request) error {
		return http.ErrUseLastResponse
	}}
	resp, err := client.Get(srv.URL + "/sub")
	if err != nil {
		t.Fatal(err)
	}
	resp.Body.Close()
	if resp.StatusCode != http.StatusMovedPermanently {
		t.Fatalf("status = %d, want 301", resp.StatusCode)
	}
	// Go emits the relative form; browsers resolve both.
	if loc := resp.Header.Get("Location"); loc != "sub/" {
		t.Fatalf("Location = %q, want sub/", loc)
	}
}

func TestMissingIsNotFound(t *testing.T) {
	srv := serve(t)
	resp, err := http.Get(srv.URL + "/nope.txt")
	if err != nil {
		t.Fatal(err)
	}
	resp.Body.Close()
	if resp.StatusCode != http.StatusNotFound {
		t.Fatalf("status = %d, want 404", resp.StatusCode)
	}
}

func TestTraversalStaysInsideRoot(t *testing.T) {
	srv := serve(t)
	resp, err := http.Get(srv.URL + "/../../../../etc/passwd")
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()
	got, _ := io.ReadAll(resp.Body)
	if strings.Contains(string(got), "root:") {
		t.Fatal("served a file outside the root")
	}
}
