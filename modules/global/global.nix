{
  pkgs,
  inputs,
  lib,
  ...
}: {
  imports = [
  ];

  nix = {
    gc = {
      automatic = true;
      options = "--delete-older-than 10d";
    };
  };

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
      "pipe-operators"
      # "pipe-operator"
    ];
    substituters = [
      "https://cache.nixos.org/"
      "https://nix-community.cachix.org"
      "https://chaotic-nyx.cachix.org/"
      "https://hyprland.cachix.org"
      # "https://wezterm.cachix.org"
      #      "https://ghostty.cachix.org"
      "https://nix-gaming.cachix.org"
      # "https://cache.lix.systems"
      "https://cuda-maintainers.cachix.org"
      "https://cache.garnix.io"
      "https://shaoyanji.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "chaotic-nyx.cachix.org-1:HfnXSw4pj95iI/n17rIDy40agHj12WfF+Gqk6SonIT8="
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
      # "wezterm.cachix.org-1:kAbhjYUC9qvblTE+s7S+kl5XM1zVa4skO+E/1IDWdH0="
      #      "ghostty.cachix.org-1:QB389yTa6gTyneehvqG58y0WnHjQOqgnA+wBnpWWxns="
      "nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4="
      # "cache.lix.systems:aBnZUw8zA7H35Cz2RyKFVs3H4PlGTLawyY5KRbvJR8o="
      "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
      "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
      "shaoyanji.cachix.org-1:3XUZGFcaq5bXFKwtCR+POG81Hh6WfTqf50Bmz4VHpj0="
    ];
    trusted-users = [
      "@admin"
      "@wheel"
      # "root"
      # "nixremote"
    ];
  };

  # Enable experimental nix command and flakes
  nix = {
    package = pkgs.nixVersions.latest;
    # package = pkgs.lix;
    optimise.automatic = true;
    extraOptions = ''
      min-free = ${toString (100 * 1024 * 1024)}
      max-free = ${toString (1024 * 1024 * 1024)}
    '';
    nixPath = [
      "nixpkgs=${pkgs.path}"
    ];
  };

  #  programs.nix-index.enable = true;
  #  programs.nix-index-database.comma.enable = true;
  #  nixpkgs.config.allowUnsupportedSystem = true;
  # nixpkgs.config.allowUnfree = true;
  # nixpkgs.config.allowUnfreePredicate = pkg:
  #   builtins.elem (lib.getName pkg) [
  #     "obsidian"
  #     "steam"
  #     "steam-original"
  #     "steam-unwrapped"
  #     "steam-run"
  #   ];

  # nixpkgs.config = {
  #   allowUnfree = true;
  #   nvidia.acceptLicense = true;
  #   cudaSupport = true; # Enables CUDA support
  # };
}
