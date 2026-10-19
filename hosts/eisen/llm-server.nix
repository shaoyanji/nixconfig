# eisen — offline MoE LLM inference (native llama.cpp, Vulkan/radv).
#
# Three models share one OpenAI-compatible endpoint via llama-swap, which
# starts/stops a llama-server per model on demand (Qwen ~21 GiB + Kolibri
# ~44 GiB cannot co-reside in 62 GiB RAM; Bonsai ~6 GiB fits RAM beside
# Qwen but not VRAM, so it swaps like the others).
#
#   * qwen3.6-35b-a3b — Qwen3.6-35B-A3B, 35B total / ~3B active (Q4_K_M).
#   * kolibri-1       — Aleph-Alpha Kolibri-1, 78B total / 3.46B active,
#                       German+English (Q4_K_M).
#   * bonsai-2-27b    — PrismML Ternary Bonsai 2, 27B dense ternary (PTQ1_0),
#                       served by the PrismML fork of llama.cpp (Vulkan).
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

  # SSE proxy policy, defined once: three vhosts (the model API, /eisen/ and
  # /router/) forwarded to this stack and each carried its own copy of it.
  # Streaming must not be buffered, and a cold model load outlives nginx's
  # 60 s default by far.
  sseProxy = ''
    proxy_buffering off;
    proxy_cache off;
    proxy_read_timeout 3600s;
    proxy_send_timeout 3600s;
    client_max_body_size 0;
  '';

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

  bonsaiName = "Ternary-Bonsai-2-27B-PTQ1_0.gguf";
  bonsaiFile = "${modelDir}/${bonsaiName}";
  bonsaiUrl = "https://huggingface.co/prism-ml/Ternary-Bonsai-2-27B-gguf/resolve/main/${bonsaiName}";

  # Vulkan (radv) build pinned to 0.7.0 (release v0.7.0 / build 11669 / commit 620d222).
  # RX 5700 (Navi 10) uses the Vulkan backend; dynamic CPU dispatch provides AVX2 for Haswell-EP.
  # The web UI is disabled in CMake to eliminate Node.js/npm dependencies during headless server builds.
  llama = (pkgs.llama-cpp.override {vulkanSupport = true;}).overrideAttrs (old: rec {
    version = "0.7.0";
    src = pkgs.fetchFromGitHub {
      owner = "ggml-org";
      repo = "llama.cpp";
      tag = "v${version}";
      hash = "sha256-pEDYgI3AMTU+cekvRX7NNt5wddznydQSNuerswvEpsA=";
    };
    npmDeps = null;
    npmDepsHash = null;
    preConfigure = "";
    nativeBuildInputs = lib.filter (p: p != pkgs.nodejs_latest && p != pkgs.npmHooks.npmConfigHook) old.nativeBuildInputs;
    cmakeFlags =
      (lib.filter (flag: !(lib.hasPrefix "-DLLAMA_BUILD_NUMBER=" flag || lib.hasPrefix "-DLLAMA_BUILD_COMMIT=" flag)) old.cmakeFlags)
      ++ [
        "-DLLAMA_BUILD_NUMBER=11669"
        "-DLLAMA_BUILD_COMMIT=620d222"
        "-DLLAMA_BUILD_UI=OFF"
        "-DLLAMA_USE_PREBUILT_UI=OFF"
      ];
  });

  # PrismML fork of llama.cpp, pinned to the #238 merge commit (3ae4f51,
  # 2026-09-21) — the merge the PrismML known-issues page ties to the
  # Vulkan ternary fixes. Serves Bonsai only; Qwen/Kolibri stay on `llama` above. Same
  # override pattern (Vulkan, no web-UI npm step), plus
  # -DLLAMA_BUILD_TESTS=OFF (community-reported mandatory for this fork).
  llamaPrism = (pkgs.llama-cpp.override {vulkanSupport = true;}).overrideAttrs (old: rec {
    version = "prism-3ae4f51";
    src = pkgs.fetchFromGitHub {
      owner = "PrismML-Eng";
      repo = "llama.cpp";
      rev = "3ae4f51087d8d9292eda16ee00cec54e798ea576";
      hash = "sha256-oS04cLZ8Zft5HIOyGO9zVCsGs7g67c+i1a2rDVtRfaY=";
    };
    npmDeps = null;
    npmDepsHash = null;
    preConfigure = "";
    nativeBuildInputs = lib.filter (p: p != pkgs.nodejs_latest && p != pkgs.npmHooks.npmConfigHook) old.nativeBuildInputs;
    cmakeFlags =
      (lib.filter (flag: !(lib.hasPrefix "-DLLAMA_BUILD_NUMBER=" flag || lib.hasPrefix "-DLLAMA_BUILD_COMMIT=" flag)) old.cmakeFlags)
      ++ [
        "-DLLAMA_BUILD_COMMIT=3ae4f51"
        "-DLLAMA_BUILD_UI=OFF"
        "-DLLAMA_USE_PREBUILT_UI=OFF"
        "-DGGML_VULKAN=ON"
        "-DLLAMA_BUILD_TESTS=OFF"
      ];
  });

  # Kolibri-1: Aleph-Alpha Kolibri-1 arch support via the Hob-forge patch
  # (kolibri1-llama.cpp.patch, 4-patch series by Seraphiel102, 2026-10-03:
  # SIGMOID_LOGIT_ADD expert gating + kolibri1 arch registration + model
  # impl + converter bits) against upstream commit 836d571 (2026-10-03).
  # Stock llama.cpp lacks the `kolibri1` architecture and exits with
  # "unknown model architecture: 'kolibri1'". Serves Kolibri only. Same
  # override pattern (Vulkan, no web-UI npm step). The patch also touches
  # conversion/ + gguf-py/ (converter, not compiled) and
  # tests/test-llama-archs.cpp.
  llamaKolibri = (pkgs.llama-cpp.override {vulkanSupport = true;}).overrideAttrs (old: rec {
    version = "kolibri-836d571";
    src = pkgs.fetchFromGitHub {
      owner = "ggml-org";
      repo = "llama.cpp";
      rev = "836d57176dc699a726c55418e4f96b8ca628e1bf";
      hash = "sha256-JhlwSNvYpG/HGzc+YXjy1pEC1t2iL2K2gR0Uhtoa7Do=";
    };
    patches = [
      (pkgs.fetchpatch {
        url = "https://huggingface.co/Hob-forge/Kolibri-1-GGUF/resolve/main/kolibri1-llama.cpp.patch";
        hash = "sha256-65Swaq5XYxpnXbsNYk4sPcVtOBchDx87miwucWBKQrA=";
      })
    ];
    npmDeps = null;
    npmDepsHash = null;
    preConfigure = "";
    nativeBuildInputs = lib.filter (p: p != pkgs.nodejs_latest && p != pkgs.npmHooks.npmConfigHook) old.nativeBuildInputs;
    cmakeFlags =
      (lib.filter (flag: !(lib.hasPrefix "-DLLAMA_BUILD_NUMBER=" flag || lib.hasPrefix "-DLLAMA_BUILD_COMMIT=" flag)) old.cmakeFlags)
      ++ [
        "-DLLAMA_BUILD_COMMIT=836d571"
        "-DLLAMA_BUILD_UI=OFF"
        "-DLLAMA_USE_PREBUILT_UI=OFF"
        "-DGGML_VULKAN=ON"
      ];
  });

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

  # Kev-4B (decision model, /v1/systemone) — GGUF from ggml-org.
  # Source is a LoRA adapter + pointer head (jaredpalmer/kev-4b); this is
  # the merged/converted GGUF that llama.cpp serves natively (build 11669+).
  # Q8_0 is the recommended quant for decision models. Apache-2.0.
  kevFile = "${modelDir}/Kev-4B-Q8_0.gguf";
  kevUrl = "https://huggingface.co/ggml-org/Kev-4B-GGUF/resolve/main/Kev-4B-Q8_0.gguf";
  dflashFlags = "--spec-draft-model ${dflashFile} --spec-type draft-dflash --spec-draft-n-max 7 --spec-draft-ngl 99";

  # llama-swap substitutes ${PORT} with a free port before exec'ing the server.
  # --reasoning-format none preserves standard OpenAI delta.content streaming
  # and prevents stripping thinking tokens into null delta.content.
  # --parallel 1 dedicates the full context pool and RAM bandwidth to the active prompt.
  mkCmd = {
    model,
    alias,
    spec ? "",
    binary ? llama,
    ctxSize ? 32768,
    experts ? true,
    # CPU threads for generation. Default 12 = eisen's Xeon E5-2673 v3
    # physical cores; a MoE model that keeps its expert FFNs in DDR4 is
    # memory-bandwidth bound, so hyperthreads help only up to the point the
    # two siblings contend for the same cache lines. Kolibri overrides this
    # with 24 (all SMT threads) — see its entry below.
    threads ? 12,
  }:
    "${lib.getExe' binary "llama-server"} --host 127.0.0.1 --port \${PORT} "
    + "--model ${model} --alias ${alias} --threads ${toString threads} --parallel 1 --ctx-size ${toString ctxSize} "
    + "--flash-attn on --jinja --metrics --reasoning-format none --n-gpu-layers 99 "
    + (lib.optionalString experts "--override-tensor exps=CPU ")
    + "--cache-type-k q8_0 --cache-type-v q8_0 "
    + spec;

  # Kolibri-1 loads via `llamaKolibri` (patched llama.cpp, Hob-forge patch);
  # the stock binary exits with "unknown model architecture: 'kolibri1'".
  # Re-test with:
  #   curl -s $EP/v1/chat/completions -d '{"model":"kolibri",...}'

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
  imports = [
    ../../modules/profiles/nixbuild-client.nix
  ];

  # Remote builder client for nixbuild.net (enables distributed builds initiated from eisen in the basement)
  profiles.nixbuild-client.enable = true;

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
  systemd.services."eisen-llm-bonsai" = mkFetch {
    file = bonsaiFile;
    url = bonsaiUrl;
  };
  systemd.services."eisen-llm-kev" = mkFetch {
    file = kevFile;
    url = kevUrl;
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
      "eisen-llm-bonsai.service"
      "eisen-llm-dflash.service"
      "mnt-storage.mount"
    ];
    wants = [
      "eisen-llm-qwen.service"
      "eisen-llm-kolibri.service"
      "eisen-llm-bonsai.service"
      "eisen-llm-dflash.service"
    ];
  };

  # --- Native llama.cpp servers, swapped on demand (no Ollama) ---
  services.llama-swap = {
    enable = true;
    listenAddress = "0.0.0.0";
    inherit port;
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
            binary = llamaKolibri;
            # All 24 SMT threads (the other models stay at 12 physical cores).
            # Kolibri is the largest expert pool (78B / 3.46B active) and its
            # experts live in DDR4 (`--override-tensor exps=CPU`), so the
            # per-token cost is dominated by memory traffic; SMT gives the
            # scheduler more outstanding loads to hide that latency.
            # Measure, don't assume: `llama-bench -t 12 -t 24` on the Kolibri
            # GGUF before treating 24 as faster on this box.
            threads = 24;
            # Low reasoning effort: Kolibri's default think is long (a "hi"
            # cost 352 output tokens, mostly <think>). Keep answers short.
            spec = "--reasoning-effort low";
          };
          aliases = ["kolibri" "aleph"];
        };
        # Bonsai 2 27B (dense ternary, PTQ1_0) on the PrismML fork.
        # No exps=CPU (dense, no experts), no DFlash (vocab/arch mismatch).
        # Verify weights after fetch: 5,946,648,928 bytes,
        # sha256 53107f530aa52eb00912263ab1ee29bd199261c87cd7b4ad4ca1318c1fe33ee3.
        "bonsai-2-27b" = {
          cmd = mkCmd {
            model = bonsaiFile;
            alias = "bonsai-2-27b";
            binary = llamaPrism;
            ctxSize = 16384;
            experts = false;
            spec = "--reasoning-effort medium";
          };
          aliases = ["bonsai"];
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
        extraConfig = sseProxy;
      };
    };
  };

  # --- Eisen router alias: /eisen/* -> /router/* (local) -----------------
  # Lets the canary guest (192.168.83.10) use the SAME endpoint
  # (http://192.168.83.1/eisen/...) whether the microVM runs on frieren
  # (frieren's /eisen/ proxies to Eisen's /router/) or on Eisen itself
  # (this rewrite, /eisen/ -> /router/ locally). Without it, a guest on
  # Eisen would need a different config than a guest on frieren.
  services.nginx.virtualHosts."eisen.lan".locations."/eisen/" = {
    proxyPass = "http://127.0.0.1:80/router/";
    proxyWebsockets = false;
    extraConfig = sseProxy;
  };

  # --- Router: http://eisen.lan/router/* -> 127.0.0.1:8000 ----------------
  # Exposes the decision router on :80 (loopback-only otherwise) so LAN /
  # bridged-subnet clients (e.g. the frieren-canary microVM, via frieren's
  # /eisen/ proxy) can reach it. The /router/ prefix is stripped by the
  # trailing slash, so the router sees /v1/chat/completions + /v1/decisions.
  # Same pattern as parakeet /stt/.
  services.nginx.virtualHosts."eisen.lan".locations."/router/" = {
    proxyPass = "http://127.0.0.1:${toString config.services.llm-decision-router.port}/";
    proxyWebsockets = false;
    extraConfig = ''
      proxy_buffering off;
      proxy_cache off;
      # A generation can run to the router's 110s cap + cold-load queueing.
      proxy_read_timeout 3600s;
      proxy_send_timeout 3600s;
      client_max_body_size 0;
    '';
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

  # `tailscale-serve` is upstream's oneshot. It is ordered `After=tailscaled`,
  # but ordering is not readiness: at boot tailscaled is still `NoState`, so
  # `tailscale serve set-config` exits 1 once and the unit stays failed with no
  # retry (seen on eisen 2026-10-19 13:44 — the tailnet serve config was not
  # applied until a manual restart). Wait for BackendState=Running first, and
  # raise TimeoutStartSec so the wait fits inside the unit's start timeout.
  systemd.services.tailscale-serve = {
    serviceConfig = {
      TimeoutStartSec = 150;
      ExecStartPre = lib.mkBefore [
        (pkgs.writeShellScript "tailscale-serve-wait" ''
          set -euo pipefail
          state=NoState
          for _ in $(seq 1 60); do
            state=$(${tc}/bin/tailscale status --json 2>/dev/null | ${pkgs.jq}/bin/jq -r '.BackendState // "NoState"' 2>/dev/null || echo NoState)
            if [ "$state" = Running ]; then
              exit 0
            fi
            sleep 2
          done
          echo "tailscale-serve: tailscaled not Running after 120s (last: $state)" >&2
          exit 1
        '')
      ];
    };
  };

  # Expose on the LAN + tailnet only (llama workload).
  networking.firewall.allowedTCPPorts = [80 port];
}
