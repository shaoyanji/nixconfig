# qwen-tts — offline Qwen3-TTS text-to-speech served over OpenAI-compatible HTTP.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.qwen-tts;
  inherit
    (lib)
    mkEnableOption
    mkIf
    mkOption
    optionalString
    types
    ;

  # --- The runtime, built from source with the Vulkan backend ----------------
  #
  # PIN ME: `nix-prefetch-git --fetch-submodules https://github.com/ServeurpersoCom/qwentts.cpp.git`
  # then drop the rev + hash below. `lib.fakeHash` fails the build on purpose
  # until this is done, so an unpinned build can never silently ship.
  qwentts = pkgs.stdenv.mkDerivation {
    pname = "qwentts.cpp";
    version = "unstable-2026-09-09";

    src = pkgs.fetchgit {
      url = "https://github.com/ServeurpersoCom/qwentts.cpp.git";
      rev = "01b6127c2aabbb890e416af96f8c512d898440cb";
      hash = "sha256-scZD8RxeJ+Wk1+94REnKQ6YFTLoN3L1+dymIqy9HAvg=";
      # Vendors ggml; without this the build has no ggml sources.
      fetchSubmodules = true;
    };

    nativeBuildInputs = with pkgs; [
      cmake
      ninja
      pkg-config
      shaderc # provides glslc, needed to compile the Vulkan shaders
    ];
    buildInputs = with pkgs; [
      vulkan-headers
      vulkan-loader
    ];

    # Upstream's buildvulkan.sh is a thin cmake wrapper; reproduce it directly
    # so the derivation stays auditable. GGML_VULKAN=ON is the whole point.
    cmakeFlags = [
      "-DCMAKE_BUILD_TYPE=Release"
      "-DGGML_VULKAN=ON"
      "-DQWEN_SHARED=OFF"
      "-DCMAKE_SKIP_BUILD_RPATH=ON"
      "-DCMAKE_BUILD_WITH_INSTALL_RPATH=ON"
      "-DCMAKE_INSTALL_RPATH=${placeholder "out"}/lib"
    ];

    # Upstream has no install target for the CLIs; place them explicitly.
    installPhase = ''
      runHook preInstall
      install -Dm755 qwen-tts -t $out/bin
      install -Dm755 tts-server -t $out/bin
      install -Dm755 qwen-codec -t $out/bin
      install -Dm755 quantize -t $out/bin
      mkdir -p $out/lib
      cp -d libggml* $out/lib/ 2>/dev/null || true
      runHook postInstall
    '';

    preFixup = ''
      for f in $out/bin/* $out/lib/*; do
        if [ -f "$f" ] && [ -x "$f" ]; then
          patchelf --shrink-rpath --allowed-rpath-prefixes "/nix/store" "$f" 2>/dev/null || true
        fi
      done
    '';

    meta = {
      description = "Qwen3-TTS local inference (GGML, Vulkan)";
      homepage = "https://github.com/ServeurpersoCom/qwentts.cpp";
      license = lib.licenses.mit;
      mainProgram = "tts-server";
    };
  };

  runtime =
    if cfg.package != null
    then cfg.package
    else qwentts;

  talker = "${cfg.modelDir}/${cfg.model}";
  codec = "${cfg.modelDir}/${cfg.codec}";
  backend = "127.0.0.1:${toString cfg.backendPort}";

  # Both GGUFs must be present before the server will start.
  modelUrl = "https://huggingface.co/${cfg.hfRepo}/resolve/main";

  # Idempotent, resumable weight fetch — runs only when the GGUF is absent, so
  # boot is never blocked on a multi-GB download (same shape as
  # llm-server.nix's eisen-llm-* units).
  mkFetch = name: file: url: {
    description = "Fetch ${name} if missing";
    after = ["network-online.target" "mnt-storage.mount"];
    wants = ["network-online.target"];
    requires = ["mnt-storage.mount"];
    unitConfig.ConditionPathExists = "!${file}";
    # Fetch at boot, not on the first request: a missing weight download on
    # the request path would make the cold start minutes long. No-op when the
    # file already exists.
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "fetch-${name}" ''
        set -euo pipefail
        ${pkgs.coreutils}/bin/echo "Fetching ${url}"
        ${pkgs.curl}/bin/curl -fL --retry 5 --retry-delay 5 -C - \
          -o "${file}.part" "${url}"
        ${pkgs.coreutils}/bin/mv -f "${file}.part" "${file}"
      '';
    };
  };

  # --- Optional bearer auth ------------------------------------------------
  #
  # The runtime's server has no auth of its own. When apiKeyFile is set we
  # enforce `Authorization: Bearer <key>` in nginx: preStart renders a `map`
  # include from the secret file, and the vhost rejects unauthenticated
  # requests. When it is unset the LAN + tailnet are the auth boundary, matching
  # the LLM and decision-model endpoints.
  authEnabled = cfg.apiKeyFile != null;
  authInclude = "/run/qwen-tts/auth.conf";
in {
  options.services.qwen-tts = {
    enable = mkEnableOption "the Qwen3-TTS OpenAI-compatible speech server";

    port = mkOption {
      type = types.port;
      default = 8181;
      description = ''
        Loopback port systemd listens on (the socket-activation front door).
        This is the port nginx and `tailscale serve` point at; the model server
        itself binds {option}`backendPort`.
      '';
    };

    backendPort = mkOption {
      type = types.port;
      default = 8182;
      description = ''
        Loopback port the tts-server itself binds, behind the socket proxy.
        Never exposed; only `port` is proxied to clients.
      '';
    };

    idleTimeout = mkOption {
      type = types.int;
      default = 900;
      description = ''
        Seconds without an open connection before the socket proxy exits and
        the model server is stopped, releasing its memory. Matches the Laya and
        Qwen-Image idle timeouts.
      '';
    };

    modelDir = mkOption {
      type = types.path;
      default = "/mnt/storage/tts/models";
      description = ''
        Directory holding the talker + tokenizer GGUFs. Kept on the data array
        (like the Qwen and Laya weights) rather than a StateDirectory, because
        the files are multi-GB and should not land on the NVMe root.
      '';
    };

    model = mkOption {
      type = types.str;
      default = "qwen-talker-1.7b-customvoice-Q4_K_M.gguf";
      description = "Talker GGUF filename within {option}`modelDir`. Q4_K_M fits 8 GB VRAM.";
    };

    codec = mkOption {
      type = types.str;
      default = "qwen-tokenizer-12hz-Q8_0.gguf";
      description = "Shared tokenizer/codec GGUF filename within {option}`modelDir`.";
    };

    hfRepo = mkOption {
      type = types.str;
      default = "Serveurperso/Qwen3-TTS-GGUF";
      description = "Hugging Face repo the GGUFs are fetched from.";
    };

    alias = mkOption {
      type = types.str;
      default = "qwen3-tts";
      description = "Model name the server advertises.";
    };

    voice = mkOption {
      type = types.str;
      default = "vivian";
      description = ''
        Default named speaker for the customvoice checkpoint, advertised to
        clients. One of: serena, vivian, uncle_fu, ryan, aiden, ono_anna,
        sohee, eric, dylan. The `tts-server` chooses the voice per request (the
        body's `voice` field), so this is the deployment default rather than a
        server flag — no `--speaker` is passed, as the server does not accept it.
      '';
    };

    apiKeyFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = ''
        Optional file containing a bearer token (read by nginx, never by the
        model). Unset = the LAN/tailnet is the trust boundary.
      '';
    };

    extraArgs = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Extra flags appended to the tts-server command line.";
    };

    package = mkOption {
      type = types.nullOr types.package;
      default = null;
      description = "Override the qwentts.cpp package (defaults to the in-module Vulkan build).";
    };
  };

  config = mkIf cfg.enable {
    # --- Dedicated system user with GPU access ------------------------------
    users.groups.qwen-tts = {};
    users.users.qwen-tts = {
      isSystemUser = true;
      group = "qwen-tts";
      extraGroups = ["video" "render"];
    };

    # Weights on the data array; small runtime state (cloned-voice registry)
    # under StateDirectory, which is also where the server is chdir'd.
    systemd.tmpfiles.rules = [
      "d ${cfg.modelDir} 0755 qwen-tts qwen-tts - -"
    ];

    systemd.services."qwen-tts-models-talker" = mkFetch "qwen-tts-talker" talker "${modelUrl}/${cfg.model}";
    systemd.services."qwen-tts-models-codec" = mkFetch "qwen-tts-codec" codec "${modelUrl}/${cfg.codec}";

    # --- The speech server ---------------------------------------------------
    systemd.services.qwen-tts = {
      unitConfig.X-Fleet-Role = "daemon";
      description = "Qwen3-TTS speech server (OpenAI-compatible)";
      after = [
        "qwen-tts-models-talker.service"
        "qwen-tts-models-codec.service"
        "mnt-storage.mount"
      ];
      wants = [
        "qwen-tts-models-talker.service"
        "qwen-tts-models-codec.service"
      ];
      requires = ["mnt-storage.mount"];
      # No wantedBy: qwen-tts.socket activates this through qwen-tts-proxy on
      # the first connection. Starting it at boot is exactly the 3.8 GiB of
      # idle RSS this module used to hold.

      environment = {
        # Force the GPU path — otherwise ggml silently falls back to CPU.
        GGML_BACKEND = "Vulkan0";
      };

      serviceConfig = {
        Type = "exec";
        User = "qwen-tts";
        Group = "qwen-tts";
        WorkingDirectory = "/var/lib/qwen-tts";
        StateDirectory = "qwen-tts"; # cloned-voice registry persists here
        Restart = "always";
        RestartSec = 5;
        TimeoutStartSec = 300;

        ExecStartPre = [
          # Log the selected Vulkan device at every start so a silent CPU
          # fallback is visible in the journal. Non-fatal if vulkaninfo is absent.
          "-${pkgs.vulkan-tools}/bin/vulkaninfo --summary"
        ];
        ExecStart = lib.concatStringsSep " " (
          [
            (lib.getExe' runtime "tts-server")
            "--model"
            talker
            "--codec"
            codec
            "--alias"
            cfg.alias
            "--port"
            (toString cfg.backendPort)
          ]
          ++ cfg.extraArgs
        );

        # --- Hardening ---
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        # Vulkan needs /dev/dri; keep the device namespace intact.
        PrivateDevices = false;
        ReadWritePaths = [cfg.modelDir "/var/lib/qwen-tts"];
        SupplementaryGroups = ["video" "render"];

        # --- Resource limits (prompt: 8 G / CPU 50 / IO 50) ---
        MemoryMax = "8G";
        CPUWeight = 50;
        IOWeight = 50;
      };
    };

    # --- On-demand front door: systemd holds the port, the proxy spins up -----
    # tts-server cannot accept an inherited listening socket (no LISTEN_FDS
    # support), so systemd owns `port` and hands it to systemd-socket-proxyd,
    # which fronts the model server on `backendPort`.
    systemd.sockets."qwen-tts" = {
      description = "Qwen3-TTS socket (on-demand activation)";
      wantedBy = ["sockets.target"];
      socketConfig = {
        ListenStream = "127.0.0.1:${toString cfg.port}";
        Accept = false;
        # The socket activates the proxy, not qwen-tts.service: the server
        # itself gets no FD and must bind its own backend port.
        Service = "qwen-tts-proxy.service";
      };
    };

    systemd.services."qwen-tts-proxy" = {
      description = "Socket-activated proxy that starts Qwen3-TTS on demand";
      requires = ["qwen-tts.service"];
      after = ["qwen-tts.service"];
      # No wantedBy: qwen-tts.socket activates this on the first connection.
      serviceConfig = {
        # Type=exec reports the backend started as soon as it execs, but
        # tts-server binds :8182 only after loading both GGUFs (~15 s). Gate the
        # proxy on /health so the queued request is forwarded, not refused.
        ExecStartPre = pkgs.writeShellScript "wait-for-qwen-tts-backend" ''
          set -eu
          for _ in $(${pkgs.coreutils}/bin/seq 1 180); do
            if ${pkgs.curl}/bin/curl -sf -o /dev/null --max-time 2 http://${backend}/health; then
              exit 0
            fi
            ${pkgs.coreutils}/bin/sleep 1
          done
          echo "qwen-tts backend not healthy on ${backend} after 180 s" >&2
          exit 1
        '';
        # Exits by itself after idleTimeout with no open connection; the idle
        # timer below then stops the backend. A long streamed request counts as
        # a connection, so it is never cut off mid-audio.
        ExecStart = "${config.systemd.package}/lib/systemd/systemd-socket-proxyd --exit-idle-time=${toString cfg.idleTimeout} ${backend}";
        TimeoutStartSec = 300;
      };
    };

    # --- Idle stop: free the ~3.8 GiB once the proxy has gone idle ----------
    # The proxy disappears on its own (--exit-idle-time); this only has to stop
    # the backend it was fronting. Running every 5 min also covers the failure
    # case where the proxy never started. The socket stays listening, so the
    # next connection re-activates the proxy -> backend.
    systemd.services."qwen-tts-idle" = {
      description = "Stop Qwen3-TTS once its socket proxy is gone";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = pkgs.writeShellScript "qwen-tts-idle-check" ''
          set -eu
          systemctl=${config.systemd.package}/bin/systemctl
          if "$systemctl" -q is-active qwen-tts-proxy.service; then
            exit 0
          fi
          if "$systemctl" -q is-active qwen-tts.service; then
            "$systemctl" stop qwen-tts.service
          fi
        '';
      };
    };

    systemd.timers."qwen-tts-idle" = {
      description = "Stop Qwen3-TTS after its socket proxy goes idle";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnBootSec = "5min";
        OnUnitActiveSec = "5min";
        Unit = "qwen-tts-idle.service";
      };
    };

    # --- LAN: http://tts.lan/v1/audio/speech (nginx :80 -> :8181) ------------
    services.nginx = {
      enable = true;
      recommendedProxySettings = true;

      # Optional bearer enforcement lives in the http block so the map is
      # available to the vhost's `if`.
      appendHttpConfig = optionalString authEnabled ''
        include ${authInclude};
      '';

      preStart = optionalString authEnabled ''
        ${pkgs.coreutils}/bin/install -d -m 0755 /run/qwen-tts
        {
          echo 'map $http_authorization $qwen_tts_authorized {'
          echo '  default 0;'
          printf '  "Bearer %s" 1;\n' "$(${pkgs.coreutils}/bin/tr -d '\n' < ${cfg.apiKeyFile})"
          echo '}'
        } > ${authInclude}
      '';

      virtualHosts."tts.lan" = {
        serverAliases = ["tts"];
        listen = [
          {
            addr = "0.0.0.0";
            port = 80;
          }
        ];
        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString cfg.port}";
          extraConfig =
            ''
              # Streaming synthesis: never buffer the audio response.
              proxy_buffering off;
              proxy_cache off;
              proxy_read_timeout 300s;
              proxy_send_timeout 300s;
              client_max_body_size 0;
            ''
            + optionalString authEnabled ''
              if ($qwen_tts_authorized = 0) { return 401; }
            '';
        };
      };
    };

    # --- Tailnet: https://<host>.<tailnet>.ts.net:8444/... -------------------
    #
    # :8444 keeps this clear of Qwen (:443) and Laya (:8443); `tailscale serve`
    # maps whole ports, so a distinct port is required.
    systemd.services."tailscale-serve-tts" = {
      description = "Serve Qwen3-TTS on the node's tailnet HTTPS name (:8444)";
      after = [
        "tailscaled.service"
        "tailscaled-autoconnect.service"
        "qwen-tts.socket"
      ];
      wants = [
        "tailscaled.service"
        # Deliberately NOT qwen-tts.service: wanting it would start the model
        # server at boot and defeat on-demand. The serve rule proxies to the
        # socket, which activates the model server on first use.
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
        ExecStartPre = pkgs.writeShellScript "wait-for-tailscale-running" ''
          set -eu
          for _ in $(seq 1 60); do
            if ${lib.getExe config.services.tailscale.package} status --json 2>/dev/null \
              | ${lib.getExe pkgs.jq} -e '.BackendState == "Running"' >/dev/null 2>&1; then
              exit 0
            fi
            sleep 2
          done
          echo "tailscaled backend not Running after 120s" >&2
          exit 1
        '';
        ExecStart = "${lib.getExe config.services.tailscale.package} serve --bg --https=8444 http://127.0.0.1:${toString cfg.port}";
      };
    };

    # NOTE: cfg.port is intentionally absent from allowedTCPPorts — it is
    # loopback-only. Exposure is only via nginx (:80) and `tailscale serve`.
  };
}
