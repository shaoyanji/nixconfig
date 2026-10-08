# Decommissioned AI-host reference (2026-09): the agent-era modules
# (nullclaw, hermes, xs, pancakes-harness, ai-services-*) were removed from
# the repo. mtfuji keeps ollama and the btrfs subvol mounts for the
# nullclaw/ollama data that still lives on disk.
{
  fileSystems = {
    "/var/lib/nullclaw" = {
      device = "/dev/disk/by-uuid/3829936d-db07-4b77-b89a-46a2476578ce";
      fsType = "btrfs";
      options = ["subvol=nix/nullclaw" "compress=zstd" "noatime"];
    };
    "/var/lib/ollama" = {
      device = "/dev/disk/by-uuid/3829936d-db07-4b77-b89a-46a2476578ce";
      fsType = "btrfs";
      options = ["subvol=nix/ollama" "compress=zstd" "noatime"];
    };
  };

  services.ollama.enable = true;
}
