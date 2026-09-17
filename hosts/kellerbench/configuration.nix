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
      # base-node + steamos (which provides the cage+steam stack Sunshine
      # captures from). To disable Sunshine streaming while keeping the
      # gaming rig functional, set enableSunshine = false in the host
      # config and remove this import.
      ../../modules/profiles/sunshine.nix
    ];

  networking.hostName = "kellerbench";

  # X server is required so XWayland can host any legacy X11-only windows
  # that Steam spawns inside cage's Wayland surface. No desktop environment
  # is configured - greetd auto-logs devji into gamescope-session (cage
  # + steam -gamepadui) which is the entire user-facing UI. Gated on
  # enableSteam so enableSteam=false stays headless.
  services.xserver.enable = enableSteam;

  # Round-4 kellerbench SteamOS-kiosk override:
  # modules/profiles/steamos.nix imports modules/profiles/steam.nix which
  # sets programs.steam.gamescopeSession.enable = true. That nixpkgs option
  # auto-installs a NixOS-module-level `gamescope-session` script which
  # shadows our `customGamescopeSession` wrapper in PATH. On kellerbench
  # (Kepler sm_30 + legacy_580) the shadow forces greetd's
  # --cmd gamescope-session to fork the real gamescope binary, which
  # segfaults because the legacy_580 Vulkan ICD is incomplete (gamescope's
  # wlserver reports "Creating headless backend" then crashes).
  # Disabling here is host-scoped (NOT in the shared steamos profile) so
  # future Turing-class successors that import steamos.nix keep the
  # upstream gamescopeSession feature without a profile rewrite.
  # mkForce priority 50 wins over steam.nix's plain assignment (priority 100).
  programs.steam.gamescopeSession.enable = lib.mkForce false;

  environment.systemPackages = with pkgs; [jq];

  services.openssh.enable = true;
  system.stateVersion = "25.05";
}
