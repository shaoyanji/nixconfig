# qwen-tts — offline Qwen3-TTS text-to-speech served over OpenAI-compatible HTTP.
#
# Runtime: ServeurpersoCom/qwentts.cpp, a C++17/GGML port of Qwen3-TTS 12 Hz
# (MIT; upstream model + codec are Apache-2.0). It builds against the bundled
# ggml submodule with a Vulkan backend, so it runs on the RX 5700 (Navi 10)
# where ROCm is unavailable. The runtime already ships an OpenAI-compatible
# `tts-server`, so this module WRAPS that rather than writing a Python server:
# fewer moving parts, and the engine's streaming path is used as-is.
#
# Weights are the pre-converted GGUFs from Serveurperso/Qwen3-TTS-GGUF. Two
# files load together: a "talker" LM (per mode/size/variant) and a shared
# "tokenizer" codec (SEANet+ConvNeXt+DAC, RVQ). Q4_K_M is the low-VRAM variant
# (~1.2 GB talker) which leaves headroom on an 8 GB card that Qwen may also be
# using; Q8_0 (~2.1 GB) is the upstream-recommended quality default.
#
# Exposure mirrors llm-server.nix / decision-models.nix: an nginx *.lan vhost on
# :80 and a `tailscale serve` listener. The ListeningPort itself is loopback-only
# and is deliberately NOT added to the firewall; the LAN + tailnet are the trust
# boundary, exactly as for the LLM and the decision model.
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
      rev = "0000000000000000000000000000000000000000";
      hash = lib.fakeHash;
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
    ];

    # Upstream has no install target for the CLIs; place them explicitly.
    installPhase = ''
      runHook preInstall
      install -Dm755 build/qwen-tts -t $out/bin
      install -Dm755 build/tts-server -t $out/bin
      install -Dm755 build/qwen-codec -t $out/bin
      runHook postInstall
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
      description = "Loopback port the tts-server listens on.";
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
      wantedBy = ["multi-user.target"];

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
            (toString cfg.port)
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
        "qwen-tts.service"
      ];
      wants = [
        "tailscaled.service"
        "qwen-tts.service"
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
