package image

import (
	"crypto/sha1"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"image"
	"image/png"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"os/exec"
	"path/filepath"
	"slices"
	"strings"
	"testing"
	"time"
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

// cmdDeploy's first gate is PAGES: anything but unset-or-1 returns before the
// root check, before the nix-shell wrangler exec — so a publish on a host that
// must not deploy skips the leg entirely and in-process.
func TestDeployPagesGate(t *testing.T) {
	t.Setenv("PAGES", "0")
	// No --root, no nix-shell, no network: if the gate were not first this
	// would die() and kill the test binary.
	cmdDeploy([]string{})
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

// slugify is the shell's tr/sed/cut chain: lower, non-[a-z0-9] runs to one
// dash, edges trimmed, capped at 48 — and the cap runs after the trim, so a
// slug can still end on a dash the way `cut -c1-48` leaves one.
func TestSlugify(t *testing.T) {
	for _, tc := range []struct{ in, want string }{
		{"Hello World", "hello-world"},
		{"---a--b---", "a-b"},
		{"A Plate: the Second!", "a-plate-the-second"},
		{"résumé café", "r-sum-caf"},
		{"wall 2026", "wall-2026"},
		{strings.Repeat("x", 60), strings.Repeat("x", 48)},
		{"a" + strings.Repeat("b", 46) + " c", "a" + strings.Repeat("b", 46) + "-"},
		{"", ""},
	} {
		if got := slugify(tc.in); got != tc.want {
			t.Errorf("slugify(%q) = %q, want %q", tc.in, got, tc.want)
		}
	}
}

// shipRunArgs is the whole launch_detached contract in one vector: the unit
// name, --collect, the checkout as working directory, DETACH=0 so the unit
// runs the pipeline instead of detaching again, and an absolute script path.
func TestShipRunArgs(t *testing.T) {
	t.Setenv("PATH", "/p")
	t.Setenv("PROMPT", "a plate")
	t.Setenv("OUT", "")
	t.Setenv("SIZE", "")
	t.Setenv("PROJECT", "")
	t.Setenv("PAGES", "")
	got := shipRunArgs("image-ship-x", "/repo", "/root", "/repo/scripts/task/image-ship.sh")
	want := []string{
		"--user", "--unit", "image-ship-x", "--collect",
		"--working-directory=/repo",
		"--setenv=PATH=/p",
		"--setenv=PROMPT=a plate", "--setenv=OUT=", "--setenv=SIZE=1536x1024",
		"--setenv=IMAGES_ROOT=/root",
		"--setenv=PROJECT=bountystash-assets", "--setenv=PAGES=1",
		"--setenv=DETACH=0", "--setenv=REPO=/repo",
		"--", "bash", "/repo/scripts/task/image-ship.sh",
	}
	if !slices.Equal(got, want) {
		t.Fatalf("shipRunArgs:\n got %q\nwant %q", got, want)
	}
}

// Without PROMPT the detach dies — the unit would re-run the ship and die on
// its own `${PROMPT:?}`; subprocess because die() is os.Exit.
func TestShipDetachRequiresPrompt(t *testing.T) {
	if os.Getenv("IMGTEST_DIE") == "1" {
		os.Unsetenv("PROMPT")
		cmdShipDetach([]string{"--repo", "/r", "--root", "/x"})
		return
	}
	cmd := exec.Command(os.Args[0], "-test.run", "TestShipDetachRequiresPrompt")
	cmd.Env = append(os.Environ(), "IMGTEST_DIE=1")
	out, err := cmd.CombinedOutput()
	exit, _ := err.(*exec.ExitError)
	if exit == nil || exit.ExitCode() != 1 {
		t.Fatalf("expected exit 1 without PROMPT, got err=%v out=%s", err, out)
	}
	if !strings.Contains(string(out), "PROMPT") {
		t.Fatalf("death should name PROMPT, got: %s", out)
	}
}

// manifestServes polls: a row that lands on the second fetch is found, and a
// missing row, a non-200, and malformed JSON are all "not served".
func TestManifestServes(t *testing.T) {
	rel := "wall/2026-11-24/001.png"
	manifest := func(paths ...string) http.HandlerFunc {
		return func(w http.ResponseWriter, _ *http.Request) {
			var rows []string
			for _, p := range paths {
				rows = append(rows, `{"path":"`+p+`"}`)
			}
			fmt.Fprintf(w, `{"assets":[%s]}`, strings.Join(rows, ","))
		}
	}
	t.Run("present", func(t *testing.T) {
		srv := httptest.NewServer(manifest(rel, "other/x.png"))
		defer srv.Close()
		if !manifestServes(srv.URL, rel, 3, time.Millisecond) {
			t.Fatal("manifest carries the row; must serve true")
		}
	})
	t.Run("appears on retry", func(t *testing.T) {
		n := 0
		srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			n++
			if n < 2 {
				fmt.Fprint(w, `{"assets":[]}`)
				return
			}
			manifest(rel)(w, r)
		}))
		defer srv.Close()
		if !manifestServes(srv.URL, rel, 3, time.Millisecond) {
			t.Fatal("a row that lands mid-poll must still serve true")
		}
		if n != 2 {
			t.Fatalf("expected the poll to retry, got %d request(s)", n)
		}
	})
	t.Run("missing", func(t *testing.T) {
		srv := httptest.NewServer(manifest("other/x.png"))
		defer srv.Close()
		if manifestServes(srv.URL, rel, 2, time.Millisecond) {
			t.Fatal("a manifest without the row must serve false")
		}
	})
	t.Run("not ok and malformed", func(t *testing.T) {
		srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
			w.WriteHeader(http.StatusServiceUnavailable)
		}))
		defer srv.Close()
		if manifestServes(srv.URL, rel, 2, time.Millisecond) {
			t.Fatal("a non-200 manifest must serve false")
		}
		srv2 := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
			fmt.Fprint(w, "not json")
		}))
		defer srv2.Close()
		if manifestServes(srv2.URL, rel, 2, time.Millisecond) {
			t.Fatal("a malformed manifest must serve false")
		}
	})
}

// served's exit code is the contract image-ship.sh's `if` reads: 0 prints
// true, absent-after-poll prints false and exits 1. Subprocess for the exit.
func TestServedExitCode(t *testing.T) {
	if os.Getenv("IMGTEST_DIE") == "1" {
		cmdServed([]string{"--rel", "wall/x.png", "--from", os.Getenv("IMGTEST_URL"), "--tries", "1"})
		return
	}
	run := func(url string) (string, int) {
		cmd := exec.Command(os.Args[0], "-test.run", "TestServedExitCode")
		cmd.Env = append(os.Environ(), "IMGTEST_DIE=1", "IMGTEST_URL="+url)
		out, err := cmd.CombinedOutput()
		code := 0
		if exit, _ := err.(*exec.ExitError); exit != nil {
			code = exit.ExitCode()
		} else if err != nil {
			t.Fatalf("served subprocess: %v", err)
		}
		first, _, _ := strings.Cut(strings.TrimSpace(string(out)), "\n")
		return first, code
	}
	hit := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		fmt.Fprint(w, `{"assets":[{"path":"wall/x.png"}]}`)
	}))
	defer hit.Close()
	miss := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		fmt.Fprint(w, `{"assets":[]}`)
	}))
	defer miss.Close()
	if out, code := run(hit.URL); out != "true" || code != 0 {
		t.Fatalf("served row: got %q rc=%d, want true rc=0", out, code)
	}
	if out, code := run(miss.URL); out != "false" || code != 1 {
		t.Fatalf("absent row: got %q rc=%d, want false rc=1", out, code)
	}
}

// cloudSign pins the shell's sha1 contract verbatim — the vector is the
// string cloudinary.sh fed sha1sum, so a reorder or a stray param shows up
// as a signature Cloudinary would refuse.
func TestCloudSign(t *testing.T) {
	params := map[string]string{"public_id": "assets/wall/x", "timestamp": "1700000000"}
	if got := cloudSign("SECRET", params); got != "5be00799e337bf075d3c603bc1e57d1923bef87a" {
		t.Fatalf("cloudSign: got %s", got)
	}
	// map order is invisible — the sorted join makes insertion order moot.
	if got := cloudSign("SECRET", map[string]string{"timestamp": "1700000000"}); got != "b4356e7c744cae717f1b865b9d19bef0c0e8ebab" {
		t.Fatalf("cloudSign timestamp-only: got %s", got)
	}
}

// A fixture credential set; the httptest handlers below verify the wire
// independently of cloudSign so a signing bug is caught by the test, not
// shared with it.
var testCreds = cloudCreds{"nm", "key", "sec"}

func testSign(t *testing.T, fields map[string]string, wantSig string) {
	t.Helper()
	ts := fields["timestamp"]
	var signed []string
	for _, k := range []string{"folder", "public_id", "timestamp"} {
		if v, ok := fields[k]; ok {
			signed = append(signed, k+"="+v)
		}
	}
	_ = ts
	sum := sha1.Sum([]byte(strings.Join(signed, "&") + "sec"))
	if got := hex.EncodeToString(sum[:]); got != wantSig {
		t.Errorf("signature = %s, want sha1 of %q+sec", wantSig, strings.Join(signed, "&"))
	}
}

// cloudUpload writes the file field plus the signed params; a refusal in
// {error:{message}} is the error, and a missing secure_url is one too.
func TestCloudUpload(t *testing.T) {
	old := cloudBase
	defer func() { cloudBase = old }()
	var gotFields map[string]string
	var gotFile string
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if !strings.HasSuffix(r.URL.Path, "/v1_1/nm/image/upload") {
			t.Errorf("upload went to %s", r.URL.Path)
		}
		if err := r.ParseMultipartForm(1 << 20); err != nil {
			t.Errorf("body is not multipart: %v", err)
			return
		}
		gotFields = map[string]string{}
		for k := range r.MultipartForm.Value {
			gotFields[k] = r.MultipartForm.Value[k][0]
		}
		if f, fh, err := r.FormFile("file"); err == nil {
			b, _ := io.ReadAll(f)
			f.Close()
			gotFile = fh.Filename + ":" + string(b)
		}
		fmt.Fprint(w, `{"secure_url":"https://res.cloudinary.com/nm/image/upload/v1/id.png"}`)
	}))
	defer srv.Close()
	cloudBase = srv.URL

	dir := t.TempDir()
	png := filepath.Join(dir, "plate.png")
	if err := os.WriteFile(png, []byte("PNGDATA"), 0o644); err != nil {
		t.Fatal(err)
	}
	got, err := cloudUpload(testCreds, png, "", "assets/wall/x")
	if err != nil {
		t.Fatalf("cloudUpload: %v", err)
	}
	if got != "https://res.cloudinary.com/nm/image/upload/v1/id.png" {
		t.Fatalf("secure_url: %s", got)
	}
	if gotFields["api_key"] != "key" || gotFields["public_id"] != "assets/wall/x" || gotFields["timestamp"] == "" {
		t.Fatalf("form fields: %v", gotFields)
	}
	testSign(t, gotFields, gotFields["signature"])
	if gotFile != "plate.png:PNGDATA" {
		t.Fatalf("file part: %q", gotFile)
	}

	// A refusal is an error with the API's own message.
	srv2 := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		fmt.Fprint(w, `{"error":{"message":"Invalid Signature"}}`)
	}))
	defer srv2.Close()
	cloudBase = srv2.URL
	if _, err := cloudUpload(testCreds, png, "", "assets/wall/x"); err == nil || !strings.Contains(err.Error(), "Invalid Signature") {
		t.Fatalf("refusal must surface its message, got %v", err)
	}
}

// cloudListAll follows next_cursor to exhaustion with basic auth — the same
// read the admin API contract gives cloudinary.sh's curl -u loop.
func TestCloudListAll(t *testing.T) {
	old := cloudBase
	defer func() { cloudBase = old }()
	var pages []string
	var gotUser, gotPass string
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotUser, gotPass, _ = r.BasicAuth()
		q := r.URL.Query()
		pages = append(pages, q.Get("next_cursor"))
		if q.Get("prefix") != "shaoyanji/" {
			t.Errorf("prefix=%q", q.Get("prefix"))
		}
		if q.Get("next_cursor") == "" {
			fmt.Fprint(w, `{"resources":[{"public_id":"a"},{"public_id":"b"}],"next_cursor":"c2"}`)
		} else {
			fmt.Fprint(w, `{"resources":[{"public_id":"c"}]}`)
		}
	}))
	defer srv.Close()
	cloudBase = srv.URL

	res, err := cloudListAll(testCreds, "shaoyanji/", 500)
	if err != nil {
		t.Fatalf("cloudListAll: %v", err)
	}
	if len(res) != 3 || res[0].PublicID != "a" || res[2].PublicID != "c" {
		t.Fatalf("pages not joined: %+v", res)
	}
	if len(pages) != 2 || pages[1] != "c2" {
		t.Fatalf("cursor not followed: %v", pages)
	}
	if gotUser != "key" || gotPass != "sec" {
		t.Fatalf("basic auth: %s:***", gotUser)
	}
}

// cloudDestroy posts the same four signed fields as the shell and wants
// {result:ok} — "not found" is a refusal, not a success.
func TestCloudDestroy(t *testing.T) {
	old := cloudBase
	defer func() { cloudBase = old }()
	var gotFields map[string]string
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if err := r.ParseMultipartForm(1 << 20); err != nil {
			t.Errorf("destroy body is not multipart: %v", err)
			return
		}
		gotFields = map[string]string{}
		for k := range r.MultipartForm.Value {
			gotFields[k] = r.MultipartForm.Value[k][0]
		}
		fmt.Fprint(w, `{"result":"ok"}`)
	}))
	defer srv.Close()
	cloudBase = srv.URL
	if err := cloudDestroy(testCreds, "assets/wall/x"); err != nil {
		t.Fatalf("cloudDestroy: %v", err)
	}
	if gotFields["public_id"] != "assets/wall/x" || gotFields["api_key"] != "key" {
		t.Fatalf("destroy fields: %v", gotFields)
	}
	testSign(t, gotFields, gotFields["signature"])

	srv2 := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		fmt.Fprint(w, `{"result":"not found"}`)
	}))
	defer srv2.Close()
	cloudBase = srv2.URL
	if err := cloudDestroy(testCreds, "gone"); err == nil || !strings.Contains(err.Error(), "not found") {
		t.Fatalf("a non-ok result must refuse, got %v", err)
	}
}

// Without ffprobe the measurement names the missing tool instead of reading
// every plate as shapeless — subprocess because die() is os.Exit.
func TestDimensionsRequiresFfprobe(t *testing.T) {
	if os.Getenv("IMGTEST_DIE") == "1" {
		os.Setenv("PATH", t.TempDir())
		dimensions("whatever.png")
		return
	}
	cmd := exec.Command(os.Args[0], "-test.run", "TestDimensionsRequiresFfprobe")
	cmd.Env = append(os.Environ(), "IMGTEST_DIE=1")
	out, err := cmd.CombinedOutput()
	exit, _ := err.(*exec.ExitError)
	if exit == nil || exit.ExitCode() != 1 {
		t.Fatalf("expected exit 1 without ffprobe, got err=%v out=%s", err, out)
	}
	if !strings.Contains(string(out), "ffprobe") {
		t.Fatalf("death should name ffprobe, got: %s", out)
	}
}

// genRetry is gen_one's case table: a 401 buys one refresh and one retry, a
// 429 is the burst window with 60 s per attempt and three tries out, both on
// the one counter — anything else is a plain failure.
func TestGenRetry(t *testing.T) {
	cases := []struct {
		result string
		tries  int
		action genAction
		wait   int
	}{
		{"401 Unauthorized", 0, genRefresh, 0},
		{"UNAUTHENTICATED", 0, genRefresh, 0},
		{"Sign in to continue", 0, genRefresh, 0},
		{"401 again", 1, genFail, 0},
		{"429 Too Many", 0, genBackoff, 60},
		{"RATE_LIMITED", 1, genBackoff, 120},
		{"429", 2, genBackoff, 180},
		{"429", 3, genFail, 0},
		{"VALIDATION_FAILED: size", 0, genFail, 0},
		{"something else broke", 0, genFail, 0},
	}
	for _, c := range cases {
		action, wait := genRetry(c.result, c.tries)
		if action != c.action || wait != c.wait {
			t.Fatalf("genRetry(%q,%d) = (%d,%d), want (%d,%d)",
				c.result, c.tries, action, wait, c.action, c.wait)
		}
	}
}

// bankRel is upload_bank's id derivation: under src/ the render banks as its
// tree-relative path; anywhere else it joins today's wall/ folder by basename.
func TestBankRel(t *testing.T) {
	if got := bankRel("/root", "/root/src/wall/2026-11-25/x.png", "2026-11-25"); got != "wall/2026-11-25/x.png" {
		t.Fatalf("src-relative rel: got %q", got)
	}
	if got := bankRel("/root", "/tmp/elsewhere/x.png", "2026-11-25"); got != "wall/2026-11-25/x.png" {
		t.Fatalf("outside rel joins today's wall: got %q", got)
	}
}

// genDetachArgs is launch_detached's vector: the unit re-runs image-gen.sh
// with every variable the pipeline needs because a detached run inherits
// nothing — PROMPT is the argument, not whatever the caller's env held.
func TestGenDetachArgs(t *testing.T) {
	t.Setenv("UPLOAD", "0")
	got := genDetachArgs("image-gen-a-fox", "/repo", "/root", "a fox", "/root/x.png", "1024x1024", "/repo/scripts/task/image-gen.sh")
	want := []string{
		"--user", "--unit", "image-gen-a-fox", "--collect",
		"--setenv=PROMPT=a fox",
		"--setenv=OUT=/root/x.png",
		"--setenv=SIZE=1024x1024",
		"--setenv=IMAGES_ROOT=/root",
		"--setenv=DETACH=0",
		"--setenv=UPLOAD=0",
		"--setenv=REPO=/repo",
		"--", "bash", "/repo/scripts/task/image-gen.sh",
	}
	if !slices.Equal(got, want) {
		t.Fatalf("genDetachArgs = %v, want %v", got, want)
	}
}

// cpgStub installs a fake `cpg` on PATH: status answers authenticated,
// refresh exits 0, image writes the -o file and prints one JSON row.
func cpgStub(t *testing.T, imageOut string) {
	t.Helper()
	dir := t.TempDir()
	stub := `#!/bin/sh
case "$1" in
  status) echo '{"authenticated":true}' ;;
  refresh) exit 0 ;;
  image)
    while [ $# -gt 0 ]; do
      case "$1" in -o) out=$2; shift 2 ;; *) shift ;; esac
    done
    printf 'x' > "$out"
    printf '%s\n' '` + imageOut + `'
    ;;
esac
`
	if err := os.WriteFile(filepath.Join(dir, "cpg"), []byte(stub), 0o755); err != nil {
		t.Fatal(err)
	}
	t.Setenv("PATH", dir)
}

// The whole gen_one merge under a stub cpg: the file on disk plus .url in the
// JSON is success, UPLOAD=0 keeps .url as the session URL and reports
// bank=false — a session-gated URL must never pass as a delivery URL.
func TestGenOnceMerge(t *testing.T) {
	cpgStub(t, `{"id":"i1","url":"https://session.example/r.png","size":"1536x1024","prompt":"a fox"}`)
	t.Setenv("UPLOAD", "0")
	out := filepath.Join(t.TempDir(), "x.png")
	payload, err := genOnce("/repo", t.TempDir(), "1536x1024", "a fox", out)
	if err != nil {
		t.Fatalf("genOnce: %v", err)
	}
	if payload["path"] != out || payload["bank"] != false || payload["url"] != "https://session.example/r.png" {
		t.Fatalf("merge contract broke: %v", payload)
	}
	if _, has := payload["session_url"]; has {
		t.Fatalf("an unbanked render must not invent session_url: %v", payload)
	}
}

// The batch loop: one prompt per line, comments and empty lines skipped,
// NNN-slug.png per render, one merged JSON row per success appended to
// index.jsonl, and the index path on stdout.
func TestGenBatch(t *testing.T) {
	cpgStub(t, `{"id":"i","url":"https://session.example/x.png","size":"s","prompt":"p"}`)
	t.Setenv("UPLOAD", "0")
	root := t.TempDir()
	outdir := filepath.Join(root, "out")
	prompts := filepath.Join(root, "prompts.txt")
	if err := os.WriteFile(prompts, []byte("a fox\n# a comment\n\na second fox\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	cmdGenBatch([]string{"--prompts", prompts, "--repo", "/repo", "--root", root, "--outdir", outdir})
	rows, err := os.ReadFile(filepath.Join(outdir, "index.jsonl"))
	if err != nil {
		t.Fatal(err)
	}
	lines := strings.Split(strings.TrimRight(string(rows), "\n"), "\n")
	if len(lines) != 2 {
		t.Fatalf("two prompts should index two rows, got %d: %s", len(lines), rows)
	}
	for _, l := range lines {
		var m map[string]any
		if err := json.Unmarshal([]byte(l), &m); err != nil || m["bank"] != false {
			t.Fatalf("each index row is the merged JSON: %s (err %v)", l, err)
		}
	}
	for _, want := range []string{"001-a-fox.png", "002-a-second-fox.png"} {
		if _, err := os.Stat(filepath.Join(outdir, want)); err != nil {
			t.Fatalf("missing batch render %s: %v", want, err)
		}
	}
}

// laneSetting must stringify booleans and numbers as well as strings; otherwise
// cmdPublish skips every lane with "publish": true and status loses max_age_days.
func TestLaneSettingTypes(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("BRIEFS", filepath.Join(dir, "briefs.json"))
	const cfg = `{"lanes":{"wall":{"publish":true,"max_age_days":4,"budget":56,"intent":"wallpaper"},"fleet":{"publish":false}}}`
	if err := os.WriteFile(filepath.Join(dir, "briefs.json"), []byte(cfg), 0o644); err != nil {
		t.Fatal(err)
	}
	cases := []struct {
		lane, key, want string
	}{
		{"wall", "publish", "true"},
		{"fleet", "publish", "false"},
		{"wall", "max_age_days", "4"},
		{"wall", "budget", "56"},
		{"wall", "intent", "wallpaper"},
		{"wall", "missing", ""},
	}
	for _, tc := range cases {
		if got := laneSetting(dir, tc.lane, tc.key); got != tc.want {
			t.Errorf("laneSetting(%q, %q) = %q, want %q", tc.lane, tc.key, got, tc.want)
		}
	}
}

// adoptMissingRows reconciles uploads returned by cloudListAll without touching
// existing rows or adopting skipped/unrelated public ids.
func TestAdoptMissingRows(t *testing.T) {
	existing := []byte("wall/2026-11-26/existing.png\thttps://example.com/old\t10\n")
	res := []cloudResource{
		{PublicID: "assets/wall/2026-11-26/existing", SecureURL: "https://example.com/new", Bytes: 20, Format: "png"},
		{PublicID: "assets/wall/2026-11-26/catwoman-dc", SecureURL: "https://example.com/catwoman", Bytes: 30, Format: "png"},
		{PublicID: "assets/fleet/frieren", SecureURL: "https://example.com/frieren", Bytes: 40, Format: "png"},
		{PublicID: "assets/repos/ignored", SecureURL: "https://example.com/ignored", Bytes: 50, Format: "png"},
	}
	merged, added := adoptMissingRows(existing, res, nil)
	if added != 2 {
		t.Fatalf("added = %d, want 2 (%s)", added, merged)
	}
	s := string(merged)
	if strings.Contains(s, "https://example.com/new") || !strings.Contains(s, "https://example.com/old") {
		t.Fatalf("existing row mutated: %s", s)
	}
	if !strings.Contains(s, "wall/2026-11-26/catwoman-dc.png\thttps://example.com/catwoman\t30") ||
		!strings.Contains(s, "badge/frieren.png\thttps://example.com/frieren\t40") ||
		strings.Contains(s, "ignored") {
		t.Fatalf("unexpected adopted rows: %s", s)
	}
}

// --- publish.go -------------------------------------------------------------

// writeLedger materializes ledger.jsonl rows the way record() would — one
// JSON object per line — so stagePublish's read side is exercised end to end.
func writeLedger(t *testing.T, root string, rows []ledgerEntry) {
	t.Helper()
	f, err := os.Create(ledgerPath(root))
	if err != nil {
		t.Fatal(err)
	}
	enc := json.NewEncoder(f)
	for _, r := range rows {
		if err := enc.Encode(r); err != nil {
			t.Fatal(err)
		}
	}
	_ = f.Close()
}

// stagePublish copies a keep row's file into published/ under its src-relative
// path, dedupes a repeated row, peels a log line off a legacy path, and counts
// a stale path that resolves under another day as shifted while one that
// resolves nowhere is gone. Other lanes and other verdicts stay out.
func TestStagePublish(t *testing.T) {
	root := t.TempDir()
	good := root + "/src/wall/2026-11-26/a.png"
	if err := os.MkdirAll(filepath.Dir(good), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(good, []byte("PLATE"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(root+"/published/wall/2026-11-20", 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(root+"/published/wall/2026-11-20/b.png", []byte("OLD"), 0o644); err != nil {
		t.Fatal(err)
	}
	writeLedger(t, root, []ledgerEntry{
		{Lane: "wall", Path: good, Verdict: "keep"},
		{Lane: "wall", Path: good, Verdict: "keep"},                             // the same row twice is one copy
		{Lane: "wall", Path: "log line\n" + good, Verdict: "keep"},               // legacy: the path is the last line
		{Lane: "wall", Path: root + "/src/wall/2026-11-21/b.png", Verdict: "keep"}, // moved: lives under another day
		{Lane: "wall", Path: root + "/src/wall/2026-11-21/c.png", Verdict: "keep"}, // nowhere: gone
		{Lane: "wall", Path: good, Verdict: "discard"},
		{Lane: "site", Path: good, Verdict: "keep"},
	})
	shifted, gone := stagePublish(root, "wall")
	if shifted != 1 || gone != 1 {
		t.Fatalf("shifted,gone = %d,%d, want 1,1", shifted, gone)
	}
	data, err := os.ReadFile(root + "/published/wall/2026-11-26/a.png")
	if err != nil || string(data) != "PLATE" {
		t.Fatalf("staged copy: %v %q", err, data)
	}
}

// A blog keep is a 3:2 render that ships as the 1200x630 banner: bannerCrop
// does the transform, so the lane is gated on ffmpeg the way dimensions() is
// on ffprobe.
func TestStagePublishBlogCrop(t *testing.T) {
	if _, err := exec.LookPath("ffmpeg"); err != nil {
		t.Skip("ffmpeg not on PATH")
	}
	root := t.TempDir()
	src := root + "/src/blog/2026-11-26/hero.png"
	writePNG(t, src, 1536, 1024)
	writeLedger(t, root, []ledgerEntry{{Lane: "blog", Path: src, Verdict: "keep"}})
	stagePublish(root, "blog")
	jpg := root + "/published/blog/hero.jpg"
	data, err := os.ReadFile(jpg)
	if err != nil || len(data) < 3 || data[0] != 0xFF || data[1] != 0xD8 {
		t.Fatalf("banner crop did not land a JPEG at %s: %v", jpg, err)
	}
}

// mergeServedURLs unions the served manifest into urls.tsv — a host that holds
// a slice of the bank must not rewrite the manifest down to that slice. Local
// rows win a shared path, a served-only path is adopted, half-formed assets
// are skipped, and the result sorts by path.
func TestMergeServedURLs(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		fmt.Fprint(w, `{"assets":[
			{"path":"wall/2026-11-24/old.png","url":"https://res.example/old","bytes":10},
			{"path":"wall/2026-11-26/local.png","url":"https://res.example/stale","bytes":1},
			{"path":"","url":"https://res.example/no-path","bytes":1},
			{"path":"wall/half.png","url":"","bytes":1}
		]}`)
	}))
	defer srv.Close()
	t.Setenv("FORCE", "")
	t.Setenv("MERGE", "")
	t.Setenv("MERGE_FROM", srv.URL)

	root, _ := writeTree(t, "wall/2026-11-26/local.png\thttps://res.example/local\t9\n")
	mergeServedURLs(root)
	got := string(mustRead(root + "/published/urls.tsv"))
	if !strings.Contains(got, "wall/2026-11-24/old.png\thttps://res.example/old\t10") {
		t.Fatalf("served-only asset not adopted: %s", got)
	}
	if !strings.Contains(got, "wall/2026-11-26/local.png\thttps://res.example/local\t9") ||
		strings.Contains(got, "res.example/stale") {
		t.Fatalf("local row must win the shared path: %s", got)
	}
	if strings.Contains(got, "no-path") || strings.Contains(got, "half.png") {
		t.Fatalf("half-formed assets adopted: %s", got)
	}
	lines := strings.Split(strings.TrimSpace(got), "\n")
	if !slices.IsSorted(lines) || len(lines) != 2 {
		t.Fatalf("merged rows not sorted or duplicated: %v", lines)
	}
}

// The merge's three refusals to fetch — FORCE=1, MERGE=0 and an unreachable or
// non-manifest answer — each leave urls.tsv exactly as the host wrote it.
func TestMergeServedURLsSkips(t *testing.T) {
	local := "wall/2026-11-26/local.png\thttps://res.example/local\t9\n"

	hits := 0
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		hits++
		fmt.Fprint(w, `{"assets":[{"path":"wall/x.png","url":"https://res.example/x","bytes":1}]}`)
	}))
	defer srv.Close()

	for _, env := range [][2]string{{"FORCE", "1"}, {"MERGE", "0"}} {
		t.Setenv("FORCE", "")
		t.Setenv("MERGE", "")
		t.Setenv("MERGE_FROM", srv.URL)
		t.Setenv(env[0], env[1])
		root, _ := writeTree(t, local)
		mergeServedURLs(root)
		if got := string(mustRead(root + "/published/urls.tsv")); got != local {
			t.Fatalf("%s=%s rewrote urls.tsv: %s", env[0], env[1], got)
		}
	}
	if hits != 0 {
		t.Fatalf("the skip paths still fetched the manifest %d time(s)", hits)
	}

	// Unreachable and non-manifest answers are the same verdict: publish this
	// host's rows only.
	t.Setenv("FORCE", "")
	t.Setenv("MERGE", "")
	t.Setenv("MERGE_FROM", "http://127.0.0.1:1/")
	root, _ := writeTree(t, local)
	mergeServedURLs(root)
	if got := string(mustRead(root + "/published/urls.tsv")); got != local {
		t.Fatalf("unreachable manifest rewrote urls.tsv: %s", got)
	}
	bad := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(500)
		fmt.Fprint(w, "not json")
	}))
	defer bad.Close()
	t.Setenv("MERGE_FROM", bad.URL)
	root, _ = writeTree(t, local)
	mergeServedURLs(root)
	if got := string(mustRead(root + "/published/urls.tsv")); got != local {
		t.Fatalf("non-manifest answer rewrote urls.tsv: %s", got)
	}
}

// shrinkGuard's pass path: the rebuilt manifest serves at least as many rows
// as the backup names, so urls.tsv is left alone and nothing rebuilds.
func TestShrinkGuardPass(t *testing.T) {
	root, repo := writeTree(t, "wall/a.png\thttps://res.example/a\t1\n")
	if err := os.WriteFile(root+"/published/manifest.json", []byte(`{"count":5}`), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(root+"/published/.urls.served", []byte("x\tu\t1\ny\tu\t2\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	shrinkGuard(root, repo, root+"/published/.urls.served")
	if got := string(mustRead(root + "/published/urls.tsv")); got != "wall/a.png\thttps://res.example/a\t1\n" {
		t.Fatalf("urls.tsv mutated on the pass path: %s", got)
	}
	// An empty backup name is no guard at all.
	shrinkGuard(root, repo, "")
}

// The refusal: a manifest that would serve fewer rows than the backup names is
// the sliced-bank publish the guard exists to catch — restore the backup,
// rebuild the index, die naming the refusal. Subprocess because die() is
// os.Exit; the child shares the parent's tree through env so the restore is
// verifiable.
func TestShrinkGuardRefusesShrink(t *testing.T) {
	if os.Getenv("IMGTEST_DIE") == "1" {
		shrinkGuard(os.Getenv("IMGTEST_ROOT"), os.Getenv("IMGTEST_REPO"),
			os.Getenv("IMGTEST_ROOT")+"/published/.urls.served")
		return
	}
	root, repo := writeTree(t, "wall/a.png\thttps://res.example/a\t1\n")
	if err := os.WriteFile(root+"/published/manifest.json", []byte(`{"count":1}`), 0o644); err != nil {
		t.Fatal(err)
	}
	served := "x/1.png\tu\t1\ny/2.png\tu\t2\nz/3.png\tu\t3\n"
	if err := os.WriteFile(root+"/published/.urls.served", []byte(served), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(repo+"/lib/image-daily/site", 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(repo+"/lib/image-daily/site/index.html", []byte("<html>"), 0o644); err != nil {
		t.Fatal(err)
	}
	cmd := exec.Command(os.Args[0], "-test.run", "TestShrinkGuardRefusesShrink")
	cmd.Env = append(os.Environ(), "IMGTEST_DIE=1",
		"IMGTEST_ROOT="+root, "IMGTEST_REPO="+repo)
	out, err := cmd.CombinedOutput()
	exit, _ := err.(*exec.ExitError)
	if exit == nil || exit.ExitCode() != 1 {
		t.Fatalf("expected the refusal exit 1, got err=%v out=%s", err, out)
	}
	if !strings.Contains(string(out), "publish refused") {
		t.Fatalf("death should name the refusal, got: %s", out)
	}
	if got := string(mustRead(root + "/published/urls.tsv")); got != served {
		t.Fatalf("the backup was not restored: %s", got)
	}
}

// --- post.go ----------------------------------------------------------------

// fmField reads one front-matter field from a draft — the first fenced block
// only, unquoted — so a promotion inherits description/author/toc without the
// generator asking for them.
func TestFmField(t *testing.T) {
	draft := "---\ntitle: \"The Title\"\ndescription: \"the desc\"\ntoc: false\nauthor: devji\n---\nbody\ntoc: true\n"
	f := filepath.Join(t.TempDir(), "draft.md")
	if err := os.WriteFile(f, []byte(draft), 0o644); err != nil {
		t.Fatal(err)
	}
	if got := fmField(f, "description"); got != "the desc" {
		t.Fatalf("description = %q", got)
	}
	if got := fmField(f, "title"); got != "The Title" {
		t.Fatalf("quoted title = %q", got)
	}
	if got := fmField(f, "toc"); got != "false" {
		t.Fatalf("toc = %q — the body's toc:true must not be seen", got)
	}
	if got := fmField(f, "missing"); got != "" {
		t.Fatalf("missing field = %q", got)
	}
	if got := fmField(filepath.Join(t.TempDir(), "absent.md"), "title"); got != "" {
		t.Fatalf("missing file = %q", got)
	}
}

// fmBody is everything after the second fence with leading blanks dropped —
// the `n>=2` awk plus `sed '/./,$!d'` the shell used.
func TestFmBody(t *testing.T) {
	draft := "---\ntitle: x\n---\n\n\nfirst line\n\nsecond para\n"
	f := filepath.Join(t.TempDir(), "draft.md")
	if err := os.WriteFile(f, []byte(draft), 0o644); err != nil {
		t.Fatal(err)
	}
	if got := fmBody(f); got != "first line\n\nsecond para\n" {
		t.Fatalf("body = %q", got)
	}
	short := filepath.Join(t.TempDir(), "nofence.md")
	if err := os.WriteFile(short, []byte("no front matter\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if got := fmBody(short); got != "" {
		t.Fatalf("unfenced file should yield no body: %q", got)
	}
}

// verdictParts is cmd_post's read of the judge JSON: all three fields when the
// verdict is a reroll, empty strings on anything unparseable.
func TestVerdictParts(t *testing.T) {
	v, d, r := verdictParts(`{"verdict":"reroll","defect":"the composition","reason":"crowded"}`)
	if v != "reroll" || d != "the composition" || r != "crowded" {
		t.Fatalf("verdictParts = %q %q %q", v, d, r)
	}
	if v, d, r := verdictParts("not json"); v != "" || d != "" || r != "" {
		t.Fatalf("garbage JSON must not parse: %q %q %q", v, d, r)
	}
}

// cmd_post refuses before spending when SLUG is unset — the same fast-die the
// shell's `${SLUG:?}` had. Subprocess because die() is os.Exit.
func TestPostRequiresSlug(t *testing.T) {
	if os.Getenv("IMGTEST_DIE") == "1" {
		cmdPost([]string{"--root", t.TempDir(), "--repo", t.TempDir()})
		return
	}
	cmd := exec.Command(os.Args[0], "-test.run", "TestPostRequiresSlug")
	cmd.Env = append(os.Environ(), "IMGTEST_DIE=1", "SLUG=", "TITLE=", "BLOG_DIR=")
	out, err := cmd.CombinedOutput()
	exit, _ := err.(*exec.ExitError)
	if exit == nil || exit.ExitCode() != 1 {
		t.Fatalf("expected exit 1 without SLUG, got err=%v out=%s", err, out)
	}
	if !strings.Contains(string(out), "SLUG") {
		t.Fatalf("death should name SLUG, got: %s", out)
	}
}
