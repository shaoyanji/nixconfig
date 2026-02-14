{
  config,
  pkgs,
  lib,
  ...
}:

{
  microvm = {
    vcpu = 2;
    mem = 2048;

    interfaces = [
      {
        type = "tap";
        id = "microvm1";
        mac = "02:00:00:00:00:01";
      }
    ];

    shares = [
      {
        proto = "virtiofs";
        tag = "ro-store";
        source = "/nix/store";
        mountPoint = "/nix/.ro-store";
      }
      {
        proto = "virtiofs";
        tag = "workspace";
        source = "/home/devji/nixconfig/hosts/microvms/testvm";
        mountPoint = "/home/devji/workspace";
      }
    ];

    volumes = [
      {
        mountPoint = "/var";
        image = "var.img";
        size = 4096;
      }
    ];
  };

  networking.hostName = "testvm";
  networking.firewall.enable = false;

  services.openssh = {
    enable = true;
  };

  users.users.devji = {
    isNormalUser = true;
    extraGroups = ["wheel" "networkmanager"];
  };

  environment.systemPackages = with pkgs; [
    git
    curl
    wget
    vim
    htop
    neofetch
  ];

  system.stateVersion = "25.05";
}
