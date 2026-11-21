# Why every tracked file exists; `task checks:provenance` fails a path that
# matches no class. First match wins; rules honor flake/policies.nix#nix-comments-are-pointers.
{
  classes = [
    "nix-source"
    "exec-source"
    "prose"
    "fixture"
    "app-source"
    "asset"
    "config"
    "secret"
    "ledger"
  ];
  rules = [
    {
      class = "secret";
      prefixes = ["modules/secrets/"];
      files = [".sops.yaml"];
      suffixes = [".enc.yaml"];
    }
    {
      class = "ledger";
      files = ["lib/agent-turns/turns.json"];
    }
    {
      class = "fixture";
      prefixes = ["tests/"];
    }
    {
      class = "nix-source";
      prefixes = [
        "flake/"
        "hosts/"
        "modules/"
        "lib/"
        "overlays/"
        "templates/"
      ];
      files = [
        "flake.nix"
        "flake.lock"
        "AGENTS.nix"
        "inventory.toml"
        "modules.toml"
        "closure-budgets.toml"
        "statix.toml"
      ];
      suffixes = [".nix"];
    }
    {
      class = "exec-source";
      prefixes = [
        "taskfiles/"
        "scripts/"
      ];
      files = ["Taskfile.yml"];
    }
    {
      class = "prose";
      prefixes = [
        "docs/"
        "ideas/"
        ".agents/"
      ];
      suffixes = [".md"];
    }
    {
      class = "app-source";
      prefixes = [
        "projects/"
        "tools/"
        "decks/"
      ];
    }
    {
      class = "asset";
      suffixes = [
        ".png"
        ".jpg"
        ".jpeg"
        ".pdf"
        ".woff2"
        ".ico"
      ];
    }
    {
      class = "config";
      prefixes = [
        ".github/"
        ".githooks/"
      ];
      files = [
        ".envrc"
        ".git-hooks-setup.sh"
        ".gitattributes"
        ".gitignore"
        ".gitmodules"
        "LICENSE"
        "README.md"
        "pkgs.txt"
      ];
    }
  ];
}
