# The inference persona: a TTY, the model, and the network. What is subtracted and
# why, plus how to pick it at boot: `.agents/deploy/hosts/eisen.md` ("Boot
# personas").
{lib, ...}: {
  # --- No graphical target ---------------------------------------------
  # Even with every session package gone, a stray `services.displayManager.enable`
  # would still put `systemd.unit=graphical.target` on the kernel command line and
  # wait for a login screen that cannot exist. Pin all three.
  services.displayManager.enable = lib.mkForce false;
  services.displayManager.sddm.enable = lib.mkForce false;
  services.displayManager.autoLogin.enable = lib.mkForce false;
  # greetd is the kiosk launcher on the default persona (it starts
  # `steam-gamescope`): it goes with the session, or the persona still ships a
  # launcher for a Steam that is not enabled here.
  services.greetd.enable = lib.mkForce false;
  services.xserver.enable = lib.mkForce false;
  systemd.defaultUnit = lib.mkForce "multi-user.target";

  # The gaming persona's default session (`lib.mkForce "steam"` in
  # configuration.nix) is a *validated* value: nixpkgs asserts it names a session
  # in `sessionPackages`, and Steam provides none once it is disabled below.
  # mkOverride 10, not mkForce: both sides are forced, and a forced value cannot
  # beat a forced value — the override priority has to go one step higher.
  services.displayManager.defaultSession = lib.mkOverride 10 null;

  # --- No shell, no games ----------------------------------------------
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
  # The kiosk persona forces 1920x1080@60 on HDMI-A-1 so gamescope has a known
  # output. This persona only ever writes to the console, so the TTY comes up on
  # whatever the plug (or an empty port) advertises. Keep the two params that are
  # hardware, not display: PCIe cold-reboot recovery and ASPM off.
  boot.kernelParams = lib.mkForce [
    "reboot=pci,cold"
    "pcie_aspm=off"
  ];
}
