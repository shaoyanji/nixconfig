{
  inputs,
  config,
  pkgs,
  lib,
  ...
}: {
  imports = [
    ./configuration.nix
  ];

  networking.hostName = "poseidon"; # Define your hostname.
  environment = {
    systemPackages = with pkgs; [
      inputs.quickshell.packages.${stdenv.hostPlatform.system}.default
    ];
    #variables = {
    # };
  };

  qt.enable = true;

  services = {
    displayManager = {
      sddm = {
        enable = true;
        wayland.enable = true;
      };
      #    xserver.digimend.enable = true;
    };
  }; # nixpkgs.config.allowUnfreePredicate = pkg:
  #   builtins.elem (lib.getName pkg) [
  #     "steam"
  #     "steam-original"
  #     "steam-run"
  #     "steam-unwrapped"
  #     "nvidia-x11"
  #     "cuda_cudart"
  #     "libcublas"
  #     "cuda_cccl"
  #     "cuda_nvcc"
  #     "nvidia-settings"
  #     "nvidia-persistenced"
  #     "ngrok"
  #   ];

  system.stateVersion = "25.11"; # Did you read the comment?
  nixpkgs.config = {
    allowUnfree = true;
    nvidia.acceptLicense = true;
    cudaSupport = true; # Enables CUDA support
  };

  programs.fish.enable = true;
  programs.foot.enable = true;
  i18n = {
    consoleFont = "Lat2-Terminus16";
    consoleKeyMap = lib.mkForce "sv-latin1";
    defaultLocale = "en_US.UTF-8";
  };
  services.xserver = {
    enable = true;
    layout = "se";
    xkbOptions = "eurosign:e";

    # Truncated the displayManager and desktopManager settings for brevity
  };
}
