# Remote-builder client for nixbuild.net (or any SSH builder).
#
# Off by default — enable on machines that should dispatch builds:
#   profiles.nixbuild-client.enable = true;
#
# nixbuild.net bills per build-second; the free tier is 25 h/month.
# Pair with scripts/task/nixbuild-warm.sh (task dev:nixbuild:warm) to
# spend that budget warming shaoyanji.cachix.org for the fleet.
#
# Key setup (one-time):
#   1. Create an SSH key for the builder: ssh-keygen -t ed25519 -f ~/.ssh/nixbuild
#   2. Register the key in the nixbuild.net console
#   3. Either keep the key in ~/.ssh/nixbuild (mode 0600) or add it to
#      modules/secrets.yaml and source it via sops-nix before dispatch
#
# Notes:
#   - trusted-users: the builder must be able to write to the local
#     store; root's daemon does the writes, but the connecting user
#     needs @wheel-style trust — base-node grants @wheel already.
#   - speedFactor > 1 makes nix prefer the remote over local cores.
{ config
, lib
, ...
}:
let
  cfg = config.profiles.nixbuild-client;
in
{
  options.profiles.nixbuild-client = {
    enable = lib.mkEnableOption "nixbuild.net distributed builds";

    hostName = lib.mkOption {
      type = lib.types.str;
      default = "eu.nixbuild.net";
      description = "SSH hostname of the remote builder";
    };

    systems = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "x86_64-linux" ];
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

  config = lib.mkIf cfg.enable {
    programs.ssh.extraConfig = ''
      Host ${cfg.hostName}
        ServerAliveInterval 60
        IdentityFile ${cfg.sshKeyPath}
    '';

    programs.ssh.knownHosts.nixbuild = {
      hostNames = [ cfg.hostName ];
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPIQCZc54poJ8vqawd8TraNryQeJnvH1eLpIDgbiqymM";
    };

    nix = {
      distributedBuilds = true;
      buildMachines = [
        {
          hostName = cfg.hostName;
          systems = cfg.systems;
          maxJobs = cfg.maxJobs;
          speedFactor = cfg.speedFactor;
          supportedFeatures = [ "benchmark" "big-parallel" ];
          protocol = "ssh";
        }
      ];
    };
  };
}
