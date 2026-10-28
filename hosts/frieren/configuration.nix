{
  config,
  pkgs,
  lib,
  ...
}: let
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
  # main repo). Pins the current generation of each host under
  # /nix/var/nix/gcroots/fleet/$h to prevent nix.gc from sweeping Harmonia paths.
  # flake.lock refreshes stay manual: task infra:warm:cache UPDATE=1.
  fleetWarmCache = pkgs.writeShellScript "fleet-warm-cache" ''
    set -u
    fail=0
    mkdir -p /nix/var/nix/gcroots/fleet
    for h in \
      frieren poseidon eisen fern stark scratch guckloch
    do
      echo "==> warming & pinning current generation: $h"
      out_link="/nix/var/nix/gcroots/fleet/$h"
      ${pkgs.nix}/bin/nix --extra-experimental-features "nix-command flakes" build \
        "github:shaoyanji/nixconfig#nixosConfigurations.$h.config.system.build.toplevel" \
        --out-link "$out_link" \
        -L || fail=1
    done
    exit $fail
  '';
in {
  imports = [
    ./hardware-configuration.nix
    ./hardware.nix
    ../../modules/profiles/base-node.nix
    ../../modules/profiles/burgernas-client.nix
    ../../modules/profiles/hermes.nix
    ../../modules/profiles/server-hardening.nix
    ../../modules/profiles/laptop.nix
    # desktop-client is infrastructure, not the desktop: it owns avahi/resolved/
    # tailscale/fuse and the NAS mounts. The graphical stack lives in desktop.nix,
    # which only the `desktop` specialisation imports.
    ../../modules/profiles/boot.nix
    ../../modules/profiles/desktop-client.nix
    ./dns.nix
    ./media-stack.nix
    ./transmission.nix
    ./paperless.nix
    ./tools.nix
    ./networking.nix
    ./firewall-scope.nix
    ./infra-stack.nix
    ./reverse-proxy.nix
    ../../modules/services/aria2-daemon.nix
    ../../modules/services/harmonia.nix
    ../../modules/services/fleet-sentinel.nix
    ../../modules/services/fleet-classification-gate.nix
    ../../modules/services/home-assistant.nix
    ../../modules/services/kiwix.nix
    ../../modules/services/paste.nix
    ../../modules/services/atuin-server.nix
    ../../modules/services/iventoy.nix
    ../../modules/services/simplex-smp-server.nix
    ../../modules/profiles/nixbuild-client.nix
  ];

  # Frieren signs SSH user certificates like the workstations (aristotle,
  # poseidon): the CA private key is already deployed via sops-nix
  # (modules/sops.nix → ~/.ssh/user_ca_key), so enable the client-cert
  # config + rotate-ssh-cert helper here too.
  ssh.ca.enableClient = true;

  # pihole-ftl unused variable issue was resolved upstream in nixpkgs (env.NIX_CFLAGS_COMPILE);
  # overlay retired as planned in overlays/pihole-ftl-werror.nix.
  nixpkgs.overlays = [];

  # Serve the fleet's LAN binary cache (see modules/services/harmonia.nix).
  services.harmonia-fleet.enable = true;

  # Closed loop: 15-minute observation ledger + health endpoint. gatus watches
  # /sentinel/status.json; `task ops:health` is the operator gate; the ledger is
  # the episodic memory agents read. See modules/services/fleet-sentinel.nix.
  services.fleetSentinel = {
    enable = true;
    # The cold vault is powered on demand: its automount failing while BurgerNAS
    # sleeps is the design, not a fault, and counting it put the whole host in
    # "degraded" — which gatus then reported as a broken monitor.
    ignoreFailedUnits = ["mnt-burgernas-peachcable.mount"];
    watchUnits = [
      {unit = "nixos-upgrade.service";}
      {unit = "fleet-warm-cache.service";}
      # Nightly classification drift: a failed run degrades this sentinel, so
      # config that would fail its own gate is reported before the 04:00 deploy.
      {unit = "fleet-classification-gate.service";}
      {unit = "restic-backups-frieren-local.service";}
      {unit = "restic-backups-frieren-burgernas.service";}
      {unit = "restic-drill.service";}
      {unit = "postgresqlBackup-immich.service";}
    ];
  };

  # Nightly drift gate: evaluates the pushed flake's host configs (the same ref
  # autoUpgrade installs) one host per process, so a broken assertion or a
  # misclassified unit is in the sentinel before it is deployed.
  services.fleetClassificationGate.enable = true;

  # Offload the weekly fleet cache-warm builds (and any local builds) to
  # nixbuild.net. Key: sops `nixbuild_ssh_key` → /root/.ssh/nixbuild
  # (see modules/profiles/nixbuild-client.nix).
  profiles.nixbuild-client.enable = true;

  # Server-class host: pin the current nixpkgs LTS kernel instead of the
  # latest-kernel default from profiles/base-node.nix.
  boot.kernelPackages = lib.mkForce pkgs.linuxPackages_6_12;

  # Frieren is a server-heavy-io-sensitive node with spinning media (/dev/sda).
  # 1. Disable full-store batch traversal to prevent mechanical head thrashing.
  nix.optimise.automatic = lib.mkForce false;

  # 2. Strict cgroup v2 I/O safety guardrails in case nix-optimise is manually triggered.
  systemd.services.nix-optimise.serviceConfig = {
    IOReadIOPSMax = ["/dev/sda 35"];
    IOWriteIOPSMax = ["/dev/sda 20"];
    IOWeight = 10;
  };

  # --- Fleet cache warmer ---
  # Weekly unattended build of all host closures (script defined above);
  # see modules/services/harmonia.nix for why this keeps the LAN fast.
  systemd.services.fleet-warm-cache = {
    description = "Build all fleet host closures to warm the harmonia LAN cache";
    after = ["network-online.target"];
    wants = ["network-online.target"];
    # Never fight the 04:00 autoUpgrade for RAM/IO/store-locks: warming 18 host
    # closures takes hours, so a 03:30 start used to run straight through 04:00.
    # systemd stops this oneshot when nixos-upgrade starts — the upgrade wins,
    # and the warmer picks up again on the next weekly trigger.
    unitConfig.Conflicts = ["nixos-upgrade.service"];
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
    wantedBy = ["timers.target"];
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
    # `--upgrade` updates root's `nixos` channel, which nixos-rebuild itself
    # reports has no effect on a flake system — it just unpacked a channel for
    # ~2.5 min at 04:02 before saying so. The github: ref is fetched fresh on
    # every run, so the flag buys nothing and channels are disabled fleet-wide.
    upgrade = false;
    dates = "04:00";
    allowReboot = true;
    persistent = true;
  };

  sops.secrets."aria2-rpc-secret" = {
    owner = "aria2";
    group = "aria2";
    mode = "0400";
  };

  # LAN TLS wildcard (*.frieren.lan) leaf key; the matching cert is committed
  # at modules/config/tls/frieren-lan-wildcard.pem and the signing CA at
  # modules/config/tls/frieren-lan-ca.pem (trusted fleet-wide via
  # security.pki in modules/profiles/base-node.nix). The nginx unit runs as
  # User=nginx (CAP_NET_BIND_SERVICE), so the key must be nginx-readable.
  sops.secrets."tls-frieren-wildcard-key" = {
    owner = "nginx";
    group = "nginx";
    mode = "0400";
  };

  # BurgerNAS sudo password for the `task burgernas:*` tooling (WoL, poweroff,
  # transmission leech policy). Loaded from SOPS (modules/secrets.yaml key
  # `burgernas-sudo-password`) and rendered to /run/secrets/nas — the path the
  # scripts read. Owned by devji because they run unprivileged; no home-dir copy.
  sops.secrets."burgernas-sudo-password" = {
    owner = "devji";
    group = "users";
    mode = "0400";
    path = "/run/secrets/nas";
  };

  # E.3: Hermes agent profile & isolated secrets (modules/profiles/hermes.nix)
  # Host-specific Telegram bot token isolated to frieren to prevent multi-host polling conflicts.
  profiles.hermes = {
    enable = true;
    telegramSecret = "hermes";
  };

  services.aria2-daemon = {
    enable = true;
    downloadDir = "/srv/data/downloads";
    rpcHost = "0.0.0.0";
    rpcSecretFile = config.sops.secrets."aria2-rpc-secret".path;
    nginx.enable = true;
    nginx.listenPort = 6801;
    # Transmission owns 51413 (its default peer port) on this host, so every
    # BitTorrent task in aria2 died on start with `Failed to bind a socket,
    # cause: Address already in use` / `Errors occurred while binding port`:
    # magnets and .torrent links were the one task type that could not work.
    # Moving aria2's listen/DHT port off the clash is all it takes.
    btListenPort = 51414;
  };

  # Home Assistant IoT and device stack (modules/services/home-assistant.nix)
  services.ha-stack.enable = true;

  # Shell-history sync (modules/services/atuin-server.nix). The one account is
  # registered; leaving signup open would let anyone who reaches the vhost write
  # to the history database.
  services.atuin-server = {
    enable = true;
    serverAliases = [
      "atuin.lan"
      "atuin.frieren.local"
      # Clients whose DNS does not know the .lan names reach it by address, and
      # this is the one they use (modules/shell/atuin.nix sets
      # sync_address = http://100.97.61.65): the tailnet address works on the
      # LAN too, so it is the only address alias that earns its place.
      "100.97.61.65"
      # The LAN address is deliberately NOT here. `frieren.lan` (the portal,
      # default_server on :80 and :443) claims 192.168.3.25, and a server_name
      # in two vhosts on one port is a conflict nginx resolves by *ignoring the
      # later block* — atuin.frieren.lan serialises first, so the bare LAN
      # address served atuin's 404 and the portal was unreachable by its own IP.
      # Nothing needs atuin by address on the LAN: the names and the tailnet
      # address cover every client. The duplicate is gated by an assertion in
      # hosts/frieren/reverse-proxy.nix.
    ];
  };

  # SimpleX Chat SMP relay server (modules/services/simplex-smp-server.nix)
  services.simplex-smp-server = {
    enable = true;
    ip = "192.168.3.25";
    tailscaleIp = "100.97.61.65";
    port = 5223;
  };

  # The home-manager persona (heim → zen → aria2.nix) ships a user-level
  # aria2 RPC fallback on :6800. frieren runs the system services.aria2
  # (rpc-secret via LoadCredential) — keep exactly ONE RPC on :6800 so the
  # unauthenticated fallback can't shadow the secret-protected daemon.
  home-manager.users.devji.programs.aria2-user-fallback.enable = false;

  # The AppImage launcher refresh is a desktop job: role:home gives this user the
  # hourly timer that opens every image in /Volumes/data/appimages to write
  # .desktop entries, but frieren's boot default declares no compositor. Measured
  # 2026-10-28: 61 images, 50 CPU-seconds and a 673 MiB peak per run, hourly, and
  # killed before it finished. No Install.WantedBy means home-manager installs no
  # timers.target link, so the unit exists but nothing starts it.
  home-manager.users.devji.systemd.user.timers.appimage-launchers.Install.WantedBy = lib.mkForce [];

  # Resurrected OpenClaw persona ("Vanta") for the hermes mainframe agent.
  home-manager.users.devji.programs.hermes-user = {
    enable = true;
    persona = true;
    gateway.enable = true;
    simplex.daemon = true;
    envFile = "/run/secrets/rendered/hermes.env";
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
  boot.kernelModules = ["ideapad_laptop"];

  # --- Bluetooth (TV keyboard/mouse) ---
  # Explicit at host level so the media center keeps BT input even if
  # desktop-client defaults change. powerOnBoot + AutoEnable ensure the
  # adapter re-powers after every boot/reboot.
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = {
      General = {
        AutoEnable = "true";
        ControllerMode = "dual";
        FastConnectable = "true";
        JustWorksRepairing = "always";
      };
      Policy = {
        AutoEnable = "true";
        ReconnectAttempts = "0";
        ReconnectIntervals = "1, 2, 4, 8, 16, 32, 64";
      };
    };
  };

  # Automatically unblock Bluetooth rfkill and disable USB autosuspend on btusb adapters
  services.udev.extraRules = ''
    SUBSYSTEM=="rfkill", ATTR{type}=="bluetooth", ATTR{soft}="0"
    ACTION=="add", SUBSYSTEM=="usb", DRIVERS=="btusb", ATTR{power/control}="on"
  ''; # --- Bluetooth rfkill safeguard (belt-and-suspenders) ---
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
    wantedBy = ["multi-user.target"];
    after = ["systemd-rfkill.service"];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${unblockBtRfkill}";
      RemainAfterExit = true;
    };
  };

  # --- Thermal management (controls fan curve on Intel) ---
  services.thermald.enable = true;

  # --- Boot persona: headless server by default, desktop on demand ---
  # This file is the boot default: no compositor, no greeter, no DisplayLink, no
  # X. specialisation.desktop (desktop.nix) adds the niri media-centre stack
  # back as a separate systemd-boot entry; nothing has to be rebuilt to pick it.
  specialisation.desktop.configuration = {
    imports = [./desktop.nix];
  };

  # --- Logind: headless, so a closed lid changes nothing (sleep is off below).
  services.logind.settings.Login.HandleLidSwitch = "ignore";

  # --- Disable all forms of system sleep (server must stay up) ---
  systemd.sleep.settings.Sleep = {
    AllowSuspend = "no";
    AllowHibernation = "no";
    AllowHybridSleep = "no";
    AllowSuspendThenHibernate = "no";
  };

  # --- Power management: no auto-cpufreq on a 24/7 AC server ---
  # laptop.nix enables it fleet-wide; on AC its charger profile pins all eight
  # cores to 3.4 GHz with EPP=performance, which measured 2.93 W / 42 °C at idle
  # on this box while the daemon itself used 0.7 % of a core. A fixed governor
  # costs nothing to run: removal measured 2.46 W / 41 °C at an 800 MHz idle.
  # `powersave` is intel_pstate's scaling governor in active mode — it still
  # boosts on demand, it just stops holding the floor at max.
  services.auto-cpufreq.enable = lib.mkForce false;
  powerManagement = {
    enable = true;
    cpuFreqGovernor = "powersave";
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

    # Non-dynamic port policy (HC-7). Only 2049 is declared in
    # firewall-scope.nix: fleet clients mount NFSv4 (which needs no rpcbind),
    # so the v3-only RPC services below are not reachable from the LAN and the
    # interface scope stays their control. Pinning them is what makes that
    # decision reviewable — before this they were drawn from
    # net.ipv4.ip_local_port_range at every boot (a *different* set each time),
    # which `task checks:ports` reported as DYNAMIC and could never be declared.
    # Values follow the long-standing NFS firewall convention (statd 32765,
    # lockd 32766) and sit just below the ephemeral range; mountd's port is its
    # upstream default, named explicitly so a future nfs-utils default cannot
    # move it silently.
    mountdPort = 20048;
    statdPort = 32765;
    lockdPort = 32766;

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
    options = ["bind"];
  };

  # Persistent user security vault bind-mount (isolated on 2TB NAS pool /dev/sda2)
  fileSystems."${user.home}/security" = {
    device = "/srv/data/security";
    fsType = "none";
    options = ["bind" "x-systemd.requires=srv-data.mount"];
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

  # BurgerNAS cold vault: the mount, the automount and the fail-fast NFS options
  # all live in profiles/burgernas-client.nix, so any host that mounts the vault
  # inherits them instead of rediscovering that `mount.nfs` retries for 2 minutes.
  # Export granted on the NAS side in /etc/exports — DSM 7 has no CLI/API for NFS
  # privileges, see the skill.
  profiles.burgernas-client.enable = true;

  # High-speed flash cache tier on USB 3.0 Samsung Flash Drive (F2FS + transparent ZSTD compression).
  # Ephemeral & acceleration tier: Nix evaluation cache, transcode scratch, gallery thumbnails, ISO staging.
  # `nofail` ensures the host boots without delay even if the external USB drive is unplugged.
  fileSystems."/mnt/flash-cache" = {
    device = "/dev/disk/by-label/flash-cache";
    fsType = "f2fs";
    options = [
      "noatime"
      "lazytime"
      "compress_algorithm=zstd:3"
      "compress_chksum"
      "compress_extension=*"
      "nodiscard"
      "nofail"
      "x-systemd.device-timeout=5s"
    ];
  };

  # Ensure directories exist
  systemd.tmpfiles.rules = [
    "d /nix/var/nix/gcroots/fleet 0755 root root -"
    "d /mnt/flash-cache 0755 root root -"
    "d /mnt/flash-cache/nix-eval 0755 ${user.name} users -"
    "d /mnt/flash-cache/staging 0755 ${user.name} users -"
    "d /mnt/flash-cache/tmp 1777 ${user.name} users -"
    "d /mnt/flash-cache/jellyfin-transcode 0777 root root -"
    "d /mnt/flash-cache/immich-thumbs 0777 root root -"
    "d /Volumes/data 0755 root root -"
    "d /srv/data 0755 root root -"
    "d /srv/data/downloads 0775 aria2 users -"
    "d /srv/data/security 0700 ${user.name} users -"
    "d ${user.home}/security 0700 ${user.name} users -"
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
    reflector = true; # Reflect mDNS across interfaces (wired, wifi, dock) for TV & device discovery
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

  # Firewall — port-scoping lives in firewall-scope.nix: the global lists
  # below (and every other module's contribution) are mkForce-overridden
  # and re-applied per interface (enp1s0/wlp2s0/tailscale0 only), so docker0
  # and friends cannot reach any service port. NEW ports must be added to
  # firewall-scope.nix's explicit lists or they stay closed everywhere.
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
  # ============================================================================
  # Closure Debloat Overrides (Tier 1 safe wins: T1-2, T1-6)
  # ============================================================================

  # T1-6: Disable printing / HPLIP drivers (~70 MiB).
  # frieren is a NAS / media center host and does not manage physical HP printers.
  services.printing = {
    enable = lib.mkForce false;
    drivers = lib.mkForce [];
  };

  # State version - RESTORED
  system.stateVersion = "26.05";
}
