package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"time"
)

// run is one subprocess with a deadline and its output captured. Everything the
// vault owns — export, create, publish, git — goes through here, so no handler
// grows its own timeout.
func (s *server) run(name string, args []string, dir string, timeout time.Duration) (stdout, stderr string, code int, err error) {
	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()
	cmd := exec.CommandContext(ctx, name, args...)
	cmd.Dir = dir
	if len(s.env) > 0 {
		cmd.Env = append(os.Environ(), s.env...)
	}
	var out, errBuf strings.Builder
	cmd.Stdout = &out
	cmd.Stderr = &errBuf
	err = cmd.Run()
	if ctx.Err() == context.DeadlineExceeded {
		return out.String(), errBuf.String(), -1, ctx.Err()
	}
	if exitErr, ok := err.(*exec.ExitError); ok {
		return out.String(), errBuf.String(), exitErr.ExitCode(), nil
	}
	return out.String(), errBuf.String(), 0, err
}

func (s *server) git(args ...string) (stdout string, code int, err error) {
	out, _, code, err := s.run(s.cfg.git, append([]string{"-C", s.cfg.vault}, args...), "", 60*time.Second)
	return out, code, err
}

// resolvePath mirrors Python's Path.resolve(): symlinks in the parent are
// followed, and a path that does not exist yet still resolves.
func resolvePath(p string) string {
	dir, base := filepath.Split(p)
	real, err := filepath.EvalSymlinks(dir)
	if err != nil {
		return filepath.Clean(p)
	}
	return filepath.Join(real, base)
}

// noteFile turns an id into the vault-relative path it names, and refuses
// anything outside the three note directories or outside the vault.
func (s *server) noteFile(id string) (string, string, error) {
	relative := strings.TrimSuffix(id, ".md")
	if !idRe.MatchString(relative) {
		return "", "", refuse(400, "an id is zettels/, 010 - MOCs/ or journal/ plus a name")
	}
	file := filepath.Join(s.cfg.vault, relative+".md")
	root := resolvePath(s.cfg.vault)
	resolved := resolvePath(file)
	if resolved != root && !strings.HasPrefix(resolved, root+string(filepath.Separator)) {
		return "", "", refuse(400, "that path leaves the vault")
	}
	return relative + ".md", file, nil
}

func readMeta(www string) map[string]any {
	raw, err := os.ReadFile(filepath.Join(www, "graph.json"))
	if err != nil {
		return map[string]any{}
	}
	var graph struct {
		Meta map[string]any `json:"meta"`
	}
	if err := json.Unmarshal(raw, &graph); err != nil || graph.Meta == nil {
		return map[string]any{}
	}
	return graph.Meta
}

func metaInt(meta map[string]any, key string) any {
	if value, ok := meta[key]; ok {
		return value
	}
	return 0
}

func metaString(meta map[string]any, key string) string {
	if value, ok := meta[key].(string); ok {
		return value
	}
	return ""
}

func (s *server) head() string {
	s.headMu.Lock()
	defer s.headMu.Unlock()
	if time.Since(s.headAt) > 5*time.Second {
		out, code, err := s.git("rev-parse", "--short", "HEAD")
		s.headVal = ""
		if err == nil && code == 0 {
			s.headVal = strings.TrimSpace(out)
		}
		s.headAt = time.Now()
	}
	return s.headVal
}

// credentials is a one-run credential store: the token never lands in argv or
// .git/config.
func (s *server) credentials() (string, error) {
	directory := os.Getenv("CREDENTIALS_DIRECTORY")
	if directory == "" {
		return "", fmt.Errorf("no github-token credential")
	}
	raw, err := os.ReadFile(filepath.Join(directory, "github-token"))
	if err != nil {
		return "", fmt.Errorf("no github-token credential")
	}
	handle, err := os.CreateTemp("", "zettel-*.gitcred")
	if err != nil {
		return "", err
	}
	defer handle.Close()
	if _, err := fmt.Fprintf(handle, "https://x-access-token:%s@github.com\n", strings.TrimSpace(string(raw))); err != nil {
		return "", err
	}
	if err := os.Chmod(handle.Name(), 0o600); err != nil {
		return "", err
	}
	return handle.Name(), nil
}

func (s *server) push() (bool, string) {
	creds, err := s.credentials()
	if err != nil {
		return false, "no github-token credential"
	}
	defer os.Remove(creds)
	out, errOut, code, err := s.run(
		s.cfg.git,
		[]string{"-C", s.cfg.vault, "-c", "credential.helper=store --file=" + creds,
			"push", "--quiet", "origin", "HEAD:refs/heads/" + s.cfg.ref},
		"", 120*time.Second,
	)
	if err == nil && code == 0 {
		return true, ""
	}
	message := strings.TrimSpace(errOut)
	if message == "" {
		message = strings.TrimSpace(out)
	}
	if len(message) > 400 {
		message = message[len(message)-400:]
	}
	return false, message
}

// record commits one path and pushes, unless the host was configured otherwise.
func (s *server) record(relative, message string) (map[string]any, error) {
	result := map[string]any{"committed": false, "pushed": false}
	if !s.cfg.commit {
		return result, nil
	}
	if _, _, err := s.git("add", "--", relative); err != nil {
		return nil, refuse(500, "commit failed: %v", err)
	}
	if _, code, err := s.git("diff", "--cached", "--quiet", "--", relative); err != nil {
		return nil, refuse(500, "commit failed: %v", err)
	} else if code == 0 {
		return result, nil
	}
	out, errOut, code, err := s.run(
		s.cfg.git,
		[]string{"-C", s.cfg.vault,
			"-c", "user.name=zettel-graph", "-c", "user.email=zettel-graph@localhost",
			"commit", "--quiet", "--only", "-m", message, "--", relative},
		"", 60*time.Second,
	)
	if err != nil || code != 0 {
		tail := strings.TrimSpace(errOut)
		if tail == "" {
			tail = strings.TrimSpace(out)
		}
		if len(tail) > 400 {
			tail = tail[len(tail)-400:]
		}
		return nil, refuse(500, "commit failed: %s", tail)
	}
	result["committed"] = true
	if s.cfg.push {
		pushed, pushErr := s.push()
		result["pushed"] = pushed
		if !pushed {
			result["push_error"] = pushErr
		}
	}
	return result, nil
}

func (s *server) writeNote(id, text string) (map[string]any, error) {
	relative, file, err := s.noteFile(id)
	if err != nil {
		return nil, err
	}
	info, statErr := os.Stat(file)
	if statErr != nil || info.IsDir() {
		return nil, refuse(404, "%s is not in the working tree", relative)
	}
	if len([]byte(text)) > maxNote {
		return nil, refuse(413, "a note over %d KiB is not a zettel", maxNote/1024)
	}
	tmp := filepath.Join(filepath.Dir(file), fmt.Sprintf(".%s.%d.tmp", filepath.Base(file), os.Getpid()))
	if err := os.WriteFile(tmp, []byte(text), info.Mode().Perm()); err != nil {
		return nil, refuse(500, "writing %s: %v", relative, err)
	}
	if err := os.Chmod(tmp, info.Mode().Perm()); err != nil {
		return nil, refuse(500, "writing %s: %v", relative, err)
	}
	if err := os.Rename(tmp, file); err != nil {
		return nil, refuse(500, "writing %s: %v", relative, err)
	}

	result := map[string]any{"id": relative, "bytes": len([]byte(text))}
	recorded, err := s.record(relative, "zettel-graph: edit "+relative)
	if err != nil {
		return nil, err
	}
	for key, value := range recorded {
		result[key] = value
	}
	meta, err := s.reexport()
	if err != nil {
		return nil, err
	}
	result["meta"] = meta
	return result, nil
}

func (s *server) reexport() (map[string]any, error) {
	www := s.cfg.www
	target := filepath.Join(www, "graph.json")
	tmp := filepath.Join(www, fmt.Sprintf(".graph.%d.json", os.Getpid()))
	out, errOut, code, err := s.run(s.cfg.python, []string{"scripts/export_graph.py", "--out", tmp}, s.cfg.vault, 240*time.Second)
	if err != nil || code != 0 {
		os.Remove(tmp)
		message := strings.TrimSpace(errOut)
		if message == "" {
			message = strings.TrimSpace(out)
		}
		if len(message) > 800 {
			message = message[len(message)-800:]
		}
		return nil, refuse(500, "export failed: %s", message)
	}
	if err := os.Rename(tmp, target); err != nil {
		return nil, refuse(500, "export failed: %v", err)
	}
	return readMeta(www), nil
}

func (s *server) createNote(spec map[string]any) (map[string]any, error) {
	title := strings.Join(strings.Fields(specString(spec, "title")), " ")
	if title == "" {
		return nil, refuse(400, "a note needs a title")
	}
	if len([]rune(title)) > 120 {
		return nil, refuse(400, "a title over 120 characters is a paragraph, not a name")
	}
	kind := specString(spec, "type")
	if kind == "" {
		kind = "zettel"
	}
	allowed := false
	for _, candidate := range createTypes {
		if kind == candidate {
			allowed = true
		}
	}
	if !allowed {
		return nil, refuse(400, "type is one of ['zettel', 'moc']")
	}
	tags := strings.Join(strings.Fields(strings.ReplaceAll(specString(spec, "tags"), ",", " ")), " ")

	args := []string{"scripts/create_note.py", "--title", title, "--type", kind, "--root", "."}
	if tags != "" {
		args = append(args, "--tags", strings.ReplaceAll(tags, " ", ","))
	}
	out, errOut, code, err := s.run(s.cfg.python, args, s.cfg.vault, 60*time.Second)
	if err != nil || code != 0 {
		message := strings.TrimSpace(errOut)
		if message == "" {
			message = strings.TrimSpace(out)
		}
		if len(message) > 600 {
			message = message[len(message)-600:]
		}
		return nil, refuse(500, "create_note.py failed: %s", message)
	}

	// The script prints the vault-relative path first; the rest is commentary.
	created := ""
	for _, line := range strings.Split(out, "\n") {
		line = strings.TrimSpace(line)
		if strings.HasSuffix(line, ".md") {
			created = line
			break
		}
	}
	if created == "" {
		trimmed := strings.TrimSpace(out)
		if len(trimmed) > 300 {
			trimmed = trimmed[len(trimmed)-300:]
		}
		return nil, refuse(500, "create_note.py wrote nothing it can name: %s", trimmed)
	}
	relative, file, err := s.noteFile(created)
	if err != nil {
		return nil, err
	}
	info, statErr := os.Stat(file)
	if statErr != nil || info.IsDir() {
		return nil, refuse(500, "create_note.py reported %s, which is not there", relative)
	}

	result := map[string]any{
		"path": relative, "id": strings.TrimSuffix(relative, ".md"), "bytes": info.Size(),
	}
	recorded, err := s.record(relative, "zettel-graph: add "+relative)
	if err != nil {
		return nil, err
	}
	for key, value := range recorded {
		result[key] = value
	}
	meta, err := s.reexport()
	if err != nil {
		return nil, err
	}
	result["meta"] = meta
	return result, nil
}

func (s *server) publish(spec map[string]any) (map[string]any, error) {
	args := []string{"scripts/publish_md.py"}
	if truthy(spec["all"]) {
		args = append(args, "--all")
	} else {
		relative, _, err := s.noteFile(specString(spec, "note"))
		if err != nil {
			return nil, err
		}
		args = append(args, relative)
	}

	started := time.Now()
	out, errOut, code, err := s.run(s.cfg.python, args, s.cfg.vault, 600*time.Second)
	output := strings.TrimSpace(out + errOut)
	if len(output) > 4000 {
		output = output[len(output)-4000:]
	}

	var rendered []string
	publishDir := filepath.Join(s.cfg.vault, "publish")
	_ = filepath.Walk(publishDir, func(p string, info os.FileInfo, walkErr error) error {
		if walkErr != nil || info == nil || info.IsDir() || filepath.Ext(p) != ".pdf" {
			return nil
		}
		if info.ModTime().After(started.Add(-time.Second)) {
			if rel, relErr := filepath.Rel(s.cfg.vault, p); relErr == nil {
				rendered = append(rendered, rel)
			}
		}
		return nil
	})
	sortByModTime(s.cfg.vault, rendered)
	if len(rendered) > 20 {
		rendered = rendered[:20]
	}

	meta, metaErr := s.reexport()
	if metaErr != nil {
		// The PDFs are on disk and the frames answer for them; a failed graph
		// export is reported the same way the reload reports it.
		meta = map[string]any{}
	}
	return map[string]any{
		"ok":     err == nil && code == 0,
		"files":  rendered,
		"output": output,
		"meta":   meta,
	}, nil
}

func sortByModTime(root string, files []string) {
	sort.SliceStable(files, func(i, j int) bool {
		left, _ := os.Stat(filepath.Join(root, files[i]))
		right, _ := os.Stat(filepath.Join(root, files[j]))
		if left == nil || right == nil {
			return false
		}
		return left.ModTime().After(right.ModTime())
	})
}

func truthy(value any) bool {
	switch v := value.(type) {
	case bool:
		return v
	case string:
		return v != "" && v != "0" && v != "false"
	case float64:
		return v != 0
	case json.Number:
		return v.String() != "0"
	}
	return false
}

func specString(spec map[string]any, key string) string {
	switch v := spec[key].(type) {
	case nil:
		return ""
	case string:
		return v
	case json.Number:
		return v.String()
	default:
		return fmt.Sprint(v)
	}
}

func readBody(r *http.Request) (map[string]any, error) {
	length := r.ContentLength
	if length <= 0 || length > maxNote+4096 {
		return nil, refuse(413, "missing or oversized body")
	}
	raw, err := io.ReadAll(io.LimitReader(r.Body, maxNote+4096))
	if err != nil {
		return nil, refuse(413, "missing or oversized body")
	}
	decoder := json.NewDecoder(strings.NewReader(string(raw)))
	decoder.UseNumber()
	var body any
	if err := decoder.Decode(&body); err != nil {
		return nil, refuse(400, "body is not JSON")
	}
	spec, ok := body.(map[string]any)
	if !ok {
		return nil, refuse(400, "body is not JSON")
	}
	return spec, nil
}

func writeJSON(w http.ResponseWriter, code int, body map[string]any) {
	payload, err := json.Marshal(body)
	if err != nil {
		http.Error(w, "encoding failed", http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Content-Length", strconv.Itoa(len(payload)))
	w.Header().Set("Cache-Control", "no-store")
	w.WriteHeader(code)
	w.Write(payload)
}

func sendFile(w http.ResponseWriter, file, ctype string) error {
	payload, err := os.ReadFile(file)
	if err != nil {
		return refuse(404, "%s is not there", filepath.Base(file))
	}
	w.Header().Set("Content-Type", ctype)
	w.Header().Set("Content-Length", strconv.Itoa(len(payload)))
	// The vault moves under this URL; a cached copy would be yesterday's graph.
	w.Header().Set("Cache-Control", "no-store")
	w.WriteHeader(200)
	_, _ = w.Write(payload)
	return nil
}

func urlUnescape(raw string) (string, error) {
	return url.PathUnescape(raw)
}
