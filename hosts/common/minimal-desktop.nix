{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: let
  localSubKeys =
    # builtins.fetchurl {
    #   url = "https://gist.githubusercontent.com/shaoyanji/8e051ec6548dcf8cebf1cd3e4e668f7d/raw/authorized_keys";
    #   sha256 = "sha256:1h32q73qiqgyxkwvxi58dxq5qvhbihaii1v1fawrv58k7mhm23m6";
    # }
    # |> builtins.readFile
    # |> builtins.split "\n"
    # |> builtins.filter (x: x != []);
    builtins.filter (x: x != []) (builtins.split "\n" (
      builtins.readFile (
        builtins.fetchurl {
          url = "https://gist.githubusercontent.com/shaoyanji/8e051ec6548dcf8cebf1cd3e4e668f7d/raw/authorized_keys";
          sha256 = "sha256:1h32q73qiqgyxkwvxi58dxq5qvhbihaii1v1fawrv58k7mhm23m6";
        }
      )
    ));
in {
  imports = [
    ./specialization-server.nix
    ./localmounts.nix
    inputs.sops-nix.nixosModules.sops
  ];
  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
    # binfmt.emulatedSystems = [] ++ lib.optionals pkgs.stdenv.hostPlatform.isx86_64 ["aarch64-linux"];
  };
  sops = {
    defaultSopsFile = ../../modules/secrets.yaml;
    age.sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];
    secrets = {
      # "server/localwd/credentials" = {};
      # "local/k3s/token" = {};
      hashedPassword.neededForUsers = true;
    };
  };

  console = {
    font = "Lat2-Terminus16";
    keyMap = "us";
    #   useXkbConfig = true; # use xkb.options in tty.
  };
  services = {
    # kubo.enable = true;
    keybase.enable = true;
    kbfs.enable = true;
    xserver.xkb = {
      layout = "us";
      variant = "";
    };
    printing.enable = true;
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      # If you want to use JACK applications, uncomment this
      #jack.enable = true;
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
  };

  # programs.nix-ld = {
  #   enable = true;
  #   libraries = with pkgs; [
  #     #libGL
  #     alsa-lib
  #     gmp #simplex-chat
  #   ];
  # };
  security = {
    sudo.wheelNeedsPassword = false;
    rtkit.enable = true;
  };
  hardware.bluetooth.enable = true;
  # Enable networking
  networking = {
    networkmanager.enable = true;
    #    nameservers = ["192.168.178.1"];
    #    search = ["fritz.box"];
    # Configure network proxy if necessary
    # proxy.default = "http://user:password@proxy:port/";
    # proxy.noProxy = "127.0.0.1,localhost,internal.domain";
  };

  # Set your time zone.
  time.timeZone = "Europe/Berlin";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "de_DE.UTF-8";
    LC_IDENTIFICATION = "de_DE.UTF-8";
    LC_MEASUREMENT = "de_DE.UTF-8";
    LC_MONETARY = "de_DE.UTF-8";
    LC_NAME = "de_DE.UTF-8";
    #    LC_NUMERIC = "de_DE.UTF-8";
    LC_PAPER = "de_DE.UTF-8";
    LC_TELEPHONE = "de_DE.UTF-8";
    #    LC_TIME = "de_DE.UTF-8";
  };

  # Enable the X11 windowing system.
  # You can disable this if you're only using the Wayland session.
  #  services.xserver.enable = true;

  # Enable the KDE Plasma Desktop Environment.
  # services.desktopManager.plasma6.enable = true;

  # Configure keymap in X11

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.devji = {
    home = "/home/devji";
    isNormalUser = true;
    description = "matt";
    extraGroups = ["networkmanager" "wheel" "docker" "incus-admin" "video"];
    hashedPasswordFile = config.sops.secrets.hashedPassword.path;
    openssh.authorizedKeys.keys = localSubKeys;
    #packages = with pkgs; [
    # kdePackages.kate
    # thunderbird
    #];
  };
  nix = {
    # sshServe = {
    #   enable = true;
    #   keys = localSubKeys;
    # };
    # buildMachines = [
    #   {
    #     hostName = "poseidon.fritz.box";
    #     protocol = "ssh-ng";
    #     # if the builder supports building for multiple architectures,
    #     # replace the previous line by, e.g.
    #     systems = [
    #       "x86_64-linux"
    #       # "aarch64-linux"
    #     ];

    #     maxJobs = 12;
    #     speedFactor = 10;
    #     supportedFeatures = ["nixos-test" "benchmark" "big-parallel" "kvm"];
    #     mandatoryFeatures = [];
    #   }

    #   {
    #     hostName = "thinsandy.fritz.box";
    #     protocol = "ssh-ng";
    #     # if the builder supports building for multiple architectures,
    #     # replace the previous line by, e.g.
    #     systems = [
    #       "x86_64-linux"
    #       # "aarch64-linux"
    #     ];

    #     maxJobs = 1;
    #     speedFactor = 1;
    #     supportedFeatures = ["nixos-test" "benchmark" "big-parallel" "kvm"];
    #     mandatoryFeatures = [];
    #   }
    # ];
    # # Switch for local builds
    # distributedBuilds = true;
    # extraOptions = ''
    #   builders-use-substitutes = true
    # '';
  };

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  environment.systemPackages = with pkgs; [
    curl
    git
    wget
    nixpkgs-fmt
  ];

  zramSwap.enable = true;
}
