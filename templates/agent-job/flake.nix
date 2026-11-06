{
  description = "A one-shot browser check: open a URL, snapshot it, write a JSON verdict — shaped to run as a clanker job";

  nixConfig = {
    extra-substituters = [
      "https://cache.numtide.com"
      "https://nix-community.cachix.org"
      "https://cache.nixos.org/"
    ];
    extra-trusted-public-keys = [
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    llm-agents.url = "github:numtide/llm-agents.nix";
  };

  outputs = {
    self,
    nixpkgs,
    llm-agents,
  }: let
    systems = ["x86_64-linux" "aarch64-linux"];
    forAll = f: nixpkgs.lib.genAttrs systems (system: f system nixpkgs.legacyPackages.${system});
  in {
    packages = forAll (system: pkgs: let
      check = pkgs.writeShellApplication {
        name = "page-check";
        runtimeInputs = [
          llm-agents.packages.${system}.agent-browser
          pkgs.jq
          pkgs.coreutils
        ];
        text = ''
          set -euo pipefail
          url="''${1:?usage: page-check <url> [out.json]}"
          out="''${2:-$PWD/page-check.json}"
          snap="$(mktemp)"
          shot="''${out%.json}.png"
          trap 'agent-browser close >/dev/null 2>&1 || true; rm -f "$snap"' EXIT

          ok=false
          err=""
          if timeout 120 agent-browser open "$url" >/dev/null 2>&1; then
            if timeout 60 agent-browser snapshot >"$snap" 2>/dev/null; then ok=true; fi
          else
            err="open failed or timed out"
          fi
          timeout 60 agent-browser screenshot "$shot" >/dev/null 2>&1 || true

          # The verdict is the deliverable: a job that dies mid-browser still
          # leaves a file saying so, which is what makes it restartable.
          jq -n \
            --arg url "$url" \
            --argjson ok "$ok" \
            --arg err "$err" \
            --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
            --arg shot "$shot" \
            --arg excerpt "$(head -c 2000 "$snap" 2>/dev/null || true)" \
            '{url: $url, ok: $ok, error: $err, ts: $ts, screenshot: $shot, snapshot_excerpt: $excerpt}' >"$out"
          jq -c '{url, ok, error, screenshot}' "$out"
          test "$ok" = true
        '';
      };
    in {
      inherit check;
      default = check;
    });

    apps = forAll (system: _pkgs: {
      default = {
        type = "app";
        program = "${self.packages.${system}.check}/bin/page-check";
      };
    });
  };
}
