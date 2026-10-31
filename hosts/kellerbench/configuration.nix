{
  lib,
  pkgs,
  ...
}: let
  enableSteam = true;
  enableAmdGpu = false;
in {
  imports =
    [
      (import ../../modules/profiles/grub-boot.nix {
        inherit lib;
        device = "nodev";
      })
      ./hardware-configuration.nix
    ]
    ++ lib.optionals enableAmdGpu [
      ./amd-rx-5700-xt.nix
    ]
    ++ lib.optionals (!enableAmdGpu) [
      ./nvidia-gt-750-ti.nix
    ]
    ++ lib.optionals enableSteam [
      ../../modules/profiles/steamos.nix
    ]
    ++ [
      ../../modules/profiles/base-node.nix
      # Sunshine GameStream/Moonlight server: Moonlight clients on the LAN
      # launch/control games running under kellerbench. Composes on top of
      # base-node + steamos (which provides the gamescope+steam stack Sunshine
      # captures from). To disable Sunshine streaming while keeping the
      # gaming rig functional, set enableSunshine = false in the host
      # config and remove this import.
      ../../modules/profiles/sunshine.nix
    ];

  # X server is required so XWayland can host any legacy X11-only windows
  # that Steam spawns inside gamescope's Wayland surface. No desktop environment
  # is configured - greetd auto-logs devji into gamescope-session (real
  # gamescope + steam -gamepadui) which is the entire user-facing UI. Gated on
  # enableSteam so enableSteam=false stays headless.
  services.xserver.enable = enableSteam;

  # Disable speechd (accessibility TTS) to avoid pulling in speech-dispatcher,
  # mbrola, and mbrola-voices (~1.2 GiB closure bloat on a gaming kiosk).
  services.speechd.enable = false;

  # Kiosk & headless benchmark node: strip doc/man pages (~700 MiB pipewire-doc/man).
  documentation.enable = false;
  documentation.nixos.enable = false;
  documentation.man.enable = false;
  documentation.doc.enable = false;

  environment.systemPackages = with pkgs; [jq];

  services.openssh.enable = true;
  system.stateVersion = "25.05";
}
