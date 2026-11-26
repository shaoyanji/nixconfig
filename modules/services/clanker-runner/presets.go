package main

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"net/url"
	"regexp"
	"strings"
)

type presetParam struct {
	Name        string `json:"name"`
	Type        string `json:"type"`
	Required    bool   `json:"required,omitempty"`
	Description string `json:"description"`
}

type jobPreset struct {
	ID          string        `json:"id"`
	Name        string        `json:"name"`
	Description string        `json:"description"`
	Kind        string        `json:"kind"`
	Machine     string        `json:"machine"`
	Required    []string      `json:"required,omitempty"`
	Optional    []string      `json:"optional,omitempty"`
	Params      []presetParam `json:"params,omitempty"`
}

type presetInput struct {
	Machine  string `json:"machine"`
	URL      string `json:"url"`
	Selector string `json:"selector"`
	Package  string `json:"package"`
	Args     string `json:"args"`
	Flake    string `json:"flake"`
	Attr     string `json:"attr"`
	Dir      string `json:"dir"`
	Target   string `json:"target"`
}

var (
	machineNameRE = regexp.MustCompile(`^[a-zA-Z0-9][a-zA-Z0-9_.-]{0,63}$`)
	packageNameRE = regexp.MustCompile(`^[a-zA-Z0-9][a-zA-Z0-9+_.-]{0,80}$`)
	selectorRE    = regexp.MustCompile(`^[a-zA-Z0-9_#.,:*\[\]="' ()>+~-]{1,160}$`)
	plainArgsRE   = regexp.MustCompile(`^[a-zA-Z0-9_+.,:/@#%= -]{0,500}$`)
	flakeRefRE    = regexp.MustCompile(`^[a-zA-Z0-9_+.,:/@#%=?&-]{1,240}$`)
	dataDirRE     = regexp.MustCompile(`^/data/[a-zA-Z0-9_+.,/@=-]{1,160}$`)
	buildTargetRE = regexp.MustCompile(`^[a-zA-Z0-9_+.,:/@#%=-]{0,160}$`)
)

var jobPresets = []jobPreset{
	{ID: "agent-browser-dom-check", Name: "agent-browser DOM check", Description: "Open a page in agent-browser and dump a small DOM visibility probe.", Kind: "agent-browser", Machine: "clanker", Required: []string{"url"}, Optional: []string{"selector"}, Params: []presetParam{{Name: "url", Type: "url", Required: true}, {Name: "selector", Type: "css-selector"}}},
	{ID: "agent-browser-screenshot", Name: "agent-browser screenshot artifact", Description: "Capture a DOM probe and screenshot into the job artifact archive.", Kind: "agent-browser", Machine: "clanker", Required: []string{"url"}, Optional: []string{"selector"}, Params: []presetParam{{Name: "url", Type: "url", Required: true}, {Name: "selector", Type: "css-selector"}}},
	{ID: "nix-flake-check", Name: "Nix flake check", Description: "Run nix flake check for a validated flake reference on clanker.", Kind: "shell", Machine: "clanker", Optional: []string{"flake"}, Params: []presetParam{{Name: "flake", Type: "flake-ref"}}},
	{ID: "nix-flake-build", Name: "Nix flake build", Description: "Build one validated flake output with --no-link and keep the log as an artifact.", Kind: "shell", Machine: "clanker", Required: []string{"attr"}, Optional: []string{"flake"}, Params: []presetParam{{Name: "attr", Type: "flake-attr", Required: true}, {Name: "flake", Type: "flake-ref"}}},
	{ID: "nix-profile-status", Name: "Nix profile status", Description: "Report generations, profile packages, nix version and store health without changing the profile.", Kind: "shell", Machine: "clanker"},
	{ID: "nix-store-hygiene", Name: "Nix store hygiene", Description: "Measure store pressure, GC dry-run output, temp roots and largest store paths without deleting anything.", Kind: "shell", Machine: "clanker"},
	{ID: "clanker-disk-hygiene", Name: "clanker disk hygiene", Description: "Report filesystem pressure, largest /data consumers and a non-destructive Nix GC dry run.", Kind: "shell", Machine: "clanker"},
	{ID: "go-cli-build", Name: "Go CLI build in /data", Description: "Run go test and go build in a validated /data checkout; build output stays in the job artifact archive when the project writes it there.", Kind: "shell", Machine: "clanker", Required: []string{"dir"}, Optional: []string{"target"}, Params: []presetParam{{Name: "dir", Type: "data-path", Required: true}, {Name: "target", Type: "build-target"}}},
	{ID: "rust-cli-build", Name: "Rust CLI build in /data", Description: "Run cargo test and cargo build in a validated /data checkout.", Kind: "shell", Machine: "clanker", Required: []string{"dir"}, Optional: []string{"target"}, Params: []presetParam{{Name: "dir", Type: "data-path", Required: true}, {Name: "target", Type: "build-target"}}},
	{ID: "nix-run-tool", Name: "run a nixpkgs tool", Description: "Run one validated nixpkgs package with constrained plain-text arguments.", Kind: "shell", Machine: "clanker", Required: []string{"package"}, Optional: []string{"args"}, Params: []presetParam{{Name: "package", Type: "package", Required: true}, {Name: "args", Type: "plain-args"}}},
}

func presetByID(id string) (jobPreset, bool) {
	if strings.TrimSpace(id) == "agent-browser" {
		id = "agent-browser-dom-check"
	}
	for _, preset := range jobPresets {
		if preset.ID == strings.TrimSpace(id) {
			return preset, true
		}
	}
	return jobPreset{}, false
}

func presetInputFromParams(raw json.RawMessage) (presetInput, error) {
	input := presetInput{}
	if len(raw) == 0 || string(raw) == "null" {
		return input, nil
	}
	decoder := json.NewDecoder(bytes.NewReader(raw))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(&input); err != nil {
		return input, err
	}
	return input, nil
}

func validateMachineName(value string) (string, error) {
	value = strings.TrimSpace(value)
	if value == "" {
		value = "clanker"
	}
	if !machineNameRE.MatchString(value) {
		return "", errors.New("machine may contain only letters, numbers, dot, underscore and dash")
	}
	return value, nil
}

func validatePlainArgs(value string) error {
	if !plainArgsRE.MatchString(value) {
		return errors.New("args must be plain space-separated text without shell syntax or control characters")
	}
	return nil
}

func validateFlakeRef(value, fallback string) (string, error) {
	value = strings.TrimSpace(value)
	if value == "" {
		value = fallback
	}
	if !flakeRefRE.MatchString(value) || strings.Contains(value, "..") {
		return "", errors.New("flake reference contains unsupported characters")
	}
	return value, nil
}

func validateDataDir(value string) (string, error) {
	value = strings.TrimSpace(value)
	if !dataDirRE.MatchString(value) || strings.Contains(value, "..") {
		return "", errors.New("dir must be a constrained absolute path under /data")
	}
	return value, nil
}

func validateBuildTarget(value string) error {
	if !buildTargetRE.MatchString(value) || strings.Contains(value, "..") {
		return errors.New("target contains unsupported characters")
	}
	return nil
}

func validateBrowserURL(rawURL string) (string, error) {
	rawURL = strings.TrimSpace(rawURL)
	if rawURL == "" {
		return "", errors.New("url is required")
	}
	parsed, err := url.Parse(rawURL)
	if err != nil || (parsed.Scheme != "http" && parsed.Scheme != "https") || parsed.Host == "" {
		return "", errors.New("url must be an absolute http or https URL")
	}
	return rawURL, nil
}

func validateSelector(selector string) (string, error) {
	selector = strings.TrimSpace(selector)
	if selector == "" {
		selector = "body"
	}
	if !selectorRE.MatchString(selector) {
		return "", errors.New("selector is not a constrained CSS selector")
	}
	return selector, nil
}

func buildPresetJob(presetID string, input presetInput) (jobInput, error) {
	preset, ok := presetByID(presetID)
	if !ok {
		return jobInput{}, fmt.Errorf("unknown preset %q", presetID)
	}
	machine, err := validateMachineName(input.Machine)
	if err != nil {
		return jobInput{}, err
	}
	if machine == "clanker" && preset.Machine != "" {
		machine = preset.Machine
	}
	base := jobInput{Machine: machine, Kind: preset.Kind}
	switch preset.ID {
	case "agent-browser-dom-check":
		rawURL, err := validateBrowserURL(input.URL)
		if err != nil {
			return jobInput{}, err
		}
		selector, err := validateSelector(input.Selector)
		if err != nil {
			return jobInput{}, err
		}
		args := "open " + shellQuote(rawURL) + " && agent-browser eval " + shellQuote(`(() => { const el = document.querySelector(`+selector+`); return {title: document.title, url: location.href, selector_found: !!el, text: (el?.innerText || '').slice(0, 1000)} })()`)
		base.Args = args
		return base, nil
	case "agent-browser-screenshot":
		rawURL, err := validateBrowserURL(input.URL)
		if err != nil {
			return jobInput{}, err
		}
		selector, err := validateSelector(input.Selector)
		if err != nil {
			return jobInput{}, err
		}
		probe := shellQuote(`(() => { const el = document.querySelector(` + selector + `); return {title: document.title, url: location.href, selector_found: !!el, text: (el?.innerText || '').slice(0, 4000)} })()`)
		base.Args = `open ` + shellQuote(rawURL) + ` && agent-browser eval ` + probe + ` | tee artifacts/dom-probe.json && (agent-browser screenshot artifacts/page.png || agent-browser capture artifacts/page.png || true)`
		return base, nil
	case "nix-flake-check":
		flake, err := validateFlakeRef(input.Flake, "/data/nixconfig")
		if err != nil {
			return jobInput{}, err
		}
		base.Command = `set -o pipefail
export PATH="$HOME/.nix-profile/bin:$PATH"
nix flake check -L ` + shellQuote(flake) + ` 2>&1 | tee artifacts/nix-flake-check.log`
		return base, nil
	case "nix-flake-build":
		flake, err := validateFlakeRef(input.Flake, "/data/nixconfig")
		if err != nil {
			return jobInput{}, err
		}
		attr := strings.TrimSpace(input.Attr)
		if attr == "" || !buildTargetRE.MatchString(attr) || strings.Contains(attr, "..") {
			return jobInput{}, errors.New("attr is required and must be a constrained flake output")
		}
		if strings.HasPrefix(attr, ".#") {
			attr = strings.TrimPrefix(attr, ".")
		} else if !strings.HasPrefix(attr, "#") {
			attr = "#" + attr
		}
		base.Command = `set -o pipefail
export PATH="$HOME/.nix-profile/bin:$PATH"
nix build -L ` + shellQuote(flake+attr) + ` --no-link 2>&1 | tee artifacts/nix-flake-build.log`
		return base, nil
	case "nix-profile-status":
		base.Command = `set -euo pipefail
export PATH="$HOME/.nix-profile/bin:$PATH"
printf '%s\n' '== nix version =='
nix --version || true
printf '%s\n' '== profile generations =='
nix profile history 2>&1 || nix-env --list-generations 2>&1 || true
printf '%s\n' '== profile packages =='
nix profile list 2>&1 || nix-env -q 2>&1 || true
printf '%s\n' '== store =='
df -h /nix/store 2>/dev/null || df -h /`
		return base, nil
	case "clanker-disk-hygiene":
		base.Command = `set -euo pipefail
printf '%s\n' '== filesystems =='
df -h / /data 2>/dev/null || df -h /
printf '%s\n' '== largest /data entries =='
du -xhd1 /data 2>/dev/null | sort -hr | head -20 || true
printf '%s\n' '== nix gc dry run =='
nix store gc --dry-run 2>&1 || nix-collect-garbage --dry-run 2>&1 || true`
		return base, nil
	case "nix-store-hygiene":
		base.Command = `set -o pipefail
export PATH="$HOME/.nix-profile/bin:$PATH"
{
printf '%s
' '== store filesystem =='
df -h /nix/store / 2>/dev/null || df -h /
printf '%s
' '== store size =='
du -sh /nix/store 2>/dev/null || true
printf '%s
' '== gc dry run =='
nix store gc --dry-run 2>&1 || nix-collect-garbage --dry-run 2>&1 || true
printf '%s
' '== temp roots =='
nix-store --gc --print-roots 2>/dev/null | grep -E '(tmp|delete)' | head -30 || true
} 2>&1 | tee artifacts/nix-store-hygiene.log`
		return base, nil
	case "go-cli-build", "rust-cli-build":
		dir, err := validateDataDir(input.Dir)
		if err != nil {
			return jobInput{}, err
		}
		target := strings.TrimSpace(input.Target)
		if err := validateBuildTarget(target); err != nil {
			return jobInput{}, err
		}
		tool := "go"
		build := "go test ./... && go build -o artifacts/cli.bin"
		if target != "" {
			build = "go test " + target + " && go build -o artifacts/cli.bin " + target
		}
		if preset.ID == "rust-cli-build" {
			tool = "cargo"
			build = "cargo test --locked && cargo build --locked --target-dir artifacts/target"
			if target != "" {
				build = "cargo test --locked " + target + " && cargo build --locked --target-dir artifacts/target " + target
			}
		}
		base.Command = `set -o pipefail
cd ` + shellQuote(dir) + `
export PATH="$HOME/.nix-profile/bin:$PATH"
{ ` + build + ` ; } 2>&1 | tee artifacts/` + tool + `-build.log`
		return base, nil
	case "nix-run-tool":
		pkg := strings.TrimSpace(input.Package)
		if !packageNameRE.MatchString(pkg) {
			return jobInput{}, errors.New("package is required and may contain only letters, numbers, plus, dot, underscore and dash")
		}
		args := strings.TrimSpace(input.Args)
		if err := validatePlainArgs(args); err != nil {
			return jobInput{}, err
		}
		command := `set -euo pipefail
export PATH="$HOME/.nix-profile/bin:$PATH"
nix run nixpkgs#` + pkg
		if args != "" {
			command += " -- " + args
		}
		base.Command = command
		return base, nil
	default:
		return jobInput{}, fmt.Errorf("preset %q has no builder", preset.ID)
	}
}
