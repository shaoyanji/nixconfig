{
  lib,
  pkgs,
  config,
  osConfig ? {},
  ...
}: let
  cfg = config.profiles.dev;

  hostName = osConfig.networking.hostName or (config.networking.hostName or "");
  invHost =
    if hostName != ""
    then (osConfig.fleet.inventory.hosts.${hostName} or (config.fleet.inventory.hosts.${hostName} or null))
    else null;
  category = invHost.category or "";
  traits =
    if invHost == null
    then []
    else (invHost.software.traits or []);

  # The heavy developer toolchain (LLVM/Clang via nixd, devenv) is a declared trait:
  # `dev-full` in inventory.toml, plus every host whose category is `workstation`.
  # Mobile laptops default to "light" so a 15W CPU and 8GB RAM do not pay for it.
  defaultTier =
    if builtins.elem "dev-full" traits || category == "workstation"
    then "full"
    else "light";
in {
  options.profiles.dev = {
    enable =
      lib.mkEnableOption "developer toolchain and environment"
      // {
        default = true;
      };

    tier = lib.mkOption {
      type = lib.types.enum ["light" "full"];
      default = defaultTier;
      description = ''
        Developer toolchain capability tier:
        - "light": lightweight developer tools (uv, go, jq, lazygit, basic formatters).
                   Excludes heavy LLVM-dependent language servers (nixd) and containerized devenv.
        - "full": complete development suite including devenv (864MB), nixd (588MB),
                  and full cloud infrastructure CLI toolset.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    programs = {
      # Fast Python package manager (uv)
      uv = {
        enable = true;
        settings = {
          python-preference = "only-system";
        };
      };

      # Go toolchain
      go = {
        enable = true;
        telemetry.mode = "off";
      };
    };

    home.packages = with pkgs;
    # Base lightweight developer utilities (available on all tiers)
      [
        lazygit
      ]
      # Heavy developer toolchain — ONLY installed when tier == "full"
      # Saves ~1.5+ GB on mobile laptops (Aristotle, Fern)
      ++ lib.optionals (cfg.tier == "full") [
        devenv # Developer environments (864 MB closure)
        nixd # Nix language server (588 MB closure, pulls LLVM)
        # Cloud & Database infrastructure CLIs
        cloudflare-cli
        supabase-cli
        turso-cli
        surge-cli
        wash-cli
        cook-cli
        bootdev-cli
      ];

    home.sessionVariables = {};
    home.sessionPath = [
      "$HOME/.dotnet/tools"
      "$HOME/go/bin"
      "$HOME/.cargo/bin"
    ];
  };
}
