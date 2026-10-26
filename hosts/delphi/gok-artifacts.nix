# The gokrazy appliance's build artifacts live here.
#
# .github/workflows/gok.yml builds root.squashfs + boot.fat + mbr.img and sends
# the tarball over Taildrop; this module receives it, proves it against the
# SHA256SUMS the build wrote, keeps the newest few and serves them back at /gok/
# on the tailnet vhost (the location is in configuration.nix, next to /sentinel/).
#
# Why Taildrop and not ssh: publishing is a one-way file drop from a runner that
# already joins the tailnet as `tag:ci`, so there is no new private key to hold
# and no ssh in an unattended path — the failure mode this replaces was a push
# step that waited forever with no output.
#
# Why the artifact is not on the public vhost: the image is built with credentials
# baked in (the wifi PSK, the tailscale auth key, the update password), so the
# tailnet ACL is the whole authorization boundary. `task infra:gok:deploy` fetches
# from the tailnet name; nothing public ever sees these bytes.
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
