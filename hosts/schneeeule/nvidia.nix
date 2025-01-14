{config, lib, pkgs, ...}:
{
  hardware.graphics= {
    enable = true;
    enable32Bit = true;
  };
  
  nixpkgs.config = {
    allowUnfree = true;
    nvidia.acceptLicense = true;
  };
  
  services.xserver.videoDrivers = [ "intel" "nvidia"];
  
  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = false;
    powerManagement.finegrained = false;
    open = false;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    forceFullCompositionPipeline = true;
    prime = {
      offload.enable = true;
      sync.enable = false;
      nvidiaBusId = "PCI:9:0:0";
      intelBusId = "PCI:0:2:0";
    };
  };
  specialisation = {
    legacynvidia.configuration = {
      system.nixos.tags = [ "Gaming" ];
      hardware.nvidia = {
        prime.offload.enable = lib.mkForce false;
        prime.offload.enableOffloadCmd = lib.mkForce false;
        prime.sync.enable = lib.mkForce true;
      };
    };
  };

    services.ollama = {
      enable = true;
      acceleration = "cuda";
    };
}
