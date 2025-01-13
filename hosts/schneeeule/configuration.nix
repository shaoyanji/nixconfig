
{inputs, config, pkgs, lib, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ./nvidia.nix
      ./steam.nix
      ../impermanence.nix
      ../base-desktop-environment.nix
      ../minimal-desktop.nix
      inputs.sops-nix.nixosModules.sops
    ];
  sops = {
    defaultSopsFile = ../../modules/secrets/secrets.yaml;
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key"];
    secrets = {
      "server/localwd/credentials" = {};
      "server/keyrepo/credentials" = {};
    };
  };
  networking.hostName = "schneeeule"; # Define your hostname.
  environment.systemPackages = with pkgs; [
    qutebrowser
    inputs.zen-browser.packages.${pkgs.system}.twilight
  ];

  fileSystems."/persist/data" = {
    device = "/dev/disk/by-uuid/ae50ae59-36e2-4e9a-88d0-04951f6a51fc";
    fsType = "ext4";
  };

  system.stateVersion = "24.11"; # Did you read the comment?

}
