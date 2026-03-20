{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  enableHermes = true;
in {
  imports =
    [
      ./hardware-configuration.nix
      ../common/minimal-desktop.nix
      inputs.nix-openclaw.nixosModules.openclaw-gateway
      inputs.sops-nix.nixosModules.sops
      ./hardware.nix
      ./media-stack.nix
      ./openclaw.nix
      ./tools.nix
      ./networking.nix
    ]
    ++ lib.optionals enableHermes [
      inputs.nix-hermes.nixosModules.hermes-agent
      ./hermes.nix
    ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "thinsandy";
  nixpkgs.overlays =
    [
      inputs.nix-openclaw.overlays.default
    ]
    ++ lib.optionals enableHermes [
      (final: prev: {
        hermes-agent = final.callPackage ./pkgs/hermes-agent.nix {
          src = inputs.hermes-src;
          version = "main";
        };
      })
    ];
  services.openclaw-gateway.config.channels.telegram.tokenFile =
    config.sops.secrets."vanta-telegram".path;

  fileSystems = {
    "/var/lib/openclaw/.openclaw/workspace/share" = {
      device = "/srv/data/openclaw";
      options = ["bind"];
    };

    "/var/lib/hermes/workspace/share" = {
      device = "/srv/data/openclaw";
      options = ["bind"];
    };
  };
  system.stateVersion = "25.05";
}
