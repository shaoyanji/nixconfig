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

    manageUsbEthernet = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Keep the dock's CDC-NCM ethernet managed by NetworkManager, as a second
        uplink. Only correct when the dock cable terminates on the SAME L2
        segment as the host's other uplink.

        Do not enable this where the cable lands behind a cascaded router — a
        Huawei mesh puts each node's LAN on its own /24 (…3.0/24, …4.0/24,
        …5.0/24) and NATs upward. A host then holds two subnets at once, and the
        node interprets the parent address arriving on its own port as an
        upstream device, which takes its bridging down for everything behind it
        (observed 2026-10-23: a static parent address on a child node broke that
        node, and the same dual-homing on a dock cable cost a host its uplink).
        Leave it false and keep one uplink per host.
      '';
    };

    usbEthernetInterface = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "enp6s0f3u1u1i5";
      description = ''
        Exact interface name the dock NIC connection is bound to. Leave null to
        match the USB-attached pattern instead — but note NetworkManager then
        binds on first activation by rewriting the profile with `interface-name`
        and a UUID-suffixed filename, which lands beside the declarative file as
        a second connection with the same UUID.        The duplicate makes later
        activations fail, so pin the name wherever it is stable.
      '';
    };

    usbEthernetAddress = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "192.168.3.3/24";
      description = ''
        Static `<address>/<prefix>` for the dock uplink; null keeps DHCP.

        Set it where the LAN's DHCP keys on the client's hostname rather than its
        MAC: both links of one host then claim the same lease and the addresses
        trade places on every re-lease (measured on poseidon 2026-10-23 -- the
        dock took Wi-Fi's .2 and Wi-Fi fell back to .4).
      '';
    };

    usbEthernetGateway = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "192.168.3.1";
      description = "Default gateway for the static dock uplink (ignored while usbEthernetAddress is null).";
    };
  };

  # Generic alias option so hosts can enable either profiles.dell-dock or profiles.docking-station
  options.profiles.docking-station = {
    enable = lib.mkEnableOption "docking station support (Dell D6000 Universal Dock)";
  };

  config = lib.mkIf cfg.enable {
    warnings = lib.optional cfg.manageUsbEthernet ''
      profiles.dell-dock.manageUsbEthernet is enabled. That is only safe when the
      dock cable is on the same L2 segment as the host's other uplink; behind a
      cascaded mesh node (Huawei …3/…4/…5 /24 chain) it dual-homes the host across
      two subnets and can take that node's bridging down for every device behind
      it.
    '';

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

    # EVDI is a kernel module and must be built against the running kernel and
    # installed: naming it in boot.kernelModules alone yields "Failed to find
    # module 'evdi'" and the dock then drives USB and ethernet but no display.
    # It also needs drm_ttm_helper for GEM buffer mapping (drm_gem_ttm_vmap).
    boot.extraModulePackages = [config.boot.kernelPackages.evdi];
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
    # enp0s20f0u2u1i5 on frieren). Left to NetworkManager's auto-generated
    # "Wired connection N", every dock/replug mints a NEW profile and takes a
    # fresh DHCP lease (observed .60, then .253), which the router then
    # recycles to the next device — the duplicate-address window behind
    # poseidon/.74 answering from two MACs. One matched profile renews the
    # same lease instead, so the dock can move between hosts without churn.
    #
    # Hosts where the port is spare (frieren, fern) keep it unmanaged: no
    # lease at all beats a stale third default route.
    networking.networkmanager.unmanaged = lib.mkIf (!cfg.manageUsbEthernet) [
      "driver:cdc_ncm"
    ];

    networking.networkmanager.ensureProfiles.profiles = lib.mkIf cfg.manageUsbEthernet {
      dock-ethernet = {
        connection =
          {
            id = "dock-ethernet";
            # Fixed, so a NetworkManager rewrite cannot mint a second identity
            # for the same profile.
            uuid = "b37ece9c-f7c4-440c-b49f-1dd1c851c03c";
            type = "ethernet";
            autoconnect = true;
            # Above any auto-generated "Wired connection N" NM has minted for the
            # same USB device (priority 0), so a re-activation always picks this.
            autoconnect-priority = 100;
          }
          // lib.optionalAttrs (cfg.usbEthernetInterface != null) {
            interface-name = cfg.usbEthernetInterface;
          }
          // lib.optionalAttrs (cfg.usbEthernetInterface == null) {
            # Falling back to the USB pattern: the name is renamed by port/hub
            # and differs per host, so each host matches its own.
            match-device = "interface-name:enp*u*";
          };
        # Fleet resolver (Pi-hole on frieren). The dock link's DHCP answer is the
        # router, which does not serve the ~lan names; without this, the wired
        # link silently becomes the primary resolution path and those break.
        ipv4 =
          {
            dns = "192.168.3.25";
            # A metric above Wi-Fi's. Two equal-metric defaults let this cable win
            # the default route, so a flaky dock uplink takes browsing and DNS down
            # with it. At 600 the dock is a fallback for when Wi-Fi is absent, not a
            # competing primary.
            route-metric = 600;
          }
          // (
            if cfg.usbEthernetAddress == null
            then {method = "auto";}
            else {
              method = "manual";
              address1 = cfg.usbEthernetAddress;
            }
          )
          // lib.optionalAttrs (cfg.usbEthernetAddress != null && cfg.usbEthernetGateway != null) {
            gateway = cfg.usbEthernetGateway;
          };
        ipv6.method = "auto";
        ipv6.route-metric = 600;
      };
    };

    # The declarative profiles land in /run/NetworkManager/system-connections,
    # and the unit that writes them starts *after* NetworkManager -- at boot NM
    # therefore has carrier on the dock before the profile exists, assumes the
    # device with a DHCP connection and keeps it. Measured 2026-10-23: after a
    # reboot the dock held .3 by DHCP at metric 100 while `dock-ethernet` sat
    # inactive. Bringing the profile up once the files exist settles it.
    systemd.services.NetworkManager-ensure-profiles = lib.mkIf cfg.manageUsbEthernet {
      postStart = ''
        ${config.networking.networkmanager.package}/bin/nmcli connection up dock-ethernet || true
      '';
    };

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
