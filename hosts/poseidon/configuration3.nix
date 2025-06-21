{
  inputs,
  config,
  pkgs,
  lib,
  ...
}: {
  imports = [
    # Include the results of the hardware scan.
    #    ./configuration2.nix
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

  # nixpkgs.config.allowUnfreePredicate = pkg:
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
}
