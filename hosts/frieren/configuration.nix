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
  # Fleet cache warmer: builds every NixOS host's toplevel from the pushed
  # flake so harmonia serves the closures to the whole LAN at wire speed.
  # Uses the same github: source as system.autoUpgrade (eval works without
  # the secrets submodule because modules/secrets.yaml is tracked in the
  # main repo). flake.lock refreshes stay manual:
  # task infra:warm:cache UPDATE=1.
  fleetWarmCache = pkgs.writeShellScript "fleet-warm-cache" ''
    set -u
    fail=0
    for h in \
      poseidon eisen fern stark scratch schneeeule ares \
      mtfuji kellerbench deckstation applevalley minyx \
      guckloch netbook aristotle aceofspades ancientace frieren
    do
      echo "==> warming: $h"
      ${pkgs.nix}/bin/nix --extra-experimental-features "nix-command flakes" build \
        "github:shaoyanji/nixconfig#nixosConfigurations.$h.config.system.build.toplevel" \
        -L || fail=1
    done
    exit $fail
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
    ./ha-stack.nix
    ./infra-stack.nix
    ./reverse-proxy.nix
    ./iventoy.nix
    ../../modules/services/aria2-daemon.nix
    ../../modules/services/harmonia.nix
    ../../modules/profiles/nixbuild-client.nix
  ];
  networking.hostName = "frieren";

  # pihole-ftl 6.7.1 fails to compile at the current nixpkgs rev (-Werror on an
  # unused variable) and has no binary substitute — see the overlay header.
  nixpkgs.overlays = [
    (import ../../overlays/pihole-ftl-werror.nix)
  ];

  # Serve the fleet's LAN binary cache (see modules/services/harmonia.nix).
  services.harmonia-fleet.enable = true;

  # Offload the weekly fleet cache-warm builds (and any local builds) to
  # nixbuild.net. Key: sops `nixbuild_ssh_key` → /root/.ssh/nixbuild
  # (see modules/profiles/nixbuild-client.nix).
  profiles.nixbuild-client.enable = true;

  # Server-class host: pin the current nixpkgs LTS kernel instead of the
  # latest-kernel default from profiles/base-node.nix.
  boot.kernelPackages = lib.mkForce pkgs.linuxPackages_6_12;

  # --- Fleet cache warmer ---
  # Weekly unattended build of all host closures (script defined above);
  # see modules/services/harmonia.nix for why this keeps the LAN fast.
  systemd.services.fleet-warm-cache = {
    description = "Build all fleet host closures to warm the harmonia LAN cache";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    # Never fight the 04:00 autoUpgrade for RAM/IO/store-locks: warming 18 host
    # closures takes hours, so a 03:30 start used to run straight through 04:00.
    # systemd stops this oneshot when nixos-upgrade starts — the upgrade wins,
    # and the warmer picks up again on the next weekly trigger.
    unitConfig.Conflicts = [ "nixos-upgrade.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${fleetWarmCache}";
      # Weekly-ish job; give slow builds room.
      TimeoutStartSec = "12h";
      Nice = 10;
      IOSchedulingClass = "idle";
    };
  };
  systemd.timers.fleet-warm-cache = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      # 01:30 (was 03:30): start the multi-hour fleet warm well before the
      # 03:00 agy runs and the 04:00 autoUpgrade so the Conflicts guard above
      # rarely has to abort it mid-way.
      OnCalendar = "Sun, 01:30";
      Persistent = true;
      RandomizedDelaySec = "30min";
    };
  };

  # --- Daily self-upgrade (04:00) ---
  # Canonical system.autoUpgrade module (no hand-rolled timer/script). Runs
  # as root via nixos-upgrade.service — equivalent to
  # `sudo nixos-rebuild boot --flake github:shaoyanji/nixconfig#frieren`.
  # allowReboot gives the smart boot-vs-switch behaviour:
  #   1. always `nixos-rebuild boot` first (stages the new generation, no
  #      live activation)
  #   2. if the new generation's kernel/initrd/kernel-modules differ from the
  #      booted system → reboot into it (`shutdown -r +1`) — only reached
  #      when the boot command exited 0
  #   3. otherwise the kernel is unchanged → plain `nixos-rebuild switch`
  #      activates the config live, no reboot needed
  # The `github:` ref fetches the public repo tarball; modules/secrets.yaml is
  # a tracked file in the main repo, so eval works without the private
  # modules/secrets submodule. Persistent timer: if the NAS is off at 04:00,
  # the upgrade runs on next boot. Reboots are allowed any time (no
  # rebootWindow) — a 04:00 NAS reboot is acceptable.
  system.autoUpgrade = {
    enable = true;
    flake = "github:shaoyanji/nixconfig#frieren";
    dates = "04:00";
    allowReboot = true;
    persistent = true;
  };

  sops.secrets."aria2-rpc-secret" = {
    owner = "aria2";
    group = "aria2";
    mode = "0400";
  };

  # E.3: Hermes agent secrets (telegram bot token, allowed users, timeout)
  # Combined with shared AI services secrets (API keys) via template.
  sops.secrets."hermes" = {
    owner = "devji";
    group = "users";
    mode = "0400";
  };

  sops.secrets."ai-services-shared-env" = {
    owner = "devji";
    group = "users";
    mode = "0400";
  };

  sops.templates."hermes.env" = {
    owner = "devji";
    group = "users";
    mode = "0400";
    path = "/home/devji/.config/hermes/hermes.env";
    content = "${config.sops.placeholder."ai-services-shared-env"}${config.sops.placeholder."hermes"}";
  };

  services.aria2-daemon = {
    enable = true;
    downloadDir = "/srv/data/downloads";
    rpcHost = "0.0.0.0";
    rpcSecretFile = config.sops.secrets."aria2-rpc-secret".path;
    nginx.enable = true;
    nginx.listenPort = 6801;
  };

  # The home-manager persona (heim → zen → aria2.nix) ships a user-level
  # aria2 RPC fallback on :6800. frieren runs the system services.aria2
  # (rpc-secret via LoadCredential) — keep exactly ONE RPC on :6800 so the
  # unauthenticated fallback can't shadow the secret-protected daemon.
  home-manager.users.devji.programs.aria2-user-fallback.enable = false;

  # Resurrected OpenClaw persona ("Vanta") for the hermes mainframe agent.
  home-manager.users.devji.programs.hermes-user.enable = true;
  home-manager.users.devji.home.sessionVariables = {
    HERMES_CONFIG = "/home/devji/.hermes/config.yaml";
    HERMES_ENV = "/home/devji/.config/hermes/hermes.env";
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

  # Autologin: media-center display boots straight into the niri desktop (no
  # login prompt on the TV). greetd's initial_session (DMS greeter module) runs
  # the resolved session; if it exits, greetd falls back to the DMS greeter.
  services.displayManager.autoLogin = {
    enable = true;
    user = user.name;
  };
  services.displayManager.defaultSession = "niri";

  programs.dms-greeter = {
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
  systemd.services.samba-smbd.serviceConfig.RuntimeDirectory = [
    "lock"
    "lock/samba"
  ];
  systemd.services.samba-nmbd.serviceConfig.RuntimeDirectory = [
    "lock"
    "lock/samba"
  ];
  systemd.services.samba-winbindd.serviceConfig.RuntimeDirectory = [
    "lock"
    "lock/samba"
  ];

  # Samba WSDD
  services.samba-wsdd = {
    enable = true;
    openFirewall = true;
  };

  # NFS exports
  services.nfs.server = {
    enable = true;
    exports = ''
      /export 192.168.3.0/24(rw,fsid=0,no_subtree_check) 100.0.0.0/8(rw,fsid=0,no_subtree_check)
      /export/data 192.168.3.0/24(rw,async,no_wdelay,hide,crossmnt,no_subtree_check,insecure_locks,anonuid=1000,anongid=100,sec=sys,insecure,root_squash,all_squash) 100.0.0.0/8(rw,async,no_wdelay,hide,crossmnt,no_subtree_check,insecure_locks,anonuid=1000,anongid=100,sec=sys,insecure,root_squash,all_squash)
      /export/private 192.168.3.0/24(rw,async,no_wdelay,hide,crossmnt,no_subtree_check,insecure_locks,anonuid=1000,anongid=100,sec=sys,insecure,root_squash,all_squash) 100.0.0.0/8(rw,async,no_wdelay,hide,crossmnt,no_subtree_check,insecure_locks,anonuid=1000,anongid=100,sec=sys,insecure,root_squash,all_squash)
      /export/public 192.168.3.0/24(rw,async,no_wdelay,hide,crossmnt,no_subtree_check,insecure_locks,anonuid=1000,anongid=100,sec=sys,insecure,root_squash,all_squash) 100.0.0.0/8(rw,async,no_wdelay,hide,crossmnt,no_subtree_check,insecure_locks,anonuid=1000,anongid=100,sec=sys,insecure,root_squash,all_squash)
    '';
  };

  # Universal path parity for fleet compatibility
  fileSystems."/Volumes/data" = {
    device = "/srv/data";
    fsType = "none";
    options = [ "bind" ];
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
    "d /Volumes/data 0755 root root -"
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

  # Avahi / mDNS zero-conf service discovery across LAN
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
    publish = {
      enable = true;
      userServices = true;
      addresses = true;
      workstation = true;
    };
    extraServiceFiles = {
      smb = ''
        <?xml version="1.0" standalone='no'?><!--*-nxml-*-->
        <!DOCTYPE service-group SYSTEM "avahi-service.dtd">
        <service-group>
          <name replace-wildcards="yes">frieren (Samba)</name>
          <service>
            <type>_smb._tcp</type>
            <port>445</port>
          </service>
          <service>
            <type>_device-info._tcp</type>
            <port>0</port>
            <txt-record>model=RackMac</txt-record>
          </service>
        </service-group>
      '';
      nfs = ''
        <?xml version="1.0" standalone='no'?><!--*-nxml-*-->
        <!DOCTYPE service-group SYSTEM "avahi-service.dtd">
        <service-group>
          <name replace-wildcards="yes">frieren (NFS)</name>
          <service>
            <type>_nfs._tcp</type>
            <port>2049</port>
            <txt-record>path=/export/data</txt-record>
          </service>
        </service-group>
      '';
      harmonia = ''
        <?xml version="1.0" standalone='no'?><!--*-nxml-*-->
        <!DOCTYPE service-group SYSTEM "avahi-service.dtd">
        <service-group>
          <name replace-wildcards="yes">frieren Nix Cache (Harmonia)</name>
          <service>
            <type>_nix-cache._tcp</type>
            <port>5000</port>
          </service>
        </service-group>
      '';
      http = ''
        <?xml version="1.0" standalone='no'?><!--*-nxml-*-->
        <!DOCTYPE service-group SYSTEM "avahi-service.dtd">
        <service-group>
          <name replace-wildcards="yes">frieren Web Portal</name>
          <service>
            <type>_http._tcp</type>
            <port>80</port>
          </service>
        </service-group>
      '';
    };
  };

  # Firewall
  networking.firewall = {
    enable = true;
    allowPing = true;
    allowedTCPPorts = [
      445
      139
      2049

      8123 # HomeAssistant
      6801 # AriaNg web UI
      28981 # Paperless-ngx
      3001 # Uptime-Kuma (ha-stack)
      # 6052 closed — ESPHome removed 2026-10 (no devices; upstream dropped
      # the built-in dashboard)
      8124 # Scrutiny SMART dashboard (infra-stack)
      # 7351 moved next to the service: networking.nix (Stirling PDF)
      # 42617 closed - ZeroClaw was removed in the 2026-09 teardown
    ];
    allowedUDPPorts = [
      137
      138
    ];
  };

  # Btrfs auto-scrub - RESTORED all filesystems
  services.btrfs.autoScrub = {
    enable = true;
    interval = "monthly";
    fileSystems = [
      "/"
      "/srv/data"
      "/srv/private"
      "/srv/public"
    ];
  };

  # Networking
  networking.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  # State version - RESTORED
  system.stateVersion = "26.05";
}
