# minyx — Raspberry Pi 3 Model B edge node (preserved; reflash planned after 26.11).
#
# The device is 1 GiB of RAM on an SD card with an impermanent (tmpfs) root, so
# every choice here is about not running out of memory or wearing the card.
{
  lib,
  pkgs,
  ...
}: {
  imports = [
    ../../modules/profiles/desktop-client.nix
  ];

  boot = {
    kernelParams = [
      "cma=256M"
      "snd_bcm2835.enable_hdmi=1"
    ];
    supportedFilesystems = lib.mkForce [
      "vfat"
      "xfs"
      "cifs"
      "ntfs"
      "nfs"
      "f2fs"
    ];
    tmp.cleanOnBoot = true;
  };

  # Nix on a 1 GiB device: one job, one core. The default `max-jobs = auto`
  # starts four compiles on four Cortex-A53s and dies of OOM before it finishes
  # any of them. aarch64 closures belong on delphi (see the note in AGENTS.nix),
  # not here — this is the setting that stops the Pi from trying.
  nix.settings = {
    max-jobs = 1;
    cores = 1;
    auto-optimise-store = true;
  };

  # tmpfs root plus 1 GiB means the only useful swap is compressed RAM, and
  # without it the first `nix build` takes the kernel down.
  zramSwap = {
    enable = true;
    memoryPercent = 50;
  };

  # The build scratch dir lives on the SD card's /var, not in a 500 MB tmpfs.
  systemd.services.nix-daemon.environment.TMPDIR = "/var/tmp";

  networking = {
    hostName = "minyx";
    # NetworkManager owns both interfaces (the fleet standard, and why
    # `/etc/NetworkManager/system-connections` is in the persistence list).
    # The Wi-Fi credentials live in NM's persistent store, not in the repo.
    networkmanager.enable = true;
    # blocky answers DNS for the LAN; without these the firewall drops it and
    # the service looks broken. 22 is sshd.
    firewall = {
      allowedTCPPorts = [22 53];
      allowedUDPPorts = [53];
    };
  };

  services.blocky = {
    enable = true;

    settings = {
      ports.dns = 53;
      upstreams.groups.default = [
        "https://one.one.one.one/dns-query"
      ];
      # Bootstrap DoH before the system resolver is up.
      bootstrapDns = {
        upstream = "https://one.one.one.one/dns-query";
        ips = ["1.1.1.1" "1.0.0.1"];
      };
      blocking = {
        denylists = {
          ads = ["https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"];
        };
        clientGroupsBlock = {
          default = ["ads"];
        };
      };
    };
  };

  hardware = {
    bluetooth.enable = true;
    enableRedistributableFirmware = true;
    firmware = [pkgs.wireless-regdb];
  };

  # Docker stays (edge containers were the original point of the box); the k8s
  # toolchain that came with the borrowed Pi config does not — there is no
  # cluster in this fleet, and kubectl/helm/nodejs are pure SD-card weight.
  virtualisation.docker.enable = true;
  environment.systemPackages = with pkgs; [
    bind # dig, for checking blocky
    iptables
    bluez
    bluez-tools
  ];

  documentation.nixos.enable = false;

  # Boot loader and `stateVersion` stay in `configuration.nix` (the host entry).
  fileSystems."/nix/persist".neededForBoot = true;
  environment.persistence."/nix/persist/system" = {
    hideMounts = true;
    directories = [
      "/etc/nixos"
      "/etc/ssh"
      "/var/log"
      "/var/lib/bluetooth"
      "/var/lib/docker"
      "/var/lib/nixos"
      "/var/lib/systemd/coredump"
      "/var/lib/tailscale"
      "/etc/NetworkManager/system-connections"
      {
        directory = "/var/lib/colord";
        user = "colord";
        group = "colord";
        mode = "u=rwx,g=rx,o=";
      }
    ];
    files = [
      "/etc/machine-id"
    ];
  };
}
