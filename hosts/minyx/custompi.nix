# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).
{
  inputs,
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [
    # Include the results of the hardware scan.
    ../common/minimal-desktop.nix
  ];
  # !!! Adding a swap file is optional, but strongly recommended!
  swapDevices = [
    #{device = "/swap";}
  ];
  # Use the extlinux boot loader. (NixOS wants to enable GRUB by default)
  # Enables the generation of /boot/extlinux/extlinux.conf
  # Disable ZFS on kernel 6
  #hardware.pulseaudio.enable = true;
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
    tmp.useTmpfs = true;
  };
  systemd.services.nix-daemon = {
    environment.TMPDIR = "/var/tmp";
  };
  # A bunch of boot parameters needed for optimal runtime on RPi 3b+
  networking.hostName = "minyx"; # Define your hostname.
  # Pick only one of the below networking options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  services.scx.enable = lib.mkDefault false;
  environment.systemPackages = with pkgs; [
    #neovim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    bind
    kubectl
    kubernetes-helm
    iptables
    openvpn
    python3
    nodejs
    docker-compose
    bluez
    bluez-tools
  ];
  services.blocky = {
    enable = true;

    settings = {
      ports.dns = 53; # Port for incoming DNS Queries.
      upstreams.groups.default = [
        "https://one.one.one.one/dns-query" # Using Cloudflare's DNS over HTTPS server for resolving queries.
      ];
      # For initially solving DoH/DoT Requests when no system Resolver is available.
      bootstrapDns = {
        upstream = "https://one.one.one.one/dns-query";
        ips = ["1.1.1.1" "1.0.0.1"];
      };
      #Enable Blocking of certain domains.
      blocking = {
        denylists = {
          #Adblocking
          ads = ["https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"];
          #Another filter for blocking adult sites
          #adult = ["https://blocklistproject.github.io/Lists/porn.txt"];
          #You can add additional categories
        };
        #Configure what block categories are used
        clientGroupsBlock = {
          default = ["ads"];
          #kids-ipad = ["ads" "adult"];
        };
      }; # anything from config.yml
    };
  };
  #  services.dnsmasq = {
  #  enable = false;
  #  settings.servers = [ "9.9.9.9" "8.8.4.4" "1.1.1.1" ];
  #};
  # WiFi
  #inputs.raspberry-pi-nix.board = "bcm2711";
  hardware = {
    #    raspberry-pi.config.all = {
    #      # as per exaple: https://github.com/nix-community/raspberry-pi-nix/blob/aaec735faf81ff05356d65c7408136d2c1522d34/example/default.nix#L17C11-L32C13
    #      base-dt-params = {
    #        BOOT_UART = {
    #          value = 1;
    #          enable = true;
    #        };
    #        uart_2ndstage = {
    #          value = 1;
    #          enable = true;
    #        };
    #      };
    #      dt-overlays = {
    #        disable-bt = {
    #          enable = true;
    #          params = { };
    #        };
    #      };
    #    };
    bluetooth.enable = true;
    enableRedistributableFirmware = true;
    firmware = [pkgs.wireless-regdb];
  };
  # Networking - no need to punch a hole through router firewall
  networking = {
    #firewall = {
    #  allowedTCPPorts = [443 80 26656 22];
    #  allowPing = true;
    #};

    # useDHCP = true;
    interfaces.wlan0 = {
      useDHCP = false;
      ipv4.addresses = [
        {
          # I used static IP over WLAN because I want to use it as local DNS resolver
          address = "192.168.178.3";
          prefixLength = 24;
        }
      ];
    };
    interfaces.eth0 = {
      useDHCP = true;
      #useDHCP = false;
      # I used DHCP because sometimes I disconnect the LAN cable
      #ipv4.addresses = [{
      #  address = "192.168.173.3";
      #  prefixLength = 24;
      #}];
    };

    # Enabling WIFI
    #    wireless.enable = true;
    #    wireless.interfaces = [ "wlan0" ];
    # If you want to connect also via WIFI to your router
    # wireless.networks."SATRIA".psk = "wifipassword";
    # You can set default nameservers
    # nameservers = [ "192.168.100.3" "192.168.100.4" "192.168.100.1" ];
    # You can set default gateway
    # defaultGateway = {
    #  address = "192.168.1.1";
    #  interface = "eth0";
    # };
  };
  # forwarding
  #boot.kernel.sysctl = {
  #  "net.ipv4.conf.all.forwarding" = true;
  #  "net.ipv6.conf.all.forwarding" = true;
  #  "net.ipv4.tcp_ecn" = true;
  #};

  documentation.nixos.enable = false;
  boot.tmp.cleanOnBoot = true;
  virtualisation.docker.enable = true;

  fileSystems."/etc/ssh".neededForBoot = true;
  fileSystems."/nix/persist".neededForBoot = true;
  environment.persistence."/nix/persist/system" = {
    hideMounts = true;
    directories = [
      "/etc/nixos"
      "/etc/ssh" # for sops impermanence
      "/var/log"
      "/var/lib/bluetooth"
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
      {
        file = "/var/keys/secret_file";
        parentDirectory = {mode = "u=rwx,g=,o=";};
      }
    ];
  };
}
