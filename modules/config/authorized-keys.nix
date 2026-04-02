{
  config,
  lib,
  ...
}: let
  # Load authorized keys from centralized config
  keysConfig = builtins.fromJSON (builtins.readFile ../config/authorized-keys.json);
  sshKeys =
    builtins.filter
    (x: x != [])
    (
      builtins.split "\n"
      (
        builtins.readFile
        (
          builtins.fetchurl {
            url = (builtins.elemAt keysConfig 0).url;
            sha256 = (builtins.elemAt keysConfig 0).sha256;
          }
        )
      )
    );
in {
  options.ssh.authorizedKeys = {
    keys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = sshKeys;
      description = "SSH authorized keys loaded from centralized config";
    };
  };

  config.ssh.authorizedKeys.keys = sshKeys;
}
