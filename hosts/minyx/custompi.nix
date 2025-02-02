# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ inputs,config, lib, pkgs, ... }:
{
  imports =
    [ # Include the results of the hardware scan.
      ../common/minimal-desktop.nix
    ];
  # !!! Adding a swap file is optional, but strongly recommended!
  swapDevices = [{ device = "/swap"; }];
  # Use the extlinux boot loader. (NixOS wants to enable GRUB by default)
  # Enables the generation of /boot/extlinux/extlinux.conf
  # Disable ZFS on kernel 6
  boot.supportedFilesystems = lib.mkForce [
    "vfat"
    "xfs"
    "cifs"
    "ntfs"
  ];
  # A bunch of boot parameters needed for optimal runtime on RPi 3b+
  boot.kernelParams = ["cma=256M"];

  networking.hostName = "minyx"; # Define your hostname.
  # Pick only one of the below networking options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
   console = {
     font = "Lat2-Terminus16";
     keyMap = "us";
  #   useXkbConfig = true; # use xkb.options in tty.
   };

   environment.systemPackages = with pkgs; [
    neovim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    helix
    bind
    kubectl
    kubernetes-helm
    iptables
    openvpn
    python3
    nodejs
    docker-compose
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
        ips = [ "1.1.1.1" "1.0.0.1" ];
      };
      #Enable Blocking of certain domains.
      blocking = {
        denylists = {
          #Adblocking
          ads = ["https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"];
          #Another filter for blocking adult sites
          adult = ["https://blocklistproject.github.io/Lists/porn.txt"];
          #You can add additional categories
        };
        #Configure what block categories are used
        clientGroupsBlock = {
          default = [ "ads" ];
          kids-ipad = ["ads" "adult"];
        };
      };   # anything from config.yml
  };
};
    services.dnsmasq = {
    enable = false;
    settings.servers = [ "9.9.9.9" "8.8.4.4" "1.1.1.1" ];
  };
    # WiFi
  hardware = {
    enableRedistributableFirmware = true;
    firmware = [ pkgs.wireless-regdb ];
  };
  # Networking
  networking = {
    # useDHCP = true;
    interfaces.wlan0 = {
      useDHCP = false;
      ipv4.addresses = [{
        # I used static IP over WLAN because I want to use it as local DNS resolver
        address = "192.168.178.3";
        prefixLength = 24;
      }];
    };
    interfaces.eth0 = {
      useDHCP = true;
      # I used DHCP because sometimes I disconnect the LAN cable
      #ipv4.addresses = [{
      #  address = "192.168.100.3";
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
  boot.kernel.sysctl = {
    "net.ipv4.conf.all.forwarding" = true;
    "net.ipv6.conf.all.forwarding" = true;
    "net.ipv4.tcp_ecn" = true;
  };

  documentation.nixos.enable = false;
 # boot.tmp.cleanOnBoot = true;
  boot = {
  tmp.useTmpfs = true;
};
systemd.services.nix-daemon = {
  environment.TMPDIR = "/var/tmp";
};
}

