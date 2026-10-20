# dms/niri greeter for impermanence desktop hosts.
_: let
  user = import ../global/user.nix;
in {
  programs.dms-greeter = {
    enable = true;
    compositor.name = "niri";
    configHome = user.home;
  };
}
