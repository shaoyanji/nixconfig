package image

// cloudinary.go — the bank client, ported from scripts/task/cloudinary.sh:
// one credential reader (sops → CLOUDINARY.{NAME,API.KEY,API.SECRET}), one
// signing path (sha1 over the alphabetical param string plus the secret) and
// upload/list/destroy against api.cloudinary.com. The helpers return errors
// so the unit tests run them in-process; cmdCloudinary is the die() wrapper
// the shell contract needs — refusals on stderr, the URL, ids or the
// destroyed id on stdout, exit 1.

import (
	"bytes"
	"crypto/sha1"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"mime/multipart"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"time"
)

// cloudBase is a var so the tests point the client at httptest.
var cloudBase = "https://api.cloudinary.com"

type cloudCreds struct{ name, key, secret string }

// cloudinaryCreds is one decrypt, three fields — the shell's own comment:
// three separate sops calls is three age ops per image.
func cloudinaryCreds(repo string) (cloudCreds, error) {
	var c struct {
		Name string `json:"NAME"`
		API  struct {
			Key    string `json:"KEY"`
			Secret string `json:"SECRET"`
		} `json:"API"`
	}
	raw := secretGet(repo, `["CLOUDINARY"]`)
	if err := json.Unmarshal([]byte(raw), &c); err != nil {
		return cloudCreds{}, errors.New("CLOUDINARY not in the apikeys file (is the modules/secrets submodule checked out?)")
	}
	if c.Name == "" || c.API.Key == "" || c.API.Secret == "" {
		return cloudCreds{}, errors.New("CLOUDINARY.NAME, CLOUDINARY.API.KEY and CLOUDINARY.API.SECRET are all required")
	}
	return cloudCreds{c.Name, c.API.Key, c.API.Secret}, nil
}

// cloudSign is the shell's sha1 of the alphabetical signed-param string with
// the secret appended: file and api_key are never part of it.
func cloudSign(secret string, params map[string]string) string {
	keys := make([]string, 0, len(params))
	for k := range params {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	parts := make([]string, len(keys))
	for i, k := range keys {
		parts[i] = k + "=" + params[k]
	}
	sum := sha1.Sum([]byte(strings.Join(parts, "&") + secret))
	return hex.EncodeToString(sum[:])
}

// cloudPost sends one multipart body — file field first when there is one —
// and decodes the reply. Cloudinary answers every refusal as
// {"error":{"message": ...}} with a 200-class or 4xx status, so the error
// field is checked before the caller's own keys.
func cloudPost(path string, fields map[string]string, fileField, filePath string, out any) error {
	var body bytes.Buffer
	w := multipart.NewWriter(&body)
	if fileField != "" {
		f, err := os.Open(filePath)
		if err != nil {
			return err
		}
		fw, err := w.CreateFormFile(fileField, filepath.Base(filePath))
		if err != nil {
			f.Close()
			return err
		}
		if _, err := io.Copy(fw, f); err != nil {
			f.Close()
			return err
		}
		f.Close()
	}
	keys := make([]string, 0, len(fields))
	for k := range fields {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	for _, k := range keys {
		_ = w.WriteField(k, fields[k])
	}
	if err := w.Close(); err != nil {
		return err
	}
	req, err := http.NewRequest(http.MethodPost, cloudBase+path, &body)
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", w.FormDataContentType())
	resp, err := (&http.Client{Timeout: 120 * time.Second}).Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if err := json.NewDecoder(resp.Body).Decode(out); err != nil {
		return fmt.Errorf("cloudinary: unreadable response: %v", err)
	}
	return nil
}

// cloudUpload posts file to image/upload with the signature. Cloudinary
// signs folder OR public_id, never both — with a folder in the request the
// public_id is excluded from the string to sign, and signing both answers
// "Invalid Signature". A caller wanting a nested id passes it whole.
func cloudUpload(c cloudCreds, file, folder, publicID string) (string, error) {
	if _, err := os.Stat(file); err != nil {
		return "", fmt.Errorf("no such file: %s", file)
	}
	ts := strconv.FormatInt(time.Now().Unix(), 10)
	if publicID != "" && folder != "" {
		publicID = folder + "/" + publicID
	}
	sign := map[string]string{"timestamp": ts}
	switch {
	case publicID != "":
		sign["public_id"] = publicID
	case folder != "":
		sign["folder"] = folder
	}
	fields := map[string]string{
		"api_key": c.key, "timestamp": ts, "signature": cloudSign(c.secret, sign),
	}
	if publicID != "" {
		fields["public_id"] = publicID
	} else if folder != "" {
		fields["folder"] = folder
	}
	var out struct {
		SecureURL string `json:"secure_url"`
		Error     *struct {
			Message string `json:"message"`
		} `json:"error"`
	}
	if err := cloudPost("/v1_1/"+c.name+"/image/upload", fields, "file", file, &out); err != nil {
		return "", err
	}
	if out.Error != nil {
		return "", errors.New("upload refused: " + out.Error.Message)
	}
	if out.SecureURL == "" {
		return "", errors.New("no secure_url in the response")
	}
	return out.SecureURL, nil
}

type cloudResource struct {
	PublicID  string `json:"public_id"`
	SecureURL string `json:"secure_url"`
	Bytes     int    `json:"bytes"`
	Format    string `json:"format"`
	CreatedAt string `json:"created_at"`
}

// cloudListAll pages the admin API — basic auth, nothing to sign, cursor
// until the account is read out in full. The page size is large on purpose:
// 500 resources is where the shell's printf-into-jq argument list overflowed
// (2026-11-21), and a streamed response has no such ceiling.
func cloudListAll(c cloudCreds, prefix string, max int) ([]cloudResource, error) {
	var all []cloudResource
	cursor := ""
	client := &http.Client{Timeout: 60 * time.Second}
	for {
		u := fmt.Sprintf("%s/v1_1/%s/resources/image?type=upload&max_results=%d&prefix=%s",
			cloudBase, c.name, max, url.QueryEscape(prefix))
		if cursor != "" {
			u += "&next_cursor=" + url.QueryEscape(cursor)
		}
		req, err := http.NewRequest(http.MethodGet, u, nil)
		if err != nil {
			return nil, err
		}
		req.SetBasicAuth(c.key, c.secret)
		resp, err := client.Do(req)
		if err != nil {
			return nil, err
		}
		var page struct {
			Resources  []cloudResource `json:"resources"`
			NextCursor string          `json:"next_cursor"`
			Error      *struct {
				Message string `json:"message"`
			} `json:"error"`
		}
		derr := json.NewDecoder(resp.Body).Decode(&page)
		resp.Body.Close()
		if derr != nil {
			return nil, fmt.Errorf("cloudinary: unreadable list response: %v", derr)
		}
		if page.Error != nil {
			return nil, errors.New("list refused: " + page.Error.Message)
		}
		all = append(all, page.Resources...)
		if page.NextCursor == "" {
			return all, nil
		}
		cursor = page.NextCursor
	}
}

// cloudDestroy posts image/destroy and wants {"result":"ok"} back — anything
// else is the refusal the shell printed.
func cloudDestroy(c cloudCreds, id string) error {
	ts := strconv.FormatInt(time.Now().Unix(), 10)
	fields := map[string]string{
		"public_id": id, "api_key": c.key, "timestamp": ts,
		"signature": cloudSign(c.secret, map[string]string{"public_id": id, "timestamp": ts}),
	}
	var out struct {
		Result string `json:"result"`
		Error  *struct {
			Message string `json:"message"`
		} `json:"error"`
	}
	if err := cloudPost("/v1_1/"+c.name+"/image/destroy", fields, "", "", &out); err != nil {
		return err
	}
	res := out.Result
	if res == "" && out.Error != nil {
		res = out.Error.Message
	}
	if res != "ok" {
		return fmt.Errorf("destroy %s: %s", id, res)
	}
	return nil
}

// `image-daily cloudinary <upload|url|list|destroy>` — same argv shape and
// stdout contract as cloudinary.sh, so the add, blog and gc shims swap one
// command word and nothing else. The arg scan is the shell's own `while`
// loop: a flag takes the next word, the first bare word is the positional.
func cmdCloudinary(args []string) {
	if len(args) == 0 {
		die("usage: image-daily cloudinary <upload FILE [--folder F] [--public-id ID]|url ID [--transform T]|list [--prefix P] [--max N] [--json]|destroy ID> [--repo PATH]")
	}
	sub, rest := args[0], args[1:]
	repo := os.Getenv("REPO")
	positional, prefix, folder, publicID := "", "", "", ""
	transform, max, jsonRows := "f_auto,q_auto", 500, false
	for i := 0; i < len(rest); i++ {
		val := func(name string) string {
			i++
			if i >= len(rest) {
				die("cloudinary %s: %s needs a value", sub, name)
			}
			return rest[i]
		}
		switch rest[i] {
		case "--repo":
			repo = val("--repo")
		case "--folder":
			folder = val("--folder")
		case "--public-id":
			publicID = val("--public-id")
		case "--transform":
			transform = val("--transform")
		case "--prefix":
			prefix = val("--prefix")
		case "--max":
			n, err := strconv.Atoi(val("--max"))
			if err != nil || n <= 0 {
				die("cloudinary list: --max needs a positive number")
			}
			max = n
		case "--json":
			jsonRows = true
		default:
			if strings.HasPrefix(rest[i], "-") {
				die("cloudinary %s: unknown argument %s", sub, rest[i])
			}
			if positional != "" {
				die("cloudinary %s: unexpected extra argument %s", sub, rest[i])
			}
			positional = rest[i]
		}
	}
	if repo == "" {
		die("cloudinary needs --repo or REPO (the credentials live in the checkout)")
	}
	c, err := cloudinaryCreds(repo)
	if err != nil {
		die("cloudinary: %v", err)
	}
	switch sub {
	case "upload":
		if positional == "" {
			die("cloudinary upload needs a file")
		}
		u, err := cloudUpload(c, positional, folder, publicID)
		if err != nil {
			die("cloudinary: %v", err)
		}
		fmt.Println(u)
	case "url":
		if positional == "" {
			die("cloudinary url needs a public id")
		}
		fmt.Printf("https://res.cloudinary.com/%s/image/upload/%s/%s\n", c.name, transform, positional)
	case "list":
		res, err := cloudListAll(c, prefix, max)
		if err != nil {
			die("cloudinary: %v", err)
		}
		for _, r := range res {
			if jsonRows {
				row, _ := json.Marshal(r)
				fmt.Println(string(row))
			} else {
				fmt.Println(r.PublicID)
			}
		}
	case "destroy":
		if positional == "" {
			die("cloudinary destroy needs a public id")
		}
		if err := cloudDestroy(c, positional); err != nil {
			die("cloudinary: %v", err)
		}
		fmt.Println(positional)
	default:
		die("cloudinary: unknown command %s (upload|url|list|destroy)", sub)
	}
}
