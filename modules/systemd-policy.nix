# modules/systemd-policy.nix — per-host systemd classification gate: every user
# unit universally, system units that declare X-Fleet-Role. Runs inside every host
# evaluation; contract in docs/nix-patterns.md "Service module conventions".
{
  config,
  lib,
  pkgs,
  osConfig ? null,
  ...
}: let
  policy = import ../lib/systemd-policy.nix {inherit lib;};

  # The capability that makes session units meaningful: the profile that installs
  # the compositor (modules/profiles/base-desktop-environment.nix) sets it, and a
  # headless generation (frieren's boot default) never imports that profile.
  sessionDeclared =
    pkgs.stdenv.hostPlatform.isLinux
    && osConfig != null
    && (osConfig.programs.niri.enable or false);

  userViolations = policy.userUnitViolations {
    services = config.systemd.user.services;
    timers = config.systemd.user.timers;
    inherit sessionDeclared;
  };

  systemViolations =
    if osConfig != null
    then policy.markedSystemViolations {services = osConfig.systemd.services;}
    else [];

  violations = userViolations ++ systemViolations;
in {
  assertions = [
    {
      assertion = violations == [];
      message = ''
        systemd classification gate (lib/systemd-policy.nix):
          ${lib.concatStringsSep "\n  " violations}'';
    }
  ];
}
