{ config
, pkgs
, lib
, ...
}:
let
  user = import ../../modules/global/user.nix;
  # Belt-and-suspenders rfkill unblock: the Ideapad EC can boot with BT
  # soft-blocked (Fn+F8 state persisted across reboots). The standalone
  # `rfkill` binary no longer exists in this nixpkgs revision, so clear the
  # sysfs attribute directly for bluetooth-type rfkill devices only.
  unblockBtRfkill = pkgs.writeShellScript "unblock-bt-rfkill" ''
    for f in /sys/class/rfkill/rfkill*/soft; do
      [ -f "$f" ] || continue
      type=''${f%/soft}/type
      [ "$(cat "$type" 2>/dev/null)" = "bluetooth" ] && printf '0\n' > "$f" 2>/dev/null || true
    done
  '';
in
{
  imports = [
    ./hardware-configuration.nix
    ./hardware.nix
    ../../modules/profiles/base-node.nix
    ../../modules/profiles/server-hardening.nix
    ../../modules/profiles/laptop.nix
    ../../modules/profiles/base-desktop-environment.nix
    ./dns.nix
    ./media-stack.nix
    ./paperless.nix
    ./tools.nix
    ./networking.nix
    ../../modules/services/aria2-daemon.nix
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

  # --- Boot parameters for GPU power saving ---
  # consoleblank removed — display output is now active for the media center.
  # i915 power saving params are still good for the iGPU even with active display.
  boot.kernelParams = [
    "i915.enable_dc=2" # DC5/DC6 deep power saving on i915
    "i915.enable_psr=2" # Panel Self-Refresh v2 (eDP power saving)
    "i915.enable_guc=2" # GuC submission + HuC loading (HEVC encoding)
    "i915.enable_fbc=1" # Frame Buffer Compression
    "intel_idle.max_cstate=9" # Allow deep C-states (C8-C9 for KBL)
    "processor.max_cstate=9" # Match intel_idle
  ];

  # --- Ensure ideapad_laptop kernel module is loaded for conservation mode ---
  boot.kernelModules = [ "ideapad_laptop" ];

  # --- Bluetooth (TV keyboard/mouse) ---
  # Explicit at host level so the media center keeps BT input even if
  # desktop-client defaults change. powerOnBoot + AutoEnable ensure the
  # adapter re-powers after every boot/reboot.
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings.Policy.AutoEnable = "true";
  }; # --- Bluetooth rfkill safeguard (belt-and-suspenders) ---
  # The Ideapad EC (embedded controller) can boot with BT rfkill-blocked
  # (Fn+F8 state persisted across reboots), which bluez config alone cannot
  # override — bluetoothctl shows "No default controller available" despite
  # the service running. `systemd-rfkill.service` restores the previously
  # saved rfkill state at boot, so this unit runs AFTER it to guarantee our
  # unblock wins. Only clears soft-blocks; a hard-block (EC hardware cutoff)
  # still needs the Fn+F8 toggle — verify via `bluetoothctl list` / the
  # /sys/class/rfkill/*/soft attributes if BT stays missing after reboot.
  systemd.services.unblock-bluetooth = {
    description = "Unblock Bluetooth rfkill at boot";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-rfkill.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${unblockBtRfkill}";
      RemainAfterExit = true;
    };
  };

  # --- Thermal management (controls fan curve on Intel) ---
  services.thermald.enable = true;

  # --- Display / compositor ---
  services.displayManager.sddm = {
    enable = false;
    wayland.enable = true;
  };

  programs.dank-material-shell.greeter = {
    enable = true;
    compositor.name = "niri";
    configHome = user.home; # Sync themes with user's DankMaterialShell config
  };

  # --- Screen idle management: swayidle runs as a user-level spawn-at-startup
  # in the niri compositor config (modules/user/desktop/niri.nix), using niri
  # IPC actions (power-off-monitors / power-on-monitors) instead of root-level
  # /sys writes.  The compositor owns the DRM lease — DPMS must go through it.

  # --- Logind: lock on lid close (media center: blank screen but keep HDMI output active, server stays up)
  services.logind.settings.Login = {
    HandleLidSwitch = "lock";
    HandleLidSwitchDocked = "ignore";
    HandleLidSwitchExternalPower = "lock";
  };

  # --- Disable all forms of system sleep (server must stay up) ---
  systemd.sleep.settings.Sleep = {
    AllowSuspend = "no";
    AllowHibernation = "no";
    AllowHybridSleep = "no";
    AllowSuspendThenHibernate = "no";
  };

  # --- Power management: auto-cpufreq handles governor switching ---
  # Removed the charger → powersave override; laptop.nix defaults to
  # performance on charger which is appropriate for 4K media center use.
  powerManagement = {
    enable = true;
    powerDownCommands = "";
  };

  # --- Samba Configuration ---
  services.samba = {
    enable = true;
    settings = {
      global = {
        security = "user";
        workgroup = "WORKGROUP";
        "server string" = config.networking.hostName;
        "netbios name" = config.networking.hostName;
        "map to guest" = "bad user";
        "guest account" = "nobody";
      };
      data = {
        path = "/export/data";
        "browseable" = "yes";
        "read only" = "no";
        "guest ok" = "no";
        "create mask" = "0644";
        "directory mask" = "0755";
        "force user" = "devji";
      };
      private = {
        path = "/export/private";
        "browseable" = "yes";
        "read only" = "no";
        "guest ok" = "no";
        "create mask" = "0644";
        "directory mask" = "0755";
        "force user" = "devji";
      };
      public = {
        path = "/export/public";
        "browseable" = "yes";
        "read only" = "no";
        "guest ok" = "no";
        "create mask" = "0644";
        "directory mask" = "0755";
        "force user" = "devji";
      };
    };
  };

  # Samba RuntimeDirectory fix
  systemd.services.samba-smbd.serviceConfig.RuntimeDirectory = [ "lock" "lock/samba" ];
  systemd.services.samba-nmbd.serviceConfig.RuntimeDirectory = [ "lock" "lock/samba" ];
  systemd.services.samba-winbindd.serviceConfig.RuntimeDirectory = [ "lock" "lock/samba" ];

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
    options = [ "bind" ];
  };
  fileSystems."/export/private" = {
    device = "/srv/private";
    fsType = "none";
    options = [ "bind" ];
  };
  fileSystems."/export/public" = {
    device = "/srv/public";
    fsType = "none";
    options = [ "bind" ];
  };

  # Ensure directories exist
  systemd.tmpfiles.rules = [
    "d /srv/data 0755 root root -"
    "d /srv/data/downloads 0775 aria2 users -"
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
    allowedUDPPorts = [ 137 138 ];
  };

  # Btrfs auto-scrub - RESTORED all filesystems
  services.btrfs.autoScrub = {
    enable = true;
    interval = "monthly";
    fileSystems = [ "/" "/srv/data" "/srv/private" "/srv/public" ];
  };

  # Networking
  networking.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  # State version - RESTORED
  system.stateVersion = "26.05";
}
