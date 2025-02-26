{
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ../common/minimal-desktop.nix
  ];
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  # Use the GRUB 2 boot loader.
  #boot.loader.grub.enable = true;
  # boot.loader.grub.efiSupport = true;
  # boot.loader.grub.efiInstallAsRemovable = true;
  # boot.loader.efi.efiSysMountPoint = "/boot/efi";
  # Define on which hard drive you want to install Grub.
  #boot.loader.grub.device = "/dev/sda"; # or "nodev" for efi only

  networking.hostName = "thinsandy"; # Define your hostname.
  # Pick only one of the below networking options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  environment.systemPackages = with pkgs; [
    btrfs-progs
    f2fs-tools
    docker
    ethtool
    networkd-dispatcher
  ];

  # Set your time zone.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Select internationalisation properties.
  # i18n.defaultLocale = "en_US.UTF-8";

  # Enable the X11 windowing system.
  # services.xserver.enable = true;

  # Configure keymap in X11
  # services.xserver.xkb.layout = "us";
  # services.xserver.xkb.options = "eurosign:e,caps:escape";

  # Enable CUPS to print documents.
  # services.printing.enable = true;

  # Enable sound.
  # hardware.pulseaudio.enable = true;
  # OR

  # Enable touchpad support (enabled default in most desktopManager).
  # services.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  #   packages = with pkgs; [
  #     firefox
  #     tree
  #   ];

  # List packages installed in system profile. To search, run:
  # $ nix search wget

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how
  # to actually do that.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  #

  #  services.blocky = {
  #    enable = true;
  #
  #    settings = {
  #      ports.dns = 53; # Port for incoming DNS Queries.
  #      upstreams.groups.default = [
  #        "https://one.one.one.one/dns-query" # Using Cloudflare's DNS over HTTPS server for resolving queries.
  #      ];
  #      # For initially solving DoH/DoT Requests when no system Resolver is available.
  #      bootstrapDns = {
  #        upstream = "https://one.one.one.one/dns-query";
  #        ips = ["1.1.1.1" "1.0.0.1"];
  #      };
  #      #Enable Blocking of certain domains.
  #      blocking = {
  #        denylists = {
  #          #Adblocking
  #          ads = ["https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"];
  #          #Another filter for blocking adult sites
  #          #adult = ["https://blocklistproject.github.io/Lists/porn.txt"];
  #          #You can add additional categories
  #        };
  #        #Configure what block categories are used
  #        clientGroupsBlock = {
  #          default = ["ads"];
  #          #kids-ipad = ["ads" "adult"];
  #        };
  #      }; # anything from config.yml
  #      conditional = {
  #        fallbackUpstream = false;
  #        rewrite = {
  #          bountystash.com = "fritz.box";
  #        };
  #        mapping = {
  #          fritz.box = "192.168.178.1";
  #        };
  #      };
  #    };
  #  };
  #  networking.nftables.enable = true;
  #  services.resolved = {
  #    enable = true;
  #    dnssec = "true";
  #    domains = ["~."];
  #    fallbackDns = [
  #      "192.168.178.1"
  #    ];
  #    dnsovertls = "true";
  #  };
  #  services.tailscale.useRoutingFeatures = "server";
  virtualisation.docker.enable = true;
  #  services = {
  #    networkd-dispatcher = {
  #      enable = true;
  #      rules."50-tailscale" = {
  #        onState = ["routable"];
  #        script = ''
  #          ${lib.getExe pkgs.ethtool} -K eth0 rx-udp-gro-forwarding on rx-gro-list off
  #        '';
  #      };
  #    };
  #  };
  system.stateVersion = "24.11"; # Did you read the comment?
}
