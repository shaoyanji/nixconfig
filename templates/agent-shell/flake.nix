{
  description = "Browser-shaped agent work in a shell: agent-browser + JSON tools, prebuilt on cache.numtide.com";

  # The substituter is the point of this template: agent-browser carries its own
  # Chromium (~700 MiB), and on `cache.numtide.com` that is a download, not a
  # compile. A box that has to compile it is the box this template exists to
  # avoid.
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
    devShells = forAll (system: pkgs: {
      default = pkgs.mkShell {
        packages = [
          llm-agents.packages.${system}.agent-browser
          # Real packages, on PATH: `nix develop -c` builds its environment from
          # scratch, so an exported shell function does not survive into the
          # command's shell (measured twice, 2026-11-06).
          self.packages.${system}.browse
          self.packages.${system}.shot
          pkgs.jq
          pkgs.curl
          pkgs.nodejs_22
          pkgs.python3
        ];
        # Shell functions, not packages: `nix develop -c` runs the command inside
        # this environment, so a function here is reachable where a package's
        # PATH entry is not. Both verbs are bounded — a chatty `open` is the
        # known failure — and both close the browser on the way out.
        shellHook = ''
          echo "agent-shell: $(agent-browser --version 2>/dev/null | head -1)"
          echo "  browse <url>        bounded open + accessibility snapshot"
          echo "  shot <url> <png>    headless screenshot, then close"
        '';
      };
    });

    # Two verbs, not a browser API: an agent needs a snapshot (text) and
    # sometimes a screenshot (pixels), and both must be bounded — a chatty
    # `open` is the known failure, so timeouts live here rather than in the
    # agent's head.
    packages = forAll (system: pkgs: let
      browser = llm-agents.packages.${system}.agent-browser;
      browse = pkgs.writeShellApplication {
        name = "browse";
        runtimeInputs = [browser pkgs.coreutils];
        text = ''
          set -euo pipefail
          url="''${1:?usage: browse <url>}"
          trap 'agent-browser close >/dev/null 2>&1 || true' EXIT
          timeout 120 agent-browser open "$url"
          timeout 60 agent-browser snapshot
        '';
      };
      shot = pkgs.writeShellApplication {
        name = "shot";
        runtimeInputs = [browser pkgs.coreutils];
        text = ''
          set -euo pipefail
          url="''${1:?usage: shot <url> <png>}"
          out="''${2:?usage: shot <url> <png>}"
          trap 'agent-browser close >/dev/null 2>&1 || true' EXIT
          timeout 120 agent-browser open "$url"
          timeout 60 agent-browser screenshot "$out"
          test -s "$out"
          printf 'wrote %s (%s bytes)\n' "$out" "$(wc -c < "$out")"
        '';
      };
    in {
      inherit browse shot;
      default = browse;
    });

    apps = forAll (system: _pkgs: {
      default = {
        type = "app";
        program = "${self.packages.${system}.browse}/bin/browse";
      };
    });
  };
}
