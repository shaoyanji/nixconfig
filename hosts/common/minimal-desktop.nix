{
  config,
  pkgs,
  ...
}: {
  imports = [
    ./nfs.nix
    ./cifs.nix
  ];
  sops = {
    defaultSopsFile = ../../modules/secrets/secrets.yaml;
    age.sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];
    secrets = {
      "server/localwd/credentials" = {};
      "server/keyrepo/credentials" = {};
      hashedPassword.neededForUsers = true;
    };
  };
  services = {
    #    xserver.digimend.enable = true;
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
    #Touchpad support
    libinput.enable = true;
    openssh = {
      enable = true;
      settings = {
        X11Forwarding = true;
        PermitRootLogin = "no";
        PasswordAuthentication = false;
      };
    };
  };

  security.sudo.wheelNeedsPassword = false;
  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

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
    LC_NUMERIC = "de_DE.UTF-8";
    LC_PAPER = "de_DE.UTF-8";
    LC_TELEPHONE = "de_DE.UTF-8";
    LC_TIME = "de_DE.UTF-8";
  };

  # Enable the X11 windowing system.
  # You can disable this if you're only using the Wayland session.
  #  services.xserver.enable = true;

  # Enable the KDE Plasma Desktop Environment.
  #services.desktopManager.plasma6.enable = true;

  # Configure keymap in X11
  #enable bluetooth
  hardware.bluetooth.enable = true;
  services.pulseaudio.enable = false;

  security.rtkit.enable = true;
  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.devji = {
    home = "/home/devji";
    isNormalUser = true;
    description = "matt";
    extraGroups = ["networkmanager" "wheel" "docker" "incus-admin"];
    hashedPasswordFile = config.sops.secrets.hashedPassword.path;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMEvIBjy85SIOMbk9WCY/jSrKiXcJ8aA4xqvMKC1b4aH jisifu@gmail.com"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKVYLgws2TgaYIsOmVmJeoJIu9F8lguBXi711Kv90jaM devji@poseidon"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOD4PopDAxzh1t4nNnDE/xiWLGYzopLRzZ7eBwd4hHza devji@schneeeule"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILaSocp/bIkehFWy8I/H+g/46sWfnmj9s+Zx13dIjQct devji@lunarfall"
    ];
    #packages = with pkgs; [
    # kdePackages.kate
    # thunderbird
    #];
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
    # config.boot.kernelPackages.digimend
    cifs-utils
    #    nfs-utils
  ];
}
