{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ../../modules/profiles/base-node.nix
    (import ../../modules/profiles/ai-host.nix {})
    ../../modules/services/nullclaw-deployment.nix
    # ../thinsandy/openclaw.nix
    # inputs.nix-openclaw.nixosModules.openclaw-gateway
    inputs.sops-nix.nixosModules.sops
  ];
  profiles.aiHost = {
    enable = true;
    nullclaw.enable = true;
  };
  aiServices.nullclawDeployment = {
    enable = true;
    mode = "env-file";
    listenHost = "127.0.0.1";
    listenPort = 3001;
    workspaceRoot = "/var/lib/nullclaw";
    environmentFile = config.sops.secrets."nullclaw".path;
  };
  sops.secrets.nullclaw = {
    owner = "nullclaw";
    group = "nullclaw";
    mode = "0400";
  };
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  # Use the GRUB 2 boot loader.
  #boot.loader.grub.enable = true;
  # boot.loader.grub.efiSupport = true;
  # boot.loader.grub.efiInstallAsRemovable = true;
  # boot.loader.efi.efiSysMountPoint = "/boot/efi";
  # Define on which hard drive you want to install Grub.
  #boot.loader.grub.device = "/dev/sda"; # or "nodev" for efi only

  networking.hostName = "mtfuji"; # Define your hostname.
  nixpkgs.overlays = [
    # inputs.nix-openclaw.overlays.default
  ];
  # Pick only one of the below networking options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # services.openclaw-gateway.config.channels.telegram.tokenFile = config.sops.secrets."morrow-telegram".path;
  # environment.systemPackages = with pkgs; [
  #   uv
  #   python313Packages.firecrawl-py
  #   python313Packages.neo4j
  #   btrfs-progs
  #   openclaw
  #   nfs-utils
  #   f2fs-tools
  #   git
  #   python3
  #   go
  #   nodejs
  #   fzf
  #   bat
  #   delta
  #   sqlite
  #   httpie
  #   yq
  #   shellcheck
  #   entr
  #   jq
  #   gnumake
  #   rsync
  #   age
  #   tmux
  #   file
  #   # diff

  #   yq # YAML/TOML/JSON processing
  #   ddgr # DuckDuckGo search CLI (web search fallback)
  #   bat # cat with syntax highlighting
  #   fd # fast file finder
  #   sqlite # database access
  #   gh # GitHub CLI

  #   # Nice to have
  #   fzf # fuzzy finder (pairs well with fd/bat)
  #   delta # better git diffs
  #   httpie # friendly HTTP client for APIs
  #   ncdu # disk usage explorer
  #   tree # directory tree view
  #   unzip # archive handling
  #   xxd # hex dump
  #   lsof # list open files
  #   pv # pipe viewer (progress bars)
  #   miller # mlr — CSV/JSON/log processing
  #   glow # markdown renderer in terminal
  #   sd # sed alternative (regex find/replace)
  #   hyperfine # CLI benchmarking
  #   tldr # simplified man pages
  #   watch # run commands periodically

  #   # Next
  #   ripgrep
  #   tmux
  #   tokei
  #   jq
  #   tgpt
  # ];

  # systemd.tmpfiles.rules = [
  #   # "d /srv/data/openclaw 0750 openclaw openclaw - -"
  # ];

  # fileSystems."/var/lib/openclaw/home" = {
  #   device = "/srv/data/openclaw";
  #   options = ["bind"];
  # };

  # services.openclaw-gateway = {
  #   execStartPre = [
  #     # "${pkgs.coreutils}/bin/install -d -o openclaw -g openclaw -m 0750 /var/lib/openclaw"
  #     # "${pkgs.coreutils}/bin/install -o openclaw -g openclaw -m 0600 /etc/openclaw/openclaw.json /var/lib/openclaw/openclaw.json"
  #   ];
  # };

  services.ollama = {
    enable = true;
    # acceleration = "cuda";
    host = "0.0.0.0";
    openFirewall = true;
    environmentVariables = {
      OLLAMA_ORIGINS = "moz-extension://*,chrome-extension://*,safari-web-extension://*";
    };
    # models = "/Volumes/data/ollama";
  };
  #powerManagement.powertop.enable = true;
  #virtualisation.docker.enable = true;

  # services.k3s = {
  #   enable = true;
  #   role = "server";
  #   tokenFile = "${config.sops.secrets."local/k3s/token".path}";
  #   clusterInit = true;
  # };
  # networking.firewall.allowedTCPPorts = [
  #   6443 # k3s: required so that pods can reach the API server (running on port 6443 by default)
  #   #    2379 # k3s, etcd clients: required if using a "High Availability Embedded etcd" configuration
  #   #    2380 # k3s, etcd peers: required if using a "High Availability Embedded etcd" configuration
  # ];

  # networking.firewall.allowedUDPPorts = [
  #   8472 # k3s, flannel: required if using multi-node for inter-node networking
  # ];
  system.stateVersion = "25.05"; # Did you read the comment?
}
