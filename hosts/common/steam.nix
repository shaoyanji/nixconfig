{
  pkgs,
  config,
  nix-std,
  lib,
  inputs,
  ...
}: {
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
    dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
    localNetworkGameTransfers.openFirewall = true; # Open ports in the firewall for Steam Local Network Game Transfers
  };

  # nixpkgs.config.allowUnfreePredicate = pkg:
  # builtins.elem (lib.getName pkg) [
  # "steam"
  # "steam-original"
  # "steam-run"
  # ];
  programs.steam.gamescopeSession.enable = true;
  programs.gamemode.enable = true;
  environment.systemPackages = with pkgs; [
    #    protonup
    #nvidia-docker
    #nvidia-container-toolkit
    #nvidia-modprobe
    #nvidia-settings
    #nvidia-smi
    #nvidia-xconfig
    #nvidia-cuda-toolkit
    #nvidia-cuda-dev
    #nvidia-cuda-doc
    #nvidia-cuda-samples
    #nvidia-opencl-icd
    #nvidia-opencl-dev
    #nvidia-opencl-doc
    proton-ge-custom
    #mangohud-git
  ];
  environment.sessionVariables = {
    STEAM_EXTRA_COMPAT_TOOLS_PATHS = "/home/devji/.steam/root/compatibilitytools.d";
  };
}
