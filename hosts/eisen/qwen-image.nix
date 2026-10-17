# Qwen-Image-2.1-Turbo — image generation / editing on Eisen.
#
# Pipeline (all GGUF/safetensors from Hugging Face, weights in designated
# storage, NOT the Nix store):
#   DiT (diffusion)  qwen-image-2.1-turbo-Q8_0.gguf  ~7-8 GB  (unsloth, Turbo, 8-step schedule)
#   Text encoder      Qwen3VL-8B-Instruct-Q4_K_M.gguf  ~5 GB    (Qwen, shared with the base)
#   VAE decoder       qwen_image_2.1_vae_bf16.safetensors ~0.68 GB (Comfy-Org)
#   mmproj (editing)  mmproj-Qwen3VL-8B-Instruct-F16.gguf ~1.1 GB (Qwen, vision tower)
#
# Runner: stable-diffusion.cpp (leejet, llama.cpp sibling for diffusion).
# License: the Turbo checkpoint is Qwen Research License (research/eval
# only, non-commercial). Non-commercial use on this host, so the license
# is a non-issue; Turbo is kept because it is the best in class (8-step
# schedule, same quality as the 40-step base). The base Qwen-Image-2.1
# (Apache-2.0, leejet/Qwen-Image-2.1-GGUF qwen_image_2.1-Q8_0.gguf) is the
# fallback if the license ever matters.
#
# Endpoints:
#   LAN:      http://eisen.lan/images/v1/images/generations (nginx :80 -> 127.0.0.1:8282)
#   Tailnet:  https://eisen.<tailnet>.ts.net:8445/v1/images/generations
# 8282 stays bound to loopback; nginx and `tailscale serve` are the only
# ways in, so there is no firewall allowance for it. (image.eisen.lan is
# NOT wired — frieren's pi-hole only maps eisen.lan itself, not subdomains;
# the /images/ merge into eisen.lan avoids a frieren DNS change.)
{ config, lib, pkgs, ... }:
let
  imageDir = "/mnt/storage/image/models";
  port = 8282;

  # stable-diffusion.cpp, pinned to a commit with Qwen-Image 2.1 support.
  # nixpkgs' stable-diffusion-cpp pins 656a135 (2026-09-18), which predates
  # sd.cpp's day-0 Qwen-Image 2.1 support (2026-09-20). Override the src to
  # f0aac52 (2026-10-17 master) and keep nixpkgs' build (CMake + ggml +
  # Vulkan). fetchSubmodules=true is REQUIRED (ggml is a submodule; without
  # it cmake/ggml.cmake fails on get_target_property). vulkanSupport=true
  # via .override (adds the Vulkan buildInputs + SD_VULKAN=ON; nixpkgs
  # defaults to CPU-only). sha256 is fakeHash — the build error prints the
  # correct hash for the submodule-inclusive fetch; update it and rebuild.
  sdCpp = (pkgs.stable-diffusion-cpp.override { vulkanSupport = true; }).overrideAttrs (old: {
    version = "2026-10-17-f0aac52";
    src = pkgs.fetchFromGitHub {
      owner = "leejet";
      repo = "stable-diffusion.cpp";
      rev = "f0aac524d3f29140e60ba78f3cfb16d6acea87db";
      fetchSubmodules = true;
      sha256 = lib.fakeHash;
    };
  });

  # Idempotent, resumable weight fetch — runs only when the file is absent.
  # Same pattern as llm-server.nix mkFetch.
  mkFetch = {
    file,
    url,
  }: {
    description = "Fetch ${file} if missing";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
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
in
{
  systemd.tmpfiles.rules = [
    "d ${imageDir} 0755 devji users - -"
  ];

  systemd.services."eisen-image-dit" = mkFetch {
    file = "${imageDir}/qwen-image-2.1-turbo-Q8_0.gguf";
    url = "https://huggingface.co/unsloth/Qwen-Image-2.1-Turbo-GGUF/resolve/main/qwen-image-2.1-turbo-Q8_0.gguf";
  };

  systemd.services."eisen-image-encoder" = mkFetch {
    file = "${imageDir}/Qwen3VL-8B-Instruct-Q4_K_M.gguf";
    url = "https://huggingface.co/Qwen/Qwen3-VL-8B-Instruct-GGUF/resolve/main/Qwen3VL-8B-Instruct-Q4_K_M.gguf";
  };

  systemd.services."eisen-image-vae" = mkFetch {
    file = "${imageDir}/qwen_image_2.1_vae_bf16.safetensors";
    url = "https://huggingface.co/Comfy-Org/Qwen-Image-2.1/resolve/main/vae/qwen_image_2.1_vae_bf16.safetensors";
  };

  systemd.services."eisen-image-mmproj" = mkFetch {
    file = "${imageDir}/mmproj-Qwen3VL-8B-Instruct-F16.gguf";
    url = "https://huggingface.co/Qwen/Qwen3-VL-8B-Instruct-GGUF/resolve/main/mmproj-Qwen3VL-8B-Instruct-F16.gguf";
  };

  # --- Image service: OpenAI-compatible /v1/images/generations ------------
  # Stdlib-HTTP wrapper (qwen-image-server.py) translating the request into
  # an sd-cli invocation (Turbo: --sigmas qwen-image-2.1-turbo --steps 8
  # --cfg-scale 1.0 --sampling-method euler --offload-to-cpu). The wrapper
  # serializes generations (one at a time). sd-cli loads the weights per
  # request, so the wrapper itself is lightweight and starts at boot.
  # VRAM split: the encoder runs on CPU (one-shot text encode), the DiT on
  # GPU (the 8-step denoising loop), the VAE on CPU (one-shot decode) —
  # --offload-to-cpu lets sd.cpp place what doesn't fit in 8 GB VRAM.
  systemd.services."qwen-image" = {
    description = "Qwen-Image-2.1-Turbo image server (OpenAI-compatible, :8282)";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.python3}/bin/python ${./qwen-image-server.py}";
      Environment = [
        "PORT=${toString port}"
        "SD_CLI=${lib.getExe' sdCpp "sd-cli"}"
        "DIT=${imageDir}/qwen-image-2.1-turbo-Q8_0.gguf"
        "ENCODER=${imageDir}/Qwen3VL-8B-Instruct-Q4_K_M.gguf"
        "VAE=${imageDir}/qwen_image_2.1_vae_bf16.safetensors"
        "MMPROJ=${imageDir}/mmproj-Qwen3VL-8B-Instruct-F16.gguf"
      ];
      Restart = "on-failure";
      RestartSec = "5s";
      DynamicUser = true;
      PrivateTmp = true;
    };
  };

  # --- LAN: http://eisen.lan/images/v1/images/generations -----------------
  # Merges into the eisen.lan vhost declared in llm-server.nix; the
  # /images/ prefix is stripped by the trailing slash on proxyPass, so the
  # service sees /v1/images/generations. (Same pattern as parakeet /stt/.)
  services.nginx.virtualHosts."eisen.lan".locations."/images/" = {
    proxyPass = "http://127.0.0.1:${toString port}/";
    extraConfig = ''
      # A Turbo generation can take minutes on the first run (cold weights).
      proxy_read_timeout 900s;
      proxy_send_timeout 900s;
      client_max_body_size 25m;
    '';
  };

  # --- Tailnet: https://eisen.<tailnet>.ts.net:8445/v1/images/generations -
  # Node serve (same pattern as tailscale-serve-node in llm-server.nix).
  # Idempotent — re-applying the same target is a no-op.
  systemd.services."tailscale-serve-image" = {
    description = "Serve Qwen-Image on the node's tailnet HTTPS name (:8445)";
    after = [
      "tailscaled.service"
      "tailscaled-autoconnect.service"
    ];
    wants = [ "tailscaled.service" ];
    wantedBy = [ "multi-user.target" ];
    partOf = [ "tailscaled.service" ];
    unitConfig = {
      StartLimitIntervalSec = 300;
      StartLimitBurst = 30;
    };
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStartPre = pkgs.writeShellScript "wait-for-tailscale-image" ''
        until ${pkgs.tailscale}/bin/tailscale status >/dev/null 2>&1; do sleep 2; done
      '';
      ExecStart = "${pkgs.tailscale}/bin/tailscale serve --bg --https=8445 http://127.0.0.1:${toString port}";
    };
  };
}
