{
  config,
  pkgs,
  inputs,
  ...
}: {
  imports = [
    ../../modules/config/authorized-keys.nix
    ./nas-client.nix
    inputs.sops-nix.nixosModules.sops
  ];

  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
  };

  sops = {
    defaultSopsFile = ../../modules/secrets.yaml;
    age.sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];
    secrets = {
      hashedPassword.neededForUsers = true;
    };
  };

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
    openssh = {
      enable = true;
      settings = {
        X11Forwarding = true;
        PermitRootLogin = "no";
        PasswordAuthentication = false;
      };
    };
    pulseaudio.enable = false;
    tailscale.enable = true;
    tailscale.useRoutingFeatures = "both";
    resolved.enable = true;
    resolved.settings.Resolve.Domains = ["~.cloudforest-kardashev.ts.net" "~.fritz.box" "~."];
  };

  programs.nix-ld.enable = true;

  security = {
    sudo.wheelNeedsPassword = false;
    rtkit.enable = true;
  };

  hardware.bluetooth.enable = true;

  networking = {
    networkmanager.enable = true;
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

  users.users.devji = {
    home = "/home/devji";
    isNormalUser = true;
    description = "matt";
    extraGroups = ["networkmanager" "wheel" "docker" "incus-admin" "video"];
    hashedPasswordFile = config.sops.secrets.hashedPassword.path;
    openssh.authorizedKeys.keys = config.ssh.authorizedKeys.keys;
  };

  environment.systemPackages = with pkgs; [
    curl
    git
    wget
    nixpkgs-fmt
  ];

  environment.localBinInPath = true;
  zramSwap.enable = true;
}
