{...}: {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ../../modules/profiles/impermanence.nix
    ../../modules/profiles/base-desktop-environment.nix
    ../../modules/profiles/laptop.nix
  ];
  networking.hostName = "ares"; # Define your hostname.
  #environment.systemPackages = with pkgs; [
  #];
  system.stateVersion = "25.05"; # Did you read the comment?
}
