{ config, pkgs, lib, ... }:

{
  # ... your other config ...

  # Samba shares
  services.samba = {
    enable = true;
    securityType = "user";
    extraConfig = ''
      workgroup = WORKGROUP
      server string = ${config.networking.hostName}
      netbios name = ${config.networking.hostName}
      map to guest = bad user
      guest account = nobody
    '';
    shares = {
      "data" = {
        "path" = "/export/data";
        "browseable" = "yes";
        "read only" = "no";
        "guest ok" = "no";
        "create mask" = "0644";
        "directory mask" = "0755";
        "valid users" = "immich root";
      };
      "private" = {
        "path" = "/export/private";
        "browseable" = "yes";
        "read only" = "no";
        "guest ok" = "no";
        "create mask" = "0644";
        "directory mask" = "0755";
        "valid users" = "immich root";
      };
      "public" = {
        "path" = "/export/public";
        "browseable" = "yes";
        "read only" = "no";
        "guest ok" = "no";
        "create mask" = "0644";
        "directory mask" = "0755";
        "valid users" = "immich root";
      };
    };
  };

  # Samba RuntimeDirectory fix
  systemd.services.samba-smbd.serviceConfig.RuntimeDirectory = [ "lock" "lock/samba" ];
  systemd.services.samba-nmbd.serviceConfig.RuntimeDirectory = [ "lock" "lock/samba" ];
  systemd.services.samba-winbindd.serviceConfig.RuntimeDirectory = [ "lock" "lock/samba" ];

  # Samba WSDD
  services.samba-wsdd = {
    enable = true;
    openFirewall = true;
  };

  # NFS exports
  services.nfs.server = {
    enable = true;
    exports = ''
      /export 192.168.3.0/24(rw,fsid=0,no_subtree_check)
      /export/data 192.168.3.0/24(rw,async,no_wdelay,hide,crossmnt,no_subtree_check,insecure_locks,anonuid=1000,anongid=100,sec=sys,insecure,root_squash,all_squash)
      /export/private 192.168.3.0/24(rw,async,no_wdelay,hide,crossmnt,no_subtree_check,insecure_locks,anonuid=1000,anongid=100,sec=sys,insecure,root_squash,all_squash)
      /export/public 192.168.3.0/24(rw,async,no_wdelay,hide,crossmnt,no_subtree_check,insecure_locks,anonuid=1000,anongid=100,sec=sys,insecure,root_squash,all_squash)
      /export/data 100.64.0.0/10(rw,async,no_wdelay,hide,crossmnt,no_subtree_check,insecure_locks,anonuid=1000,anongid=100,sec=sys,insecure,root_squash,all_squash)
    '';
  };

  # BIND MOUNTS - THIS IS THE CRITICAL FIX
  fileSystems."/export/data" = {
    device = "/srv/data";
    options = [ "bind" ];
  };
  fileSystems."/export/private" = {
    device = "/srv/private";
    options = [ "bind" ];
  };
  fileSystems."/export/public" = {
    device = "/srv/public";
    options = [ "bind" ];
  };

  # Ensure directories exist
  systemd.tmpfiles.rules = [
    "d /srv/data 0755 root root -"
    "d /srv/private 0755 root root -"
    "d /srv/public 0755 root root -"
    "d /export 0755 root root -"
    "d /export/data 0755 root root -"
    "d /export/private 0755 root root -"
    "d /export/public 0755 root root -"
  ];

  # Firewall
  networking.firewall = {
    enable = true;
    allowPing = true;
    allowedTCPPorts = [ 445 139 2049 ];
    allowedUDPPorts = [ 137 138 ];
  };

  # Btrfs auto-scrub
  services.btrfs.autoScrub = {
    enable = true;
    interval = "monthly";
    fileSystems = [ "/" ];
  };

  # Networking
  networking.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
