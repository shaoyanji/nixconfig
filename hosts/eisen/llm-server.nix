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

  # A Steam game is recognised by a process whose executable lives under a
  # Steam library's steamapps/common/. See the unit below for why gamescope
  # and gamescopereaper cannot be used as "is a game running" signals here.
  gamingGuard = pkgs.writeShellScript "llama-swap-gaming-guard" ''
    set -eu
    gaming() {
      local p t
      for p in /proc/[0-9]*/exe; do
        t=$(readlink "$p" 2>/dev/null) || continue
        case "$t" in
          */steamapps/common/*) return 0 ;;
        esac
      done
      return 1
    }

    suspended=0
    while true; do
      if gaming; then
        if [ "$suspended" = 0 ]; then
          echo "game detected - yielding, stopping llama-swap"
          systemctl stop llama-swap.service || true
          suspended=1
        fi
      elif [ "$suspended" = 1 ]; then
        echo "game exited - resuming llama-swap"
        systemctl start llama-swap.service || true
        suspended=0
      fi
      sleep 15
    done
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

  # DFlash2 speculative-decoding head for Qwen: a block-diffusion drafter
  # trained for this exact target (vocab 248320, matching) that is verified by
  # the target, so output distribution is unchanged. Measured on eisen on a
  # 256-token generation: 13.5 -> 19.0 tok/s (+40%), 48% draft acceptance, head
  # fully resident in VRAM. Kolibri-1 has no equivalent head, and borrowing one
  # is impossible — Qwen3's 152k vocab does not match Qwen3.6's 248k, so a
  # cross-family draft fails to load. n-gram speculation (`--spec-type
  # ngram-*`) was also measured here and is a wash (12.5–13.8 tok/s), i.e. no
  # self-repetition to exploit on this workload.
  dflashName = "Qwen3.6-35B-A3B-DFlash2-Q8_0.gguf";
  dflashFile = "${modelDir}/${dflashName}";
  dflashUrl = "https://huggingface.co/aminya/Qwen3.6-35B-A3B-DFlash2-GGUF/resolve/main/${dflashName}";
  dflashFlags = "--spec-draft-model ${dflashFile} --spec-type draft-dflash --spec-draft-n-max 7 --spec-draft-ngl 99";

  # llama-swap substitutes ${PORT} with a free port before exec'ing the server.
  mkCmd = {
    model,
    alias,
    spec ? "",
  }:
    "${lib.getExe' llama "llama-server"} --host 127.0.0.1 --port \${PORT} "
    + "--model ${model} --alias ${alias} --threads 12 --ctx-size 32768 "
    + "--flash-attn on --jinja --metrics --n-gpu-layers 99 "
    + "--override-tensor exps=CPU --cache-type-k q8_0 --cache-type-v q8_0 "
    + spec;

  # NOTE — Kolibri-1 does not currently load: this nixpkgs' llama-cpp (0.5.0)
  # reports "unknown model architecture: 'kolibri1'" and exits, so a request for
  # the `kolibri` alias returns HTTP 500. The weights and the entry are kept
  # because the wiring is correct and it will start working as soon as the
  # pinned llama-cpp learns the architecture (or `llama` is overridden to a
  # newer revision); re-test with:
  #   curl -s $EP/v1/chat/completions -d '{"model":"kolibri",...}'
  # See .agents/deploy/hosts/eisen.md for the evidence and the patch route.

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
  systemd.services."eisen-llm-dflash" = mkFetch {
    file = dflashFile;
    url = dflashUrl;
  };

  # Weights and the storage mount must exist before llama-swap accepts traffic.
  systemd.services.llama-swap = {
    after = [
      "eisen-llm-qwen.service"
      "eisen-llm-kolibri.service"
      "eisen-llm-dflash.service"
      "mnt-storage.mount"
    ];
    wants = [
      "eisen-llm-qwen.service"
      "eisen-llm-kolibri.service"
      "eisen-llm-dflash.service"
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
          cmd = mkCmd {
            model = qwenFile;
            alias = "qwen3.6-35b-a3b";
            spec = dflashFlags;
          };
          aliases = ["qwen"];
        };
        "kolibri-1" = {
          cmd = mkCmd {
            model = kolibriFile;
            alias = "kolibri-1";
          };
          aliases = ["kolibri" "aleph"];
        };
      };
    };
  };

  # --- Auto-yield to gaming ------------------------------------------------
  #
  # eisen is a gaming desktop first. Gamescope and gamescopereaper are ALWAYS
  # running here (the Steam tenfoot kiosk session), so neither is a usable
  # "is a game running" signal — using them would suspend the LLM permanently.
  # The reliable signal is a process whose executable lives under a Steam
  # library's steamapps/common/, which covers native, Proton and
  # SteamLinuxRuntime-container games alike, and leaves the LLM alone when
  # only Steam itself is idle in the background.
  #
  # On detection llama-swap is stopped outright rather than left holding a
  # half-starved model: that returns the model's RAM (21 GiB Qwen, 44 GiB
  # Kolibri) and, measured with Qwen resident, 5.4 GiB of the 8 GiB VRAM to the
  # game, and the API answers
  # connection-refused until the game exits — an honest "yielded to gaming"
  # instead of a model quietly competing for VRAM.
  systemd.services."llama-swap-gaming-guard" = {
    description = "Suspend the LLM while a Steam game is running";
    after = ["llama-swap.service"];
    wantedBy = ["multi-user.target"];
    path = [config.systemd.package pkgs.coreutils];
    serviceConfig = {
      ExecStart = gamingGuard;
      Restart = "always";
      RestartSec = 10;
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
