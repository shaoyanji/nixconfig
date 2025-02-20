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
