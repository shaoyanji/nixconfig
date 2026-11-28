{
  self,
  config,
  pkgs,
  lib,
  user,
  systemdJobs,
  ...
}: let
  # The EC can boot with BT soft-blocked (Fn+F8 persists across reboots); the
  # rfkill binary is gone → sysfs write (Trap: note frieren-ops-history).
  unblockBtRfkill = pkgs.writeShellScript "unblock-bt-rfkill" ''
    for f in /sys/class/rfkill/rfkill*/soft; do
      [ -f "$f" ] || continue
      type=''${f%/soft}/type
      [ "$(cat "$type" 2>/dev/null)" = "bluetooth" ] && printf '0\n' > "$f" 2>/dev/null || true
    done
  '';
  # --ff-only into every checkout under the data volume; rules in .agents/deploy/hosts/frieren.md.
  # Discovery is a scan, not a list: a checkout added under the volume is covered
  # without editing this file. Arguments override the scan, which is how the
  # behaviour is proven against scratch clones.
  checkoutFf = pkgs.writeShellScript "checkout-ff" ''
    set -u
    export PATH="${lib.makeBinPath [pkgs.git pkgs.openssh]}:$PATH"
    git=${pkgs.git}/bin/git
    root=/Volumes/data/projects
    fail=0
    if [ $# -gt 0 ]; then
      candidates="$*"
    else
      candidates=""
      for d in "$root"/*; do
        [ -d "$d/.git" ] && candidates="$candidates $d"
      done
    fi
    [ -n "$candidates" ] || {
      echo "no git checkout under $root; nothing to do"
      exit 0
    }
    for dir in $candidates; do
      if [ ! -d "$dir/.git" ]; then
        echo "==> $dir is not a checkout; skipped"
        continue
      fi
      if [ -n "$($git -C "$dir" status --porcelain)" ]; then
        echo "==> $dir is dirty; left alone until the change is committed"
        continue
      fi
      branch=$($git -C "$dir" symbolic-ref --quiet --short HEAD) || {
        echo "==> $dir has a detached HEAD; left alone"
        continue
      }
      before=$($git -C "$dir" rev-parse HEAD)
      if ! $git -C "$dir" fetch --quiet --prune origin; then
        echo "==> $dir: fetch failed" >&2
        fail=1
        continue
      fi
      if ! $git -C "$dir" merge --ff-only --quiet "origin/$branch" >/dev/null 2>&1; then
        echo "==> $dir: origin/$branch is not a fast-forward; local commits need a human" >&2
        fail=1
        continue
      fi
      after=$($git -C "$dir" rev-parse HEAD)
      if [ "$before" = "$after" ]; then
        echo "==> $dir: already current at $($git -C "$dir" log -1 --format='%h %s')"
      else
        echo "==> $dir: +$($git -C "$dir" rev-list --count "$before..$after") commit(s), now $($git -C "$dir" log -1 --format='%h %s')"
      fi
    done
    exit $fail
  '';

  # Inventory opt-in, never a copied list:
  # [[flake/policies.nix#warmed-set-is-inventory-derived]] (frieren omitted
  # itself once; Story: note frieren-ops-history).
  warmHosts = builtins.attrNames (
    lib.filterAttrs (_: host: host.managed && host.kind == "nixos" && host.status == "active") self.inventory.hosts
  );

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
      ${lib.concatStringsSep " " warmHosts}
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
  fleetWarmCacheJob = systemdJobs.mkTimerJob {} {
    description = "Build all fleet host closures to warm the harmonia LAN cache";
    after = ["network-online.target"];
    wants = ["network-online.target"];
    # Never fight the 04:00 autoUpgrade — Conflicts stops this oneshot and it
    # retries next trigger (Rule: note frieren-ops-history).
    unitConfig.Conflicts = ["nixos-upgrade.service"];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${fleetWarmCache}";
      # Weekly-ish job; give slow builds room.
      TimeoutStartSec = "12h";
      Nice = 10;
      IOSchedulingClass = "idle";
    };
    onCalendar = "Sun, 01:30";
    randomizedDelaySec = "30min";
  };
  checkoutFfJob = systemdJobs.mkTimerJob {} {
    description = "Fast-forward the nixconfig and console checkouts on /Volumes/data";
    after = ["network-online.target"];
    wants = ["network-online.target"];
    path = [pkgs.git pkgs.openssh];
    serviceConfig = {
      Type = "oneshot";
      User = user.name;
      Group = "users";
      ExecStart = "${checkoutFf}";
      # A fetch is seconds of work; anything near this means the network is wedged.
      TimeoutStartSec = "10min";
      Nice = 10;
      IOSchedulingClass = "idle";
    };
    timerDescription = "Nightly fast-forward of the checkouts on /Volumes/data";
    onCalendar = "*-*-* 02:45:00";
    randomizedDelaySec = "5min";
  };
in {
  imports = [
    ./hardware-configuration.nix
    ./hardware.nix
    self.modules."profiles.base-node"
    self.modules."profiles.burgernas-client"
    self.modules."profiles.hermes"
    self.modules."profiles.server-hardening"
    self.modules."profiles.laptop"
    # desktop-client is infrastructure, not the desktop: it owns avahi/resolved/
    # tailscale/fuse and the NAS mounts. The graphical stack lives in desktop.nix,
    # which only the `desktop` specialisation imports. base-node and
    # desktop-client are therefore load-bearing here, not chain duplicates;
    # profiles.boot was the one true duplicate — base-node already carries it
    # (chain-split 2026-11-24).
    self.modules."profiles.desktop-client"
    ./dns.nix
    ./media-stack.nix
    ./transmission.nix
    # ./paperless.nix — offloaded to delphi 2026-11-02; the module is kept in the
    # tree so a switch-back is one import plus the shelter copy. See
    # `open-frieren-offload` in AGENTS.nix and docs/service-offload.md.
    ./tools.nix
    ./networking.nix
    ./firewall-scope.nix
    ./infra-stack.nix
    ./reverse-proxy.nix
    ./gemini.nix
    self.modules."services.aria2-daemon"
    self.modules."services.harmonia"
    self.modules."services.fleet-sentinel"
    self.modules."profiles.sentinel-push"
    self.modules."services.fleet-classification-gate"
    self.modules."services.home-assistant"
    self.modules."services.kiwix"
    self.modules."services.paste"
    self.modules."services.atuin-server"
    self.modules."services.iventoy"
    self.modules."services.simplex-smp-server"
    self.modules."services.task-web"
    self.modules."services.tailnet-forward-proxy"
    self.modules."profiles.nixbuild-client"
  ];

  # Frieren signs SSH user certificates like the workstations (aristotle,
  # poseidon): the CA private key is already deployed via sops-nix
  # (modules/sops.nix → ~/.ssh/user_ca_key), so enable the client-cert
  # config + rotate-ssh-cert helper here too.
  ssh.ca.enableClient = true;

  # Overlay retired — the pihole-ftl fix landed upstream (Story: note
  # frieren-ops-history).
  nixpkgs.overlays = [];

  # Serve the fleet's LAN binary cache (see modules/services/harmonia.nix).
  services.harmonia-fleet.enable = true;

  services.tailnetForwardProxy = {
    enable = true;
    port = 8471;
    memoryMax = "64M";
  };

  # Closed loop: 15-minute observation ledger + health endpoint. gatus watches
  # /sentinel/status.json; `task ops:health` is the operator gate; the ledger is
  # the episodic memory agents read. See modules/services/fleet-sentinel.nix.
  services.fleetSentinel = {
    enable = true;
    # A prefill's own % is not evidence — it serves its new chunks first; the
    # ledger's newest run rides status.json (Trap: note frieren-ops-history).
    prefillRuns = config.services.steamCache.prefill.ledger;
    # exit 0 is not the verdict — gatus reads the outcome FILE (Trap: note
    # frieren-ops-history).
    auditRecord = "/var/lib/agy-system/last-run";
    # The cold vault sleeps: automount failure while BurgerNAS is off is design
    # — it must not degrade the host (Trap: note frieren-ops-history).
    ignoreFailedUnits = ["mnt-burgernas-peachcable.mount"];
    watchUnits = [
      {unit = "nixos-upgrade.service";}
      {unit = "fleet-warm-cache.service";}
      # Nightly classification drift: a failed run degrades this sentinel, so
      # config that would fail its own gate is reported before the 04:00 deploy.
      {unit = "fleet-classification-gate.service";}
      {unit = "kg-ontology-check.service";}
      {unit = "restic-backups-frieren-local.service";}
      {unit = "restic-backups-frieren-burgernas.service";}
      {unit = "restic-drill.service";}
      {unit = "postgresqlBackup-immich.service";}
    ];
    ingest = {
      enable = true;
      tokenFile = config.sops.secrets."agent-turns-token".path;
    };
  };

  sops.secrets."agent-turns-token" = {};

  # Nightly drift gate: evaluates the pushed flake's host configs (the same ref
  # autoUpgrade installs) one host per process, so a broken assertion or a
  # misclassified unit is in the sentinel before it is deployed.
  services.fleetClassificationGate.enable = true;

  # Tailnet task control plane (modules/services/task-web.nix): loopback on
  # 8490, published via the mount in hosts/frieren/reverse-proxy.nix.
  services.taskWeb.enable = true;

  # Offload the weekly fleet cache-warm builds (and any local builds) to
  # nixbuild.net. Key: sops `nixbuild_ssh_key` → /root/.ssh/nixbuild
  # (see modules/profiles/nixbuild-client.nix).
  profiles.nixbuild-client.enable = true;

  # Degrades to the nixpkgs default when an LTS attr leaves the tree — a
  # pinned-missing attr would stop the 04:00 upgrade (Trap: note frieren-ops-history).
  boot.kernelPackages =
    lib.mkForce
    pkgs.${
      lib.findFirst (name: builtins.hasAttr name pkgs) "linuxPackages" [
        "linuxPackages_6_12"
        "linuxPackages_6_6"
        "linuxPackages_5_15"
      ]
    };

  # server-heavy-io-sensitive tier (Fact: inventory.toml): spinning /dev/sda —
  # no full-store batch traversal.
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
  systemd.services.fleet-warm-cache = fleetWarmCacheJob.service;
  systemd.timers.fleet-warm-cache = fleetWarmCacheJob.timer;

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
    # --upgrade once unpacked a channel for ~2.5min at 04:02 — flakes ignore it
    # (Story: note frieren-ops-history).
    upgrade = false;
    dates = "04:00";
    allowReboot = true;
    persistent = true;
  };

  # --- Checkout fast-forward (02:45) --- .agents/deploy/hosts/frieren.md
  systemd.services.checkout-ff = checkoutFfJob.service;

  systemd.timers.checkout-ff = checkoutFfJob.timer;

  sops.secrets."aria2-rpc-secret" = {
    owner = "aria2";
    group = "aria2";
    mode = "0400";
  };

  # LAN TLS wildcard (*.frieren.lan) leaf key; the matching cert is committed
  # at modules/config/tls/frieren-lan-wildcard.pem and the signing CA at
  # modules/config/tls/frieren-lan-ca.pem (trusted fleet-wide via
  # security.pki in modules/profiles/base-node.nix). The nginx unit runs as
  # User=nginx (CAP_NET_BIND_SERVICE), so the key must be nginx-readable —
  # group-readable, not world-readable, because molly-brown (DynamicUser)
  # joins the nginx group for the Gemini capsule in gemini.nix.
  sops.secrets."tls-frieren-wildcard-key" = {
    owner = "nginx";
    group = "nginx";
    mode = "0440";
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

  # E.3 → profiles/hermes.nix. Telegram token per host — two pollers on one
  # token conflict (Rule: note frieren-ops-history).
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
    # Transmission owns 51413 on this host; aria2's btListenPort moved off the
    # clash (Trap: note frieren-ops-history).
    btListenPort = 51414;
  };

  # ModemManager is enabled but idle on this host and has no device to manage: no
  # /dev/cdc-wdm*, no /dev/ttyUSB*, nothing in `mmcli -L`. It comes in from outside
  # this host's config — the string appears nowhere in the tree — so the switch is
  # mkForce rather than a plain false.
  networking.modemmanager.enable = lib.mkForce false;

  services.ha-stack = {
    enable = true;
    # off 2026-11-04 (zero monitors) — declarative gatus lives on delphi
    # (Story: note frieren-ops-history).
    uptime-kuma.enable = false;
    # off 2026-11-09 — zero clients in a week of journal; the module stays for
    # the ESP32/Zigbee layer [[exp-009]] (Story: note frieren-ops-history).
    mqtt.enable = false;
    # 65OLED759 at 192.168.3.26:1925; no Hue bridge → hue off (Fact: inventory.toml).
    devices.ambilightTV = {
      enable = true;
      host = "192.168.3.26";
    };
  };

  # One account registered; open signup lets any vhost visitor write the
  # history db (Rule: note frieren-ops-history).
  services.atuin-server = {
    enable = true;
    serverAliases = [
      "atuin.lan"
      "atuin.frieren.local"
      # Clients whose DNS does not know the .lan names reach it by tailnet
      # address (Fact: inventory.toml; sync_address in modules/shell/atuin.nix).
      "100.97.61.65"
      # frieren.lan claims 192.168.3.25 (portal, default_server) — a duplicate
      # server_name is ignored and shadowed the portal; gated by the assertion in
      # reverse-proxy.nix (Story: note frieren-ops-history).
    ];
  };

  # SimpleX Chat SMP relay server (modules/services/simplex-smp-server.nix)
  services.simplex-smp-server = {
    enable = true;
    ip = "192.168.3.25";
    tailscaleIp = "100.97.61.65";
    port = 5223;
  };

  # Exactly ONE RPC on :6800 — the unauthenticated fallback must not shadow
  # the secret-protected daemon (Rule: note frieren-ops-history).
  home-manager.users.devji.programs.aria2-user-fallback.enable = false;

  # Resurrected OpenClaw persona — provenance: note frieren-ops-history.
  home-manager.users.devji.programs.hermes-user = {
    enable = true;
    persona = true;
    gateway.enable = true;
    simplex.daemon = true;
    envFile = "/run/secrets/rendered/hermes.env";
    # The free buffet: chatplayground's web chat models behind an OpenAI-shaped
    # /v1 on loopback, so hermes' `custom:chatplayground` provider is one hop
    # from the same session a browser uses.
    chatplayground.enable = true;
    firecrawl.enable = true;
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
  '';
  # systemd-rfkill restores the EC's persisted block — run after it (Trap: note
  # frieren-ops-history · .agents/deploy/hosts/frieren.md §"Bluetooth rfkill").
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

  programs.dms-greeter.enable = false;

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

  # auto-cpufreq pinned all cores at 3.4GHz (+0.47W idle vs the fixed governor,
  # measured — Story: note frieren-ops-history); powersave still boosts on demand.
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

    # Non-dynamic port policy (HC-7): pin the v3 RPC ports so checks:ports can
    # declare them; NFSv4 clients need only 2049. Conventional values below the
    # ephemeral range (hosts/frieren/firewall-scope.nix; Story: note frieren-ops-history).
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

  # Persistent vault bind-mount (2TB pool /dev/sda2 — Fact: inventory.toml).
  fileSystems."${user.home}/security" = {
    device = "/srv/data/security";
    fsType = "none";
    options = ["bind" "x-systemd.requires=srv-data.mount"];
  };

  # BurgerNAS cold vault: the mount, the automount and the fail-fast NFS options
  # all live in profiles/burgernas-client.nix, so any host that mounts the vault
  # inherits them instead of rediscovering that `mount.nfs` retries for 2 minutes.
  # Export granted on the NAS side in /etc/exports — DSM 7 has no CLI/API for NFS
  # privileges, see the skill.
  profiles.burgernas-client.enable = true;

  # Flash-cache tier — Samsung USB3, F2FS+ZSTD (Fact: inventory.toml).
  # nofail: boot never waits on an unplugged stick.
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
    # RESTORED — a sweep deleted this once (Story: note frieren-ops-history).
    "d /srv/private/jellyfin 0755 jellyfin jellyfin -"
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
      3001 # Uptime-Kuma (retired — Story: note frieren-ops-history)
      # 6052 closed — ESPHome removed 2026-10 (Story: note frieren-ops-history)
      8124 # Scrutiny SMART dashboard (infra-stack)
      # 7351 moved next to the service: networking.nix (Stirling PDF)
      # 42617 closed — ZeroClaw teardown 2026-09 (Story: note frieren-ops-history)
    ];
    allowedUDPPorts = [
      137
      138
    ];
  };

  # RESTORED — a sweep deleted this once (Story: note frieren-ops-history).
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
  # T1-2/T1-6 closure debloat (Story: note frieren-ops-history).

  # No printers managed on this host (Fact: inventory.toml).
  services.printing = {
    enable = lib.mkForce false;
    drivers = lib.mkForce [];
  };

  # State version — RESTORED (Story: note frieren-ops-history).
  system.stateVersion = "26.05";
}
