# The kitchen-workstation face of frieren: niri media centre on the Samsung 4K,
# driven through the Dell D6000 dock. Only applied by `specialisation.desktop`;
# the boot default is the headless server config in configuration.nix.
{lib, ...}: let
  user = import ../../modules/global/user.nix;
in {
  imports = [../../modules/profiles/base-desktop-environment.nix];

  # nixpkgs' graphical-desktop module mkDefault-enables speechd for any desktop,
  # which drags in speech-dispatcher -> mbrola voices (~650 MiB, measured
  # 2026-10-17). Nothing here uses a speech daemon.
  services.speechd.enable = false;

  # greetd's initial_session (DMS greeter) runs niri straight away; the greeter
  # is the fallback when the session exits.
  services.displayManager.defaultSession = "niri";
  programs.dms-greeter = {
    enable = true;
    compositor.name = "niri";
    configHome = user.home;
  };

  # DisplayLink/EVDI video, dlm, and the USB-autosuspend exemptions that keep
  # the dock's DisplayLink ASIC and Bluetooth alive.
  profiles.dell-dock.enable = true;

  # Media-centre lid policy: lock the session, keep the server up. mkForce
  # because the headless base in configuration.nix pins HandleLidSwitch = ignore.
  services.logind.settings.Login = {
    HandleLidSwitch = lib.mkForce "lock";
    HandleLidSwitchDocked = "ignore";
    HandleLidSwitchExternalPower = "lock";
  };
}
