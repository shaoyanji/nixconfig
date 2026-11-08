# `user` inside the nested home-manager evalModules, which the outer
# `_module.args` injection in flake/module-sets.nix does not reach; the embedded
# chains list this in `home-manager.sharedModules`.
{self, ...}: {
  _module.args.user = import self.modules."global.user";
}
