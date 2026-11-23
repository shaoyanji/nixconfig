{
  self,
  config,
  lib,
  nvidiaPkgs,
  ...
}: {
  imports = [
    self.modules."profiles.nvidia"
  ];

  services.xserver.videoDrivers = ["intel"];
  nixpkgs.config.nvidia.acceptLicense = true;
  # nvidia-settings-470 pulls gtk2; nixpkgs marks it broken pending NixOS 27.05
  nixpkgs.config.problems.handlers."gtk+".broken = "warn";

  boot.kernelPackages = lib.mkForce nvidiaPkgs.linuxPackages;
  hardware.nvidia = {
    open = false;
    package = config.boot.kernelPackages.nvidiaPackages.legacy_470;
    nvidiaPersistenced = false;
    prime = {
      nvidiaBusId = "PCI:9:0:0";
      intelBusId = "PCI:0:2:0";
    };
  };
}
