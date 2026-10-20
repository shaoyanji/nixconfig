# Fleet-wide skill materialization.
{lib, ...}: let
  # This file is modules/user/ai/skills/default.nix — four levels below the
  # repo root (skills → ai → user → modules → root).
  repoSkills = ../../../../.agents/skills;
  runtimeSkills = ./.;

  dirsOf = p:
    builtins.attrNames (
      lib.filterAttrs (name: type: type == "directory" && !(lib.hasPrefix "." name))
      (builtins.readDir p)
    );

  # Runtime wins on a name collision: it is the tree that carries scripts.
  names = lib.unique (dirsOf repoSkills ++ dirsOf runtimeSkills);
  sourceFor = name:
    if builtins.pathExists (runtimeSkills + "/${name}")
    then runtimeSkills + "/${name}"
    else repoSkills + "/${name}";
in {
  home.file =
    lib.listToAttrs (
      lib.concatMap (name: let
        source = sourceFor name;
      in [
        {
          name = ".agents/skills/${name}";
          value = {
            inherit source;
            recursive = true;
            force = true;
          };
        }
        {
          name = ".gemini/config/skills/${name}";
          value = {
            inherit source;
            recursive = true;
            force = true;
          };
        }
      ])
      names
    )
    // {
      # A clone-less agent still gets the contract and the router. The index is
      # compiled (`nix eval .#agentSkills`), not copied here.
      ".agents/README.md".source = ../../../../.agents/README.md;
      ".agents/SCHEMA.md".source = ../../../../.agents/SCHEMA.md;
    };
}
