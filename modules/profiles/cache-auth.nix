# Cache PUSH credentials for publishing closures to the fleet WAN cache (task, not a hook).
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
      // lib.optionalAttrs (cfg.sopsFile != null) {inherit (cfg) sopsFile;};

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
