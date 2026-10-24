# Atuin history server: one sync target for every shell that runs atuin. nixpkgs
# ships the server and its postgres wiring; this module is the deployment —
# loopback listener, nginx in front, no second firewall hole.
{
  config,
  lib,
  ...
}: let
  cfg = config.services.atuin-server;
in {
  options.services.atuin-server = {
    enable = lib.mkEnableOption "the atuin shell-history sync server";

    port = lib.mkOption {
      type = lib.types.port;
      default = 8888;
      description = "Loopback port the sync server listens on.";
    };

    openRegistration = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Accept `atuin register` from anyone who can reach the vhost. Turned on
        for the first account and back off afterwards: there is no admin UI, and
        a registration left open is an account on a history database.
      '';
    };

    vhost = lib.mkOption {
      type = lib.types.str;
      default = "atuin.frieren.lan";
      description = "nginx server name that fronts the sync server.";
    };

    serverAliases = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Extra names the same vhost answers to.";
    };

    maxHistoryLength = lib.mkOption {
      type = lib.types.int;
      default = 32768;
      description = ''
        Longest command line the server stores. The nixpkgs default is 8192,
        which silently truncates the pasted certificates and one-liners that are
        the reason to search history at all.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.atuin = {
      enable = true;
      # Loopback only: the LAN and the tailnet reach it through nginx on :80,
      # which this host already serves.
      host = "127.0.0.1";
      inherit (cfg) port openRegistration maxHistoryLength;
    };

    services.nginx.virtualHosts.${cfg.vhost} = {
      inherit (cfg) serverAliases;
      listen = [
        {
          addr = "0.0.0.0";
          port = 80;
        }
      ];
      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString cfg.port}";
        extraConfig = ''
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          # History arrives in batches; buffering them just delays the ack that
          # the client waits for before it stops retrying.
          proxy_buffering off;
          client_max_body_size 4m;
        '';
      };
    };
  };
}
