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
    };
    learn = {
      deutsch-srs.pkg = pkgs.callPackage ./deutsch-srs.nix {};
      anki-author.pkg = pkgs.callPackage ./anki-author.nix {};
    };
    # The preview server every `site-target.sh preview` and the kg-canvas gate
    # run: Go stdlib, so it answers Range (a video can be seeked) and needs no
    # interpreter. It replaced `python3 -m http.server`, which ignores Range.
    serve = {
      static-serve.pkg = pkgs.buildGoModule {
        pname = "static-serve";
        version = "0.1.0";
        src = ../tools/static-serve;
        vendorHash = null;
        env.CGO_ENABLED = 0;
        meta.description = "Static file server with Range support (Go stdlib, no dependencies)";
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
