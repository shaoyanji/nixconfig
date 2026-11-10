# eisen — DeepSeek-V4-Flash 284B on CPU: a mock, imported by nothing because the benchmark
# settled against it. Measured 2026-11-10: the bundled binary below never starts on this Xeon
# (`invalid opcode`; it is an AVX-512 native build), and the source build that does start
# (`scripts/build_zen5_llama.sh`, AVX2 path) decodes at 2.9 tok/s against Strata's 19.4.
# `AGENTS.nix` note `deepseek-v4-flash-eisen` and docs/deepseek-v4-flash.md carry the numbers;
# this module stays unimported, so `deepseek-v4-flash.service` does not exist on the host.
{
  lib,
  pkgs,
  ...
}: let
  port = 8086; # 8085 Strata, 8090 Laya, 8091 Parakeet, 8080 llama-swap (dormant)
  dir = "/mnt/storage/models/deepseek-v4-flash";
  hf = "https://huggingface.co/Synchopate/DeepSeek-V4-Flash-0731-Fractal-64GB-CPU-GGUF/resolve/main";

  # 36.47 + 24.26 GB + a 5.2 MB metadata shard = 60.74 GB (56.56 GiB). Only the
  # first shard is named on the command line; llama.cpp finds the rest beside it.
  shard1 = "${dir}/DeepSeek-V4-Flash-0731-Fractal-00001-of-00003.gguf";
  serverBin = "${dir}/llama-server-modchip-linux-x86_64";

  payload = [
    {
      file = "${dir}/DeepSeek-V4-Flash-0731-Fractal-00001-of-00003.gguf";
      path = "DeepSeek-V4-Flash-0731-Fractal-00001-of-00003.gguf";
    }
    {
      file = "${dir}/DeepSeek-V4-Flash-0731-Fractal-00002-of-00003.gguf";
      path = "DeepSeek-V4-Flash-0731-Fractal-00002-of-00003.gguf";
    }
    {
      file = "${dir}/DeepSeek-V4-Flash-0731-Fractal-00003-of-00003.gguf";
      path = "DeepSeek-V4-Flash-0731-Fractal-00003-of-00003.gguf";
    }
    {
      file = "${serverBin}";
      path = "llama-server-modchip-linux-x86_64";
      exec = true;
    }
    {
      file = "${dir}/llama-cli-modchip-linux-x86_64";
      path = "llama-cli-modchip-linux-x86_64";
      exec = true;
    }
    {
      file = "${dir}/deepseek-v4-flash-fractal-256k.patch";
      path = "patches/deepseek-v4-flash-fractal-256k.patch";
    }
  ];

  # Same contract as eisen-llm-* in llm-server.nix: idempotent and resumable,
  # absent-only. These are the fallback path — the bytes are expected to arrive
  # from frieren's aria2 job at ~110 MB/s over the LAN, because the HF CDN served
  # eisen at 1.45 MB/s (2026-11-03) and this payload is 60.7 GB.
  mkFetch = {
    file,
    path,
    exec ? false,
  }: {
    description = "Fetch ${baseNameOf file} if missing";
    after = ["network-online.target" "mnt-storage.mount"];
    wants = ["network-online.target" "mnt-storage.mount"];
    unitConfig.ConditionPathExists = "!${file}";
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "fetch-${baseNameOf file}" ''
        set -euo pipefail
        echo "Fetching ${hf}/${path}"
        ${pkgs.curl}/bin/curl -fL --retry 5 --retry-delay 5 -C - \
          -o "${file}.part" "${hf}/${path}"
        ${pkgs.coreutils}/bin/mv -f "${file}.part" "${file}"
        ${lib.optionalString exec "${pkgs.coreutils}/bin/chmod +x '${file}'"}
      '';
    };
  };

  fetches = lib.filter (f: !(f.skip or false)) payload;
in {
  systemd.tmpfiles.rules = [
    "d ${dir} 0755 devji users - -"
  ];

  # 57.61 GiB VmRSS at 256K ctx. Nothing on this host may co-reside with it:
  # llama-swap, Strata and a Steam game all have to be stopped first, which is
  # why this is a unit of its own and not a llama-swap model.
  systemd.services =
    lib.listToAttrs (map (f: {
        name = "eisen-dsv4-${baseNameOf f.file}";
        value = mkFetch {inherit (f) file path exec;};
      })
      fetches)
    // {
      "deepseek-v4-flash" = {
        description = "DeepSeek-V4-Flash 284B-A13B (llama-modchip, CPU-only)";
        after = ["mnt-storage.mount"] ++ map (f: "eisen-dsv4-${baseNameOf f.file}.service") fetches;
        wants = ["mnt-storage.mount"] ++ map (f: "eisen-dsv4-${baseNameOf f.file}.service") fetches;
        wantedBy = ["multi-user.target"];
        unitConfig = {
          # Half a model is not a model: a missing shard means refuse to start
          # rather than load 00001 and fail on the first tensor past shard 1.
          ConditionPathExists = shard1;
          StartLimitBurst = 3;
          StartLimitIntervalSec = 600;
        };
        serviceConfig = {
          Type = "simple";
          User = "devji";
          Group = "users";
          WorkingDirectory = dir;
          # 12 physical cores for generation and 24 for the batch path, the split
          # measured on this Xeon (docs/eisen-llm-architecture.md): decode is
          # bandwidth-bound and SMT hurts it, prefill is compute-bound and SMT helps.
          # --ctx-size 32768 is the starting point, not the ceiling — the pack is
          # documented to 256K. No --n-gpu-layers: there is no GPU path in this pack.
          ExecStart = lib.concatStringsSep " " [
            serverBin
            "-m ${shard1}"
            "--alias deepseek-v4-flash"
            "--host 127.0.0.1"
            "--port ${toString port}"
            "--threads 12"
            "--threads-batch 24"
            "--ctx-size 32768"
            "--parallel 1"
            "--flash-attn on"
            "--jinja"
            "--metrics"
          ];
          Restart = "on-failure";
          RestartSec = 15;
          # The 2026-11-04 lesson from strata.nix: a crashing 57 GiB address space is
          # streamed to the dump spool *before* ProcessSizeMax is consulted. No core.
          LimitCORE = "0";
        };
      };
    };

  # LAN surface only while this is a mock. Tailnet serve, the gaming guard and an
  # entry in the router are promotion steps, not part of the trial.
  services.nginx.virtualHosts."eisen.lan".locations."/deepseek/" = {
    proxyPass = "http://127.0.0.1:${toString port}/";
    proxyWebsockets = false;
    extraConfig = ''
      proxy_buffering off;
      proxy_cache off;
      proxy_read_timeout 3600s;
      proxy_send_timeout 3600s;
      client_max_body_size 0;
    '';
  };
}
