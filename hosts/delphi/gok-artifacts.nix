# Gokrazy appliance build artifacts receiver and tailnet HTTP server.
{
  config,
  pkgs,
  lib,
  ...
}: let
  cfg = config.services.gokArtifacts;

  # The body is hosts/delphi/gok-artifacts.sh, not a Nix string: this script
  # deletes things, so it has to be runnable against a scratch directory without
  # rendering a whole host. `replaceVarsWith` (not `replaceVars`) because the
  # result is `ExecStart`, and the plain variant installs 0444 — a text file that
  # systemd refuses to exec.
  # One list, two consumers: the unit's PATH (which resolves the `#!/usr/bin/env
  # bash` shebang — without bash here the unit dies at exec with status 127) and
  # the script's own PATH (a unit gets no login PATH, and tar/zstd on this host
  # live in a user profile, so the receiver would find nothing to unpack with).
  tools = [
    pkgs.bash
    pkgs.coreutils
    pkgs.gnutar
    pkgs.zstd
    pkgs.gnused
    pkgs.gnugrep
    pkgs.findutils
  ];

  receive = pkgs.replaceVarsWith {
    src = ./gok-artifacts.sh;
    isExecutable = true;
    replacements = {
      inherit (cfg) directory;
      keep = toString cfg.keep;
      tailscale = "${pkgs.tailscale}/bin/tailscale";
      path = lib.makeBinPath tools;
    };
  };
in {
  options.services.gokArtifacts = {
    enable = lib.mkEnableOption "the gokrazy artifact drop (Taildrop receiver + tailnet-only static serving)";
    directory = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/gok-artifacts";
      description = "Where received artifacts are unpacked, one directory per build.";
    };
    keep = lib.mkOption {
      type = lib.types.int;
      default = 3;
      description = "How many builds to keep before the oldest is deleted.";
    };
  };

  config = lib.mkIf cfg.enable {
    # 2750 (setgid) so the files root writes below belong to the group nginx
    # reads as; without the setgid bit they land as root:root and 404 with EACCES.
    systemd.tmpfiles.rules = [
      "d ${cfg.directory} 2750 root nginx -"
      "d ${cfg.directory}/incoming 2750 root nginx -"
    ];

    systemd.services.gok-taildrop = {
      description = "Receive gokrazy build artifacts sent to this host via Taildrop";
      wants = ["tailscaled.service"];
      after = ["tailscaled.service"];
      path = tools;
      serviceConfig = {
        Type = "oneshot";
        ExecStart = receive;
        # Artifacts are chmod 0640 by the build's umask; nginx reaches them
        # through the directory group, nothing else needs to read them.
        UMask = "0027";
        Nice = 10;
        IOSchedulingClass = "idle";
      };
    };

    systemd.timers.gok-taildrop = {
      description = "Poll Taildrop for gokrazy build artifacts";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnBootSec = "2min";
        OnUnitActiveSec = "2min";
        # A missed poll while tailscaled restarts is not an incident.
        Persistent = false;
      };
    };
  };
}
