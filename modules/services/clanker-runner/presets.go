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

type jobPreset struct {
	ID          string   `json:"id"`
	Name        string   `json:"name"`
	Description string   `json:"description"`
	Kind        string   `json:"kind"`
	Machine     string   `json:"machine"`
	Required    []string `json:"required,omitempty"`
	Optional    []string `json:"optional,omitempty"`
}

type presetInput struct {
	Machine  string `json:"machine"`
	URL      string `json:"url"`
	Selector string `json:"selector"`
	Package  string `json:"package"`
	Args     string `json:"args"`
}

var (
	machineNameRE = regexp.MustCompile(`^[a-zA-Z0-9][a-zA-Z0-9_.-]{0,63}$`)
	packageNameRE = regexp.MustCompile(`^[a-zA-Z0-9][a-zA-Z0-9+_.-]{0,80}$`)
	selectorRE    = regexp.MustCompile(`^[a-zA-Z0-9_#.,:*\[\]="' ()>+~-]{1,160}$`)
	plainArgsRE   = regexp.MustCompile(`^[a-zA-Z0-9_+.,:/@#%= -]{0,500}$`)
)

var jobPresets = []jobPreset{
	{ID: "agent-browser-dom-check", Name: "agent-browser DOM check", Description: "Open a page in agent-browser and dump a small DOM visibility probe.", Kind: "agent-browser", Machine: "clanker", Required: []string{"url"}, Optional: []string{"selector"}},
	{ID: "nix-profile-status", Name: "Nix profile status", Description: "Report generations, profile packages, nix version and store health without changing the profile.", Kind: "shell", Machine: "clanker"},
	{ID: "clanker-disk-hygiene", Name: "clanker disk hygiene", Description: "Report filesystem pressure, largest /data consumers and a non-destructive Nix GC dry run.", Kind: "shell", Machine: "clanker"},
	{ID: "nix-run-tool", Name: "run a nixpkgs tool", Description: "Run one validated nixpkgs package with constrained plain-text arguments.", Kind: "shell", Machine: "clanker", Required: []string{"package"}, Optional: []string{"args"}},
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
		rawURL := strings.TrimSpace(input.URL)
		if rawURL == "" {
			return jobInput{}, errors.New("url is required")
		}
		parsed, err := url.Parse(rawURL)
		if err != nil || (parsed.Scheme != "http" && parsed.Scheme != "https") || parsed.Host == "" {
			return jobInput{}, errors.New("url must be an absolute http or https URL")
		}
		selector := strings.TrimSpace(input.Selector)
		if selector == "" {
			selector = "body"
		}
		if !selectorRE.MatchString(selector) {
			return jobInput{}, errors.New("selector is not a constrained CSS selector")
		}
		args := "open " + shellQuote(rawURL) + " && agent-browser eval " + shellQuote(`(() => { const el = document.querySelector(`+selector+`); return {title: document.title, url: location.href, selector_found: !!el, text: (el?.innerText || '').slice(0, 1000)} })()`)
		base.Args = args
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
