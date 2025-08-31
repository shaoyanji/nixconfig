{
  config,
  pkgs,
  inputs,
  ...
}:
let
  age_key_path = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
in
{
  home.username = "jisifu";
  home.homeDirectory = "/home/jisifu";
  home.stateVersion = "22.05";
  imports = [
    # inputs.sops-nix.homeManagerModules.sops
    ../modules/env.nix
    ../modules/lf
    ../modules/shell
    ../modules/helix.nix
    inputs.kickstart-nixvim.homeManagerModules.default
  ];

  programs.nixvim.enable = true;
  home.packages = with pkgs; [
    sops
    nix-index
    aichat
    tgpt
    go-task
    yq-go
    # cmark
    age
    pop
    glow
    charm-freeze
    viu
    qrencode
    duf
    slides
    graphviz
    graph-easy
    nix-output-monitor
    gum
    mailsy
    sqlite
    lynx
    caddy
    go
    tinygo
    yj
    gcc
    pandoc
    translate-shell
    xq
    comrak
    cloak
    hyperfine
    fastfetch
    asciinema
    python3
    md2pdf
    ddgr
    qrencode
    wasmtime
    ghc
    rustc
    hare
    ghostscript_headless
  ];
  home.sessionVariables = {
    GUM_CHOOSE_SELECTED_FOREGROUND = 50;
    GUM_CHOOSE_CURSOR_FOREGROUND = 50;
    GUM_CHOOSE_HEADER_FOREGROUND = 30;
    BROWSER = "lynx";
    SOPS_EDITOR = "hx";
  };
  home.file = {
    "Caddyfile".source = config.lib.file.mkOutOfStoreSymlink ../modules/config/Caddyfile;
  };

  home.sessionVariables = {
    EDITOR = "nvim";
  };
  # sops = {
  #     age = {
  #       keyFile = "${age_key_path}";
  #       generateKey = true;
  #       #sshKeyPaths = [ "${ssh_key_path}" ];
  #     };
  #     defaultSopsFile = ./secrets/server/secrets.yaml;
  #     validateSopsFiles = false;
  #     secrets = {
  #       # "awscredentials".path = "${config.home.homeDirectory}/.aws/credentials";
  #       # "cfcertpem".path = "${config.home.homeDirectory}/.cloudflared/cert.pem";
  #       # "cloak".path = "${config.home.homeDirectory}/.cloak/accounts";
  #       #"${local_ssh_key}".path = "${ssh_key_path}";
  #       #
  #     };
  #   };
  programs.home-manager.enable = true;
}
