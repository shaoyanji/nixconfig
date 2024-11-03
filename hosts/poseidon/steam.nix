{ pkgs, config, nix-std, lib, ... }:
{
  # For discord wayland pipewire screensharing
  #nixpkgs.config.ungoogled-chromium.commandLineArgs = "
  #  --ozone-platform=auto
  #  --disable-features=UseChromeOSDirectVideoDecoder
  #  --enable-features=RunVideoCaptureServiceInBrowserProcess
  #  --disable-gpu-memory-buffer-compositor-resources
  #  --disable-gpu-memory-buffer-video-frames
  #  --enable-hardware-overlays
  #";

  #/*nixpkgs.config.permittedInsecurePackages = [
  #  "libtiff-4.0.3-opentoonz"
  #  "libxls-1.6.2"
  #];*/

  #environment.systemPackages = with pkgs; [
  #  goofcord
  #];

  programs.steam = {
  enable = true;
  remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
  dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
  localNetworkGameTransfers.openFirewall = true; # Open ports in the firewall for Steam Local Network Game Transfers
  };

  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
    "steam"
    "steam-original"
    "steam-run"
];
programs.steam.gamescopeSession.enable = true;
programs.gamemode.enable = true;
}
