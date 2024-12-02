{inputs, config, pkgs, lib, ... }:

{
  # Bootloader.
  boot.loader={
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };
  services={
    ollama = {
      enable = true;
      acceleration = "cuda";
    };
  };
  
  environment.systemPackages = with pkgs; [

  ];
}
