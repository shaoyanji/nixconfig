{ lib, ... }:
let
  # Load authorized keys from centralized config
  keysConfig = builtins.fromJSON (builtins.readFile ../config/authorized-keys.json);
  fetchedKeys =
    builtins.filter
      (x: x != [ ])
      (
        builtins.split "\n"
          (
            builtins.readFile
              (
                builtins.fetchurl {
                  inherit ((builtins.elemAt keysConfig 0)) url;
                  inherit ((builtins.elemAt keysConfig 0)) sha256;
                }
              )
          )
      );

  # Repo-side extra keys. benutzer@bitlockerpremium is a Windows machine
  # (not a NixOS host) that SSHes into the fleet — appended here rather
  # than in the gist so the repo is the reviewable source for it. The
  # second key is the Bitwarden-stored SSH key (no comment field on the
  # key itself).
  sshKeys =
    fetchedKeys
    ++ [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPSf4l8am6ZRnUAXX0uinxFTW3IKm5zPFVGL8cn1/35h benutzer@bitlockerpremium"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA0PNF2ea41zmEcLNV+hk58py3LMxWjbsJV1CgO96T2I"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC6Q+UiPCzp+dhUydXWiUrVw1jnohdsBMwieAiuINaww alice@netbook"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILrvO+LslaA0+SWCvy46hUoVUifVjhtM8hXzoViIBebG u0_a301@moto-g35-5g"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFOS9RHGObNEmXWrmgry6j4NjepOYSC101CmdCtfxRVr devji@stark"
    ];
in
{
  options.ssh.authorizedKeys = {
    keys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = sshKeys;
      description = "SSH authorized keys loaded from centralized config";
    };
  };

  config.ssh.authorizedKeys.keys = sshKeys;
}
