# dms/niri greeter for impermanence desktop hosts.
{user, ...}: {
  programs.dms-greeter = {
    enable = true;
    compositor.name = "niri";
    configHome = user.home;
  };
}
