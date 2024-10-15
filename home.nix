{ config, pkgs,  ... }:

{
  # Home Manager needs a bit of information about you and the paths it should
  # manage.
  #  home.username = "devji";
  #  home.homeDirectory= "/Users/devji";

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = "24.05"; # Please read the comment before changing.

  imports = [ 
    ./lf
    ./wezterm
    ./env.nix
    ./shell
    ./nvim
    #./nixvim

  ];

  programs.htop = {
    enable = true;
    settings = {
      show_program_path = true;
      sort_key = "PERCENT_CPU";
      sort_order = "DESCENDING";
      hide_threads = false;
      highlight_megabytes = false;
      update_process_names = false;
      count_cpus_from_zero = false;
      color_scheme = "default";
    };
  };

  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages = with pkgs; [
    cmus
    obsidian
# utilities
    thefuck
    jq
    ripgrep
    fd
    glow
    fm
    wget
    entr
    # mc
    # hyperfine
    gum

  # base tools 
    # alacritty
    # tmux
    # m-cli	
    # zed-editor
    # niv #nix package manager
  # dev tools
    #	xcbuild
    #	coreutils
  # miscellaneous
    #	pandoc
    #	texlive.combined.scheme-small
    #	wkhtmltopdf
    # languages
    #	python3
    #	nodejs
    #	go
    #	rustup
    #	gcc
    #	clang
    #	ruby
    #	lua
    #	luajit
    #	moonscript
    #	perl
    #	php
    #	quarto
    #	ghostscript
    # large language model tools
        # aichat
        # mods
        # tgpt
        # ollama
    # database
        # duckdb
        # pocketbase
        # haskelkPackages.postgrest
        # postgres
        # 
# applications
    #spotube # too many updates (better managed through homebrew)
    # niv
    # m-cli
    #browsh
    #neovim
    #python3
    #htop
    # tmux
    #gcc
    #  coreutils
    #eza
    #fd
    #ripgrep
    #bat
    #fzf
    #zoxide
    #thefuck
    #go
    #docker
    #pocketbase
    #haskellPackages.postgrest
    #zed-editor
    # # Adds the 'hello' command to your environment. It prints a friendly
    # # "Hello, world!" when run.
    # pkgs.hello

    # # It is sometimes useful to fine-tune packages, for example, by applying
    # # overrides. You can do that directly here, just don't forget the
    # # parentheses. Maybe you want to install Nerd Fonts with a limited number of
    # # fonts?
    #    (pkgs.nerdfonts.override { fonts = [ "JetBrainsMono" ]; })

    # # You can also create simple shell scripts directly inside your
    # # configuration. For example, this adds a command 'my-hello' to your
    # # environment:
    # (pkgs.writeShellScriptBin "my-hello" ''
    #   echo "Hello, ${config.home.username}!"
    # '')
   ] ++ lib.optionals stdenv.isDarwin [
    cocoapods
    m-cli # useful macOS CLI commands
  ];
  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  home.file = {
    # # Building this configuration will create a copy of 'dotfiles/screenrc' in
    # # the Nix store. Activating the configuration will then make '~/.screenrc' a
    # # symlink to the Nix store copy.
    # ".screenrc".source = dotfiles/screenrc;
	#  ".zshrc".source = dotfiles/zshrc;
   # # You can also set the file content immediately.
    # ".gradle/gradle.properties".text = ''
    #   org.gradle.console=verbose
    #   org.gradle.daemon.idletimeout=3600000
    # '';
  };

  # Home Manager can also manage your environment variables through
  # 'home.sessionVariables'. These will be explicitly sourced when using a
  # shell provided by Home Manager. If you don't want to manage your shell
  # through Home Manager then you have to manually source 'hm-session-vars.sh'
  # located at either
  #
  #  ~/.nix-profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  ~/.local/state/nix/profiles/profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  /etc/profiles/per-user/mattji/etc/profile.d/hm-session-vars.sh
  #
    home.sessionVariables = {
  #    EDITOR = "nvim";
   };

  # Let Home Manager install and manage itself.
    programs.home-manager.enable = true;
}
