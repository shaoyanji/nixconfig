# eisen — offline decision models (Laya), served beside the Qwen MoE LLM.
{
  config,
  lib,
  pkgs,
  ...
}: let
  user = import ../../modules/global/user.nix;

  port = 8090;
  root = "/mnt/storage/decision";
  venv = "${root}/laya";
  hfHome = "${root}/hf";
  # Written only by a bootstrap that ran to completion (see below).
  ready = "${root}/.laya-ready";

  python = pkgs.python312;
  # PyPI's manylinux torch wheel links libstdc++.so.6, which does not exist at
  # /usr/lib on NixOS. LD_LIBRARY_PATH keeps the fix host-local (no nix-ld).
  ccLib = pkgs.stdenv.cc.cc.lib;

  tc = config.services.tailscale.package;

  # See llm-server.nix: `after = tailscaled.service` only waits for the daemon
  # to start, not for the node to be Running, so serve would race a restart.
  waitForTailscale = pkgs.writeShellScript "wait-for-tailscale-running" ''
    set -eu
    for _ in $(seq 1 60); do
      if ${lib.getExe tc} status --json 2>/dev/null \
        | ${lib.getExe pkgs.jq} -e '.BackendState == "Running"' >/dev/null 2>&1; then
        exit 0
      fi
      sleep 2
    done
    echo "tailscaled backend not Running after 120s" >&2
    exit 1
  '';

  # Idle timeout for on-demand Laya (seconds). Matches llama-swap's ttl, so
  # the two serving paths go quiet on the same cadence.
  idleTimeout = 900;

  # Socket-activation wrapper for laya-serve.
  #
  # laya.serve.main() binds host:port itself and cannot take systemd's passed
  # socket, so this wrapper replicates it with one addition: when systemd
  # socket-activates the service (LISTEN_FDS >= 1), the pre-bound socket is
  # handed to uvicorn as fd 3 instead of binding :8090 again (which would fail
  # with EADDRINUSE — systemd already holds the listen socket).
  #
  # It also records the last served request (excluding /health) in
  # $RUNTIME_DIRECTORY/last-request; the idle timer uses its mtime to stop the
  # service after idleTimeout. The file is touched at startup too, so a service
  # that has not served yet is never stopped as "idle".
  layaWrapper = pkgs.writeTextFile {
    name = "laya-serve-wrapper";
    executable = true;
    destination = "/bin/laya-serve-wrapper";
    text = ''
      #!${venv}/bin/python
      import os
      import socket

      import uvicorn
      from uvicorn.protocols.http.auto import AutoHTTPProtocol


      class NoDelayHTTPProtocol(AutoHTTPProtocol):
          # Mirrors laya.serve.main: asyncio only sets TCP_NODELAY when the
          # accepted socket reports IPPROTO_TCP; on macOS/Windows it reports 0,
          # so Nagle delays small responses (uvicorn #620).
          def connection_made(self, transport):
              sock = transport.get_extra_info("socket")
              if sock is not None and sock.family in (socket.AF_INET, socket.AF_INET6):
                  try:
                      sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
                  except OSError:
                      pass  # a latency hint, never a reason to drop the connection
              super().connection_made(transport)


      def _touch(path):
          try:
              with open(path, "a"):
                  pass
          except OSError:
              pass


      def main():
          from laya.serve import create_app

          runtime_dir = os.environ.get("RUNTIME_DIRECTORY", "/run/laya-serve")
          last_request = os.path.join(runtime_dir, "last-request")
          _touch(last_request)

          app = create_app()

          @app.middleware("http")
          async def _record_request(request, call_next):
              # Health probes are not use: a monitoring poll must not keep the
              # service alive past the idle timeout.
              if request.url.path != "/health":
                  _touch(last_request)
              return await call_next(request)

          kwargs = {
              "log_level": os.environ.get("LAYA_LOG_LEVEL", "info"),
              "http": NoDelayHTTPProtocol,
          }
          if int(os.environ.get("LISTEN_FDS", "0")) >= 1:
              # systemd passed the listening socket as fd 3 (Accept=no).
              uvicorn.run(app, fd=3, **kwargs)
          else:
              uvicorn.run(
                  app,
                  host=os.environ.get("LAYA_HOST", "0.0.0.0"),
                  port=int(os.environ.get("LAYA_PORT", "8000")),
                  **kwargs,
              )


      if __name__ == "__main__":
          main()
    '';
  };

  # Idle check for the laya-serve-idle timer: stop the service when no request
  # has been served within idleTimeout. The socket stays listening, so the
  # next connection re-activates the service. A stop racing a just-arrived
  # request fails that one request cleanly (502 at the caller), and the next
  # request wakes Laya again.
  layaIdleCheck = pkgs.writeShellScript "laya-serve-idle-check" ''
    set -eu
    systemctl=${config.systemd.package}/bin/systemctl
    if ! "$systemctl" -q is-active laya-serve.service; then
      exit 0
    fi
    last="/run/laya-serve/last-request"
    if [ ! -f "$last" ]; then
      exit 0
    fi
    now=$(${pkgs.coreutils}/bin/date +%s)
    mtime=$(${pkgs.coreutils}/bin/stat -c %Y "$last")
    if [ $((now - mtime)) -ge ${toString idleTimeout} ]; then
      "$systemctl" stop laya-serve.service
    fi
  '';

  bootstrap = pkgs.writeShellScript "eisen-laya-bootstrap" ''
    set -euo pipefail
    # Needed even here: the verification import below loads torch.
    export LD_LIBRARY_PATH=${ccLib}/lib
    # The fleet default index (test.pypi.org) carries no real releases.
    export UV_INDEX_URL=https://pypi.org/simple
    export UV_DEFAULT_INDEX=https://pypi.org/simple
    export UV_PYTHON_DOWNLOADS=never
    # The venv is on /mnt/storage and uv's cache on the NVMe root, so
    # hardlinking across them is impossible; copy without the warning.
    export UV_LINK_MODE=copy
    # A systemd unit with User= does not set HOME, and uv locates its cache
    # through it.
    export HOME=${user.home}

    # Both the entry point and the readiness mark must be present, so an
    # install that dies part way through — or a venv someone deleted — is
    # rebuilt on the next boot rather than left wedged. Doing this as a plain
    # script instead of a systemd ConditionPathExists keeps the unit's exit
    # status meaningful to switch-to-configuration, which otherwise reports a
    # `condition failed` unit as a failed switch.
    if [ -x "${venv}/bin/laya-serve" ] && [ -f "${ready}" ]; then
      echo "laya venv already bootstrapped (${ready})"
      exit 0
    fi
    rm -f "${ready}"

    echo "building the laya venv from ${python}"
    ${pkgs.coreutils}/bin/rm -rf ${venv}
    ${lib.getExe pkgs.uv} venv ${venv} --python ${python}/bin/python3.12
    ${lib.getExe pkgs.uv} pip install \
      --python ${venv}/bin/python --torch-backend=cpu 'laya[serve]==0.4.1'
    # Record exactly what was resolved; the venv is not hermetic, so this is
    # the only way to reproduce or audit it after the fact.
    ${lib.getExe pkgs.uv} pip freeze --python ${venv}/bin/python \
      > ${root}/laya-requirements.lock
    # Proves the wheel actually loads — the first thing that breaks here is the
    # manylinux torch wheel linking a libstdc++ that NixOS does not ship.
    ${venv}/bin/python -c 'import laya, torch; print("laya", laya.__version__, "torch", torch.__version__)'
    ${pkgs.coreutils}/bin/touch "${ready}"
  '';
in {
  systemd.tmpfiles.rules = [
    "d ${root} 0755 ${user.name} users - -"
    "d ${hfHome} 0755 ${user.name} users - -"
  ];

  # --- One-time venv bootstrap (idempotent; the guard is in the script) -----
  # Requires the storage mount: without it `mkdir -p /mnt/storage/decision`
  # would silently create a masking directory on the NVMe root and install the
  # venv there, shadowed as soon as the real array mounts.
  systemd.services."eisen-laya-bootstrap" = {
    description = "Bootstrap Laya's uv venv on /mnt/storage";
    after = ["mnt-storage.mount" "network-online.target"];
    requires = ["mnt-storage.mount"];
    wants = ["network-online.target"];
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = user.name;
      ExecStart = bootstrap;
    };
  };

  # --- The decision-model server: on-demand via socket activation -----------
  # laya-serve is NOT started at boot. systemd holds :8090 (laya-serve.socket);
  # the first connection activates the service, whose wrapper hands systemd's
  # socket to uvicorn. The idle timer stops the service after idleTimeout with
  # no served request, freeing the ~3.5 GiB RSS; the socket keeps listening,
  # so the next request wakes it again. Nothing may `want` laya-serve — the
  # router and tailscale-serve-laya deliberately do not — or boot would pull
  # it up and defeat on-demand. Cold start (model load) is on the first
  # request's path; the router's 25 s decision timeout may 502 that one
  # request — measure cold-start latency during activation testing.
  systemd.sockets."laya-serve" = {
    description = "Laya decision model socket (on-demand activation)";
    wantedBy = ["sockets.target"];
    socketConfig = {
      ListenStream = "127.0.0.1:${toString port}";
      Accept = false;
    };
  };

  systemd.services."laya-serve" = {
    description = "Laya decision model (Jev-compatible /v1/systemone)";
    after = ["eisen-laya-bootstrap.service" "mnt-storage.mount"];
    wants = ["eisen-laya-bootstrap.service"];
    requires = ["mnt-storage.mount" "laya-serve.socket"];
    # No wantedBy: the socket activates this on first connection.
    environment = {
      LAYA_HOST = "127.0.0.1";
      LAYA_PORT = toString port;
      LAYA_DEVICE = "cpu";
      LAYA_PRELOAD = "1";
      # Keep english + multilingual resident; typed-decisions stays lazy and is
      # routed to on demand by LAYA_AUTO_TASK when question ids match it.
      LAYA_MODELS = "english,multilingual";
      LAYA_AUTO_TASK = "1";
      # 12 = the Xeon's physical core count. Being conservative here costs
      # real latency (8 threads 0.56 s, 4 threads 0.98 s vs 0.43 s), and the
      # calls are short enough that a game's scheduler never starves.
      LAYA_THREADS = "12";
      HF_HOME = hfHome;
      HF_HUB_DISABLE_TELEMETRY = "1";
      # transformers probes for TensorFlow at import and its abseil runtime can
      # deadlock model construction, so keep TF off.
      USE_TF = "0";
      LD_LIBRARY_PATH = "${ccLib}/lib";
    };
    serviceConfig = {
      Type = "exec";
      User = user.name;
      WorkingDirectory = root;
      ExecStart = "${layaWrapper}/bin/laya-serve-wrapper";
      Restart = "always";
      RestartSec = 5;
      # First boot downloads ~1.5 GiB of checkpoints from the Hub.
      TimeoutStartSec = 600;
      # Holds the last-request record the idle timer reads.
      RuntimeDirectory = "laya-serve";
    };
  };

  # --- Idle stop: free the ~3.5 GiB after idleTimeout with no request -------
  systemd.services."laya-serve-idle" = {
    description = "Stop Laya if idle past the timeout";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = layaIdleCheck;
    };
  };

  systemd.timers."laya-serve-idle" = {
    description = "Stop Laya after the idle timeout";
    wantedBy = ["timers.target"];
    timerConfig = {
      OnBootSec = "5min";
      OnUnitActiveSec = "5min";
      Unit = "laya-serve-idle.service";
    };
  };

  # --- LAN: plain http://laya.lan/v1/systemone (nginx :80 -> :8090) ---------
  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    virtualHosts."laya.lan" = {
      serverAliases = ["laya"];
      listen = [
        {
          addr = "0.0.0.0";
          port = 80;
        }
      ];
      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString port}";
        extraConfig = ''
          # A batch of up to 64 states is answered in one forward pass; give it
          # more than the 60 s proxy default.
          proxy_read_timeout 300s;
          proxy_send_timeout 300s;
          client_max_body_size 0;
        '';
      };
    };
  };

  # --- Tailnet: https://eisen.<tailnet>.ts.net:8443/v1/systemone -----------
  # A second listener on the same node name as the LLM's :443 (llm-server.nix);
  # the two coexist in the serve config. `--https=<port>` is a node serve, not
  # the `svc:` form, so it needs no admin-console preview toggle.
  systemd.services."tailscale-serve-laya" = {
    description = "Serve Laya on the node's tailnet HTTPS name (:8443)";
    after = [
      "tailscaled.service"
      "tailscaled-autoconnect.service"
      "laya-serve.service"
    ];
    wants = [
      "tailscaled.service"
      # Deliberately NOT laya-serve: wanting it would start Laya at boot and
      # defeat on-demand. `tailscale serve` proxies to :8090 regardless; a
      # request through it activates Laya via the socket.
    ];
    wantedBy = ["multi-user.target"];
    partOf = ["tailscaled.service"];
    unitConfig = {
      StartLimitIntervalSec = 300;
      StartLimitBurst = 30;
    };
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStartPre = waitForTailscale;
      ExecStart = "${lib.getExe tc} serve --bg --https=8443 http://127.0.0.1:${toString port}";
    };
  };

  # :80 is declared by llm-server.nix too; the list merges. Port 8090 is
  # deliberately absent — it is loopback-only by design.
  networking.firewall.allowedTCPPorts = [80];
}
