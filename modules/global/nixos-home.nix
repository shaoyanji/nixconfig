{ config, pkgs, lib,  ... }:

{
  imports = [ 
    ./home.nix
    ./hyprland.nix
        ] ++ [ ./nixvim ./browser/firefox.nix
  ];


  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages = with pkgs; [
    #cmus
    #obsidian
# nix formatting
    #nixfmt-rfc-style
    #alejandra
    #nixpkgs-fmt
# utilities
    #glow
    #fm
    #wget
    #entr
    #gum
    #go-task
    #mc
    #hyperfine

  # base tools 
    # alacritty
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
    #         tgpt
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
    #(pkgs.nerdfonts.override { fonts = [ "JetBrainsMono" ]; })

    # # You can also create simple shell scripts directly inside your
    # # configuration. For example, this adds a command 'my-hello' to your
    # # environment:
    # (pkgs.writeShellScriptBin "my-hello" ''
    #   echo "Hello, ${config.home.username}!"
    # '')
    #]  ++ lib.optionals stdenv.isDarwin [
    #cocoapods
    #m-cli # useful macOS CLI commands
    #wezterm
  ];
 # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  home.file = {
    # # Building this configuration will create a copy of 'dotfiles/screenrc' in
    # # the Nix store. Activating the configuration will then make '~/.screenrc' a
    # # symlink to the Nix store copy.
    # ".screenrc".source = dotfiles/screenrc;
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
  #  programs.home-manager.enable = true;
}