# NAS server — migrating from thinsandy.
# Stage: NAS-first (DNS, media, Paperless, tools, Docker, aria2).
# AI services (ZeroClaw, NullClaw) stay on thinsandy for now.
# NFS/Samba will be ported from thinsandy's hardware-configuration.nix
# after the 2TB data drive is physically moved.
{ config
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
  # NOTE: NFS (2049) + Samba (445,139,137,138) will be added after drive migration.
  networking.firewall.allowedTCPPorts = [
    8123 # HomeAssistant
    7351 # Stirling PDF
    6801 # AriaNg web UI
    28981 # Paperless-ngx
  ];

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

  system.stateVersion = "26.05";
}
