# Desktop client layer: base-node plus fuse/kbfs and the user services a graphical host runs.
{
  self,
  pkgs,
  lib,
  ...
}: {
  # Desktop client profile with NAS client dependency
  # Note: nas-client.nix is imported unconditionally as it's a core dependency
  # for desktop client functionality. To disable NAS mounts, configure
  # profiles.nas-client.enable = false in nas-client.nix itself.
  imports = [
    self.modules."profiles.base-node"
    self.modules."profiles.nas-client"
    self.modules."profiles.nas-media"
  ];

  profiles.nasMedia.enable = lib.mkDefault true;

  # Enable FUSE so kbfsfuse can call /run/wrappers/bin/fusermount
  programs.fuse = {
    enable = true;
    userAllowOther = true;
  };

  systemd.user.services.kbfs = {
    # `Restart=on-failure` without `RestartSec` retries at systemd's 100 ms
    # default, so a login without a network retires the unit after five fast
    # failures and the session has no kbfs at all. Retry forever with backoff.
    unitConfig.StartLimitIntervalSec = 0;
    serviceConfig = {
      # Upstream nixpkgs sets PrivateTmp = true in services.kbfs, which places the
      # unit in an unprivileged private mount namespace where setuid fusermount
      # fails (EPERM) and isolates any mounts from the rest of the user session.
      # Disable PrivateTmp to allow persistent user-visible FUSE mounting.
      PrivateTmp = lib.mkForce false;
      RestartSec = "2s";
      RestartSteps = 5;
      RestartMaxDelaySec = "300s";
    };
  };

  systemd.user.services.keybase = {
    unitConfig.StartLimitIntervalSec = 0;
    serviceConfig = {
      RestartSec = "2s";
      RestartSteps = 5;
      RestartMaxDelaySec = "300s";
    };
  };

  services = {
    keybase.enable = true;
    kbfs.enable = true;
    xserver.xkb = {
      layout = "us";
      variant = "";
    };
    avahi = {
      enable = true;
      nssmdns4 = true;
      openFirewall = true;
      publish = {
        enable = true;
        userServices = true;
      };
    };
    printing = {
      enable = true;
      listenAddresses = ["*:631"];
      allowFrom = ["all"];
      browsing = true;
      defaultShared = true;
      openFirewall = true;
      drivers = [
        pkgs.hplip
        pkgs.hplipWithPlugin
      ];
    };
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };
    pulseaudio.enable = false;
    tailscale.enable = true;
    tailscale.useRoutingFeatures = "both";
    # The tailnet pushes DNS and the LAN route through `tailscale set`; the old
    # `--dns=` flag never applied. Why: docs/dns-failover.md §"Point clients at it".
    tailscale.extraSetFlags = lib.mkDefault [
      "--accept-dns=true"
      "--accept-routes=true"
    ];
    resolved.enable = true;
    resolved.settings.Resolve.Domains = ["~lan" "~frieren.lan"];
  };

  # Keybase's GUI writes an autostart entry whose `run_keybase` only exists with
  # keybase-gui, so it fails at every login. Why:
  # .agents/deploy/hosts/fern.md §"Keybase autostart".
  system.activationScripts.removeBrokenKeybaseAutostart = ''
    for autostart in /home/*/.config/autostart/keybase_autostart.desktop; do
      [ -e "$autostart" ] || continue
      if ! command -v run_keybase >/dev/null 2>&1 && ! ls /etc/profiles/per-user/*/bin/run_keybase >/dev/null 2>&1; then
        echo "removing dead Keybase autostart entry: $autostart"
        rm -f "$autostart"
      fi
    done
  '';

  # Required for non-Nix binaries/toolchains in daily desktop workflows.
  # Keep enabled here, but treat this as a compatibility tradeoff.
  programs.nix-ld.enable = false;

  security.rtkit.enable = true;

  hardware.bluetooth.enable = true;

  users.users.devji.extraGroups = [
    "docker"
    # "incus-admin"
    "video"
  ];
}
