# CLI tools the fleet can borrow instead of installing: `nix run .#cli.<family>.<tool>`.
# One table is the whole namespace, using the family names the host package lists
# already use; `bin` is set only where the attribute and the executable disagree.
{
  lib,
  pkgs,
  inputs,
  system,
}: let
  isLinux = pkgs.stdenv.hostPlatform.isLinux;

  all = {
    search = {
      qmd.pkg = inputs.llm-agents.packages.${system}.qmd;
      toon.pkg = inputs.llm-agents.packages.${system}.toon;
    };
    data = {
      jq.pkg = pkgs.jq;
      yq.pkg = pkgs.yq-go;
      tomlq.pkg = pkgs.tomlq;
      sqlite = {
        pkg = pkgs.sqlite;
        bin = "sqlite3";
      };
      file.pkg = pkgs.file;
      tree.pkg = pkgs.tree;
    };
    text = {
      sd.pkg = pkgs.sd;
      sed.pkg = pkgs.gnused;
      awk.pkg = pkgs.gawk;
    };
    nix = {
      alejandra.pkg = pkgs.alejandra;
      deadnix.pkg = pkgs.deadnix;
      statix.pkg = pkgs.statix;
      nom.pkg = pkgs.nix-output-monitor;
    };
    net = {
      dig.pkg = pkgs.dnsutils;
      drill.pkg = pkgs.ldns;
      mtr.pkg = pkgs.mtr;
      nmap.pkg = pkgs.nmap;
      socat.pkg = pkgs.socat;
      iperf3.pkg = pkgs.iperf3;
      gping.pkg = pkgs.gping;
      iftop.pkg = pkgs.iftop;
      bandwhich.pkg = pkgs.bandwhich;
      ipcalc.pkg = pkgs.ipcalc;
    };
    disk = {
      duf.pkg = pkgs.duf;
      procs.pkg = pkgs.procs;
      # The Linux-only members of this family; the filter below drops them on
      # darwin instead of failing the whole flake there.
      lsof = {
        pkg = pkgs.lsof;
        linux = true;
      };
      strace = {
        pkg = pkgs.strace;
        linux = true;
      };
    };
    transfer = {
      aria2.pkg = pkgs.aria2;
      rclone.pkg = pkgs.rclone;
      rsync.pkg = pkgs.rsync;
    };
    archive = {
      zip.pkg = pkgs.zip;
      unzip.pkg = pkgs.unzip;
      "7z".pkg = pkgs.p7zip;
      zstd.pkg = pkgs.zstd;
      lz4.pkg = pkgs.lz4;
    };
    security = {
      age.pkg = pkgs.age;
      cloak.pkg = pkgs.cloak;
      # The vault clients. rbw is the one that tolerates a plain-http base URL,
      # but it prompts through pinentry, so the binary has to be reachable and
      # cannot be guessed: `pkgs.pinentry` no longer exists, and pinentry-curses
      # ships its executable as `pinentry`.
      rbw.pkg = pkgs.rbw;
      pinentry.pkg = pkgs.pinentry-curses;
      pass = {
        pkg = pkgs.pass;
        linux = true;
      };
    };
    auto = {
      task.pkg = pkgs.go-task;
      just.pkg = pkgs.just;
      gum.pkg = pkgs.gum;
      entr.pkg = pkgs.entr;
      sar = {
        pkg = pkgs.sysstat;
        linux = true;
      };
    };
    hw = {
      lspci = {
        pkg = pkgs.pciutils;
        linux = true;
      };
      lsusb = {
        pkg = pkgs.usbutils;
        linux = true;
      };
    };
    # Tools this flake builds rather than borrows: the families where `pkg` is a
    # local derivation instead of a nixpkgs attribute.
    ai = {
      gemini-api.pkg = pkgs.stdenvNoCC.mkDerivation {
        pname = "gemini-api";
        version = "0.5.0";
        src = pkgs.fetchurl {
          url = "https://github.com/google-gemini/gemini-api-cli/releases/download/v0.5.0/gemini-api_Linux_x86_64.tar.gz";
          hash = "sha256-/OIp3Uguwcr/Fc0Ueik1E/+1pSOQOU5SE2+FtKSXx0I=";
        };
        dontUnpack = true;
        installPhase = ''
          tar -xzf $src
          mkdir -p $out/bin
          cp gemini-api $out/bin/gemini-api
          chmod +x $out/bin/gemini-api
        '';
        meta = {
          description = "Google Gemini API CLI";
          mainProgram = "gemini-api";
          platforms = ["x86_64-linux"];
        };
      };

      # vox is the explainer layer: needle3 picks one tool call, jev routes the
      # lane, cpg says the result to a person. Go stdlib only, so `vendorHash =
      # null` and the binary builds on either architecture — the *engine* it
      # calls is linux-arm64, and `vox doctor` reports that rather than hiding it.
      # Source is the separate project, pinned like any other upstream: the pin
      # is the whole interface, so a fleet cannot run a half-merged tree.
      vox.pkg = pkgs.buildGoModule {
        pname = "vox";
        version = "0.1.0";
        src = pkgs.fetchFromGitHub {
          owner = "shaoyanji";
          repo = "pancakes-harness";
          rev = "ad225137c65f0afa3e3826faae7b469ca59d7c9c";
          hash = "sha256-nPjlvfWfj157Eb6pQIayJQQkTDJAejgHVi1Eh07/R7M=";
        };
        subPackages = ["cmd/vox"];
        vendorHash = null;
        env.CGO_ENABLED = 0;
        meta = {
          description = "Explain one question: needle3 caller, jev lane routing, cpg voice";
          mainProgram = "vox";
        };
      };

      # agy reads GEMINI_API_KEY only when the session says modelProvider=gemini,
      # and `--settings` is the flag that says it without saving anything. So the
      # key route is a wrapper rather than a settings.json key: the Pro account
      # route stays the default, and one command opts a single run into Hydrogen.
      agy-gemini.pkg =
        (pkgs.writeShellApplication {
          name = "agy-gemini";
          # No runtimeInputs: antigravity-cli is resolved at call time —
          # PATH first, then `nix run` fresh off the numtide cache, so the
          # wrapper's closure never bakes the agy package and never pins it.
          runtimeInputs = [pkgs.nix];
          text = ''
            usage() {
              cat <<'EOF'
            agy-gemini — agy on the Gemini API key route (Hydrogen), for this session only

              agy-gemini [agy args...]     e.g. agy-gemini -p 'hello'
              agy-gemini models            what the key unlocks

              Sets modelProvider=gemini via --settings, which agy never saves: the
              account route and ~/.gemini/antigravity-cli/settings.json are untouched,
              and requests bill the API key's project rather than the Pro plan. Pass
              your own --model to override the default.

            Env:
              GEMINI_API_KEY     required; a login shell exports it from the sops cache
              AGY_GEMINI_MODEL   default gemini-4-hydrogen-high
                                 (low | medium | high | xhigh, as suffixed model ids)
              AGY_GEMINI_EFFORT  optional, passed as --effort (low|medium|high|xhigh|max)

            Budget: the free API tier allows a handful of requests per minute and about
            20 per day per project, and one agent turn is one request plus retries. A
            429 with quota_exceeded ends the day, so use this for a Hydrogen task and
            the account route for a long sweep. Unsuffixed ids (gemini-4-hydrogen) are
            the ones that answer 503 under load.
            EOF
            }

            case "''${1:-}" in
              -h | --help) usage; exit 0 ;;
            esac

            if [ -z "''${GEMINI_API_KEY:-}" ]; then
              echo "agy-gemini: GEMINI_API_KEY is unset — agy reads it only with modelProvider=gemini, which this sets." >&2
              exit 2
            fi

            args=(--settings '{"modelProvider":"gemini"}')

            # Subcommands (models, mcp, ...) take no model flag; everything else gets
            # the default unless the caller already picked one.
            model=0
            subcommand=0
            for a in "$@"; do
              case "$a" in
                --model) model=1 ;;
                models | agents | agent | mcp | plugin | plugins | acp | changelog | help | install | mic-serve | remote-control | update) subcommand=1 ;;
              esac
            done
            if [ "$subcommand" = 0 ] && [ "$model" = 0 ]; then
              args+=(--model "''${AGY_GEMINI_MODEL:-gemini-4-hydrogen-high}")
            fi
            if [ -n "''${AGY_GEMINI_EFFORT:-}" ]; then
              args+=(--effort "$AGY_GEMINI_EFFORT")
            fi

            if command -v agy >/dev/null 2>&1; then
              exec agy "''${args[@]}" "$@"
            fi
            exec nix run "github:numtide/llm-agents.nix#antigravity-cli" -- "''${args[@]}" "$@"
          '';
        })
        .overrideAttrs (old: {
          meta =
            (old.meta or {})
            // {
              description = "Run agy on the Gemini API key route (Hydrogen) for one session";
            };
        });
    };
    learn = {
      deutsch-srs.pkg = pkgs.callPackage ./deutsch-srs.nix {};
      anki-author.pkg = pkgs.callPackage ./anki-author.nix {};
    };
    image = {
      # The image-daily pipeline's data leg is folded into the one-os-cli
      # umbrella (tools/os, internal/image): this package still answers
      # `bin/image-daily` — a symlink onto the umbrella binary, whose argv[0]
      # dispatch selects the image domain — so the lib resolver, taskfiles and
      # frieren's slot closures resolve unchanged.
      daily = {
        bin = "image-daily";
        pkg = pkgs.buildGoModule {
          pname = "image-daily";
          version = "0.1.0";
          src = ../tools/os;
          vendorHash = null;
          env.CGO_ENABLED = 0;
          postInstall = ''
            ln -s $out/bin/os $out/bin/image-daily
          '';
          meta.description = "image-daily verbs on the os umbrella binary (Go stdlib, no dependencies)";
        };
      };
    };
    # The preview server every `site-target.sh preview` and the kg-canvas gate
    # run: Go stdlib, so it answers Range (a video can be seeked) and needs no
    # interpreter. It replaced `python3 -m http.server`, which ignores Range.
    # Folded into the os umbrella (tools/os, internal/serve) — `bin/static-serve`
    # is the argv[0] alias, so both callers resolve unchanged; the same
    # derivation also backs `packages.<system>.servers.static-serve`.
    serve = {
      static-serve = {
        bin = "static-serve";
        pkg = pkgs.buildGoModule {
          pname = "static-serve";
          version = "0.1.0";
          src = ../tools/os;
          vendorHash = null;
          env.CGO_ENABLED = 0;
          postInstall = ''
            ln -s $out/bin/os $out/bin/static-serve
          '';
          meta.description = "static file server with Range support on the os umbrella binary (Go stdlib, no dependencies)";
        };
      };
    };
  };

  # One pipe, one predicate: an entry with `linux = true` survives only on
  # Linux, everything else is platform-neutral because nixpkgs already built it.
  families =
    all
    |> lib.mapAttrs (_: lib.filterAttrs (_: t: isLinux || !(t.linux or false)));

  toolName = name: tool: tool.bin or name;

  # A flake app must be a leaf, so `apps.<system>.cli.<family>.<tool>` cannot
  # exist: `nix run` finds the `cli` attrset, asks it for `.program` and fails
  # instead of falling through to `packages`. One namespace replaces the two:
  # `nix run .#cli.<family>.<tool>` resolves through `packages`, and
  # `meta.mainProgram` is what picks the executable. Without it nix guesses from
  # the derivation name (`bind` for `dnsutils`, `gnused` for `sed`).
  #
  # meta-only override: the derivation and its store path are untouched, so the
  # cache still serves it.
  runnable = program: pkg:
    pkg.overrideAttrs (old: {
      meta = (old.meta or {}) // {mainProgram = program;};
    });
in rec {
  # `packages.cli.<family>.<tool>` — the derivation, for `nix build`, for a host
  # that wants the store path, and for `nix run` (see `runnable` above).
  packages =
    families
    |> lib.mapAttrs (
      _family: tools:
        tools
        |> lib.mapAttrs (name: t: runnable (toolName name t) t.pkg)
    );

  inherit families;
}
