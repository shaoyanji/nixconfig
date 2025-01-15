{ config, lib, pkgs, ... }:
{

  environment.systemPackages = with pkgs; [
    incus
  ];

  virtualisation.incus.enable = true;
  networking.firewall.enable = true;
  networking.firewall.trustedInterfaces = [ "incusbr0" ];
  networking.nftables.enable = true;
  
}
