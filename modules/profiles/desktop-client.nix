{pkgs, lib, ...}: {
  # Desktop client profile with NAS client dependency
  # Note: nas-client.nix is imported unconditionally as it's a core dependency
  # for desktop client functionality. To disable NAS mounts, configure
  # profiles.nas-client.enable = false in nas-client.nix itself.
  imports = [
    ./base-node.nix
    ./nas-client.nix
  ];

  # Enable FUSE so kbfsfuse can call /run/wrappers/bin/fusermount
  programs.fuse = {
    enable = true;
    userAllowOther = true;
  };

  # Upstream nixpkgs sets PrivateTmp = true in services.kbfs, which places the unit
  # in an unprivileged private mount namespace where setuid fusermount fails (EPERM)
  # and isolates any mounts from the rest of the user session. Disable PrivateTmp to
  # allow persistent user-visible FUSE mounting.
  systemd.user.services.kbfs.serviceConfig.PrivateTmp = lib.mkForce false;

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
    # Accept DNS config pushed by the tailnet (pi-hole at frieren, once set
    # as a global nameserver in the Tailscale admin console) plus the
    # 192.168.3.0/24 subnet route frieren advertises so off-LAN clients
    # reach the NAS (pdf.frieren.lan etc.). Declared via extraSetFlags
    # because extraUpFlags only apply with authKeyFile (none of our hosts
    # use one) — the boot-time `tailscale set` works on already-
    # authenticated nodes. The previous extraUpFlags entry
    # "--dns=100.97.61.65" never applied: that flag doesn't exist on this
    # tailscale version. Tailscaled skips installing routes for subnets the
    # machine is directly attached to, so LAN-resident hosts keep their
    # native path.
    tailscale.extraSetFlags = [
      "--accept-dns=true"
      "--accept-routes=true"
    ];
    resolved.enable = true;
    resolved.settings.Resolve.Domains = ["~lan" "~frieren.lan"];
  };

  # Keybase's GUI writes ~/.config/autostart/keybase_autostart.desktop the first
  # time it runs. Its Exec is `env KEYBASE_AUTOSTART=1 run_keybase`, and
  # `run_keybase` ships only with keybase-gui. With services.keybase/kbfs above
  # already running Keybase as user services, that entry is a duplicate that can
  # only fail: fern logged `env: 'run_keybase': No such file or directory`
  # (exit 127) on every login, leaving a permanently failed user unit.
  # Drop the entry while `run_keybase` is absent; if the GUI is ever installed
  # the entry is valid and this leaves it alone. Keybase's sentinel
  # (~/.config/keybase/autostart_created) stops it being rewritten meanwhile.
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
