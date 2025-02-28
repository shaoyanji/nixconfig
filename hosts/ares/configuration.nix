{...}: {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ../common/impermanence.nix
    ../common/base-desktop-environment.nix
  ];
  networking.hostName = "ares"; # Define your hostname.
  #environment.systemPackages = with pkgs; [
  #];
  system.stateVersion = "24.11"; # Did you read the comment?
}
