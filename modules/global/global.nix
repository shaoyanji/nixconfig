{ pkgs, lib, config, inputs, ... }:
{
  imports = [ 
    ./lf
    #inputs.sops-nix.nixosModules.sops
    ];
  #sops = {
  #  defaultSopsFile = ./secrets.yaml;
  #  validateSopsFiles = false;
  #  age = {
  #    sshKeyPaths = ["/var/root/.ssh/id_ed25519"];
  #    keyFile = "/var/lib/sops-nix/keys.txt";
  #    generateKey = true;
  #  };
  #  secrets = {
  #    local ={};
  #  };
  #};
 # Nix configuration ------------------------------------------------------------------------------
  #
  nix.settings = {
    substituters= [
      "https://cache.nixos.org/"
    ];
    trusted-public-keys= [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    ];
      trusted-users = [
        "@admin"
      ];
  };

  nix.configureBuildUsers = true;

  # Enable experimental nix command and flakes
  # nix.package = pkgs.nixUnstable;
  nix.extraOptions = ''
    auto-optimise-store = true
    experimental-features = nix-command flakes
  '';

  # Create /etc/bashrc that loads the nix-darwin environment.
  #programs.zsh.enable = true;

  # Auto upgrade nix package and the daemon service.
  services.nix-daemon.enable = true;
  # Apps
  # `home-manager` currently has issues adding them to `~/Applications`
  # Issue: https://github.com/nix-community/home-manager/issues/1341
  environment.systemPackages = with pkgs; [
  ];

  # https://github.com/nix-community/home-manager/issues/423
  environment.variables = {
    #    TERMINFO_DIRS = "${pkgs.kitty.terminfo.outPath}/share/terminfo";
  };
  programs.nix-index.enable = true;

  # Fonts
  fonts.packages = [
    (pkgs.nerdfonts.override { fonts = ["JetBrainsMono"]; })
  ];
      
 
      nixpkgs.config.allowUnsupportedSystem = true;
      nixpkgs.config.allowUnfree = true;
 
}
