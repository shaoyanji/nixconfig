# eisen — Parakeet Redux speech-to-text (ONNX, CPU-only), its own endpoint.
#
# Parakeet Redux is Moondream's 1.58-bit ternary version of NVIDIA's
# parakeet-tdt-0.6b-v3 (600M params, 25 languages incl. German). The ONNX
# export used here is the COMMUNITY export eschmidbauer/parakeet-redux-onnx
# on Hugging Face — NOT Moondream-official, treat as experiment. The
# transcribe pipeline (preprocessor -> encoder -> greedy decoder_joint loop,
# VAD cuts >30 s audio at pauses) is vendored verbatim from that repo's
# transcribe.py into parakeet-transcribe.py; parakeet-server.py is the thin
# HTTP wrapper around it.
#
# It deliberately does NOT go through llama-swap (llama-swap execs
# llama-server; Parakeet is ONNX). CPU-only: the RX 5700 has no ROCm and ONNX
# has no Vulkan path for this model. ~1 GB resident, serialised requests.
#
# Exposure:
#   * LAN:   http://eisen.lan/stt/transcribe   (nginx :80 -> 127.0.0.1:8091)
#   * Direct: http://eisen:8091/transcribe     (loopback only; no firewall port)
{
  config,
  lib,
  pkgs,
  ...
}: let
  port = 8091;
  modelDir = "/mnt/storage/parakeet";

  hfBase = "https://huggingface.co/eschmidbauer/parakeet-redux-onnx/resolve/main";

  # ONNX export files. Sizes from the export's README: preprocessor 1.2 MB,
  # encoder 344 MB, decoder_joint 73 MB, vad 18 MB (~436 MB total).
  parakeetFiles = [
    "preprocessor.onnx"
    "encoder-model.onnx"
    "decoder_joint-model.onnx"
    "vad-model.onnx"
    "vocab.txt"
    "config.json"
  ];

  # Idempotent, resumable weight fetch — runs only when the file is absent.
  # Same shape as mkFetch in llm-server.nix (curl, ConditionPathExists).
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

  fetchUnits = map (f: "eisen-parakeet-${f}.service") parakeetFiles;

  # Python environment: onnxruntime + numpy only (the reference pipeline's
  # inference deps). No pip/uv — Nix resolves everything into /nix/store.
  parakeetEnv = pkgs.python3.withPackages (ps: [
    ps.onnxruntime
    ps.numpy
  ]);

  # The service binary: vendored pipeline + HTTP wrapper assembled into one
  # derivation, launched with the Nix-packaged interpreter.
  parakeetApp = pkgs.runCommand "parakeet-stt-1.0" { } ''
    mkdir -p $out/bin $out/lib/parakeet_stt
    cp ${./parakeet-transcribe.py} $out/lib/parakeet_stt/transcribe.py
    cp ${./parakeet-server.py} $out/lib/parakeet_stt/server.py
    cat > $out/bin/parakeet-server <<EOF
    #!${pkgs.runtimeShell}
    export PYTHONPATH=$out/lib
    exec ${parakeetEnv}/bin/python -m parakeet_stt.server "\$@"
    EOF
    chmod +x $out/bin/parakeet-server
  '';
in
{
  # Model weight repository on the persistent storage array.
  systemd.tmpfiles.rules = [
    "d ${modelDir} 0755 devji users - -"
  ];

  systemd.services = lib.listToAttrs (
    map (
      f:
      lib.nameValuePair "eisen-parakeet-${f}" (mkFetch {
        file = "${modelDir}/${f}";
        url = "${hfBase}/${f}";
      })
    ) parakeetFiles
  ) // {
    parakeet-stt = {
    description = "Parakeet Redux speech-to-text (ONNX, CPU-only)";
    after = fetchUnits ++ [
      "mnt-storage.mount"
      "network-online.target"
    ];
    wants = fetchUnits ++ [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    # ffmpeg on PATH for decoding non-wav audio (read_audio in the pipeline).
    path = [ pkgs.ffmpeg ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${parakeetApp}/bin/parakeet-server --model-dir ${modelDir} --bind 127.0.0.1 --port ${toString port} --threads 8";
      Restart = "always";
      RestartSec = 5;
    };
    };
  };

  # --- LAN: http://eisen.lan/stt/* (nginx :80 -> 127.0.0.1:8091) -----------
  # Merges into the eisen.lan vhost declared in llm-server.nix; the /stt/
  # prefix is stripped by the trailing slash on proxyPass, so the service
  # sees /transcribe and /health.
  services.nginx.virtualHosts."eisen.lan".locations."/stt/" = {
    proxyPass = "http://127.0.0.1:${toString port}/";
    extraConfig = ''
      # A transcription can take a while on long clips — don't time out.
      proxy_read_timeout 600s;
      proxy_send_timeout 600s;
      client_max_body_size 25m;
    '';
  };
}
