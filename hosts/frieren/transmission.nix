# Transmission — leech-only BitTorrent client for open-access content.
#
# Scope: this host only ever *downloads*. It is not a seedbox. The policy is
# enforced in `settings` (not by trusting the UI):
#
#   * Leech-only stop: `ratio-limit = 0` + `ratio-limit-enabled = true`. In
#     Transmission 4.1.3 `effective_seed_ratio()` returns `0.0`, so the seed
#     goal is `size_when_done * 0 = 0` bytes and is met the instant the torrent
#     finishes; the ratio check only ever runs for seeds (`seed_ratio_applies =
#     is_done()`), so it never interrupts a download.
#   * Upload capped at 1 kB/s (the protocol floor — 0 would mean *unlimited*)
#     plus a single upload slot, so the swarm gets handshakes and no bulk data.
#   * DHT/PEX/LPD off and no UPnP/NAT-PMP: the client never advertises itself to
#     the public swarm nor asks the router to open an inbound port.
#   * `openPeerPorts = false`: no inbound peer connections at all.
#
# RPC binds loopback only; the `torrent.frieren.lan` vhost in reverse-proxy.nix
# is the sole reachable front end. Deliberately NOT a `profiles.serviceExposure`
# entry — that would open a raw LAN port with only a loopback listener behind it
# (the REDUNDANT class `checks:ports` flags).
#
# State lives on the dedicated btrfs subvolume /var/lib/transmission. Downloads
# land in the shared /srv/data/downloads staging area (same 2TB pool), so the
# `transmission` service user is added to `users` to write the aria2:users 0775
# directory. Per-torrent locations can still be overridden in the web UI.
#
# Where finished downloads belong (ISOs -> isos/, papers -> books/, video ->
# arr/, installers -> software/) is defined in docs/download-taxonomy.md.
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
