# Remote-builder client for nixbuild.net (or any SSH builder).
#
# Off by default — enabling is one line on any host whose module chain
# includes sops-nix (every real NixOS chain; NOT globalModulesDemo):
#   profiles.nixbuild-client.enable = true;
#
# With the default useSops = true, the builder's SSH key is decrypted
# by sops-nix from modules/secrets.yaml (key: nixbuild_ssh_key) and
# placed at profiles.nixbuild-client.sshKeyPath (default
# /root/.ssh/nixbuild, root:0600) — no manual key placement.
#
# CHAIN REQUIREMENT: this module defines the `sops.secrets` path (under
# mkIf). The module system walks config paths structurally BEFORE mkIf
# conditions are evaluated, so importing this profile on a chain
# without sops-nix options fails eval even when disabled (same trap as
# modules/profiles/impermanence-greeter.nix). Conditional imports
# cannot fix this either — they recurse infinitely on `config`.
#
# Key setup (one-time):
#   1. ssh-keygen -t ed25519 -f ~/.ssh/nixbuild
#   2. Register the PUBLIC key in the nixbuild.net console
#   3. task infra:secrets:edit:secrets  → add the private key as
#        nixbuild_ssh_key: |
#          -----BEGIN OPENSSH PRIVATE KEY-----
#          ...
#   4. New hosts only: register their age key in .sops.yaml + rekey
#      (task infra:sops:update-keys) or the secret will not decrypt.
#
# Fresh installs: without a decrypted key the builder is unreachable
# and nix falls back to local builds — nothing breaks; the warm flow
# (scripts/task/nixbuild-warm.sh) starts working after the host's
# age key is registered and the host rebuilds.
#
# nixbuild.net bills per build-second (free tier: 25 h/month). Pair
# with task dev:nixbuild:warm to spend that budget warming
# shaoyanji.cachix.org for the fleet.
{
  config,
  lib,
  ...
}: let
  cfg = config.profiles.nixbuild-client;
in {
  options.profiles.nixbuild-client = {
    enable = lib.mkEnableOption "nixbuild.net distributed builds";

    useSops = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Fetch the builder SSH key from sops (secret nixbuild_ssh_key)
        instead of expecting a manually placed key at sshKeyPath.
        Requires the host's module chain to include sops-nix.
      '';
    };

    hostName = lib.mkOption {
      type = lib.types.str;
      default = "eu.nixbuild.net";
      description = "SSH hostname of the remote builder";
    };

    systems = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = ["x86_64-linux"];
      description = "Systems the builder supports";
    };

    maxJobs = lib.mkOption {
      type = lib.types.int;
      default = 100;
      description = "Concurrent jobs the builder accepts";
    };

    speedFactor = lib.mkOption {
      type = lib.types.int;
      default = 2;
      description = "Prefer the remote over local cores (>=2)";
    };

    sshKeyPath = lib.mkOption {
      type = lib.types.str;
      default = "/root/.ssh/nixbuild";
      description = "Path to the SSH key the nix daemon uses for the builder";
    };
  };

  config = lib.mkMerge [
    # Builder wiring — plain nix/ssh options, safe on every host.
    (lib.mkIf cfg.enable {
      programs.ssh.extraConfig = ''
        Host ${cfg.hostName}
          ServerAliveInterval 60
          IdentityFile ${cfg.sshKeyPath}
      '';

      programs.ssh.knownHosts.nixbuild = {
        hostNames = [cfg.hostName];
        publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPIQCZc54poJ8vqawd8TraNryQeJnvH1eLpIDgbiqymM";
      };

      nix = {
        distributedBuilds = true;
        buildMachines = [
          {
            inherit (cfg) hostName systems maxJobs speedFactor;
            supportedFeatures = ["benchmark" "big-parallel"];
            protocol = "ssh";
          }
        ];
      };
    })

    # sops wiring: mkIf (NOT a conditional import — see header). The
    # path walk needs sops-nix options in the closure, which every real
    # NixOS chain has; only globalModulesDemo lacks them.
    (lib.mkIf (cfg.enable && cfg.useSops) {
      sops.secrets."nixbuild_ssh_key" = {
        path = cfg.sshKeyPath;
        owner = "root";
        mode = "0600";
        restartUnits = ["nix-daemon.service"];
      };
    })
  ];
}
