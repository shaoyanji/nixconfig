# Dell D6000 Universal Dock profile (DisplayLink / EVDI, dlm, and USB autosuspend prevention).
{
  config,
  lib,
  ...
}: let
  cfg = config.profiles.dell-dock;
in {
  options.profiles.dell-dock = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.profiles.docking-station.enable;
      description = "Dell D6000 Universal Dock (DisplayLink / EVDI) hardware support";
    };

    ignoreLidSwitch = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Ignore laptop lid switch when connected to dock (HandleLidSwitchDocked=ignore).";
    };

    preventAutosuspend = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Disable USB autosuspend for DisplayLink, USB hubs, and Bluetooth adapters.";
    };
  };

  # Generic alias option so hosts can enable either profiles.dell-dock or profiles.docking-station
  options.profiles.docking-station = {
    enable = lib.mkEnableOption "docking station support (Dell D6000 Universal Dock)";
  };

  config = lib.mkIf cfg.enable {
    # Synaptics upstream zip is fetched via fetchurl so hydra/nixbuild can build it without requireFile prompts.
    nixpkgs.overlays = [
      (final: _prev: {
        displaylink = _prev.displaylink.overrideAttrs (_old: {
          src = final.fetchurl {
            url = "https://www.synaptics.com/sites/default/files/exe_files/2026-06/DisplayLink%20USB%20Graphics%20Software%20for%20Ubuntu6.3-EXE.zip";
            hash = "sha256-cmmFbHUnBgxRMhXOG1o2/vB02Oicq4m8qxPfNCrM4Jg=";
            name = "displaylink-630.zip";
          };
        });
      })
    ];

    # DisplayLink video driver (appended so primary GPU drivers like amdgpu/nvidia remain first)
    services.xserver.videoDrivers = lib.mkAfter ["displaylink" "modesetting"];

    # EVDI kernel module requires drm_ttm_helper for GEM buffer mapping symbols (drm_gem_ttm_vmap)
    boot.kernelModules = ["drm_ttm_helper" "evdi"];

    # DisplayLink Manager daemon
    systemd.services.dlm = {
      wantedBy = ["multi-user.target"];
    };

    # Disable USB autosuspend: kernel 6.12 defaults enable_autosuspend=Y (and usbcore.autosuspend=2),
    # which aggressively powers down BT adapters after 2s and drops DisplayLink DL-6950 ASIC / USB 3.0 hubs.
    boot.kernelParams = lib.mkIf cfg.preventAutosuspend [
      "usbcore.autosuspend=-1"
      "consoleblank=0"
    ];

    services.udev.extraRules = lib.mkIf cfg.preventAutosuspend ''
      # Prevent autosuspend and enable wakeup on DisplayLink docks and external USB hubs
      ACTION=="add|change", SUBSYSTEM=="usb", ATTR{idVendor}=="17e9", ATTR{power/control}="on", ATTR{power/wakeup}="enabled"
      ACTION=="add|change", SUBSYSTEM=="usb", ATTR{idVendor}=="05e3", ATTR{power/control}="on", ATTR{power/wakeup}="enabled"
      ACTION=="add|change", SUBSYSTEM=="usb", ATTR{idVendor}=="06c4", ATTR{power/control}="on", ATTR{power/wakeup}="enabled"
    '';

    # The dock's Ethernet is a USB CDC-NCM device (`cdc_ncm`, e.g.
    # enp0s20f0u2u1i5 on frieren). Left managed, NetworkManager treats every
    # dock/replug as a new connection and takes a fresh DHCP lease (observed
    # .60, then .253), which the router then recycles to the next device. The
    # port is spare — frieren and fern each keep their own wired/wifi uplink —
    # so leave it unmanaged: no lease churn, and no duplicate-address window
    # against a device that already holds that address.
    networking.networkmanager.unmanaged = [
      "driver:cdc_ncm"
    ];

    # Disable USB autosuspend for btusb: kernel 6.12 defaults enable_autosuspend=Y,
    # which aggressively powers down BT adapters after 2s and drops connection to MX Keys/Master.
    boot.extraModprobeConfig = lib.mkIf cfg.preventAutosuspend ''
      options btusb enable_autosuspend=n
    '';

    # Keep docked laptops alive when the lid is closed
    services.logind.settings.Login = lib.mkIf cfg.ignoreLidSwitch {
      HandleLidSwitchDocked = lib.mkDefault "ignore";
    };
  };
}
