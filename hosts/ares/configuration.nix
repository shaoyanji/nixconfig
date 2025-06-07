{...}: {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ../common/impermanence.nix
    ../common/base-desktop-environment.nix
    ../common/laptop.nix
  ];
  services.thermald.enable = true;
  networking.hostName = "ares"; # Define your hostname.
  #environment.systemPackages = with pkgs; [
  #];
  system.stateVersion = "25.05"; # Did you read the comment?
}
