# Base node configuration for all NixOS hosts.
# Primary user constants: modules/global/user.nix
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  user = import ../global/user.nix;
in {
  imports = [
    ../../modules/config/authorized-keys.nix
    ../../modules/ssh-ca.nix
    inputs.sops-nix.nixosModules.sops
    ./firewall-baseline.nix
    ./boot.nix
    ./hermes.nix
  ];

  boot = {
    kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;
  };

  sops = {
    defaultSopsFile = ../../modules/secrets.yaml;
    age.sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];
    secrets = {
      hashedPassword.neededForUsers = true;
    };
  };

  ssh.ca.enable = true;

  console = {
    font = "Lat2-Terminus16";
    keyMap = "us";
  };

  services = {
    keyd = {
      enable = true;
      keyboards = {
        default = {
          ids = ["*"];
          settings = {
            main = {
              capslock = "escape";
            };
          };
        };
      };
    };
    openssh = {
      enable = true;
      settings = {
        X11Forwarding = false;
        PermitRootLogin = "no";
        PasswordAuthentication = false;
        # sshd defaults this to yes; no host uses keyboard-interactive
        # (PAM) auth, and leaving it on widens the auth surface for free.
        KbdInteractiveAuthentication = false;
      };
    };
  };

  security = {
    sudo.wheelNeedsPassword = false;
  };

  networking = {
    networkmanager.enable = true;
    # Fleet hostname resolution: deploys, remote logs, and the harmonia
    # cache URL all reference hosts by name. frieren has a static LAN IP
    # (see profiles/nas-client.nix).
    hosts = {
      "192.168.3.25" = ["frieren"];
      "192.168.3.36" = ["netbook"];
    };
  };

  time.timeZone = "Europe/Berlin";

  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "de_DE.UTF-8";
    LC_IDENTIFICATION = "de_DE.UTF-8";
    LC_MEASUREMENT = "de_DE.UTF-8";
    LC_MONETARY = "de_DE.UTF-8";
    LC_NAME = "de_DE.UTF-8";
    LC_PAPER = "de_DE.UTF-8";
    LC_TELEPHONE = "de_DE.UTF-8";
  };

  users.users.${user.name} = {
    inherit (user) home;
    isNormalUser = true;
    description = "matt";
    extraGroups = ["networkmanager" "wheel"];
    hashedPasswordFile = config.sops.secrets.hashedPassword.path;
    openssh.authorizedKeys.keys = config.ssh.authorizedKeys.keys;
  };

  environment.systemPackages = with pkgs; [
    curl
    git
    wget
    # Nix toolchain for scripts/task/nix-fmt.sh, the pre-commit hook and the
    # watcher. alejandra replaced nixpkgs-fmt here deliberately: nixpkgs-fmt was
    # the ONLY one of these on PATH, and it is not the repo's formatter — running
    # it would rewrite ~170 of the 187 tracked .nix files. Shipping the real
    # toolchain also means nix-fmt.sh takes its PATH branch and never has to
    # `nix build` a formatter on first use.
    alejandra
    deadnix
    statix
  ];

  # Fixes TERM mismatches when SSHing from kitty/ghostty/xterm-kitty.
  # Safe on desktops: kitty/ghostty override TERM themselves on launch.
  environment.sessionVariables = {
    TERM = "xterm-256color";
  };

  environment.localBinInPath = true;

  # Compressed RAM swap: keeps swap in zstd-compressed RAM pages instead of
  # on disk. Hosts that import base-node are workstations with comfortable
  # RAM headroom (16-64 GB typical), so we scale the NixOS default 25%
  # memoryPercent up to 50% — this matters when /nix/store + active builds
  # + browserland cross physical RAM, where the alternative is an SSD
  # swap partition or file that thrashes wear leveling. zstd is the
  # kernel default compressor and is well-suited to the mixed workload of
  # dev + build + long-running services these hosts tend to carry.
  # priority=100 keeps zram ahead of any physical swap device so the
  # kernel prefers the compressed-RAM pages first.
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
    priority = 100;
  };
}
