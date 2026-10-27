# minyx — Raspberry Pi 3 Model B: always-on jump box and DNS failover backup.
# Roles beside this file: dns.nix, tunnel.nix (hardware-configuration.nix is
# sd-image generated). Budget, medium and deploy: .agents/deploy/hosts/minyx.md
{
  config,
  lib,
  pkgs,
  ...
}: let
  user = import ../../modules/global/user.nix;
in {
  imports = [
    ./dns.nix
    ./hardware-configuration.nix
    ./tunnel.nix
    ../../modules/config/authorized-keys.nix
    ../../modules/ssh-ca.nix
  ];

  system.stateVersion = "24.11";

  # base-node.nix sets this for the fleet, and this host does not import it. Left
  # as UTC, its journal is an hour off every other host's: during the 2026-10-27
  # failover test a BACKUP transition here and the matching MASTER transition on
  # frieren could not be lined up without converting by hand.
  time.timeZone = "Europe/Berlin";

  # ── platform budget ─────────────────────────────────────────────────────
  # The old config reserved 256M of this box's 1 GiB for a VideoCore that a
  # headless jump host never shows anything on.
  boot.kernelParams = ["cma=16M"];
  boot.tmp.cleanOnBoot = true;

  # aarch64 closures are built elsewhere when they can be. This is NOT
  # `max-jobs = 0`: the host has no cached closure of its own and no push path, so
  # substitute-or-fail left it unable to even build its way back to a working
  # system. It is a WIP host pending a clean reinstall — until then the honest
  # setting is "may build, slowly", not "may never build".
  nix.settings = {
    max-jobs = 1;
    cores = 1;
    auto-optimise-store = true;
  };

  # No swap file on the stick: compressed RAM only.
  zramSwap = {
    enable = true;
    memoryPercent = 50;
  };

  # The store is the only thing that grows between fleet updates, so bound it.
  # `automatic` and `dates` are set here; the retention string belongs to
  # modules/global/global.nix (10d) — defining it in both places is a hard eval
  # error that a module-system + assertions check does not surface, because a
  # conflicting option is only detected when its value is forced.
  nix.gc = {
    automatic = true;
    dates = "weekly";
  };

  # ext4 is the root filesystem and vfat the firmware partition. Both are
  # declared so their tools (e2fsprogs, dosfstools) are in the closure the
  # expand-on-boot service needs, and nothing else is — no btrfs, xfs, zfs, cifs
  # or NFS tooling on a box whose only filesystem is the one it boots from.
  boot.supportedFilesystems = ["ext4" "vfat"];

  # sd-image.nix forces hardware.enableAllHardware = true, and that implies
  # enableRedistributableFirmware — which is linux-firmware at 1.98 GB, plus
  # Intel 2200/ralink/zd1211 radios, DVB tuner blobs and SOF audio DSPs. On a Pi
  # 3B the only radio is a Broadcom SDIO part, so the firmware payload drops to
  # the Pi wireless firmware and the regulatory database. The
  # all-hardware *kernel modules* stay on purpose: usb-storage/xhci in the initrd
  # is what finds this box's root disk on the USB stick.
  hardware.enableRedistributableFirmware = lib.mkForce false;
  hardware.wirelessRegulatoryDatabase = true;

  documentation = {
    nixos.enable = false;
    man.enable = false;
    doc.enable = false;
    info.enable = false;
    dev.enable = false;
  };

  # This box is ssh'd into from three different terminals — kitty on the
  # desktops, foot on scratch, alacritty on the netbook — and ssh passes the
  # client's TERM through, so minyx is handed xterm-kitty, foot or alacritty and
  # has to answer all of them. With none of those entries present ncurses refuses
  # the session ("missing or unsuitable terminal") and tmux will not start.
  #
  # modules/profiles/base-node.nix settles this fleet-wide by pinning
  # TERM=xterm-256color. This host imports globalModules instead of that
  # baseline, and pinning one name is the wrong answer for a jump box every
  # client lands on anyway: it hides the client's real terminal and takes its
  # capabilities with it. enableAllTerminfo installs the *terminfo outputs* only
  # (kitty, foot, alacritty, ghostty, wezterm, st, tmux and seven more), not the
  # applications — a couple of megabytes of database, nothing that runs.
  #
  # TERMINFO_DIRS needs no config: nixpkgs' terminfo module already exports it
  # profile-relative, and a literal value would only duplicate entries.
  environment.enableAllTerminfo = true;

  # The stock image left nix-channel's artefacts behind, and Nix still consults
  # them whenever NIX_PATH is unset (NixOS/nix#9574) — every activation of this
  # host printed "… exists, but channels have been disabled" for both. Channels
  # are off fleet-wide (`nix.channel.enable = false`, modules/global/global.nix),
  # so NixOS will not recreate them; this removes what a flash put on the card,
  # which means reflashing and re-pushing cannot silently reintroduce a channel
  # as a second nixpkgs. `R` on the profile also drops its `channels-N-link`
  # generations via the glob.
  systemd.tmpfiles.rules = [
    "R /root/.nix-defexpr/channels"
    "R /nix/var/nix/profiles/per-user/root/channels"
    "R /nix/var/nix/profiles/per-user/root/channels-*-link"
  ];

  # ── flash-write policy ──────────────────────────────────────────────────
  # The medium, and why these four settings are a policy: .agents/deploy/hosts/minyx.md
  # Measured on the candidate stick (SanDisk Cruzer, 2026-10-26): 16.9 MB/s read
  # and `discard_max_bytes = 0` — NO TRIM at all. Without TRIM the controller
  # cannot learn which blocks the filesystem freed, so NixOS's GC churn turns into
  # rewrite-the-live-data. The response is not a tweak, it is a policy: keep bytes
  # OFF the stick.
  #
  # 1. The journal never touches it. A jump box's journal is read on the box, in
  #    the hour it happened, or it is read nowhere; `volatile` puts it in RAM and
  #    caps it there.
  # `settings`, not the removed `extraConfig`: this nixpkgs rejects the old option
  # outright, which the eval caught before anything was built.
  services.journald.settings.Journal = {
    Storage = "volatile";
    RuntimeMaxUse = "32M";
    MaxRetentionSec = "1h";
    RateLimitIntervalSec = "30s";
    RateLimitBurst = 500;
  };

  # 2. /tmp in RAM, not on the stick. No swap file on this host (zram only), so
  #    this is bounded explicitly rather than left to grow into the OOM killer.
  boot.tmp.useTmpfs = true;
  boot.tmp.tmpfsSize = "128M";

  # 3. Writeback in fewer, calmer bursts. Cheap flash controllers stall under
  #    bursty traffic and the stalls land exactly during a switch.
  boot.kernel.sysctl = {
    "vm.dirty_background_ratio" = 3;
    "vm.dirty_ratio" = 8;
    "vm.dirty_writeback_centisecs" = 3000;
  };

  # 4. `fstrim` is pointless here: the device reports no discard support, so the
  #    timer would run weekly and issue requests the controller drops.
  services.fstrim.enable = false;

  # ── network ─────────────────────────────────────────────────────────────
  networking = {
    hostName = "minyx";

    # NetworkManager owns both interfaces. It is the only client that can take a
    # PSK from a file at activation time (`ensureProfiles.environmentFiles` runs
    # envsubst over the generated profile), so the secret stays out of the store
    # and out of this file. `useDHCP` is deliberately unset: the NetworkManager
    # module assigns it `false` outright, and a second definition of one option
    # is a hard eval error rather than a pick.
    networkmanager = {
      enable = true;
      ensureProfiles = {
        environmentFiles = [config.sops.templates."network-manager.env".path];
        profiles = {
          # Ethernet is the preferred path: the jump box is reached at its LAN
          # address, and keeping the USB NIC on the same lease beats churning
          # over to wifi whenever both are up.
          fleet-wired = {
            connection = {
              id = "fleet-wired";
              # Fixed, so an NM rewrite cannot mint a second identity for the
              # same profile (the dell-dock precedent).
              uuid = "6f0a1cf4-6c2e-4a7b-9f0e-5b3d8c1a2e77";
              type = "ethernet";
              interface-name = "enu1u1";
              autoconnect = true;
              autoconnect-priority = 100;
            };
            ipv4.method = "auto";
            ipv6.method = "auto";
          };
          fleet-wifi = {
            connection = {
              id = "fleet-wifi";
              uuid = "0d7c4b19-3a5e-4d2f-8c61-9e0f2b7a4d58";
              type = "wifi";
              autoconnect = true;
              autoconnect-priority = 10;
            };
            wifi = {
              ssid = "$WIFI_SSID";
              mode = "infrastructure";
            };
            wifi-security = {
              key-mgmt = "wpa-psk";
              psk = "$WIFI_PSK";
            };
            ipv4.method = "auto";
            ipv6.method = "auto";
          };
        };
      };
    };

    # Only sshd listens. Tailscale is outbound-initiated and installs its own
    # rules, so it needs no inbound hole here; the resolver's 53 is opened on the
    # role's interface by modules/net/dns/failover.nix.
    firewall.allowedTCPPorts = [22];
  };

  # ── access ──────────────────────────────────────────────────────────────
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  # This host is never managed in place: it takes a remotely built closure
  # pushed from delphi, and with `PermitRootLogin = "no"` plus no password for
  # its user there is no other way back in. The fleet baseline
  # (modules/profiles/base-node.nix) answers that with two settings, and this
  # host had neither: CA-signed certs are what a fleet host authenticates with,
  # and passwordless wheel sudo is what `nixos-rebuild --target-host
  # --use-remote-sudo` needs to activate the pushed system.
  ssh.ca.enable = true;
  security.sudo.wheelNeedsPassword = false;

  # This box had no system account at all: the old chain created only a
  # home-manager user entry, so there was nothing to log in as once HM went away.
  users.users.${user.name} = {
    isNormalUser = true;
    home = user.home;
    description = user.shortName;
    extraGroups = ["wheel"];
    openssh.authorizedKeys.keys = config.ssh.authorizedKeys.keys;
  };

  environment.systemPackages = with pkgs; [
    age
    curl
    gh
    gitMinimal
    jq
    mosh
    rsync
    tmux
  ];

  # ── secrets ─────────────────────────────────────────────────────────────
  # This host imports sops-nix (flake/host-inventory.nix) but nothing ever
  # configured it: no default file, no identity, and no secret declared — so
  # every secret would have stayed unrendered, which is why `ghcs` reported
  # "sops is not enrolled on this host yet".
  #
  # `age.sshKeyPaths` is the fleet convention (modules/profiles/base-node.nix):
  # the host's own SSH host key *is* its age identity, and `&minyxhost` in
  # .sops.yaml is the matching recipient. No age `keys.txt` belongs on a NixOS
  # host — that file is the Home Manager plane, and this host has no Home
  # Manager on purpose.
  sops = {
    defaultSopsFile = ../../modules/secrets.yaml;
    age.sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];
    secrets."github-token" = {
      # Read by `ghcs` (hosts/minyx/tunnel.nix); the value is the `ghsudo`
      # entry in modules/secrets.yaml.
      key = "ghsudo";
      owner = user.name;
    };
    # The fleet's own wireless network — the same pair the gok appliance takes
    # from sops (hosts/gok/instance.nix). The SSID is not a secret, but it lives
    # beside the PSK so one entry owns the network and the two cannot drift.
    # sops-nix splits `key` on `/` (pkgs/sops-install-secrets/main.go), so the
    # path is slashes, not the dotted form `gok.sh` uses when it reads the same
    # entry — a dotted key is looked up as one literal name and fails the
    # build-time manifest check.
    secrets."wifi-ssid" = {key = "gokrazy/gok/wifi_ssid";};
    secrets."wifi-psk" = {key = "gokrazy/gok/wifi_psk";};
    # NetworkManager's profile writer is the only piece that can substitute a
    # secret at activation time, so this is where the PSK crosses the boundary.
    templates."network-manager.env".content = ''
      WIFI_SSID=${config.sops.placeholder."wifi-ssid"}
      WIFI_PSK=${config.sops.placeholder."wifi-psk"}
    '';
  };

  services.tailscale.enable = true;
}
