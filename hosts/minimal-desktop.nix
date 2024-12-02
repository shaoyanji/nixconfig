{inputs, config, pkgs, lib, ... }:
{
  nix.settings.experimental-features = [ "nix-command" "flakes"];
  nixpkgs.config.allowUnfree = true;
  services={
    xserver.digimend.enable = true;
    displayManager.sddm = {
      enable = true;
      wayland.enable = true;
    };
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
  # Enable automatic login for the user.
    displayManager.autoLogin={
      enable = true;
      user = "devji";
    };
  };
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
  # services.xserver.enable = true;

  # Enable the KDE Plasma Desktop Environment.
  #services.desktopManager.plasma6.enable = true;
 
 programs.hyprland = {
    enable = true;
    # set the flake package
    package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
    # make sure to also set the portal package, so that they are in sync
    portalPackage = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
    xwayland.enable = true;
 };

  # Optional, hint Electron apps to use Wayland:
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  # Configure keymap in X11
  #enable bluetooth
  hardware={
    bluetooth.enable = true;
    pulseaudio.enable = false;
  };

  security.rtkit.enable = true;
  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.devji = {
    isNormalUser = true;
    description = "matt";
    extraGroups = [ "networkmanager" "wheel" ];
    hashedPassword = "$6$.MwUydqIuXNoHXxy$8N0tM2mWOStiuDEkDw/wBCwg73PTKGY24G7huRi3gn0GJPW.o9d4eEseTmB7KXxlOtUG06fNgQwTmEkAYkS.a.";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMEvIBjy85SIOMbk9WCY/jSrKiXcJ8aA4xqvMKC1b4aH jisifu@gmail.com"
    ];
    packages = with pkgs; [
    # kdePackages.kate
    # thunderbird
    ];
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
    kitty
    cifs-utils
    ffmpeg
    gphoto2
    config.boot.kernelPackages.digimend
    # nfs-utils
  ];
}

