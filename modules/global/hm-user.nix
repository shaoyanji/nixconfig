# `user` inside the home-manager module system.
#
# The NixOS/darwin evaluation gets the constants through `_module.args`
# (flake/module-sets.nix). Home Manager is a nested `evalModules` with its own
# arguments, so the outer injection does not reach it: this module is listed in
# `home-manager.sharedModules` by every embedded chain
# (`global.home-manager-shared`, `global.noDE`, `global.demo`) and supplies the
# same value there. A standalone home-manager host needs nothing extra — its
# chain carries `flake/module-sets.nix`'s injection directly.
{self, ...}: {
  _module.args.user = import self.modules."global.user";
}
