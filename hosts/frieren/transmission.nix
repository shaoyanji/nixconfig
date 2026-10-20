# Transmission — leech-only BitTorrent client for open-access content.
{
  services.transmission = {
    enable = true;
    home = "/var/lib/transmission";

    # No inbound peers, no router hole.
    openRPCPort = false;
    openPeerPorts = false;

    settings = {
      # --- Storage ---------------------------------------------------------
      download-dir = "/srv/data/downloads";
      incomplete-dir-enabled = false;
      rename-partial-files = true;
      umask = "002";

      # --- Leech-only: stop the instant a download completes ---------------
      ratio-limit-enabled = true;
      ratio-limit = 0;
      idle-seeding-limit-enabled = true;
      idle-seeding-limit = 1;

      # --- Near-zero upstream (protocol floor; avoids peer choking) --------
      speed-limit-up-enabled = true;
      speed-limit-up = 1;
      upload-slots-per-torrent = 1;

      # --- Stay off the public swarm; require encrypted peers --------------
      dht-enabled = false;
      pex-enabled = false;
      lpd-enabled = false;
      port-forwarding-enabled = false;
      encryption = 2;

      # --- RPC: loopback only, fronted by nginx ----------------------------
      rpc-bind-address = "127.0.0.1";
      rpc-port = 9091;
      rpc-authentication-required = false;
      rpc-whitelist-enabled = false;
      # Transmission 4 enables the host-header whitelist by default with an
      # EMPTY list, so every request whose Host is not `localhost` gets 421
      # Misdirected Request — which is what the torrent.frieren.lan vhost sent.
      # The RPC is loopback-only and has no auth, so the host check adds nothing.
      rpc-host-whitelist-enabled = false;
    };
  };

  # /srv/data/downloads is 0775 aria2:users — let the torrent daemon write it.
  users.users.transmission.extraGroups = ["users"];
}
