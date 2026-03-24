{flake-utils}: {
  default = flake-utils.lib.defaultSystems;
  checks = ["x86_64-linux"];
}
