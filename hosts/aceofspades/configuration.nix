{inputs, config, pkgs, lib, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
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
  boot.loader = {
    grub = {
      device = "/dev/sda";
      enableCryptodisk = true;
      useOSProber = true;
      enable = true;
    };
  };
  networking.hostName = "aceofspades"; # Define your hostname.
  services.xserver.videoDrivers = [ "amdgpu" ];

  environment.systemPackages = with pkgs; [
    qutebrowser
    inputs.zen-browser.packages.${pkgs.system}.twilight
  ];

  hardware.graphics.extraPackages = [
    pkgs.mesa.opencl
  ];
  system.stateVersion = "24.05"; # Did you read the comment?

}
