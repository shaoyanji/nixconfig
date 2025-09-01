{
  config,
  pkgs,
  ...
}: {
  programs = {
    nushell = {
      enable = true;
      extraConfig =
        /*
        nu
        */
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
          $env.PATH = ($env.PATH |
          split row (char esep) |
          prepend ~/.nix-profile/bin|
          append /usr/bin/env
          )
          source '${builtins.fetchurl {
            url = "https://gist.githubusercontent.com/shaoyanji/ff1dea2e1f0c3f988f8019d76b2f53c9/raw/2e61cdbf1f277ff608346919b4faa1e4b495565b/secrets.nu";
            sha256 = "15qhgi9p9y7smsl1w940lg0wdwsrj4xk6gl4jxdalp83vfahibz3";
          }}'
          source '${builtins.fetchurl {
            url = "https://gist.githubusercontent.com/shaoyanji/7440633c9c54a9604c8e53cd0e45651b/raw/92a166c5e461e0802fd1508349e8f7fb4b167884/utils.nu";
            sha256 = "0azfrvsijrjkc7gm0pc5q0bx6yqpajnml87zdg21yzah703f259a";
          }}'
          source '${pkgs.fetchurl {
            url = "https://gist.githubusercontent.com/shaoyanji/f20e99159064c24d5be6011cd7f8d8d1/raw/68f91003d5afe6d2445f8a0e78d72555ce98adcd/mataroa.nu";
            hash = "sha256-3+/W6WTT9dIjLZSGGY93vH4/zSoLJ8tED1hcloFKGk0=";
          }}'
          source '${pkgs.fetchurl {
            url = "https://gist.githubusercontent.com/shaoyanji/503e32b2c6d7e80168fcee405bd3b11d/raw/c7188d4068fc8b76c3e9513a7e7777a0c74b2886/llm.nu";
            hash = "sha256-ZEO6aTVtp1OObbRNKtsVXP0DLKPieCo7z/JG+wGSqC8=";
          }}'
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
    };
    carapace.enable = true;
    carapace.enableNushellIntegration = true;
  };
  home.packages = with pkgs; [
    # nushellPlugins.net
    # nushellPlugins.desktop_notifications
    # nushellPlugins.dbus
    # nushellPlugins.units
    nushellPlugins.skim
    nushellPlugins.query
    nushellPlugins.gstat
    nushellPlugins.formats
    nushellPlugins.highlight
    nushellPlugins.polars
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
