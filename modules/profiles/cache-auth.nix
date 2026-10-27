# Cache PUSH credentials, and nothing else.
#
# This is deliberately not a post-build-hook. A hook runs as nix-daemon for every
# output a host compiles, so on a 2-OCPU guest a single switch becomes a stream of
# NAR re-compresses and uploads that outlives the rebuild that started them — the
# host looks wedged and cannot get a new generation landed.
#
# What a small builder actually needs is the ability to publish ONCE, when it has
# finished: `nix copy --to <cache> $(readlink -f /run/current-system)` stores what
# took an hour to compile so the next switch substitutes it. That is a task
# (`task infra:cache:publish`), not a hook, and it costs one process the operator
# started rather than one per derivation.
{
  config,
  lib,
  ...
}: let
  cfg = config.profiles.cacheAuth;
in {
  options.profiles.cacheAuth = {
    enable = lib.mkEnableOption "credentials for pushing to the fleet's WAN cache (no hook)";

    cacheUrl = lib.mkOption {
      type = lib.types.str;
      default = "https://shaoyanji.cachix.org";
      description = "Destination cache. Must accept pushes with the token below.";
    };

    tokenSecret = lib.mkOption {
      type = lib.types.str;
      default = "cachix/auth_token";
      description = "NAME of the sops secret (`/run/secrets/<name>`), not the key inside the file.";
    };

    tokenKey = lib.mkOption {
      type = lib.types.str;
      default = "CACHIX/AUTH/TOKEN";
      description = "Slash-separated path of the token inside {option}`sopsFile`.";
    };

    sopsFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "sops file holding the token; null inherits the global default.";
    };
  };

  config = lib.mkIf cfg.enable {
    # netrc speaks hostnames; the option is a URL.
    # `nix copy --to` reads it, so no token is ever passed on a command line.
    sops.secrets.${cfg.tokenSecret} =
      {
        owner = "root";
        mode = "0400";
        key = cfg.tokenKey;
      }
      // lib.optionalAttrs (cfg.sopsFile != null) {sopsFile = cfg.sopsFile;};

    sops.templates."nix-cache-netrc" = {
      owner = "root";
      mode = "0400";
      content = ''
        machine ${
          let
            m = builtins.match "https?://([^/:]+).*" cfg.cacheUrl;
          in
            if m == null
            then cfg.cacheUrl
            else builtins.head m
        } password ${config.sops.placeholder.${cfg.tokenSecret}}
      '';
      restartUnits = ["nix-daemon.service"];
    };

    # Read-side only: the netrc is what a push needs, and setting it here does not
    # cause anything to be pushed.
    nix.settings.netrc-file = config.sops.templates."nix-cache-netrc".path;
  };
}
