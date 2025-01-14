# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, lib, pkgs, ... }:
{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Use the extlinux boot loader. (NixOS wants to enable GRUB by default)
  # Enables the generation of /boot/extlinux/extlinux.conf
   boot.kernelPackages = pkgs.linuxPackages_latest;

  # A bunch of boot parameters needed for optimal runtime on RPi 3b+
  boot.kernelParams = ["cma=256M"];
  networking.hostName = "minyx"; # Define your hostname.
  # Pick only one of the below networking options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
   networking.networkmanager.enable = true;  # Easiest to use and most distros use this by default.

  # Set your time zone.
   time.timeZone = "Europe/Berlin";

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Select internationalisation properties.
   i18n.defaultLocale = "en_US.UTF-8";
   console = {
     font = "Lat2-Terminus16";
     keyMap = "us";
  #   useXkbConfig = true; # use xkb.options in tty.
   };

  # Configure keymap in X11
   services.xserver.xkb.layout = "us";
  # services.xserver.xkb.options = "eurosign:e,caps:escape";

  # Enable CUPS to print documents.
   services.printing.enable = true;

   services.pipewire = {
     enable = true;
     pulse.enable = true;
   };


   users.users.devji= {
home = "/home/devji";
     isNormalUser = true;
     extraGroups = [ "wheel" "networkmanager" ]; # Enable ‘sudo’ for the user.
openssh.authorizedKeys.keys = [
	"ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMEvIBjy85SIOMbk9WCY/jSrKiXcJ8aA4xqvMKC1b4aH jisifu@gmail.com"
"ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKVYLgws2TgaYIsOmVmJeoJIu9F8lguBXi711Kv90jaM devji@poseidon"
"ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOD4PopDAxzh1t4nNnDE/xiWLGYzopLRzZ7eBwd4hHza devji@schneeeule"
];
hashedPassword="$6$.MwUydqIuXNoHXxy$8N0tM2mWOStiuDEkDw/wBCwg73PTKGY24G7huRi3gn0GJPW.o9d4eEseTmB7KXxlOtUG06fNgQwTmEkAYkS.a."; 

};
   environment.systemPackages = with pkgs; [
    neovim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    curl
    git
    wget
   ];
#  fileSystems."/mnt/w" = {
#    device = "192.168.178.4:/volume1/peachcable";
#    fsType = "nfs";
#    options = [ "x-systemd.automount" "noauto" "x-systemd.after=network-online.target" "x-systemd.mount-timeout=30" ];
#  };
  documentation.nixos.enable = false;
  boot.tmp.cleanOnBoot = true;
  # Configure basic SSH access
  services.openssh.enable = true;
  services.openssh.settings.PermitRootLogin= "yes";
  # Enable the OpenSSH daemon.
   security.sudo.wheelNeedsPassword = false;
}

