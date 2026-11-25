// Package image is the image-daily pipeline's data leg in Go, folded into the
// one-os-cli umbrella (tools/os). Its Main runs the image-daily verb set; the
// umbrella reaches it as `os image <verb>` or via the `image-daily` argv[0]
// alias that .#cli.image.daily installs.
//
// The first extraction is `manifest`: the jq/awk pipeline that used to live in
// scripts/task/image-daily-engine.sh (plates_description + the build_index jq
// blob). It reads urls.tsv, the judge ledger, the brief bank and the plate
// roster, and writes the manifest the Pages frontend serves — same shape, same
// key order, same description-cascade precedence, so the output is diffable
// against the shell it replaced.
//
// Stdlib only. Byte-identical replication is the contract: a manifest that
// differs from the shell output is a bug in this tool, not a data problem.
package image

import (
	"bufio"
	"bytes"
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"path"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"time"
	"unicode/utf8"
)

var tagStop = map[string]bool{
	"the": true, "and": true, "for": true, "new": true, "post": true,
	"with": true, "its": true, "this": true, "that": true, "them": true,
	"they": true, "when": true, "where": true, "which": true, "while": true,
	"your": true, "you": true, "our": true, "not": true, "one": true,
	"own": true, "out": true, "from": true, "into": true, "than": true,
	"then": true, "was": true, "were": true, "have": true, "has": true,
	"had": true, "can": true, "did": true, "get": true, "got": true,
	"just": true, "like": true, "more": true, "most": true, "about": true,
	"after": true, "before": true, "how": true, "what": true, "why": true,
	"all": true, "but": true, "any": true, "two": true, "via": true,
	"now": true, "yet": true, "also": true, "still": true, "even": true,
	"only": true, "such": true, "some": true, "been": true, "being": true,
	"both": true, "each": true, "here": true, "there": true, "these": true,
	"those": true, "under": true, "very": true, "will": true, "would": true,
	"should": true, "much": true, "many": true, "other": true, "over": true,
	"same": true, "part": true,
}

var (
	reExt      = regexp.MustCompile(`\.(png|jpg|jpeg|webp)$`)
	reDate     = regexp.MustCompile(`[0-9]{4}-[0-9]{2}-[0-9]{2}`)
	reDateSeg  = regexp.MustCompile(`^[0-9]{4}-[0-9]{2}-[0-9]{2}$`)
	reLanePfx1 = regexp.MustCompile(`^(wall|blog|badge|site)-`)
	reLanePfx2 = regexp.MustCompile(`^(char|plate)-`)
	reHold     = regexp.MustCompile(`^hold: .* :: `)
	reArch     = regexp.MustCompile(`arch:[a-z0-9-]+`)
	reTail     = regexp.MustCompile(`[ \t\n\v\f\r]*4k, photorealistic, realistic, neumorphism\.?[ \t\n\v\f\r]*$`)
	reWS       = regexp.MustCompile(`[ \t\n\v\f\r]+`)
	reDigits   = regexp.MustCompile(`^[0-9]+$`)
	reUpload   = regexp.MustCompile(`/upload/`)
	badReason  = []string{"error", "429", "backfilled", "rate limited", "agy exited"}
)

// tsvEsc replicates jq's @tsv escaping so the escaped text — not the raw
// string — is what the description cleanup sees, exactly as the awk stage did.
func tsvEsc(s string) string {
	r := strings.NewReplacer(
		`\`, `\\`,
		"\t", `\t`,
		"\n", `\n`,
		"\r", `\r`,
		"\b", `\b`,
		"\f", `\f`,
	)
	return r.Replace(s)
}

func noExt(name string) string { return reExt.ReplaceAllString(name, "") }

// cleanDesc is the awk description cleanup, in order. Counts in runes, the way
// gawk counts characters in a UTF-8 locale.
func cleanDesc(desc string) string {
	desc = reHold.ReplaceAllString(desc, "")
	desc = reArch.ReplaceAllString(desc, "")
	desc = reTail.ReplaceAllString(desc, "")
	desc = reWS.ReplaceAllString(desc, " ")
	desc = strings.TrimSpace(desc)
	if utf8.RuneCountInString(desc) > 300 {
		desc = string([]rune(desc)[:297]) + "..."
	}
	return desc
}

// jsonlObject calls fn for each line that parses as a JSON object, stopping at
// the first malformed line — the `|| true`-guarded jq stream aborts there too.
func jsonlObject(file string, fn func(map[string]json.RawMessage)) {
	f, err := os.Open(file)
	if err != nil {
		return
	}
	defer f.Close()
	sc := bufio.NewScanner(f)
	sc.Buffer(make([]byte, 1024*1024), 64*1024*1024)
	for sc.Scan() {
		line := strings.TrimSpace(sc.Text())
		if line == "" {
			continue
		}
		var v any
		if err := json.Unmarshal([]byte(line), &v); err != nil {
			return // jq aborts the whole stream on a malformed line
		}
		obj, ok := v.(map[string]any)
		if !ok {
			continue // select(type == "object")
		}
		raw := make(map[string]json.RawMessage, len(obj))
		_ = json.Unmarshal([]byte(line), &raw)
		fn(raw)
	}
}

func str(v json.RawMessage) string {
	var s string
	if len(v) > 0 && json.Unmarshal(v, &s) == nil {
		return s
	}
	return ""
}

func skipReason(r string) bool {
	l := strings.ToLower(r)
	for _, p := range badReason {
		if strings.Contains(l, p) {
			return true
		}
	}
	return false
}

// platesDescription is the four-stream description cascade, verbatim: last
// non-empty writer wins, and an empty cleaned description never overwrites.
func platesDescription(ledger, briefs, roster string) map[string]string {
	d := map[string]string{}
	add := func(slug, desc string) {
		slug, desc = tsvEsc(slug), tsvEsc(desc)
		if desc = cleanDesc(desc); desc != "" {
			d[slug] = desc
		}
	}

	// 1. Judge sentences, the weakest source.
	jsonlObject(ledger, func(o map[string]json.RawMessage) {
		if str(o["prompt"]) != "" {
			return
		}
		if r := str(o["reason"]); r != "" && !skipReason(r) {
			add(noExt(path.Base(str(o["path"]))), r)
		}
	})

	// 2. Briefs, the weakest real sentence.
	if data, err := os.ReadFile(briefs); err == nil {
		var b struct {
			Briefs []struct {
				ID     string `json:"id"`
				Prompt string `json:"prompt"`
			} `json:"briefs"`
		}
		if json.Unmarshal(data, &b) == nil {
			for _, br := range b.Briefs {
				slug := reLanePfx2.ReplaceAllString(reLanePfx1.ReplaceAllString(br.ID, ""), "")
				add(slug, br.Prompt)
			}
		}
	}

	// 3. Ledger prompts, oldest to newest.
	jsonlObject(ledger, func(o map[string]json.RawMessage) {
		if p := str(o["prompt"]); p != "" {
			add(noExt(path.Base(str(o["path"]))), p)
		}
	})

	// 4. The roster wins over an earlier ledger prompt.
	if f, err := os.Open(roster); err == nil {
		defer f.Close()
		sc := bufio.NewScanner(f)
		sc.Buffer(make([]byte, 1024*1024), 64*1024*1024)
		for sc.Scan() {
			line := sc.Text()
			if strings.HasPrefix(line, "#") {
				continue
			}
			fields := strings.Split(line, "|")
			if len(fields) < 2 {
				continue
			}
			add(fields[0], fields[1])
		}
	}
	return d
}

type asset struct {
	Path        string   `json:"path"`
	URL         string   `json:"url"`
	Bytes       int64    `json:"bytes"`
	PublicID    string   `json:"public_id"`
	Lane        string   `json:"lane"`
	Name        string   `json:"name"`
	Day         string   `json:"day"`
	Title       string   `json:"title"`
	Description string   `json:"description"`
	Shape       string   `json:"shape"`
	Enhanced    string   `json:"enhanced"`
	Tags        []string `json:"tags"`
}

type tagCount struct {
	Tag   string `json:"tag"`
	Count int    `json:"count"`
}

type manifest struct {
	GeneratedAt string     `json:"generatedAt"`
	Count       int        `json:"count"`
	Tags        []tagCount `json:"tags"`
	Assets      []asset    `json:"assets"`
}

func titleCase(name string) string {
	var parts []string
	for _, p := range strings.Split(name, "-") {
		if p == "" {
			continue
		}
		r := []rune(p)
		if r[0] >= 'a' && r[0] <= 'z' { // jq ascii_upcase, not a Unicode fold
			r[0] -= 'a' - 'A'
		}
		parts = append(parts, string(r))
	}
	return strings.Join(parts, " ")
}

func tagsFor(publicID, lane string) []string {
	seen := map[string]bool{}
	out := []string{} // a nil slice marshals null; jq emits []
	for _, seg := range strings.Split(publicID, "/") {
		if reDateSeg.MatchString(seg) {
			continue
		}
		for _, piece := range strings.Split(seg, "-") {
			for _, t := range strings.Split(piece, "_") {
				t = strings.ToLower(t)
				if utf8.RuneCountInString(t) <= 2 || reDigits.MatchString(t) ||
					t == lane || tagStop[t] || seen[t] {
					continue
				}
				seen[t] = true
				out = append(out, t)
			}
		}
	}
	sort.Strings(out) // jq `unique` sorts, then dedups
	return out
}

func die(format string, args ...any) {
	fmt.Fprintf(os.Stderr, "image-daily: "+format+"\n", args...)
	os.Exit(1)
}

func runManifest(root, repo string) {
	os.Stdout.Write(manifestJSON(root, repo))
}

func manifestJSON(root, repo string) []byte {
	urlsPath := root + "/published/urls.tsv"
	urls, err := os.Open(urlsPath)
	if err != nil {
		die("no urls.tsv at %s — the manifest is built from it", urlsPath)
	}
	defer urls.Close()

	var rows []struct {
		path, url string
		bytes     int64
	}
	sc := bufio.NewScanner(urls)
	sc.Buffer(make([]byte, 1024*1024), 64*1024*1024)
	for sc.Scan() {
		line := sc.Text()
		if line == "" {
			continue
		}
		f := strings.Split(line, "\t")
		if len(f) < 2 {
			continue
		}
		b := int64(0)
		if len(f) > 2 && f[2] != "" {
			b, err = strconv.ParseInt(f[2], 10, 64)
			if err != nil {
				die("urls.tsv: bytes %q is not a number", f[2])
			}
		}
		rows = append(rows, struct {
			path, url string
			bytes     int64
		}{f[0], f[1], b})
	}

	meta := platesDescription(root+"/ledger.jsonl", repo+"/lib/image-daily/briefs.json",
		repo+"/lib/image-daily/plates.txt")

	shapes := map[string]string{}
	if data, err := os.ReadFile(root + "/published/shapes.tsv"); err == nil {
		for _, line := range strings.Split(string(data), "\n") {
			if f := strings.Split(line, "\t"); len(f) >= 2 && f[0] != "" {
				shapes[f[0]] = f[1]
			}
		}
	}

	assets := []asset{}
	for _, r := range rows {
		// `capture` yields nothing on a dateless path, but `// ""` rescues the
		// empty generator: the row stays in the manifest with an empty day.
		day := reDate.FindString(r.path)
		publicID := noExt(r.path)
		name := path.Base(r.path)
		lane := strings.SplitN(r.path, "/", 2)[0]
		assets = append(assets, asset{
			Path:        r.path,
			URL:         r.url,
			Bytes:       r.bytes,
			PublicID:    publicID,
			Lane:        lane,
			Name:        name,
			Day:         day,
			Title:       titleCase(noExt(name)),
			Description: meta[noExt(name)],
			Shape:       shapes[r.path],
			Enhanced: reUpload.ReplaceAllString(r.url,
				"/upload/w_2400,c_limit,e_sharpen:70,q_auto:best,f_auto/"),
			Tags: tagsFor(publicID, lane),
		})
	}
	sort.Slice(assets, func(i, j int) bool { return assets[i].Path < assets[j].Path })

	counts := map[string]int{}
	for _, a := range assets {
		for _, t := range a.Tags {
			counts[t]++
		}
	}
	tags := make([]tagCount, 0, len(counts))
	for t, c := range counts {
		tags = append(tags, tagCount{t, c})
	}
	sort.Slice(tags, func(i, j int) bool {
		if tags[i].Count != tags[j].Count {
			return tags[i].Count > tags[j].Count
		}
		return tags[i].Tag < tags[j].Tag
	})

	m := manifest{
		GeneratedAt: time.Now().UTC().Format("2006-01-02T15:04:05Z"),
		Count:       len(assets),
		Tags:        tags,
		Assets:      assets,
	}
	var buf bytes.Buffer
	enc := json.NewEncoder(&buf)
	enc.SetEscapeHTML(false)
	enc.SetIndent("", "  ")
	if err := enc.Encode(m); err != nil {
		die("manifest encode: %v", err)
	}
	return buf.Bytes()
}

func Main(args []string) {
	if len(args) < 1 {
		die("usage: image-daily <manifest|judge|attempt|lane|stage|adopt|remaining|share|pending|shapes|reason|archive|resolve|dimensions|landscape|crop|deploy|publish|post|plates|round|lanes|budget|setting|guard|due|parked|record|index|shrink-guard|ship-detach|served|cloudinary|gen|gen-batch|gen-detach> [flags]")
	}
	switch args[0] {
	case "manifest":
		fs := flag.NewFlagSet("manifest", flag.ExitOnError)
		root := fs.String("root", os.Getenv("IMAGES_ROOT"), "image tree root (IMAGES_ROOT)")
		repo := fs.String("repo", os.Getenv("REPO"), "nixconfig checkout root (REPO)")
		_ = fs.Parse(args[1:])
		if *root == "" || *repo == "" {
			die("manifest needs --root and --repo (or IMAGES_ROOT and REPO)")
		}
		runManifest(*root, *repo)
	case "judge":
		cmdJudge(args[1:])
	case "attempt":
		cmdAttempt(args[1:])
	case "lane":
		cmdLane(args[1:])
	case "stage":
		cmdStage(args[1:])
	case "adopt":
		cmdAdopt(args[1:])
	case "remaining":
		cmdRemaining()
	case "share":
		cmdShare(args[1:])
	case "pending":
		cmdPending(args[1:])
	case "shapes":
		cmdShapes(args[1:])
	case "reason":
		cmdReason(args[1:])
	case "archive":
		cmdArchive(args[1:])
	case "resolve":
		cmdResolve(args[1:])
	case "dimensions":
		cmdDimensions(args[1:])
	case "landscape":
		cmdLandscape(args[1:])
	case "crop":
		cmdCrop(args[1:])
	case "deploy":
		cmdDeploy(args[1:])
	case "publish":
		cmdPublish(args[1:])
	case "post":
		cmdPost(args[1:])
	case "plates":
		cmdPlates(args[1:])
	case "round":
		cmdRound(args[1:])
	case "lanes":
		cmdLanes(args[1:])
	case "budget":
		cmdBudget(args[1:])
	case "setting":
		cmdSetting(args[1:])
	case "guard":
		cmdGuard(args[1:])
	case "due":
		cmdDue(args[1:])
	case "parked":
		cmdParked(args[1:])
	case "record":
		cmdRecord(args[1:])
	case "index":
		cmdIndex(args[1:])
	case "shrink-guard":
		cmdShrinkGuard(args[1:])
	case "ship-detach":
		cmdShipDetach(args[1:])
	case "served":
		cmdServed(args[1:])
	case "cloudinary":
		cmdCloudinary(args[1:])
	case "gen":
		cmdGen(args[1:])
	case "gen-batch":
		cmdGenBatch(args[1:])
	case "gen-detach":
		cmdGenDetach(args[1:])
	default:
		die("usage: image-daily <manifest|judge|attempt|lane|stage|adopt|remaining|share|pending|shapes|reason|archive|resolve|dimensions|landscape|crop|deploy|publish|post|plates|round|lanes|budget|setting|guard|due|parked|record|index|shrink-guard|ship-detach|served|cloudinary|gen|gen-batch|gen-detach> [flags]")
	}
}
