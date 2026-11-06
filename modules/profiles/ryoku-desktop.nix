# Ryoku desktop baseline (pilot): the graphical-host services without
# `base-desktop-environment.nix`, whose niri build and DMS greeter Ryoku replaces.
# What the fork owns, and why: docs/nix-patterns.md item 11.
{
  self,
  pkgs,
  lib,
  ...
}: {
  imports = [
    self.modules."profiles.desktop-client"
    self.modules."profiles.boot"
  ];

  # No dms/dank-greeter modules in the chain or in home: two Quickshell shells
  # cannot share one session.
  fleet.dankShell.enable = false;

  programs.ryoku = {
    enable = true;
    # Stated, not inherited: this is what makes Ryoku's own module add
    # `ryotunes.cachix.org`, and its default is upstream's to change whenever.
    # Declaring the URL here instead would show the cache twice in nix.conf.
    # [[flake/policies.nix#desktop-cache-declared-once]]
    binaryCache.enable = true;
    # niri, not Hyprland: this fleet's sessions are niri-shaped.
    defaultCompositor = "niri";
    # Browser ownership stays with the host (zen is the fleet browser role).
    browser = null;
    # fish is Ryoku's upstream default; these hosts log in with zsh.
    shell = "zsh";
  };

  # Ryoku's power-profiles-daemon cannot coexist with `laptop.nix`'s auto-cpufreq;
  # the profile wins, so a host that keeps auto-cpufreq has to drop Ryoku.
  services.auto-cpufreq.enable = lib.mkForce false;

  # Ryoku wires gnome-keyring and gvfs but not the PAM half, and without it the
  # keyring stays locked for secret-service clients (agy).
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.login.enableGnomeKeyring = true;
  security.pam.services.sddm.enableGnomeKeyring = true;

  hardware.graphics = {
    enable = lib.mkDefault true;
    enable32Bit = lib.mkDefault pkgs.stdenv.hostPlatform.isx86_64;
  };
}
