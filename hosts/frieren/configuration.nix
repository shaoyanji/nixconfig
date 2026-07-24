# NAS server — migrating from thinsandy.
# Stage: NAS-first (DNS, media, Paperless, tools, Docker, aria2).
# AI services (ZeroClaw, NullClaw) stay on thinsandy for now.
# NFS/Samba will be ported from thinsandy's hardware-configuration.nix
# after the 2TB data drive is physically moved.
{ config
, lib
, pkgs
, ...
}: {
  imports = [
    ./hardware-configuration.nix
    ./hardware.nix
    ../../modules/profiles/base-node.nix
    ../../modules/profiles/server-hardening.nix
    ../../modules/profiles/laptop.nix
    ../../hosts/thinsandy/dns.nix
    ../../hosts/thinsandy/media-stack.nix
    ../../hosts/thinsandy/paperless.nix
    ../../hosts/thinsandy/tools.nix
    ../../hosts/thinsandy/networking.nix
    ../../modules/services/aria2-daemon.nix
  ];

  networking.hostName = "frieren";

  # Server hardening — journald caps, tmp cleanup, /var relocation.
  # /srv/private paths will overlay correctly once the 2TB drive is mounted.
  profiles.serverHardening = {
    enable = true;
    varLogDevice = "/srv/private/var-log";
    varCacheDevice = "/srv/private/var-cache";
  };

  # --- SOPS secrets ---
  # IMPORTANT: Before first deploy, add frieren's host SSH age key to .sops.yaml
  #   ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub
  # Then rekey secrets:
  #   task infra:sops:update-keys

  sops.secrets."aria2-rpc-secret" = {
    owner = "aria2";
    group = "aria2";
    mode = "0400";
  };

  services.aria2-daemon = {
    enable = true;
    downloadDir = "/srv/data/downloads";
    rpcHost = "0.0.0.0";
    rpcSecretFile = config.sops.secrets."aria2-rpc-secret".path;
    nginx.enable = true;
    nginx.listenPort = 6801;
  };

  # --- Firewall (extends firewall-baseline from base-node) ---
  networking.firewall.allowedTCPPorts = [
    8123 # HomeAssistant
    7351 # Stirling PDF
    6801 # AriaNg web UI
    28981 # Paperless-ngx
    445  # SMB
    139  # SMB NetBIOS session
    2049 # NFS
  ];
  networking.firewall.allowedUDPPorts = [
    137 # SMB NetBIOS name service
    138 # SMB NetBIOS datagram
  ];

  # --- Per-NIC overrides for thinsandy/dns.nix imports ---
  # thinsandy pins pihole to eno1 + a tailscale0 dnsmasq line. Frieren's wired
  # NIC is enp1s0 and tailscale0 only appears after `tailscale up`. Force the
  # overrides so unit eval resolves against our real interfaces instead of
  # thinsandy's, and add an enp1s0 firewall rule for DNS on frieren's NIC.
  services.pihole-ftl.settings.dns.interface = lib.mkForce "enp1s0";
  services.pihole-ftl.settings.misc.dnsmasq_lines = lib.mkForce [];
  networking.firewall.interfaces.eno1 = lib.mkForce {};
  networking.firewall.interfaces.enp1s0 = {
    allowedUDPPorts = [ 53 ];
    allowedTCPPorts = [ 53 ];
  };

  # --- Laptop-as-server: lid-close behavior & low-power tuning ---
  # Don't suspend when the lid closes — this is a server.
  # consoleblank=60: kernel blanks the virtual console after 60s idle (saves backlight).
  # auto-cpufreq (laptop.nix) and powertop (hardware.nix) handle CPU power states.
  services.logind.settings.Login = {
    HandleLidSwitch = "ignore";
    HandleLidSwitchExternalPower = "ignore";
    HandleLidSwitchDocked = "ignore";
  };
  boot.kernelParams = [ "consoleblank=60" ];

  # --- TODO: After 2TB data drive migration from thinsandy ---
  #
  # Drive layout principle: OS stays on 1TB SSHD, services/data live on 2TB.
  # /nix, /home, / (root), /boot, /.snapshots → already on 1TB SSHD (no changes).
  # /srv/{data,public,private} → 2TB drive btrfs subvolumes (to be added).
  #
  # 1. Add btrfs subvolume mounts to hardware-configuration.nix:
  #    /srv/data, /srv/public, /srv/private, /var/lib/transmission, /swap
  #    (NOTE: /nix stays on the 1TB SSHD — no split-brain like thinsandy had)
  #
  # 2. Add bind mounts needed by media services (from thinsandy/hardware-configuration.nix):
  #    /var/lib/immich → /srv/public/immich
  #    /media → /export/data/media (unified Jellyfin/Plex path)
  #    /export/data → /srv/data (NFS export root)
  #    /export/public → /srv/public
  #    /export/private → /srv/private
  #
  # 3. Port NFS exports + Samba config from thinsandy/hardware-configuration.nix.
  #    Update NIC name (eno1 on thinsandy → check frieren's interface name).
  #
  # 4. Port samba-wsdd + btrfs autoScrub from thinsandy.
  #
  # 5. Add firewall ports: 445, 139, 2049 TCP; 137, 138 UDP
  #
  # 6. Service data directories on the 2TB drive (services will fail until mounted):
  #    Jellyfin:  /srv/private/jellyfin
  #    Plex:      /srv/private/plex
  #    Home Asst: /srv/private/home-assistant
  #    Paperless: /srv/data/paperless → bind to /var/lib/paperless
  #    aria2:     /srv/data/downloads
  #    Immich:    /srv/public/immich → bind to /var/lib/immich

  # --- Tailscale: ensure daemon + `tailscale up` survive reboots ---
  # thinsandy/dns.nix already sets services.tailscale.enable = true and orders
  # tailscaled after network-online. Here we force-enable it at boot and add a
  # one-shot tailscale-up service so reboots don't require manual re-auth.
  # First-time interactive login still happens locally; afterwards
  # /var/lib/tailscale/ caches the auth state.
  systemd.services.tailscaled = {
    wantedBy = lib.mkForce [ "multi-user.target" ];
    after    = lib.mkForce [ "network-online.target" ];
    wants    = lib.mkForce [ "network-online.target" ];
  };
  systemd.services.tailscale-up = {
    wantedBy = [ "multi-user.target" ];
    after    = [ "tailscaled.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.tailscale}/bin/tailscale up --accept-dns=false --operator=devji";
    };
  };

  # --- NAS sharing: SMB + NFS + WSDD + btrfs autoScrub ---
  # Mirrors the export shape that lives in hosts/thinsandy/hardware-configuration.nix
  # on thinsandy. Frieren takes over the NAS role at 192.168.3.25 — keep share
  # names identical so existing clients keep working without re-mount.
  services.samba = {
    enable = true;
    openFirewall = true;
    settings = {
      global = {
        "workgroup" = "WORKGROUP";
        "server string" = "frieren";
        "netbios name" = "frieren";
        "security" = "user";
      };
      "data" = {
        path = "/export/data";
        browseable = "yes";
        "read only" = "no";
        "guest ok" = "yes";
        "create mask" = "0644";
        "directory mask" = "0755";
      };
      "private" = {
        path = "/export/private";
        browseable = "yes";
        "read only" = "no";
        "guest ok" = "no";
        "create mask" = "0644";
        "directory mask" = "0755";
      };
      "public" = {
        path = "/export/public";
        browseable = "yes";
        "read only" = "no";
        "guest ok" = "no";
        "create mask" = "0644";
        "directory mask" = "0755";
      };
    };
  };

  # samba RuntimeDirectory lock-path fix — smbd/nmbd/winbindd need /run/lock/samba
  # to exist before start. Mirrors thinsandy commit that fixed the post-reboot crash.
  systemd.services.samba-smbd.serviceConfig.RuntimeDirectory     = [ "lock" "lock/samba" ];
  systemd.services.samba-nmbd.serviceConfig.RuntimeDirectory     = [ "lock" "lock/samba" ];
  systemd.services.samba-winbindd.serviceConfig.RuntimeDirectory = [ "lock" "lock/samba" ];

  services.samba-wsdd = {
    enable = true;
    openFirewall = true;
  };

  services.nfs.server = {
    enable = true;
    exports = ''
      /export 192.168.3.0/24(rw,fsid=0,no_subtree_check)
      /export/data 192.168.3.0/24(rw,async,no_wdelay,hide,crossmnt,no_subtree_check,insecure_locks,anonuid=1000,anongid=100,sec=sys,insecure,root_squash,all_squash)
      /export/private 192.168.3.0/24(rw,async,no_wdelay,hide,crossmnt,no_subtree_check,insecure_locks,anonuid=1000,anongid=100,sec=sys,insecure,root_squash,all_squash)
      /export/public 192.168.3.0/24(rw,async,no_wdelay,hide,crossmnt,no_subtree_check,insecure_locks,anonuid=1000,anongid=100,sec=sys,insecure,root_squash,all_squash)
    '';
  };

  services.btrfs.autoScrub = {
    enable = true;
    interval = "monthly";
    fileSystems = [ "/" "/srv/data" "/srv/private" "/srv/public" ];
  };

  # --- Jellyfin: ensure /srv/private/jellyfin exists pre-start ---
  # nixpkgs sets WorkingDirectory = dataDir = /srv/private/jellyfin. If the
  # @private btrfs subvol on the 2TB drive didn't ship with the jellyfin/ dir,
  # chdir() at start fails with status 200/CHDIR. tmpfiles creates it
  # idempotently before the unit activates.
  systemd.tmpfiles.rules = [
    "d /srv/private/jellyfin 0755 jellyfin jellyfin -"
  ];

  system.stateVersion = "26.05";
}
