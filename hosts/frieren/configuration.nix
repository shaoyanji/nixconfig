{
  config,
  lib,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    ./hardware.nix
    ../../modules/profiles/base-node.nix
    ../../modules/profiles/server-hardening.nix
    ../../modules/profiles/laptop.nix
    ./dns.nix
    ./media-stack.nix
    ./paperless.nix
    ./tools.nix
    ./networking.nix
    ../../modules/services/aria2-daemon.nix

    # ... your imports ...
  ];
  networking.hostName = "frieren";

  sops.secrets."aria2-rpc-secret" = {
    owner = "aria2";
    group = "aria2";
    mode = "0400";
  };

  services.aria2-daemon = {
    enable = true;
    downloadDir = "/srv/data/downloads";
    rpcHost = "0.0.0.0";
    rpcSecretFile = config.sops.secrets."aria2-rpc-secret".path;
    nginx.enable = true;
    nginx.listenPort = 6801;
  };

  # --- Boot parameters for power saving ---
  boot.kernelParams = [
    "consoleblank=30" # Blank console after 30s idle
    "i915.enable_dc=2" # DC5/DC6 deep power saving on i915
    "i915.enable_psr=2" # Panel Self-Refresh v2 (eDP power saving)
    "i915.enable_guc=2" # GuC submission + HuC loading (HEVC encoding)
    "i915.enable_fbc=1" # Frame Buffer Compression
    "intel_idle.max_cstate=9" # Allow deep C-states (C8-C9 for KBL)
    "processor.max_cstate=9" # Match intel_idle
  ];

  # --- Ensure ideapad_laptop kernel module is loaded for conservation mode ---
  boot.kernelModules = ["ideapad_laptop"];

  # --- Thermal management (controls fan curve on Intel) ---
  services.thermald.enable = true;

  services.logind = {
    lidSwitch = "ignore";
    lidSwitchDocked = "ignore";
    lidSwitchExternalPower = "ignore";
  };

  # --- Override auto-cpufreq: even on charger, stay in powersave (server, not workstation) ---
  services.auto-cpufreq.settings.charger = {
    governor = lib.mkDefault "powersave";
    # turbo = "never";
  };

  # --- Turn off the internal display at boot (headless server) ---
  systemd.services.frieren-headless = {
    description = "Frieren headless server — turn off display and set GPU power saving";
    after = ["multi-user.target"];
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      # Turn off internal display backlight
      for bl in /sys/class/backlight/*/brightness; do
        [ -f "$bl" ] && echo 0 > "$bl" 2>/dev/null || true
      done
      # Put GPU into automatic power saving
      echo auto > /sys/class/drm/card0/power/control 2>/dev/null || true
      # Put PCI devices into auto power saving
      for ctrl in /sys/class/drm/card0/*/power/control; do
        [ -f "$ctrl" ] && echo auto > "$ctrl" 2>/dev/null || true
      done
      # Enable battery conservation mode (~60% charge limit, extends battery life)
      for cons in /sys/bus/platform/drivers/ideapad_acpi/*/conservation_mode; do
        [ -f "$cons" ] && echo 1 > "$cons" 2>/dev/null || true
      done
    '';
  };

  # Disable all forms of sleep
  systemd.sleep.settings.Sleep = {
    AllowSuspend = "no";
    AllowHibernation = "no";
    AllowHybridSleep = "no";
    AllowSuspendThenHibernate = "no";
  };

  # Disable automatic suspend
  powerManagement = {
    enable = true;
    powerDownCommands = "";
    cpuFreqGovernor = "powersave"; # 24/7 server, no need for performance governor
  };

  # --- Boot Settings (optional but recommended) ---
  # Skip boot menu timeout (no keyboard needed)
  boot.loader.grub.timeout = 0;
  # --- Samba Configuration ---
  services.samba = {
    enable = true;
    securityType = "user";
    settings = {
      global = {
        workgroup = "WORKGROUP";
        "server string" = config.networking.hostName;
        "netbios name" = config.networking.hostName;
        "map to guest" = "bad user";
        "guest account" = "nobody";
      };
    };

    shares = {
      data = {
        path = "/export/data";
        "browseable" = "yes";
        "read only" = "no";
        "guest ok" = "no";
        "create mask" = "0644";
        "directory mask" = "0755";
      };
      private = {
        path = "/export/private";
        "browseable" = "yes";
        "read only" = "no";
        "guest ok" = "no";
        "create mask" = "0644";
        "directory mask" = "0755";
      };
      public = {
        path = "/export/public";
        "browseable" = "yes";
        "read only" = "no";
        "guest ok" = "no";
        "create mask" = "0644";
        "directory mask" = "0755";
      };
    };
  };

  # Samba RuntimeDirectory fix
  systemd.services.samba-smbd.serviceConfig.RuntimeDirectory = ["lock" "lock/samba"];
  systemd.services.samba-nmbd.serviceConfig.RuntimeDirectory = ["lock" "lock/samba"];
  systemd.services.samba-winbindd.serviceConfig.RuntimeDirectory = ["lock" "lock/samba"];

  # Samba WSDD
  services.samba-wsdd = {
    enable = true;
    openFirewall = true;
  };

  # NFS exports
  services.nfs.server = {
    enable = true;
    exports = ''
      /export 192.168.3.0/24(rw,fsid=0,no_subtree_check)
      /export/data 192.168.3.0/24(rw,async,no_wdelay,hide,crossmnt,no_subtree_check,insecure_locks,anonuid=1000,anongid=100,sec=sys,insecure,root_squash,all_squash)
      /export/private 192.168.3.0/24(rw,async,no_wdelay,hide,crossmnt,no_subtree_check,insecure_locks,anonuid=1000,anongid=100,sec=sys,insecure,root_squash,all_squash)
      /export/public 192.168.3.0/24(rw,async,no_wdelay,hide,crossmnt,no_subtree_check,insecure_locks,anonuid=1000,anongid=100,sec=sys,insecure,root_squash,all_squash)
      /export/data 100.64.0.0/10(rw,async,no_wdelay,hide,crossmnt,no_subtree_check,insecure_locks,anonuid=1000,anongid=100,sec=sys,insecure,root_squash,all_squash)
    '';
  };

  # Bind mounts for /export
  fileSystems."/export/data" = {
    device = "/srv/data";
    fsType = "none";
    options = ["bind"];
  };
  fileSystems."/export/private" = {
    device = "/srv/private";
    fsType = "none";
    options = ["bind"];
  };
  fileSystems."/export/public" = {
    device = "/srv/public";
    fsType = "none";
    options = ["bind"];
  };

  # Ensure directories exist
  systemd.tmpfiles.rules = [
    "d /srv/data 0755 root root -"
    "d /srv/private 0755 root root -"
    "d /srv/public 0755 root root -"
    "d /export 0755 root root -"
    "d /export/data 0755 root root -"
    "d /export/private 0755 root root -"
    "d /export/public 0755 root root -"
    "d /srv/private/jellyfin 0755 jellyfin jellyfin -" # RESTORED
  ];

  # Firewall
  networking.firewall = {
    enable = true;
    allowPing = true;
    allowedTCPPorts = [
      445
      139
      2049

      8123 # HomeAssistant
      7351 # Stirling PDF
      6801 # AriaNg web UI
      28981 # Paperless-ngx
      42617 # ZeroClaw dashboard
    ];
    allowedUDPPorts = [137 138];
  };

  # Btrfs auto-scrub - RESTORED all filesystems
  services.btrfs.autoScrub = {
    enable = true;
    interval = "monthly";
    fileSystems = ["/" "/srv/data" "/srv/private" "/srv/public"];
  };

  # Networking
  networking.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  # State version - RESTORED
  system.stateVersion = "26.05";
}
