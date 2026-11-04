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
    unitConfig = {
      X-Fleet-Role = "daemon";
      # Card off the bus = nothing to serve. Without this the unit reloads the
      # model every 11 s for as long as the GPU is absent (2026-11-03).
      ConditionPathExists = "/dev/dri/renderD128";
      StartLimitBurst = 3;
      StartLimitIntervalSec = 300;
    };
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
      # IQ2_XS (68.15 GB, all 512 experts) — the tier the model card calls its
      # standout, and the last candidate `strata-quant-tier` was holding open.
      # IQ3_XXS measured at median 12.2 tok/s against IQ1_M's 14.6-21.0 and lost
      # the engine on the agent suite; this is the one that fits the cache budget.
      ExecStart = "${strataEnv}/bin/strata-fhs -c 'source ${strataDir}/.venv/bin/activate && python -m serve.server --engine strata --config ${strataDir}/strata-coder-iq2_xs.json --port ${toString port}'";
      Restart = "on-failure";
      RestartSec = 10;
      # Never dump core. The kernel streams a crashing process's whole address
      # space into systemd-coredump's spool *before* ProcessSizeMax is consulted:
      # one 2026-11-04 abort of this unit drove / from 44 GB to 94 GB used for
      # five minutes, until the dump unit hit its runtime limit and was killed and
      # the spool file went with it. RLIMIT_CORE=0 means the dump never starts;
      # the wrapper's "the engine had stopped (exit code -6)" line and the journal
      # are what actually get read after a crash.
      LimitCORE = "0";
    };
  };

  # Expose port 8085 for OpenAI-compatible completions
  networking.firewall.allowedTCPPorts = [port];
}
