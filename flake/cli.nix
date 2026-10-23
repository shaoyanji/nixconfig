# CLI tools the fleet can borrow instead of installing: `nix run .#cli.<family>.<tool>`.
#
# One table is the whole namespace — the family names are the comment groups the
# host package lists already use, so a tool moved here keeps the word it was
# found under and can be dropped from `home.packages` without moving the idea.
#
# `bin` is set only where the executable and the attribute name disagree;
# otherwise the attribute *is* the binary, which keeps `nix run` from guessing.
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
  };

  # One pipe, one predicate: an entry with `linux = true` survives only on
  # Linux, everything else is platform-neutral because nixpkgs already built it.
  families =
    all
    |> lib.mapAttrs (_: lib.filterAttrs (_: t: isLinux || !(t.linux or false)));

  toolName = name: tool: tool.bin or name;
in rec {
  # `packages.cli.<family>.<tool>` — the derivation, for `nix build` and for a
  # host that wants the store path.
  packages =
    families
    |> lib.mapAttrs (_: lib.mapAttrs (_: t: t.pkg));

  # `apps.cli.<family>.<tool>` — the same tree as run targets, so the two
  # namespaces can never disagree about which tools exist.
  apps =
    families
    |> lib.mapAttrs (
      _family: tools:
        tools
        |> lib.mapAttrs (name: t: {
          type = "app";
          program = "${t.pkg}/bin/${toolName name t}";
        })
    );

  inherit families;
}
