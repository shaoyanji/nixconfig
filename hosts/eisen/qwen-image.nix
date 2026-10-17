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
# only, non-commercial). The base Qwen-Image-2.1 is Apache-2.0. Turbo is
# used here because the host is a personal research box; switch the DiT
# URL to leejet/Qwen-Image-2.1-GGUF qwen_image_2.1-Q8_0.gguf for Apache-2.0.
{ config, lib, pkgs, ... }:
let
  imageDir = "/mnt/storage/image/models";

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
}
