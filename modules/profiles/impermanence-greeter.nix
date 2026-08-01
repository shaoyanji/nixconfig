# dms/niri greeter for impermanence desktop hosts.
#
# Import this alongside modules/profiles/impermanence.nix ONLY on hosts
# that have dms in their closure (e.g. schneeeule on globalModulesNixos).
# noDE hosts (Steam kiosks like ares on globalModulesContainers) must NOT
# import this — the `programs.dank-material-shell` option does not exist
# in their closure and would fail eval with "option does not exist".
_:
let
  user = import ../global/user.nix;
in
{
  programs.dank-material-shell.greeter = {
    enable = true;
    compositor.name = "niri";
    configHome = user.home;
  };
}
