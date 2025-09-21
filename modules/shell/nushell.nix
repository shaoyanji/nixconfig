{
  config,
  pkgs,
  ...
}: {
  programs = {
    nushell = {
      enable = true;
      extraConfig =
        # nu
        ''
          let carapace_completer = {|spans|
          carapace $spans.0 nushell $spans | from json
          }
          $env.config = {
           show_banner: false,
           history: {
            max_size: 100_000 # Session has to be reloaded for this to take effect
            sync_on_enter: true # Enable to share history between multiple sessions, else you have to close the session to write history to file
            file_format: "sqlite" # "sqlite" or "plaintext"
            isolation: false # only available with sqlite file_format. true enables history isolation, false disables it. true will allow the history to be isolated to the current session using up/down arrows. false will allow the history to be shared across all sessions.
           }
           completions: {
           case_sensitive: false # case-sensitive completions
           quick: true    # set to false to prevent auto-selecting completions
           partial: true    # set to false to prevent partial filling of the prompt
           algorithm: "fuzzy"    # prefix or fuzzy
           external: {
           # set to false to prevent nushell looking into $env.PATH to find more suggestions
               enable: true
           # set to lower can improve completion performance at the cost of omitting some options
               max_results: 100
               completer: $carapace_completer # check 'carapace_completer'
             }
           }
          }
          $env.config.edit_mode = 'vi'
          $env.PATH = (
            $env.PATH
              | split row (char esep)
              | prepend ~/.nix-profile/bin
              | append /usr/bin/env
          )
          ${builtins.concatStringsSep "\n" (builtins.map (x: "source " + builtins.fetchurl x) (builtins.fromJSON (builtins.readFile ../config/nu.json)))}
          source ${pkgs.nu_scripts}/share/nu_scripts/modules/nix/nix.nu
          source ${pkgs.nu_scripts}/share/nu_scripts/modules/data_extraction/ultimate_extractor.nu
          source ${pkgs.nu_scripts}/share/nu_scripts/modules/system/mod.nu

          source ${pkgs.nu_scripts}/share/nu_scripts/custom-completions/nix/nix-completions.nu
          source ${pkgs.nu_scripts}/share/nu_scripts/custom-completions/bitwarden-cli/bitwarden-cli-completions.nu
          source ${pkgs.nu_scripts}/share/nu_scripts/custom-completions/glow/glow-completions.nu
          source ${pkgs.nu_scripts}/share/nu_scripts/custom-completions/gh/gh-completions.nu
          source ${pkgs.nu_scripts}/share/nu_scripts/custom-completions/git/git-completions.nu
          source ${pkgs.nu_scripts}/share/nu_scripts/custom-completions/just/just-completions.nu
          source ${pkgs.nu_scripts}/share/nu_scripts/custom-completions/eza/eza-completions.nu
          source ${pkgs.nu_scripts}/share/nu_scripts/custom-completions/bat/bat-completions.nu
          source ${pkgs.nu_scripts}/share/nu_scripts/custom-completions/rg/rg-completions.nu
          source ${pkgs.nu_scripts}/share/nu_scripts/custom-completions/tar/tar-completions.nu
          source ${pkgs.nu_scripts}/share/nu_scripts/custom-completions/ssh/ssh-completions.nu
          # source ${pkgs.nu_scripts}/share/nu_scripts/custom-completions/zoxide/zoxide-completions.nu
          source ${pkgs.nu_scripts}/share/nu_scripts/custom-completions/man/man-completions.nu
        '';
      plugins = with pkgs.nushellPlugins; [
        skim
        query
        gstat
        formats
        highlight
        polars
      ];
    };
    carapace.enable = true;
    carapace.enableNushellIntegration = true;
  };
  home.packages = with pkgs; [
    # nushellPlugins.net
    # nushellPlugins.desktop_notifications
    # nushellPlugins.dbus
    # nushellPlugins.units
    # nushellPlugins.skim
    # nushellPlugins.query
    # nushellPlugins.gstat
    # nushellPlugins.formats
    # nushellPlugins.highlight
    # nushellPlugins.polars
    nu_scripts
  ];
  xdg.configFile = {
    # "nushell/plugins/nu_plugin_net".source = config.lib.file.mkOutOfStoreSymlink "${pkgs.nushellPlugins.net}/bin/nu_plugin_net";
    # "nushell/plugins/nu_plugin_skim".source = config.lib.file.mkOutOfStoreSymlink "${pkgs.nushellPlugins.skim}/bin/nu_plugin_skim";
    # "nushell/plugins/nu_plugin_dbus".source = config.lib.file.mkOutOfStoreSymlink "${pkgs.nushellPlugins.dbus}/bin/nu_plugin_dbus";
    # "nushell/plugins/nu_plugin_query".source = config.lib.file.mkOutOfStoreSymlink "${pkgs.nushellPlugins.query}/bin/nu_plugin_query";
    # "nushell/plugins/nu_plugin_units".source = config.lib.file.mkOutOfStoreSymlink "${pkgs.nushellPlugins.units}/bin/nu_plugin_units";
    # "nushell/plugins/nu_plugin_gstat".source = config.lib.file.mkOutOfStoreSymlink "${pkgs.nushellPlugins.gstat}/bin/nu_plugin_gstat";
    # "nushell/plugins/nu_plugin_formats".source = config.lib.file.mkOutOfStoreSymlink "${pkgs.nushellPlugins.formats}/bin/nu_plugin_formats";
    # "nushell/plugins/nu_plugin_highlight".source = config.lib.file.mkOutOfStoreSymlink "${pkgs.nushellPlugins.highlight}/bin/nu_plugin_highlight";
    # "nushell/plugins/nu_plugin_polars".source = config.lib.file.mkOutOfStoreSymlink "${pkgs.nushellPlugins.polars}/bin/nu_plugin_polars";

    # ".gradle/gradle.properties".text = ''
    #   org.gradle.console=verbose
    #   org.gradle.daemon.idletimeout=3600000
    # '';
  };

  home.sessionVariables = {
  };
  home.sessionPath = [
    # "${pkgs.nu_scripts}/share/nu_scripts/modules/nix"
  ];
}
