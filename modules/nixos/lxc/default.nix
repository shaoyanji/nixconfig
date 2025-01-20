{ config, lib, pkgs, ... }:
{

  environment.systemPackages = with pkgs; [
    incus
  ];

  virtualisation.incus.enable = true;
  networking.firewall.enable = true;
  networking.firewall.trustedInterfaces = [ "incusbr0" ];
  networking.firewall.interfaces.incusbr0.allowedTCPPorts = [ 53 67 ];
  networking.firewall.interfaces.incusbr0.allowedUDPPorts = [ 53 67 ];
  networking.nftables.enable = true;

  
}
