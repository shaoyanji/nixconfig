# NixOS home-manager embedded configuration.
{self, ...}: {
  imports = [
    self.modules."global.home-manager-shared"
  ];

  # home-manager.extraSpecialArgs lives in global.home-manager-shared: the
  # passthrough was byte-identical here and in global.macos. This file keeps
  # only the overlay nixos adds on top of the shared baseline.
  config.nixpkgs.overlays = [
    (import self.nixFiles.overlays."nushell-plugins-compat.nix")
  ];
}
