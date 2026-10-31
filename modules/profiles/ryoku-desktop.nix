# Ryoku desktop baseline (pilot). The desktop-client services a graphical host
# needs, without `base-desktop-environment.nix` — that profile enables niri and
# assumes the DMS greeter runs under greetd, both of which Ryoku replaces.
#
# Ryoku owns its compositor build (mkForce on programs.niri.package), its session
# packages, portals, keyring, fonts and SDDM theme, so this profile deliberately
# declares none of those: the point of the pilot is to measure what Ryoku brings.
{
  pkgs,
  lib,
  ...
}: {
  imports = [
    ./desktop-client.nix
    ./boot.nix
  ];

  # No dms/dank-greeter modules in the chain (globalModulesRyoku), and no DMS
  # home modules either: two Quickshell shells cannot share one session.
  fleet.dankShell.enable = false;

  programs.ryoku = {
    enable = true;
    # niri, not Hyprland: this fleet's sessions are niri-shaped.
    defaultCompositor = "niri";
    # Browser ownership stays with the host (zen is the fleet browser role).
    browser = null;
    # fish is Ryoku's upstream default; these hosts log in with zsh.
    shell = "zsh";
  };

  # Ryoku enables power-profiles-daemon (mkDefault true) and NixOS asserts it
  # cannot coexist with auto-cpufreq, which `laptop.nix` turns on for fern.
  # Ryoku's power surface is the one this desktop exposes, so the daemon pair
  # resolves in its favour; a host that keeps auto-cpufreq has to drop Ryoku.
  services.auto-cpufreq.enable = lib.mkForce false;

  # Ryoku sets up gnome-keyring and gvfs itself; the PAM wiring it does not do,
  # and without it the keyring stays locked for secret-service clients (agy).
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.login.enableGnomeKeyring = true;
  security.pam.services.sddm.enableGnomeKeyring = true;

  hardware.graphics = {
    enable = lib.mkDefault true;
    enable32Bit = lib.mkDefault pkgs.stdenv.hostPlatform.isx86_64;
  };
}
