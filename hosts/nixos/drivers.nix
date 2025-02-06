{
  pkgs,
  userConfig,
  ...
}:
let
  # ... existing let bindings ...

  # Define the hardware configuration based on userConfig
  hasAmdCpu = builtins.elem "amdcpu" userConfig.drivers or [ ];
  hasIntelCpu = builtins.elem "intel" userConfig.drivers or [ ];
  hasAmdGpu = builtins.elem "amdgpu" userConfig.drivers or [ ];
  hasNvidia = builtins.elem "nvidia" userConfig.drivers or [ ];
  hasOlderIntelCpu = builtins.elem "intel-old" userConfig.drivers or [ ];

  # Define when Mesa is needed based on hardware configuration
  needsMesa = hasAmdGpu || hasIntelCpu || hasOlderIntelCpu;
in
{

  # ===== Hardware Configuration =====
  hardware = {
    # Existing config
    graphics = {
      enable = true;
      enable32Bit = true;
      extraPackages = pkgs.lib.flatten (
        with pkgs;
        [
          # AMD GPU packages
          (lib.optional hasAmdGpu amdvlk)

          # Nvidia GPU packages
          (lib.optional hasNvidia nvidia-vaapi-driver)
          (lib.optional hasNvidia libva-vdpau-driver)

          # Intel Cpu packages
          (lib.optional hasIntelCpu intel-media-driver)
          (lib.optional hasOlderIntelCpu intel-vaapi-driver)

          # Mesa
          (lib.optional needsMesa mesa)
        ]
      );
      extraPackages32 = pkgs.lib.flatten (
        with pkgs;
        [
          # AMD GPU packages
          (lib.optional hasAmdGpu amdvlk)

          # Nvidia GPU packages
          (lib.optional hasNvidia libva-vdpau-driver)

          # Intel Cpu packages
          (lib.optional hasIntelCpu intel-media-driver)
          (lib.optional hasOlderIntelCpu intel-vaapi-driver)

          # Mesa
          (lib.optional needsMesa mesa)
        ]
      );
    };

    # CPU Configuration
    cpu = {
      amd.updateMicrocode = hasAmdCpu;
      intel.updateMicrocode = hasIntelCpu || hasOlderIntelCpu;
    };

    # Nvidia specific configuration
    nvidia = pkgs.lib.mkIf hasNvidia {
      modesetting.enable = true;
      powerManagement = {
        enable = false;
      };
      open = false;
      nvidiaSettings = true;
      forceFullCompositionPipeline = true;
    };
  };

  # Boot configuration for GPU support
  boot = {

    # Kernel parameters
    kernelParams =
      with pkgs.lib;
      [ ]
      ++ (optionals hasAmdCpu [ "amd_pstate=active" ])
      ++ (optionals hasAmdGpu [
        "radeon.si_support=0"
        "amdgpu.si_support=1"
      ])
      ++ (optionals hasNvidia [ "nvidia-drm.modeset=1" ]);

    # Kernel modules
    kernelModules =
      with pkgs.lib;
      [ ]
      ++ (optionals hasAmdCpu [ "kvm-amd" ])
      ++ (optionals (hasIntelCpu || hasOlderIntelCpu) [ "kvm-intel" ])
      ++ (optionals hasAmdGpu [ "amdgpu" ])
      ++ (optionals hasNvidia [
        "nvidia"
        "nvidia_drm"
        "nvidia_modeset"
      ]);

    # Module blacklisting
    blacklistedKernelModules =
      with pkgs.lib;
      [ ] ++ (optionals hasAmdGpu [ "radeon" ]) ++ (optionals hasNvidia [ "nouveau" ]);

    # Extra modprobe config for Nvidia
    extraModprobeConfig = pkgs.lib.mkIf hasNvidia ''
      options nvidia-drm modeset=1
      options nvidia NVreg_PreserveVideoMemoryAllocations=1
    '';
  };

  # Environment packages for GPU support
  environment.systemPackages =
    with pkgs;
    lib.optionals (needsMesa) [
      mesa
    ]
    ++ lib.optionals (hasAmdGpu) [
      vulkan-tools
      vulkan-loader
      vulkan-validation-layers
      amdvlk
    ]
    ++ lib.optionals hasNvidia [
      nvidia-vaapi-driver
      libva-vdpau-driver
      vulkan-tools
      vulkan-loader
      vulkan-validation-layers
    ];

}
