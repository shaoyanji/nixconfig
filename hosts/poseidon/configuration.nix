{inputs, config, pkgs, lib, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ./nvidia.nix
      ./steam.nix
      ../base-desktop-environment.nix
      ../minimal-desktop.nix
      # ../cifs.nix
    ];
  boot.kernelPackages = pkgs.linuxPackages_latest;
  sops = {
    defaultSopsFile = ../../modules/secrets/secrets.yaml;
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key"];
    secrets = {
      "server/localwd/credentials" = {};
      "server/keyrepo/credentials" = {};
    };
  };
  networking.hostName = "poseidon"; # Define your hostname.
  environment.systemPackages = with pkgs; [
    qutebrowser
    libreoffice
    hunspell
    hunspellDicts.en_US
    inputs.zen-browser.packages.${pkgs.system}.twilight
  ];
  environment.variables = {

  };
  system.stateVersion = "24.05"; # Did you read the comment?
}
