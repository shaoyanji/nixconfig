package image

import (
	"encoding/json"
	"image"
	"image/png"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

// writeTree makes the minimal IMAGES_ROOT + REPO manifestJSON reads: only
// published/urls.tsv is required — ledger, briefs and roster are all
// missing-file-tolerant, so the test root is the same seam the flag uses.
func writeTree(t *testing.T, urls string) (root, repo string) {
	t.Helper()
	root = t.TempDir()
	repo = t.TempDir()
	if err := os.MkdirAll(filepath.Join(root, "published"), 0o755); err != nil {
		t.Fatal(err)
	}
	if urls != "" {
		if err := os.WriteFile(filepath.Join(root, "published", "urls.tsv"), []byte(urls), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	return root, repo
}

func manifestOf(t *testing.T, urls string) manifest {
	t.Helper()
	root, repo := writeTree(t, urls)
	var m manifest
	if err := json.Unmarshal(manifestJSON(root, repo), &m); err != nil {
		t.Fatalf("manifestJSON emits invalid JSON: %v", err)
	}
	return m
}

func TestManifestProjectsEveryWellFormedRow(t *testing.T) {
	m := manifestOf(t,
		"wall/2026-11-24/stairway-light.png\thttps://res.cloudinary.com/x/image/upload/v1/assets/wall/2026-11-24/stairway-light.png\t100\n"+
			"badge/delphi.png\thttps://res.cloudinary.com/x/image/upload/v1/assets/fleet/delphi.png\t200\n")
	if m.Count != 2 || len(m.Assets) != 2 {
		t.Fatalf("expected 2 assets, got count=%d len=%d", m.Count, len(m.Assets))
	}
	// Assets sort by path: badge before wall.
	b, w := m.Assets[0], m.Assets[1]
	if b.PublicID != "badge/delphi" || b.Lane != "badge" || b.Day != "" {
		t.Fatalf("badge row mis-derived: %+v", b)
	}
	if w.PublicID != "wall/2026-11-24/stairway-light" || w.Lane != "wall" ||
		w.Day != "2026-11-24" || w.Name != "stairway-light.png" ||
		w.Title != "Stairway Light" || w.Bytes != 100 {
		t.Fatalf("wall row mis-derived: %+v", w)
	}
	if !strings.Contains(w.Enhanced, "/upload/w_2400,c_limit,e_sharpen:70,q_auto:best,f_auto/") {
		t.Fatalf("enhanced URL lacks the transform: %s", w.Enhanced)
	}
}

// A row with no tab is silently dropped by the scanner — the manifest simply
// counts one asset fewer. That quiet drop is the drift the projection gate
// (scripts/task/images-check.sh) exists to name; the port carries it through
// unchanged rather than inventing a row.
func TestManifestDropsMalformedRow(t *testing.T) {
	m := manifestOf(t,
		"wall/2026-11-24/kept.png\thttps://res.cloudinary.com/x/image/upload/v1/assets/wall/2026-11-24/kept.png\t1\n"+
			"wall/2026-11-24/path-only-no-tab.png\n")
	if m.Count != 1 {
		t.Fatalf("malformed row should drop: count=%d", m.Count)
	}
	for _, a := range m.Assets {
		if strings.Contains(a.Path, "path-only") {
			t.Fatalf("malformed row leaked into the manifest: %+v", a)
		}
	}
}

// The port carries the row's URL verbatim and only rewrites /upload/ for the
// enhanced field — it does not validate that the URL is a bank delivery URL.
// A session-gated render URL (the mistake the shell gate names "session-gated
// URL, not the bank") passes through untouched, which is why that check lives
// in images-check.sh rather than here.
func TestManifestCarriesURLVerbatim(t *testing.T) {
	m := manifestOf(t,
		"wall/2026-11-24/x.png\thttps://chatplayground.ai/api/files/abc.png\t5\n")
	u := m.Assets[0].URL
	if u != "https://chatplayground.ai/api/files/abc.png" {
		t.Fatalf("url not verbatim: %s", u)
	}
	if !strings.Contains(m.Assets[0].Enhanced, "chatplayground.ai") {
		t.Fatalf("expected the session URL to survive into enhanced: %s", m.Assets[0].Enhanced)
	}
}

// Without urls.tsv the command dies — exercised in a subprocess because die()
// is os.Exit: the test binary itself must not exit.
func TestManifestDiesWithoutUrlsTsv(t *testing.T) {
	if os.Getenv("IMGTEST_DIE") == "1" {
		root, repo := writeTree(t, "")
		manifestJSON(root, repo)
		return
	}
	cmd := exec.Command(os.Args[0], "-test.run", "TestManifestDiesWithoutUrlsTsv")
	cmd.Env = append(os.Environ(), "IMGTEST_DIE=1")
	out, err := cmd.CombinedOutput()
	exit, _ := err.(*exec.ExitError)
	if exit == nil || exit.ExitCode() != 1 {
		t.Fatalf("expected exit 1 without urls.tsv, got err=%v out=%s", err, out)
	}
	if !strings.Contains(string(out), "urls.tsv") {
		t.Fatalf("death should name urls.tsv, got: %s", out)
	}
}

// writePNG materializes a real WxH image for the ffprobe read — the shape
// cache measures the file, not the request.
func writePNG(t *testing.T, file string, w, h int) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(file), 0o755); err != nil {
		t.Fatal(err)
	}
	img := image.NewRGBA(image.Rect(0, 0, w, h))
	f, err := os.Create(file)
	if err != nil {
		t.Fatal(err)
	}
	defer f.Close()
	if err := png.Encode(f, img); err != nil {
		t.Fatal(err)
	}
}

func TestDimensions(t *testing.T) {
	if _, err := exec.LookPath("ffprobe"); err != nil {
		t.Skip("ffprobe not on PATH")
	}
	f := filepath.Join(t.TempDir(), "p.png")
	writePNG(t, f, 6, 3)
	if got := dimensions(f); got != "6x3" {
		t.Fatalf("dimensions: %q", got)
	}
	if got := dimensions(filepath.Join(t.TempDir(), "absent.png")); got != "" {
		t.Fatalf("dimensions on a missing file: %q", got)
	}
}

// shapesPass is the ffprobe cache loop from build_index: a cached rel is never
// re-probed, published/ wins over src/, a missing file leaves no row, and each
// new measurement appends rel\tWxH.
func TestShapesPass(t *testing.T) {
	if _, err := exec.LookPath("ffprobe"); err != nil {
		t.Skip("ffprobe not on PATH")
	}
	root, _ := writeTree(t,
		"wall/a.png\tu\t1\nwall/b.png\tu\t1\nwall/c.png\tu\t1\nwall/d.png\tu\t1\n")
	writePNG(t, filepath.Join(root, "published", "wall", "a.png"), 4, 2)
	writePNG(t, filepath.Join(root, "src", "wall", "b.png"), 3, 3)
	// wall/c.png exists nowhere: no row. wall/d.png is already cached.
	shapes := filepath.Join(root, "published", "shapes.tsv")
	if err := os.WriteFile(shapes, []byte("wall/d.png\t9x9\n"), 0o644); err != nil {
		t.Fatal(err)
	}

	shapesPass(root)

	data, err := os.ReadFile(shapes)
	if err != nil {
		t.Fatal(err)
	}
	lines := strings.Split(strings.TrimSpace(string(data)), "\n")
	if len(lines) != 3 {
		t.Fatalf("expected 3 cache rows, got %v", lines)
	}
	for _, want := range []string{"wall/d.png\t9x9", "wall/a.png\t4x2", "wall/b.png\t3x3"} {
		found := false
		for _, l := range lines {
			if l == want {
				found = true
			}
		}
		if !found {
			t.Fatalf("cache missing %q: %v", want, lines)
		}
	}
	// A second pass appends nothing: the cache is the cache.
	shapesPass(root)
	again, _ := os.ReadFile(shapes)
	if string(again) != string(data) {
		t.Fatalf("second pass rewrote the cache: %q", again)
	}
}

// skipReason's reject list is the 0-of-43 burn's vocabulary: the verdicts the
// judge emitted while the account route was quota-dead. Removing one of these
// strings re-admits the burn's own verdict rows as real judge output.
func TestSkipReasonRejectsBurnVocabulary(t *testing.T) {
	for _, r := range []string{
		"agy exited 3", "429 Too Many Requests", "rate limited by the provider",
		"backfilled verdict", "Error: upstream",
	} {
		if !skipReason(r) {
			t.Fatalf("burn-vocabulary reason not skipped: %q", r)
		}
	}
	for _, r := range []string{"keep: the plate reads well", "reject: model off-centre", ""} {
		if skipReason(r) {
			t.Fatalf("real judge reason skipped: %q", r)
		}
	}
}

func TestVerdictFieldsAndReasonOf(t *testing.T) {
	v, d := verdictFields(`{"verdict":"reject","defect":"wing off-frame"}`)
	if v != "reject" || d != "wing off-frame" {
		t.Fatalf("verdictFields: got %q %q", v, d)
	}
	if r := reasonOf(`{"reason":"good light","defect":"flat sky"}`); r != "good light | flat sky" {
		t.Fatalf("reasonOf with defect: %q", r)
	}
	if r := reasonOf(`{"reason":"keep"}`); r != "keep" {
		t.Fatalf("reasonOf without defect: %q", r)
	}
	if r := reasonOf("not json"); r != "" {
		t.Fatalf("reasonOf on garbage: %q", r)
	}
}

// The description cascade: judge reason < briefs < ledger prompt < roster, and
// empty cleaned descriptions never overwrite. An "agy exited" judge reason is
// burn vocabulary and must not seed a description.
func TestPlatesDescriptionCascade(t *testing.T) {
	dir := t.TempDir()
	ledger := filepath.Join(dir, "ledger.jsonl")
	briefs := filepath.Join(dir, "briefs.json")
	roster := filepath.Join(dir, "plates.txt")
	os.WriteFile(ledger, []byte(
		`{"path":"a.png","reason":"agy exited 3"}`+"\n"+
			`{"path":"a.png","reason":"judge liked the light"}`+"\n"+
			`{"path":"a.png","prompt":"ledger prompt for a"}`+"\n"+
			`{"path":"b.png","reason":"judge liked b"}`+"\n"), 0o644)
	os.WriteFile(briefs, []byte(`{"briefs":[{"id":"wall-a","prompt":"brief for a"}]}`), 0o644)
	os.WriteFile(roster, []byte("# a comment\na|roster for a\n"), 0o644)

	d := platesDescription(ledger, briefs, roster)
	if d["a"] != "roster for a" {
		t.Fatalf("roster must win the cascade: %q", d["a"])
	}
	if d["b"] != "judge liked b" {
		t.Fatalf("b should fall to the judge reason: %q", d["b"])
	}
	// Briefs lose to the roster but still feed a slug nothing else wrote.
	d2 := platesDescription(ledger, briefs, filepath.Join(dir, "absent.txt"))
	if d2["a"] != "ledger prompt for a" {
		t.Fatalf("ledger prompt must beat brief + judge: %q", d2["a"])
	}
	if d2["b"] != "judge liked b" {
		t.Fatalf("burn-adjacent slug: %q", d2["b"])
	}
}

func TestPureHelpers(t *testing.T) {
	if got := tsvEsc("a\tb\nc\\d"); got != `a\tb\nc\\d` {
		t.Fatalf("tsvEsc: %q", got)
	}
	if got := noExt("x.PNG"); got != "x.PNG" { // lowercase exts only
		t.Fatalf("noExt: %q", got)
	}
	if got := noExt("x.png"); got != "x" {
		t.Fatalf("noExt: %q", got)
	}
	if got := titleCase("stairway-of-light"); got != "Stairway Of Light" {
		t.Fatalf("titleCase: %q", got)
	}
	if got := titleCase("über-cool"); got != "über Cool" { // ascii_upcase, not a fold
		t.Fatalf("titleCase fold: %q", got)
	}
	if got := jqNum(5); got != "5" {
		t.Fatalf("jqNum int: %q", got)
	}
	if got := jqNum(5.5); got != "5.5" {
		t.Fatalf("jqNum float: %q", got)
	}
	if _, ok := epoch("2026-11-24"); !ok {
		t.Fatal("epoch rejected a valid day")
	}
	if _, ok := epoch("not-a-day"); ok {
		t.Fatal("epoch accepted garbage")
	}
}

func TestCleanDesc(t *testing.T) {
	if got := cleanDesc("hold: x :: the real  desc   "); got != "the real desc" {
		t.Fatalf("cleanDesc hold/ws: %q", got)
	}
	if got := cleanDesc("scene arch:plate-a, 4k, photorealistic, realistic, neumorphism."); got != "scene ," {
		t.Fatalf("cleanDesc arch/tail: %q", got)
	}
	long := strings.Repeat("ü", 400)
	if got := cleanDesc(long); len([]rune(got)) != 300 || !strings.HasSuffix(got, "...") {
		t.Fatalf("cleanDesc must cap at 300 runes incl. ellipsis, got %d", len([]rune(got)))
	}
}

// tagsFor is the manifest's tag vocabulary: date segments out, stopwords out,
// <=2-rune and pure digits out, the lane's own name out, deduped and sorted.
func TestTagsFor(t *testing.T) {
	got := tagsFor("wall/2026-11-24/stairway-of-light-wall", "wall")
	want := []string{"light", "stairway"}
	if strings.Join(got, ",") != strings.Join(want, ",") {
		t.Fatalf("tagsFor: got %v want %v", got, want)
	}
	got = tagsFor("badge/delphi", "badge")
	if strings.Join(got, ",") != "delphi" {
		t.Fatalf("tagsFor badge: %v", got)
	}
}
