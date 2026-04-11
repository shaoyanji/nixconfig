# Base node configuration for all NixOS hosts.
# Primary user constants: modules/global/user.nix
{
  config,
  pkgs,
  inputs,
  ...
}: {
  imports = [
    ../../modules/config/authorized-keys.nix
    inputs.sops-nix.nixosModules.sops
    ./firewall-baseline.nix
  ];

  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;
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
    openssh = {
      enable = true;
      settings = {
        X11Forwarding = true;
        PermitRootLogin = "no";
        PasswordAuthentication = false;
      };
    };
  };

  security = {
    sudo.wheelNeedsPassword = false;
  };

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
    extraGroups = ["networkmanager" "wheel"];
    hashedPasswordFile = config.sops.secrets.hashedPassword.path;
    openssh.authorizedKeys.keys = config.ssh.authorizedKeys.keys;
  };

  environment.systemPackages = with pkgs; [
    curl
    git
    wget
    nixpkgs-fmt
    nurl
    python3
  ];

  environment.localBinInPath = true;
  zramSwap.enable = true;
}
