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
    experimental-features = ["nix-command" "flakes"];
    substituters= [
      "https://cache.nixos.org/"
      "https://nix-community.cachix.org"
      "https://chaotic-nyx.cachix.org/"
      "https://shaoyanji.cachix.org"
      "https://hyprland.cachix.org"
      "https://wezterm.cachix.org"
      "https://ghostty.cachix.org"
    ];
    trusted-public-keys= [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "chaotic-nyx.cachix.org-1:HfnXSw4pj95iI/n17rIDy40agHj12WfF+Gqk6SonIT8="
      "shaoyanji.cachix.org-1:3XUZGFcaq5bXFKwtCR+POG81Hh6WfTqf50Bmz4VHpj0="
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
      "wezterm.cachix.org-1:kAbhjYUC9qvblTE+s7S+kl5XM1zVa4skO+E/1IDWdH0="
      "ghostty.cachix.org-1:QB389yTa6gTyneehvqG58y0WnHjQOqgnA+wBnpWWxns="
    ];
    #      trusted-users = [
    #    "@admin"
    #  ];
  };

  # Enable experimental nix command and flakes
  # nix.package = pkgs.nixUnstable;
  nix.optimise.automatic = true;
  nix.extraOptions = ''
    min-free = ${toString (100 * 1024 * 1024)}
    max-free = ${toString (1024 * 1024 * 1024)}
  '';
  nix.nixPath = [
    "nixpkgs=${pkgs.path}"
  ];
  environment.systemPackages = with pkgs; [
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
  fonts.packages = [
    pkgs.nerd-fonts.jetbrains-mono
  #  (pkgs.nerdfonts.override { fonts = ["JetBrainsMono"]; })
  ];
  nixpkgs.config.allowUnsupportedSystem = true;
  nixpkgs.config.allowUnfree = true;
}
