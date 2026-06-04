# DEPRECATED: Part of orb-cassini (see configuration.nix for context).
# Retained as a reference only.

{pkgs, ...}: {
  services.tailscale.enable = true;
  #virtualisation.docker.rootless = {
  #  enable = true;
  #  setSocketVariable = true;
  #};
  #

  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    #libGL
    alsa-lib
  ];
}
