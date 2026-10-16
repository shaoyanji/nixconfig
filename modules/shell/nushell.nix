{
  lib,
  pkgs,
  ...
}: {
  programs = {
    nushell = {
      enable = true;

      # Stage 1: env.nu — executed first for PATH & session environment
      extraEnv = ''
        $env.PATH = (
          $env.PATH
            | split row (char esep)
            | prepend ~/.nix-profile/bin
            | append /usr/bin/env
        )

        # In-memory cached secrets loader (sub-millisecond warm starts)
        source ${../config/secrets.nu}
      '';

      # Stage 2: config.nu — executed second for UI, completions, hooks, modules
      extraConfig = ''
        let carapace_completer = {|spans|
          carapace $spans.0 nushell $spans | from json
        }

        $env.config = {
          show_banner: false
          edit_mode: 'vi'
          history: {
            max_size: 100_000
            sync_on_enter: true
            file_format: "sqlite"
            isolation: false
          }
          completions: {
            case_sensitive: false
            quick: true
            partial: true
            algorithm: "fuzzy"
            external: {
              enable: true
              max_results: 100
              completer: $carapace_completer
            }
          }
        }

        # User workflow modules (tracked in git under modules/config/nu/)
        source ${../config/nu/llm.nu}
        source ${../config/nu/mataroa.nu}
        source ${../config/nu/utils.nu}
        source ${../config/nu/finance.nu}
        source ${../config/nu/de.nu}
        source ${../config/nu/jobby.nu}
        source ${../config/nu/todoist.nu}

        # System & extraction modules
        source ${pkgs.nu_scripts}/share/nu_scripts/modules/data_extraction/ultimate_extractor.nu
        source ${pkgs.nu_scripts}/share/nu_scripts/modules/system/mod.nu
        use ${pkgs.nu_scripts}/share/nu_scripts/modules/nix/nufetch.nu
        use ${pkgs.nu_scripts}/share/nu_scripts/modules/wc/wc.nu
        source ${pkgs.nu_scripts}/share/nu_scripts/modules/weather/get-weather.nu

        # High-value custom completions (Carapace handles git, gh, ssh, tar, rg, bat, eza, just, man)
        source ${pkgs.nu_scripts}/share/nu_scripts/custom-completions/nix/nix-completions.nu
      '';

      plugins = with pkgs.nushellPlugins;
        [
          query
          gstat
          formats
          # highlight
          polars
        ]
        ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
          # units
          # dbus
          # semver
          # desktop_notifications
        ];
    };

    carapace = {
      enable = true;
      enableNushellIntegration = true;
    };
  };

  home.packages = with pkgs; [
    nu_scripts
  ];

  xdg.configFile = {};
  home.sessionVariables = {};
  home.sessionPath = [];
}
