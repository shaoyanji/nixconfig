# eisen — offline decision models (Laya), served beside the Qwen MoE LLM.
#
# Laya is a 421M "System One" decision model: it reads one document (the
# `state`) plus a set of typed questions about it and returns a calibrated
# distribution over the options supplied at request time, in a single forward
# pass and without generating text. It speaks the same `POST /v1/systemone`
# contract as TypeSafe's hosted Jev, so a Jev client works by changing its base
# URL — which matters here because this fleet has no hosted Jev. This is the
# offline stand-in.
#
#   question shapes:  choice (n options) | score (ordinal) | noul (yes/no)
#
# CPU only (torch 2.14.1+cpu). It holds no VRAM, so unlike the Qwen MoE it
# needs no gaming guard and keeps answering while a game runs; it also
# co-resides with Qwen rather than competing for the 62 GiB, which is what
# makes a qwen + laya offline tandem possible on one box.
#
# Measured on eisen — a 274-token state with 4 questions:
#   12 threads 0.43 s | 8 threads 0.56 s | 4 threads 0.98 s | 3-state batch 0.25 s
# RSS ~3.5 GiB with english + multilingual resident.
#
# Exposure (mirrors llm-server.nix):
#   LAN:      http://laya.lan/v1/systemone          (nginx :80 -> 127.0.0.1:8090)
#   Tailnet:  https://eisen.<tailnet>.ts.net:8443/v1/systemone
# 8090 stays bound to loopback; nginx and `tailscale serve` are the only ways
# in, so there is no firewall allowance for it.
#
# No API key, matching the LLM endpoint: the LAN and the tailnet are the trust
# boundary. Set LAYA_API_KEY (via sops) to require `Authorization: Bearer`.
#
# Accuracy is NOT a drop-in for Jev — do not let this gate a destructive
# decision on its own. On the public 49-task / 869-case benchmark Jev scores
# 0.966 macro accuracy against Laya-base 0.583, and on large option sets the
# base checkpoints fall to ~0.43 where Jev holds 0.87 (Banking77, 77 labels).
# Prefer `typed-decisions` (reached lazily via LAYA_AUTO_TASK) and threshold on
# `answer_confidence`, which must be fit on your own data — Laya's `confidence`
# is 1 - normalised entropy, not Jev's (n*p_max - 1)/(n - 1), so a cutoff
# carried over from Jev does not transfer.
#
# Kev-4B was evaluated for this host and rejected: it serves only on CUDA,
# ROCm or Apple MLX, and eisen's RX 5700 (Navi 10 / gfx1010) sits outside
# ROCm's support matrix with 8 GiB VRAM against Kev-4B's ~16 GiB floor. The
# llama.cpp route is closed too, because Kev is a LoRA adapter plus a pointer
# head on Qwen3.5-4B-Base rather than a merged model.
#
# `laya` is not in nixpkgs, so the venv is bootstrapped once with uv onto
# /mnt/storage. The bootstrap is guarded by the presence of its entry point, so
# it is idempotent and self-heals if the venv is deleted. Python and libstdc++
# come from the store and are referenced by the system closure, which means the
# venv's shebangs point at store paths that can never be collected out from
# under it. The bootstrap also overrides the fleet's uv index: modules/dev.nix
# points `pip.index-url` at test.pypi.org, which carries no real releases.
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

  # --- The decision-model server -------------------------------------------
  systemd.services."laya-serve" = {
    description = "Laya decision model (Jev-compatible /v1/systemone)";
    after = ["eisen-laya-bootstrap.service" "mnt-storage.mount"];
    wants = ["eisen-laya-bootstrap.service"];
    requires = ["mnt-storage.mount"];
    wantedBy = ["multi-user.target"];
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
      ExecStart = "${venv}/bin/laya-serve";
      Restart = "always";
      RestartSec = 5;
      # First boot downloads ~1.5 GiB of checkpoints from the Hub.
      TimeoutStartSec = 600;
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
      "laya-serve.service"
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
