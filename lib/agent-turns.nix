{
  lib,
  path ? ./agent-turns/turns.json,
}: let
  data = builtins.fromJSON (builtins.readFile path);
  turns = data.turns or [];
  ids = lib.sort (a: b: a < b) (map (t: t.id or "") turns);
  expected = builtins.hashString "sha256" (lib.concatStringsSep "\n" ids + "\n");
  recorded = data.pin or "";

  entry = t: let
    id = "turn-" + builtins.substring 0 8 (t.id or "");
  in {
    inherit id;
    origin = "turn";
    kind = "turn";
    status = t.outcome or "unknown";
    title = t.subject or "";
    claim = null;
    summary = t.action or "";
    date = builtins.substring 0 10 (t.ts or "");
    refs = {
      hosts = [];
      modules = t.claims or [];
      tasks = [];
      docs = [];
    };
    links = [];
    from = [];
    supersedes = [];
    ancestors = [];
    descendants = [];
    replacedBy = [];
    leaf = true;
    lines = 1;
    body = "";
  };

  entries = lib.listToAttrs (map (t: let e = entry t; in lib.nameValuePair e.id e) turns);
in {
  inherit entries;

  api = {
    generated = data.generated or null;
    count = builtins.length turns;
    pin = {
      inherit recorded;
      computed = expected;
      ok = recorded != "" && recorded == expected;
    };
  };

  append = notes: notes // entries;
}
