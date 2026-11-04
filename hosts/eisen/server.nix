# The inference face of eisen: a TTY, the model, and the network. No greeter, no
# compositor, no gamescope, no Steam, no capture server.
#
# Applied by `specialisation.server` (configuration.nix); the boot default stays
# the Ryoku/gamescope gaming desktop. Both toplevels live in one generation, so
# picking this persona needs no rebuild: choose the "specialisation server" entry
# in the systemd-boot menu, or `nixos-rebuild switch --specialisation server` on
# a running box.
#
# Everything below subtracts, because that is where this host's inference value
# is: the desktop stack's ~450-500 MiB of idle VRAM (hosts/eisen/MANUAL.md §3,
# which Strata would rather spend on resident experts), the Steam client +
# gamescope + greeter's few GiB of RAM (page cache for the mmapped expert
# arena), and the threads they leave idle between frames.
{lib, ...}: {
  # --- No graphical target ---------------------------------------------
  # Even with every session package gone, a stray `services.displayManager.enable`
  # would still put `systemd.unit=graphical.target` on the kernel command line and
  # wait for a login screen that cannot exist. Pin all three.
  services.displayManager.enable = lib.mkForce false;
  services.displayManager.sddm.enable = lib.mkForce false;
  services.displayManager.autoLogin.enable = lib.mkForce false;
  services.xserver.enable = lib.mkForce false;
  systemd.defaultUnit = lib.mkForce "multi-user.target";

  # The gaming persona's default session (`lib.mkForce "steam"` in
  # configuration.nix) is a *validated* value: nixpkgs asserts it names a session
  # in `sessionPackages`, and Steam provides none once it is disabled below.
  # mkOverride 10, not mkForce: both sides are forced, and a forced value cannot
  # beat a forced value — the override priority has to go one step higher.
  services.displayManager.defaultSession = lib.mkOverride 10 null;

  # --- No shell, no games ----------------------------------------------
  programs.ryoku.enable = lib.mkForce false; # niri session, portals, greeter theme
  programs.steam.enable = lib.mkForce false; # Steam client and the `steam` session
  programs.steam.gamescopeSession.enable = lib.mkForce false;
  programs.gamescope.enable = lib.mkForce false;
  programs.gamemode.enable = lib.mkForce false;

  # Sunshine captures a session; there is none here to capture, and its encoder
  # holds VRAM the model wants.
  services.sunshine.enable = lib.mkForce false;

  # The guard stops the model when a Steam game starts. No game can start in this
  # persona, so its 15 s walk of every /proc/*/exe is pure overhead.
  systemd.services."llama-swap-gaming-guard".enable = lib.mkForce false;

  # --- The dummy plug stops mattering ----------------------------------
  # The desktop persona forces 1920x1080@60 on HDMI-A-1 so gamescope has a known
  # output. This persona only ever writes to the console, so the TTY comes up on
  # whatever the plug (or an empty port) advertises. Keep the two params that are
  # hardware, not display: PCIe cold-reboot recovery and ASPM off.
  boot.kernelParams = lib.mkForce [
    "reboot=pci,cold"
    "pcie_aspm=off"
  ];
}
