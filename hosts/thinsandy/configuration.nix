{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  enableHermes = true;
  enableOpenClaw = true;
  enableNullClaw = true;
in {
  imports =
    [
      ./hardware-configuration.nix
      ../common/minimal-desktop.nix
      inputs.nix-openclaw.nixosModules.openclaw-gateway
      inputs.sops-nix.nixosModules.sops
      ./hardware.nix
      ./media-stack.nix
      ./tools.nix
      ./networking.nix
    ]
    ++ lib.optionals enableOpenClaw [
      ./openclaw.nix
    ]
    ++ lib.optionals enableNullClaw [
      ./nullclaw.nix
    ]
    ++ lib.optionals enableHermes [
      inputs.nix-hermes.nixosModules.hermes-agent
      ./hermes.nix
    ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "thinsandy";
  nixpkgs.overlays =
    []
    ++ lib.optionals enableOpenClaw [
      inputs.nix-openclaw.overlays.default
    ]
    ++ lib.optionals enableHermes [
      (final: prev: {
        hermes-agent = final.callPackage ../../pkgs/hermes-agent.nix {
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

    "/var/lib/nullclaw/workspace/share" = {
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
