# Global Nix and Nixpkgs configuration applied across all fleet hosts.
{
  config,
  lib,
  pkgs,
  ...
}: let
  hostName = config.networking.hostName or (config.hostName or "");
  hostMeta = config.fleet.inventory.hosts.${hostName} or {};
  isCloudHost =
    (hostMeta.category or "")
    == "cloud"
    || hostName == "delphi"
    || hostName == "garnixMachine";

  # ── Fleet Binary Cache Registry ─────────────────────────────────────────────
  # Single source of truth for all substituters and their signing keys.
  fleetCaches = {
    # 1. Private LAN Binary Cache (Harmonia on frieren.lan)
    harmoniaLan = {
      name = "Harmonia LAN (frieren)";
      url = "http://192.168.3.25:5000";
      key = "frieren.lan-1:BUg+1UmfYlF0XCbC0+ZyWQOY1DpQJhj/wa2q76NTFOg=";
      tier = "lan";
    };

    # 2. Personal Cachix Cache (prebuilt fleet derivations & gaps)
    shaoyanji = {
      name = "Personal Cachix (shaoyanji)";
      url = "https://shaoyanji.cachix.org";
      key = "shaoyanji.cachix.org-1:3XUZGFcaq5bXFKwtCR+POG81Hh6WfTqf50Bmz4VHpj0=";
      tier = "personal";
    };

    # 3. Official Upstream Nixpkgs Binary Cache
    nixos = {
      name = "NixOS Official Cache";
      url = "https://cache.nixos.org/";
      key = "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=";
      tier = "upstream";
    };

    # 4. Numtide LLM Agents Cache (crush, toon, qmd, pdfvision, etc.)
    numtide = {
      name = "Numtide LLM Agents Cache";
      url = "https://cache.numtide.com";
      key = "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g=";
      tier = "upstream";
    };

    # 5. Nix Community Cachix
    nixCommunity = {
      name = "Nix Community Cachix";
      url = "https://nix-community.cachix.org";
      key = "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=";
      tier = "community";
    };

    # 6. Nix Gaming Cachix (Steam, gamescope, proton enhancements)
    nixGaming = {
      name = "Nix Gaming Cachix";
      url = "https://nix-gaming.cachix.org";
      key = "nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4=";
      tier = "community";
    };

    # 7. Determinate Systems / FlakeHub Binary Cache
    determinate = {
      name = "Determinate Systems FlakeHub";
      url = "https://install.determinate.systems";
      key = "cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM=";
      tier = "upstream";
    };
  };

  # Active substituters ordered by network tier:
  # - LAN hosts: Harmonia LAN first (gigabit local transfer), followed by Cachix and upstreams.
  # - Cloud/Remote hosts (Delphi): Cachix and fast WAN upstreams first. Harmonia LAN is
  #   excluded (or deprioritized to bottom) to prevent WAN timeouts and asymmetric uplink saturation.
  activeSubstituters =
    if config.profiles.cache.preferCloud
    then
      [
        fleetCaches.shaoyanji.url
        fleetCaches.nixos.url
        fleetCaches.numtide.url
        fleetCaches.nixCommunity.url
        fleetCaches.determinate.url
        fleetCaches.nixGaming.url
      ]
      ++ lib.optional config.profiles.cache.includeHarmonia fleetCaches.harmoniaLan.url
    else
      (lib.optional config.profiles.cache.includeHarmonia fleetCaches.harmoniaLan.url)
      ++ [
        fleetCaches.shaoyanji.url
        fleetCaches.nixos.url
        fleetCaches.numtide.url
        fleetCaches.nixCommunity.url
        fleetCaches.nixGaming.url
        fleetCaches.determinate.url
      ];

  allSubstituterUrls = builtins.map (c: c.url) (builtins.attrValues fleetCaches);
  allTrustedKeys = builtins.map (c: c.key) (builtins.attrValues fleetCaches);
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
      default = fleetCaches;
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
