# Greeter verdict for the dms feature — same call modules/profiles/impermanence.nix makes.
{lib, ...}: {
  services.displayManager.sddm = {
    enable = lib.mkDefault false;
    wayland.enable = lib.mkDefault true;
  };
}
