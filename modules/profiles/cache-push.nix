# A host that BUILDS pushes what it builds, from its own uplink.
#
# The fleet's caches have jobs, and only one of them is "everything":
#
#   harmonia (frieren)  the LAN cache. Serves this house at gigabit. It is not a
#                       cache for a cloud host — delphi cannot reach it, and
#                       relaying an aarch64 closure through the NAS spends the
#                       NAS's 20 Mbit uplink for nothing.
#   cachix (shaoyanji)  the cache every host can reach, LAN or cloud. This module
#                       is what puts a builder's output there.
#   CI                  a strategic anchor for an artifact worth caching once
#                       (an aarch64 image, an RPi kernel). Not a per-push path.
#
# So delphi — the only native aarch64 builder — is the case this exists for: it
# compiles the closure, and the result goes to cachix over ITS OWN uplink
# immediately. Without this, everything it builds dies in its own store at the
# next GC and the next switch compiles it again.
#
# `post-build-hook` is the mechanism, not a wrapper script: it fires on every
# local build, for the outputs that were just produced, and runs as the daemon.
# A copy that fails is logged and does not fail the build — caching must never be
# able to break an activation.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.profiles.cachePush;

  # netrc speaks hostnames; the option is a URL. "https://host[/path]" -> "host".
  cacheHost = let
    m = builtins.match "https?://([^/:]+).*" cfg.cacheUrl;
  in
    if m == null
    then cfg.cacheUrl
    else builtins.head m;
in {
  options.profiles.cachePush = {
    enable = lib.mkEnableOption "pushing locally built outputs to a WAN binary cache";

    cacheUrl = lib.mkOption {
      type = lib.types.str;
      default = "https://shaoyanji.cachix.org";
      description = "Destination cache. Must accept pushes with the token below.";
    };

    tokenSecret = lib.mkOption {
      type = lib.types.str;
      default = "cachix/auth_token";
      description = ''
        sops key holding the cache's auth token. The KEY MUST EXIST before this is
        enabled: sops-nix fails activation when a declared secret is absent from
        the file, which would break the host's next switch rather than the push.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Nix reads the token from a netrc entry, so nothing has to export an
    # environment variable into a daemon that has no session of its own.
    sops.secrets.${cfg.tokenSecret} = {
      owner = "root";
      mode = "0400";
    };

    sops.templates."nix-cache-netrc" = {
      owner = "root";
      mode = "0400";
      content = ''
        machine ${cacheHost} password ${config.sops.placeholder.${cfg.tokenSecret}}
      '';
      # The daemon reads it on every push, so it must exist before nix-daemon
      # starts serving builds — not merely before login.
      restartUnits = ["nix-daemon.service"];
    };

    nix.settings = {
      netrc-file = config.sops.templates."nix-cache-netrc".path;
      post-build-hook = pkgs.writeShellScript "cache-push-hook" ''
        set -u
        # Set by nix for a local build; empty when the hook is invoked for
        # something that produced no new output.
        [ -n "''${OUT_PATHS:-}" ] || exit 0
        # --no-check-sigs: the destination accepts uploads by token, and these
        # paths were built here, so there is no incoming signature to verify.
        # No `exec`: the failure path has to survive to reach `exit 0`.
        ${config.nix.package}/bin/nix copy --to ${cfg.cacheUrl} \
          --no-check-sigs ''${OUT_PATHS} || true
        exit 0
      '';
    };
  };
}
