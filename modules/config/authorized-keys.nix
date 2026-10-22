{lib, ...}: let
  # The fleet's one key list. Most keys come from the gist named in
  # authorized-keys.json; the literals below cover machines that are not in it.
  keysSource = builtins.elemAt (builtins.fromJSON (builtins.readFile ./authorized-keys.json)) 0;
  fetchedKeys =
    builtins.filter (key: key != "")
    (lib.splitString "\n" (builtins.readFile (builtins.fetchurl {
      inherit (keysSource) url sha256;
    })));

  sshKeys =
    fetchedKeys
    ++ [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPSf4l8am6ZRnUAXX0uinxFTW3IKm5zPFVGL8cn1/35h benutzer@bitlockerpremium"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA0PNF2ea41zmEcLNV+hk58py3LMxWjbsJV1CgO96T2I"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC6Q+UiPCzp+dhUydXWiUrVw1jnohdsBMwieAiuINaww alice@netbook"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILrvO+LslaA0+SWCvy46hUoVUifVjhtM8hXzoViIBebG u0_a301@moto-g35-5g"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFOS9RHGObNEmXWrmgry6j4NjepOYSC101CmdCtfxRVr devji@stark"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIF1XL9TzXWLtNRoO/csE9BbcYsZChMUSZPnDtFIH0eVY devji@eisen"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMptCVdbDOaPovY/J7QOicHHjThJd7GOSSMFxZg7uh04 devji@fern"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIbiJspn0JANpr2SNXCzOd7xVS2YoF35fq6wRrHf9wfB devji@delphi"
    ];
in {
  options.ssh.authorizedKeys.keys = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = sshKeys;
    description = "The fleet's one SSH authorized-key list";
  };

  # Pinned so no host can ship a divergent list (flake/policies.nix asserts it).
  config.ssh.authorizedKeys.keys = sshKeys;
}
