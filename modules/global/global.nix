{ pkgs, inputs, ... }:
{
  imports = [ 

    ];

 # Nix configuration ------------------------------------------------------------------------------
  #
  nix = {
    gc = {
      automatic = true;
      options = "--delete-older-than 10d";
    };
  };

  nix.settings = {
    substituters= [
      "https://cache.nixos.org/"
      "https://nix-community.cachix.org"
      "https://hyprland.cachix.org"
    ];
    trusted-public-keys= [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "shaoyanji.cachix.org-1:3XUZGFcaq5bXFKwtCR+POG81Hh6WfTqf50Bmz4VHpj0="
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
    ];
      trusted-users = [
        "@admin"
      ];
  };

  # Enable experimental nix command and flakes
  # nix.package = pkgs.nixUnstable;
  nix.extraOptions = ''
    auto-optimise-store = true
    experimental-features = nix-command flakes
  '';
  nix.nixPath = [
    "nixpkgs=${pkgs.path}"
  ];
  environment.systemPackages = with pkgs; [
    nixd
    devenv
  ];
  # Create /etc/bashrc that loads the nix-darwin environment.
  #programs.zsh.enable = true;

  # Auto upgrade nix package and the daemon service.
  #  services.nix-daemon.enable = true;
  # Apps
  # `home-manager` currently has issues adding them to `~/Applications`
  # Issue: https://github.com/nix-community/home-manager/issues/1341
  #  environment.systemPackages = with pkgs; [
  #];

  # https://github.com/nix-community/home-manager/issues/423
  #environment.variables = {
  #};
  #  programs.nix-index.enable = true;

  # Fonts
  #fonts.packages = [
  #  (pkgs.nerdfonts.override { fonts = ["JetBrainsMono"]; })
  #];
      nixpkgs.config.allowUnsupportedSystem = true;
      nixpkgs.config.allowUnfree = true;
}
