# Gate: task checks:host; regression: task checks:sops:key-coverage:test.
# Reads key names from committed YAML such as modules/secrets.yaml; never decrypts.
{
  config,
  lib,
  ...
}: let
  # Nested `key` attrs are declared in modules/sops.nix; keep intermediate and leaf paths.
  yamlKeyPaths = text: let
    lines = lib.splitString "\n" text;
    step = state: line: let
      matched = builtins.match "^([ ]*)([A-Za-z0-9_.-]+):([[:space:]].*)?$" line;
    in
      if matched == null
      then state
      else let
        indent = lib.stringLength (builtins.elemAt matched 0);
        key = builtins.elemAt matched 1;
        keep = builtins.filter (part: part.indent < indent) state.parts;
        path = lib.concatStringsSep "/" (map (part: part.key) keep ++ [key]);
      in {
        parts = keep ++ [{inherit indent key;}];
        paths = state.paths ++ [path];
      };
  in
    (builtins.foldl' step {
        parts = [];
        paths = [];
      }
      lines).paths;

  secrets = config.sops.secrets or {};
  missing =
    lib.mapAttrsToList (name: secret: {
      inherit name;
      inherit (secret) key;
      file = toString secret.sopsFile;
    })
    (lib.filterAttrs (
        _: secret:
          (secret.format or "yaml")
          == "yaml"
          && secret.key != ""
          && (
            !(builtins.pathExists secret.sopsFile)
            || !(builtins.elem secret.key (yamlKeyPaths (builtins.readFile secret.sopsFile)))
          )
      )
      secrets);
in {
  config = lib.mkIf (secrets != {}) {
    assertions = [
      {
        assertion = missing == [];
        message = ''
          sops key coverage failed: a declared secret key is absent from its encrypted YAML file.
          The check reads key names only; nothing is decrypted.
          ${lib.concatMapStringsSep "\n" (m: "  - sops.secrets.${lib.strings.escapeNixIdentifier m.name} key '${m.key}' missing from ${m.file}") missing}
        '';
      }
    ];
  };
}
