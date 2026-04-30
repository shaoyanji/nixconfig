# Boot configuration profile
# Provides standardized boot loader configuration for NixOS hosts
# Usage:
#   imports = [ ../../modules/profiles/boot.nix ];
#   profiles.boot.systemd-boot = true;
#   profiles.boot.efi = true;
{
  config,
  lib,
  ...
}: {
  options.profiles.boot = {
    systemd-boot = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable systemd-boot loader";
    };

    efi = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable EFI variables for boot loader";
    };
  };

  config = {
    boot.loader.systemd-boot.enable = config.profiles.boot.systemd-boot;
    boot.loader.efi.canTouchEfiVariables = config.profiles.boot.efi;
  };
}