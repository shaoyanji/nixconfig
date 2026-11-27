# Greeter verdict for the dms feature — same call modules/profiles/impermanence.nix makes.
{
  lib,
  user,
  ...
}: {
  services.displayManager.sddm = {
    enable = lib.mkDefault false;
    wayland.enable = lib.mkDefault true;
  };

  programs.dms-greeter = {
    enable = lib.mkDefault true;
    compositor.name = lib.mkDefault "niri";
    configHome = lib.mkDefault user.home;
  };
}
