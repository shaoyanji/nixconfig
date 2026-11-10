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
      # IQ1_M (58.41 GB, 256 of 512 experts) is the served tier and the one the
      # agent loop uses: it is the only pack that finishes an agent session on
      # this card (2026-10-21, 19.4 tok/s, 11818 of 14637 prompt tokens reused).
      # IQ3_XXS (75.97) and IQ2_XS (68.15) lose the engine every time — SIGABRT
      # on the desktop persona, a silent freeze on `server` — and it is not
      # memory: IQ2 at `--max-context 16384` (636 MiB VRAM free, 50.9 GB RSS)
      # aborted on the *4K prompt* stage after ~7k tokens of chat traffic, with
      # no assertion line in the engine log and `oom_kill 0` in the journal.
      # `--no-ple` cannot be used to shrink them: the engine refuses it under
      # `--native` ("the PLE key is native too"), so PLE in IQ2/IQ3 is not a
      # separable 28 GB shard. The three configs stay on /mnt/storage, so a
      # retest after an engine fix is one ExecStart line and a restart.
      # Home: .agents/deploy/hosts/eisen.md §"Retesting a larger tier".
      ExecStart = "${strataEnv}/bin/strata-fhs -c 'source ${strataDir}/.venv/bin/activate && python -m serve.server --engine strata --config ${strataDir}/strata-coder-iq1_m.json --port ${toString port}'";
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
      # Context is host state, in the config the wrapper reads: IQ1_M runs
      # `--max-context 32768` with `--kv int8`, MTP (`--mtp …/mtp/rt`) and 24
      # engine threads. 16384 was tried on 2026-11-04 and reverted: at that
      # context every agent run stalled in prefill at turn 3 of 6 (the engine's
      # own no-progress guard, issue #29, ~9k prompt tokens), so the KV it saves
      # costs the turns an agent session needs.
    };
  };

  # Expose port 8085 for OpenAI-compatible completions
  networking.firewall.allowedTCPPorts = [port];
}
