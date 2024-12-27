{inputs, config, pkgs, lib, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ./nvidia.nix
      ./steam.nix
      ../base-desktop-environment.nix
      ../minimal-desktop.nix
      #    <sops-nix/modules/sops>
      #      ../cifs.nix
    ];
  #sops.defaultSopsFile = ../../modules/secrets/secrets.nix;
  #sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key"];
  #TODO: finish the secrets ops.
  networking.hostName = "poseidon"; # Define your hostname.
  environment.systemPackages = with pkgs; [
    inputs.zen-browser.packages.${pkgs.system}.default
  ];
  system.stateVersion = "24.05"; # Did you read the comment?
}
