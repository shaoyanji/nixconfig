# Strata — Niko1221/Strata MoE LLM inference (Qwen3.8-Flash-Next) on Eisen's AMD RX 5700.
# Runs inside an isolated FHS environment on /mnt/storage/strata so host Mesa/RADV Vulkan stays clean.
{pkgs, ...}: let
  port = 8085;
  strataDir = "/mnt/storage/strata";

  # FHS environment providing standard C/C++ runtimes and isolated dynamic linking for ROCm wheels
  strataEnv = pkgs.buildFHSEnv {
    name = "strata-fhs";
    targetPkgs = p:
      with p; [
        gcc.cc
        glibc.dev
        zlib
        git
        cmake
        ninja
        python3
      ];
    runScript = "bash";
  };
in {
  systemd.services.strata = {
    description = "Strata MoE LLM Inference Engine (ROCm HIP gfx1010)";
    after = ["network-online.target"];
    wants = ["network-online.target"];
    wantedBy = ["multi-user.target"];

    environment = {
      ROCR_VISIBLE_DEVICES = "0";
      HIP_VISIBLE_DEVICES = "0";
      SSL_CERT_FILE = "/etc/ssl/certs/ca-bundle.crt";
      STRATA_ALLOWED_HOSTS = "*";
    };

    serviceConfig = {
      Type = "simple";
      User = "devji";
      Group = "users";
      SupplementaryGroups = ["video" "render"];
      WorkingDirectory = strataDir;
      ExecStart = "${strataEnv}/bin/strata-fhs -c 'source ${strataDir}/.venv/bin/activate && python -m serve.server --engine strata --config ${strataDir}/strata-coder-iq1_m.json --port ${toString port}'";
      Restart = "on-failure";
      RestartSec = 10;
    };
  };

  # Expose port 8085 for OpenAI-compatible completions
  networking.firewall.allowedTCPPorts = [port];
}
