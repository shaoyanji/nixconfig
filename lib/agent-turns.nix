{
  lib,
  path ? ./agent-turns/turns.json,
}: let
  data = path |> builtins.readFile |> builtins.fromJSON;
  turns = data.turns or [];
  ids = turns |> map (t: t.id or "") |> lib.sort (a: b: a < b);
  expected = ids |> lib.concatStringsSep "\n" |> (s: s + "\n") |> builtins.hashString "sha256";
  recorded = data.pin or "";

  entry = t: let
    id = "turn-" + ((t.id or "") |> builtins.substring 0 8);
  in {
    inherit id;
    origin = "turn";
    kind = "turn";
    status = t.outcome or "unknown";
    title = t.subject or "";
    claim = null;
    summary = t.action or "";
    date = (t.ts or "") |> builtins.substring 0 10;
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

  entries = turns |> map (t: let e = entry t; in lib.nameValuePair e.id e) |> lib.listToAttrs;
in {
  inherit entries;

  api = {
    generated = data.generated or null;
    count = turns |> builtins.length;
    pin = {
      inherit recorded;
      computed = expected;
      ok = recorded != "" && recorded == expected;
    };
  };

  append = notes: notes // entries;
}
