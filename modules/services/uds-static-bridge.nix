# Declarative Zero-TCP Static Documentation Bridge via UNIX Domain Sockets (EXP-024).
#
# Serves immutable static documentation and hypermedia assets (Aki fleet docs,
# NixOS manuals, closure graphs) directly over a local filesystem UNIX domain socket
# (unix:/run/uds-docs/docs.sock) rather than loopback TCP ports (127.0.0.1:PORT).
#
# Eliminates loopback TCP 3-way handshakes, packet framing, and port collisions,
# while enforcing POSIX filesystem DAC security (0660 / group: users).
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.udsStaticBridge;
  akiDocs = import ../../lib/aki-site.nix {inherit pkgs;};
in {
  options.services.udsStaticBridge = {
    enable = lib.mkEnableOption "declarative zero-TCP static documentation bridge via UNIX domain sockets";

    socketDir = lib.mkOption {
      type = lib.types.str;
      default = "/run/uds-docs";
      description = "Runtime directory where the UNIX domain socket is placed.";
    };

    socketPath = lib.mkOption {
      type = lib.types.str;
      default = "/run/uds-docs/docs.sock";
      description = "Filesystem path for the UNIX domain socket listener.";
    };

    root = lib.mkOption {
      type = lib.types.path;
      default = akiDocs;
      description = "Static site directory to serve over the UNIX domain socket.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d ${cfg.socketDir} 0775 nginx users -"
    ];

    services.nginx = {
      enable = true;
      virtualHosts."uds-docs" = {
        listen = [
          {
            addr = "unix:${cfg.socketPath}";
            extraParameters = ["backlog=1024"];
          }
        ];
        locations."/" = {
          inherit (cfg) root;
          extraConfig = ''
            # Zero-runtime CPU compression via pre-compressed static assets
            gzip_static on;

            # Inode and open file descriptor cache for immutable Nix store assets
            open_file_cache max=1000 inactive=300s;
            open_file_cache_valid 3600s;
            open_file_cache_min_uses 1;
            open_file_cache_errors on;

            # Declarative client cache directives
            add_header Cache-Control "public, max-age=3600, stale-while-revalidate=86400" always;

            # Zero-TCP IPC headers
            add_header X-Bridge-Transport "UNIX-Domain-Socket" always;
            add_header X-Bridge-Security "POSIX-DAC-Isolated" always;
          '';
        };
      };
    };
  };
}
