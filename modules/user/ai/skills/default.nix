{lib, ...}: let
  skillsDir = ./.;
  # Scan all directories in this folder (excluding default.nix and hidden files)
  skillEntries = lib.filterAttrs (
    name: type:
      type == "directory" && name != "default.nix" && !(lib.hasPrefix "." name)
  ) (builtins.readDir skillsDir);
  skillNames = builtins.attrNames skillEntries;
in {
  # Declaratively symlink skills into:
  # 1. ~/.agents/skills/<name> (workspace & local agent discovery)
  # 2. ~/.gemini/config/skills/<name> (Antigravity global skill discovery)
  home.file = lib.listToAttrs (
    lib.concatMap (name: [
      {
        name = ".agents/skills/${name}";
        value = {
          source = "${skillsDir}/${name}";
          recursive = true;
        };
      }
      {
        name = ".gemini/config/skills/${name}";
        value = {
          source = "${skillsDir}/${name}";
          recursive = true;
        };
      }
    ])
    skillNames
  );
}
