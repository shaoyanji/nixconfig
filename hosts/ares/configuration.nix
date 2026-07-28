{ config, lib, pkgs, ... }:
let
  # ares is now a desktop Steam kiosk (see flake/host-inventory.nix for
  # the 2026-Q3 T440p → desktop case move note).  Flags below mirror
  # kellerbench's enableSteam toggles so adding/removing sub-features
  # is a single boolean flip.
  enableSteam = true;
  enableNvidiaGpu = true;
  enableSunshine = true;
in
{
  imports =
    [
      ./hardware-configuration.nix
      # modules/profiles/impermanence.nix stays imported even on the
      # Steam-kiosk rewrite because it owns the btrfs impermanence
      # initrd systemd unit (boot.initrd.systemd.services.impermanence-root)
      # and the system-level environment.persistence."/persist/system"
      # symlink list (including /etc/nixos, /var/log, /etc/NetworkManager
      # /system-connections, etc) that the desktop rebuild relies on.
      # The host-scoped `programs.dank-material-shell.greeter.enable =
      # lib.mkForce false` override below masks the only block in that
      # profile we don't want (dms-greeter initial_session conflict
      # with steamos's gamescope-session default_session).
      ../../modules/profiles/impermanence.nix
      ../../modules/profiles/base-node.nix
    ]
    ++ lib.optionals enableNvidiaGpu [
      ./nvidia-gt-750-ti.nix
    ]
    ++ lib.optionals enableSteam [
      ../../modules/profiles/steamos.nix
    ]
    ++ lib.optionals enableSunshine [
      ../../modules/profiles/sunshine.nix
    ];

  networking.hostName = "ares";
  system.stateVersion = "25.05";

  # X server is required so XWayland can host any legacy X11-only windows
  # that Steam spawns inside cage's Wayland surface. No desktop environment
  # is configured - greetd auto-logs devji into gamescope-session (cage
  # + steam -gamepadui) which is the entire user-facing UI. Gated on
  # enableSteam so enableSteam=false stays headless.
  services.xserver.enable = enableSteam;

  # Round-4 kellerbench SteamOS-kiosk override, applied host-scoped on
  # ares too because ares carries the same Kepler sm_30 + legacy_580
  # dGPU:
  # modules/profiles/steamos.nix imports modules/profiles/steam.nix
  # which sets programs.steam.gamescopeSession.enable = true. That
  # nixpkgs option auto-installs a NixOS-module-level `gamescope-session`
  # script which shadows our `customGamescopeSession` wrapper in PATH.
  # On Kepler + legacy_580 the shadow forces greetd's
  # --cmd gamescope-session to fork the real gamescope binary, which
  # segfaults because the legacy_580 Vulkan ICD is incomplete
  # (gamescope's wlserver reports "Creating headless backend" then
  # crashes).  Disabling here is host-scoped (NOT in the shared steamos
  # profile) so future Turing-class successors that import steamos.nix
  # keep the upstream gamescopeSession feature without a profile
  # rewrite.  mkForce priority 50 wins over steam.nix's plain
  # assignment (priority 100).
  programs.steam.gamescopeSession.enable = lib.mkForce false;

  # impermanence.nix (still imported above for the btrfs setup) sets
  # `programs.dank-material-shell.greeter.enable = true`, which makes
  # the dms greeter compose greetd's `initial_session` so its login UI
  # pops up before default_session.  steamos.nix sets
  # default_session.user = "devji" + command = "gamescope-session"
  # for kiosk auto-login, so dms greeter must be OFF or the user
  # stops on a dms login screen instead of dropping straight into
  # steam -gamepadui.  mkForce (priority 50) wins over impermanence.nix's
  # plain assignment (priority 100).
  programs.dank-material-shell.greeter.enable = lib.mkForce false;

  # TODO(migration): hosts/ares/hardware-configuration.nix was generated
  # for the T440p laptop and contains laptop-specific kernel modules
  # (ehci_pci, usbhid, usb_storage, sr_mod, sdhci).  When the next
  # onsite rebuild on the new desktop case runs, regenerate via
  # `nixos-generate-config` against the live desktop hardware and
  # commit the replacement.  Until then the file evaluates and boots
  # the desktop fine — the unrelated modules are inert.

  environment.systemPackages = [];
}
