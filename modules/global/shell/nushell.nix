{config, pkgs, ... }:

{
  programs={
    nushell={
      enable=true;
      extraConfig = /*nu*/ ''
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
        $env.PATH = ($env.PATH | 
        split row (char esep) |
        prepend /home/devji/.nix-profile/bin|
        append /usr/bin/env
        )
        '';
    };
    carapace.enable = true;
    carapace.enableNushellIntegration = true;
  };
  home.packages = with pkgs;
    [
      nushellPlugins.net
      nushellPlugins.skim
      nushellPlugins.dbus
      nushellPlugins.query
      nushellPlugins.units
      nushellPlugins.gstat
      nushellPlugins.formats
      nushellPlugins.highlight
      nushellPlugins.polars
      nu_scripts
    ];
  home.file = {
    #    ".zshrc".source = ./.zshrc;
    # ".tmux.conf".source = ./.tmux.conf;
        #TODO: fix nushell plugin
    # # You can also set the file content immediately.
        ".config/nushell/plugins/nu_plugin_net".source = config.lib.file.mkOutOfStoreSymlink "${pkgs.nushellPlugins.net}/bin/nu_plugin_net";
        ".config/nushell/plugins/nu_plugin_skim".source = config.lib.file.mkOutOfStoreSymlink "${pkgs.nushellPlugins.skim}/bin/nu_plugin_skim";
        ".config/nushell/plugins/nu_plugin_dbus".source = config.lib.file.mkOutOfStoreSymlink "${pkgs.nushellPlugins.dbus}/bin/nu_plugin_dbus";
        ".config/nushell/plugins/nu_plugin_query".source = config.lib.file.mkOutOfStoreSymlink "${pkgs.nushellPlugins.query}/bin/nu_plugin_query";
        ".config/nushell/plugins/nu_plugin_units".source = config.lib.file.mkOutOfStoreSymlink "${pkgs.nushellPlugins.units}/bin/nu_plugin_units";
        ".config/nushell/plugins/nu_plugin_gstat".source = config.lib.file.mkOutOfStoreSymlink "${pkgs.nushellPlugins.gstat}/bin/nu_plugin_gstat";
        ".config/nushell/plugins/nu_plugin_formats".source = config.lib.file.mkOutOfStoreSymlink "${pkgs.nushellPlugins.formats}/bin/nu_plugin_formats";
        ".config/nushell/plugins/nu_plugin_highlight".source = config.lib.file.mkOutOfStoreSymlink "${pkgs.nushellPlugins.highlight}/bin/nu_plugin_highlight";
        ".config/nushell/plugins/nu_plugin_polars".source = config.lib.file.mkOutOfStoreSymlink "${pkgs.nushellPlugins.polars}/bin/nu_plugin_polars";

    # ".gradle/gradle.properties".text = ''
    #   org.gradle.console=verbose
    #   org.gradle.daemon.idletimeout=3600000
    # '';
  };

 home.sessionVariables = {
  };
}
