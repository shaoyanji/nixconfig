# Global Nix and Nixpkgs configuration applied across all fleet hosts.
{
  config,
  lib,
  pkgs,
  ...
}: let
  hostName = config.networking.hostName or (config.hostName or "");
  hostMeta = config.fleet.inventory.hosts.${hostName} or {};
  # `category = "cloud"` in inventory.toml is the whole fact: a host that is not on
  # the LAN and must not assume LAN services. The two names that used to be OR'd in
  # both carry it, so the list was already redundant.
  isCloudHost = (hostMeta.category or "") == "cloud";

  # ── Binary cache policy ──────────────────────────────────────────────────────
  # The list itself lives in lib/cache-policy.nix and is compiled per host into
  # `.#inventory.cache.<host>`; this module only applies it to nix.settings. The
  # registry used to be duplicated here, which is how the deploy scripts ended up
  # disagreeing with the module about whether harmonia serves a cloud host.
  policy = config.fleet.inventory.cache.${hostName} or null;
  harmoniaUrl = "http://192.168.3.25:5000";

  # Active substituters ordered by network tier:
  # - LAN hosts: Harmonia LAN first (gigabit local transfer), followed by Cachix and upstreams.
  # - Cloud/Remote hosts (Delphi): Cachix and fast WAN upstreams first. Harmonia LAN is
  #   excluded (or deprioritized to bottom) to prevent WAN timeouts and asymmetric uplink saturation.
  # `policy.substituters` is already ordered for this host: harmonia first on the
  # LAN, absent for a cloud host. The two options stay as deliberate overrides —
  # preferCloud forces the WAN order, includeHarmonia re-adds the LAN cache — but
  # their defaults now come from the same fact the scripts read.
  activeSubstituters =
    if policy == null
    then []
    else let
      wan = builtins.filter (u: u != harmoniaUrl) policy.substituters;
      lan = lib.optional config.profiles.cache.includeHarmonia harmoniaUrl ++ wan;
    in
      if config.profiles.cache.preferCloud
      then wan ++ lib.optional config.profiles.cache.includeHarmonia harmoniaUrl
      else lan;

  allSubstituterUrls =
    if policy == null
    then []
    else policy.trustedSubstituters;
  allTrustedKeys =
    if policy == null
    then []
    else policy.trustedKeys;
in {
  options.profiles.cache = {
    preferCloud = lib.mkOption {
      type = lib.types.bool;
      default = isCloudHost;
      description = ''
        Whether to prioritize fast WAN substituters (Cachix, upstream)
        over the private LAN Harmonia cache. Defaults to true for cloud hosts
        (delphi, garnixMachine).
      '';
    };

    includeHarmonia = lib.mkOption {
      type = lib.types.bool;
      default = !config.profiles.cache.preferCloud;
      description = ''
        Whether to include the private LAN Harmonia cache in active substituters.
        Disabled by default on cloud/remote hosts.
      '';
    };

    registry = lib.mkOption {
      type = lib.types.attrsOf lib.types.attrs;
      default =
        if policy == null
        then {}
        else policy.registry;
      readOnly = true;
      description = "Queryable structured registry of all fleet binary caches.";
    };
  };

  config = {
    nix = {
      # mkDefault, not a plain definition: the Determinate Nix module
      # (modules/global/determinate-nix.nix) defines `nix.package` at the normal
      # priority (100), so a plain fleet definition is a definition CONFLICT —
      # not a pick. mkDefault makes the fleet value the fallback DN overrides.
      package = lib.mkDefault pkgs.nixVersions.latest;

      # The fleet is flake-bootstrapped and has never had a channel profile,
      # but NixOS/nix-darwin default `nix.channel.enable = true`, which appends
      # `/nix/var/nix/profiles/per-user/root/channels` to NIX_PATH. Resolving
      # `<nixpkgs>` then prints "search path entry ... does not exist, ignoring".
      channel.enable = false;

      gc = {
        automatic = true;
        options = "--delete-older-than 10d";
      };

      optimise =
        {
          automatic = lib.mkDefault true;
        }
        // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
          dates = ["Sun 06:00"];
        }
        // lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
          interval = [
            {
              Weekday = 7;
              Hour = 6;
              Minute = 0;
            }
          ];
        };

      extraOptions = ''
        min-free = ${toString (100 * 1024 * 1024)}
        max-free = ${toString (1024 * 1024 * 1024)}
      '';

      settings = {
        substituters = activeSubstituters;
        trusted-substituters = allSubstituterUrls;
        trusted-public-keys = allTrustedKeys;
        trusted-users = [
          "@admin"
          "@wheel"
        ];
        accept-flake-config = true;
        experimental-features = [
          "nix-command"
          "flakes"
          "pipe-operators"
        ];
        connect-timeout = 5;
        fallback = true;
        keep-outputs = true;
        nix-path = [
          "nixpkgs=flake:nixpkgs"
        ];
      };
    };

    # Prevent missed maintenance timers from bursting during daytime production hours.
    systemd.timers = lib.mkIf (pkgs.stdenv.hostPlatform.isLinux && config.nix.optimise.automatic) {
      nix-optimise.timerConfig.Persistent = lib.mkDefault false;
    };

    nixpkgs.config.allowUnfree = true;
  };
}
