{...}: {
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  services.xserver.videoDrivers = ["nvidia"];

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = false;
    powerManagement.finegrained = false;
    open = false;
    nvidiaSettings = true;
    forceFullCompositionPipeline = true;
    prime = {
      offload.enable = true;
      sync.enable = false;
    };
  };

  hardware.nvidia-container-toolkit.enable = true;
  virtualisation.docker.enableNvidia = true;

  services.ollama = {
    enable = true;
    host = "0.0.0.0";
    openFirewall = true;
    environmentVariables = {
      OLLAMA_ORIGINS = "moz-extension://*,chrome-extension://*,safari-web-extension://*";
    };
  };
}
