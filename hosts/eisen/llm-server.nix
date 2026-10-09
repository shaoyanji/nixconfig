# eisen — offline MoE LLM inference (native llama.cpp, Vulkan/radv).
#
# Two MoE models share one OpenAI-compatible endpoint via llama-swap, which
# starts/stops a llama-server per model on demand (they cannot co-reside in
# 62 GiB RAM: Qwen ~21 GiB + Kolibri ~44 GiB > 62 GiB).
#
#   * qwen3.6-35b-a3b — Qwen3.6-35B-A3B, 35B total / ~3B active (Q4_K_M).
#   * kolibri-1       — Aleph-Alpha Kolibri-1, 78B total / 3.46B active,
#                       German+English (Q4_K_M).
#
# Blueprint: ~/HANDOFF.md §3 and .agents/deploy/hosts/eisen.md.
#
# MoE expert-offload strategy (per model):
#   * `--n-gpu-layers 99` offloads every non-expert tensor (attention, norms,
#     embeddings, router/gate) to the RX 5700's 8 GiB VRAM.
#   * `--override-tensor exps=CPU` keeps the sparse expert FFN tensors in DDR4,
#     so only the ~3B active parameters per token touch the GPU.
#   * q8_0 KV cache + flash-attn keep the attention working set inside 8 GiB.
#
# Exposure:
#   * LAN:      http://eisen.lan/v1              (nginx :80 -> 127.0.0.1:8080)
#   * Tailnet:  https://eisen.<tailnet>.ts.net/v1 (services.tailscale.serve)
#   * Direct:   http://eisen:8080/v1             (llama-swap on 0.0.0.0)
{
  config,
  lib,
  pkgs,
  ...
}: let
  port = 8080;
  modelDir = "/mnt/storage/models";

  tc = config.services.tailscale.package;

  # Gate both serve paths on the tailnet backend actually being connected.
  # `after = tailscaled.service` only waits for the daemon to start, not for
  # the node to be Running; without this the units race it on a tailscaled
  # restart and die with "unexpected state: NoState".
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

  qwenName = "Qwen_Qwen3.6-35B-A3B-Q4_K_M.gguf";
  qwenFile = "${modelDir}/${qwenName}";
  qwenUrl = "https://huggingface.co/bartowski/Qwen_Qwen3.6-35B-A3B-GGUF/resolve/main/${qwenName}";

  kolibriName = "Kolibri-1-Q4_K_M.gguf";
  kolibriFile = "${modelDir}/${kolibriName}";
  kolibriUrl = "https://huggingface.co/Hob-forge/Kolibri-1-GGUF/resolve/main/${kolibriName}";

  # Vulkan (radv) build — RX 5700 (Navi 10) has no ROCm/CDNA; Vulkan is the
  # supported compute path. Cached in the binary cache (no source build).
  llama = pkgs.llama-cpp.override {vulkanSupport = true;};

  # llama-swap substitutes ${PORT} with a free port before exec'ing the server.
  mkCmd = model: alias:
    "${lib.getExe' llama "llama-server"} --host 127.0.0.1 --port \${PORT} "
    + "--model ${model} --alias ${alias} --threads 12 --ctx-size 32768 "
    + "--flash-attn on --jinja --metrics --n-gpu-layers 99 "
    + "--override-tensor exps=CPU --cache-type-k q8_0 --cache-type-v q8_0";

  # Idempotent, resumable weight fetch — runs only when the GGUF is absent.
  mkFetch = {
    file,
    url,
  }: {
    description = "Fetch ${file} if missing";
    after = ["network-online.target"];
    wants = ["network-online.target"];
    unitConfig.ConditionPathExists = "!${file}";
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "fetch-${baseNameOf file}" ''
        set -euo pipefail
        ${pkgs.coreutils}/bin/echo "Fetching ${url}"
        ${pkgs.curl}/bin/curl -fL --retry 5 --retry-delay 5 -C - \
          -o "${file}.part" "${url}"
        ${pkgs.coreutils}/bin/mv -f "${file}.part" "${file}"
      '';
    };
  };
in {
  # Model weight repository on the persistent storage array.
  systemd.tmpfiles.rules = [
    "d ${modelDir} 0755 devji users - -"
  ];

  systemd.services."eisen-llm-qwen" = mkFetch {
    file = qwenFile;
    url = qwenUrl;
  };
  systemd.services."eisen-llm-kolibri" = mkFetch {
    file = kolibriFile;
    url = kolibriUrl;
  };

  # Weights and the storage mount must exist before llama-swap accepts traffic.
  systemd.services.llama-swap = {
    after = [
      "eisen-llm-qwen.service"
      "eisen-llm-kolibri.service"
      "mnt-storage.mount"
    ];
    wants = [
      "eisen-llm-qwen.service"
      "eisen-llm-kolibri.service"
    ];
  };

  # --- Native llama.cpp servers, swapped on demand (no Ollama) ---
  services.llama-swap = {
    enable = true;
    listenAddress = "0.0.0.0";
    port = port;
    settings = {
      healthCheckTimeout = 600;
      # Unload an idle model so the next swap has the RAM to load the other.
      ttl = 900;
      models = {
        "qwen3.6-35b-a3b" = {
          cmd = mkCmd qwenFile "qwen3.6-35b-a3b";
          aliases = ["qwen"];
        };
        "kolibri-1" = {
          cmd = mkCmd kolibriFile "kolibri-1";
          aliases = ["kolibri" "aleph"];
        };
      };
    };
  };

  # --- LAN: plain http://eisen.lan/v1 (nginx :80 -> llama-swap :8080) ---
  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    virtualHosts."eisen.lan" = {
      serverAliases = ["eisen" "192.168.3.76"];
      listen = [
        {
          addr = "0.0.0.0";
          port = 80;
        }
      ];
      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString port}";
        proxyWebsockets = false;
        extraConfig = ''
          # Token streaming: never buffer the SSE response.
          proxy_buffering off;
          proxy_cache off;
          # Model swaps can take minutes on first load — don't time out.
          proxy_read_timeout 3600s;
          proxy_send_timeout 3600s;
          client_max_body_size 0;
        '';
      };
    };
  };

  # --- Tailnet: https://eisen.<tailnet>.ts.net/v1 (classic node serve) ---
  #
  # This is the primary tailnet exposure. `tailscale serve --bg` is the only
  # way to set a *node* serve target: `tailscale serve set-config` — the file
  # form that services.tailscale.serve writes — only accepts the Services
  # schema (it rejects TCP/Web with "unknown object member name"), and the
  # `svc:` form further requires the tailnet "Services" preview to be enabled
  # in the admin console. The node form needs no toggle: the tailnet already
  # issues HTTPS certs (`tailscale cert eisen.<tailnet>.ts.net` succeeds), so
  # this answers on https://eisen.cloudforest-kardashev.ts.net/v1 with a
  # valid cert.
  #
  # Idempotent — re-applying the same target is a no-op — so `partOf` can just
  # re-assert the same mapping whenever tailscaled restarts.
  systemd.services."tailscale-serve-node" = {
    description = "Serve eisen's LLM API on the node's tailnet HTTPS name";
    after = [
      "tailscaled.service"
      "tailscaled-autoconnect.service"
    ];
    wants = ["tailscaled.service"];
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
      ExecStart = "${lib.getExe tc} serve --bg http://127.0.0.1:${toString port}";
    };
  };

  # Alias form: https://eisen-llm.<tailnet>.ts.net/v1 . This is nixpkgs' own
  # declarative path, but `svc:` names only resolve once the tailnet's
  # "Services" preview is enabled in the admin console; until then it is inert
  # but harmless, so it stays declared alongside the node serve above.
  services.tailscale.serve = {
    enable = true;
    services.eisen-llm = {
      endpoints."tcp:443" = "http://127.0.0.1:${toString port}";
    };
  };

  # Expose on the LAN + tailnet only (llama workload).
  networking.firewall.allowedTCPPorts = [80 port];
}
