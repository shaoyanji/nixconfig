{
  config,
  pkgs,
  inputs,
  ...
}:
## Please read the home-configuration.nix manpage for a list of all available options.
let
  # local_ssh_key= "local/mb1/ssh/private-key";
  # local_ssh_key= "local/ps1xp/ssh/private-key";
  # local_ssh_key= "local/bizmac/ssh/private-key";
  # local_ssh_key= "local/aceofspades/ssh/private-key";
  #ssh_key_path = "${config.home.homeDirectory}/.ssh/id_ed25519";
  age_key_path = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
  # taskfile_path = ./secrets/Taskfile.yaml;
in {
  home.username = "jisifu";
  home.homeDirectory = "/home/jisifu";
  home.stateVersion = "22.05";
  imports = [
    # inputs.sops-nix.homeManagerModules.sops
    ../modules/env.nix
    ../modules/lf
    ../modules/shell
    ../modules/helix.nix
    ../modules/nixvim
    # ../modules/shell/nushell.nix #included in shell now
  ];
  home.packages = with pkgs; [
    nix-index
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
  ];
  home.sessionVariables = {
    GUM_CHOOSE_SELECTED_FOREGROUND = 50;
    GUM_CHOOSE_CURSOR_FOREGROUND = 50;
    GUM_CHOOSE_HEADER_FOREGROUND = 30;
    BROWSER = "lynx";
    SOPS_EDITOR = "hx";
  }; # Let Home Manager install and manage itself.
  home.file = {
    # "public_html".source = config.lib.file.mkOutOfStoreSymlink "${WWW}";
  };

  # sops = {
  #     age = {
  #       keyFile = "${age_key_path}";
  #       generateKey = true;
  #       #sshKeyPaths = [ "${ssh_key_path}" ];
  #     };
  #     defaultSopsFile = ./secrets/secrets.yaml;
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
