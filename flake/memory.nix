# The fleet memory/recall map as compiled data — one row per layer. The host
# preamble restates the search order in prose; this is the machine-readable
# table the prose points at. `nix eval --json .#memoryLayers.layers | toon -e`.
{lib}: let
  layers = [
    {
      id = "xs";
      role = "coordination";
      store = "delphi postgres :8449 (append-only turns)";
      authority = "live coordination claims — who is doing what, right now";
      access = "task agents:xs:list";
    }
    {
      id = "notes";
      role = "design-record";
      store = "AGENTS.nix";
      authority = "repo decisions, proposals, open work — schema-gated, kg nodes";
      access = "task ops:notes";
    }
    {
      id = "kg";
      role = "structure";
      store = ".#knowledgeGraph";
      authority = "what touches what — structural facts only";
      access = "task ops:kg";
    }
    {
      id = "qmd";
      role = "recall";
      store = "qmd index over docs + code";
      authority = "search hits — cites, never truth itself";
      access = "qmd";
    }
    {
      id = "vault";
      role = "personal-prose";
      store = "/Volumes/data/Obsidian-Git-Sync";
      authority = "personal zettels — never repo facts";
      access = "Obsidian-Git-Sync";
    }
    {
      id = "deep";
      role = "deep-consult";
      store = "mem0 + supermemory REST, keys in hermes.env";
      authority = "advisory recall — Jev-selected, never authority";
      access = "hermes.env";
    }
    {
      id = "ai-memory";
      role = "scratch";
      store = "wiki + SQLite, :49374 (no unit — cold start)";
      authority = "none — never authority for a repo fact";
      access = "pkgs.llm-agents.ai-memory";
    }
    {
      id = "persona";
      role = "boot-context";
      store = "modules/user/ai/hermes-persona/ -> ~/.hermes";
      authority = "session boot context — priming, not facts";
      access = "~/.hermes";
    }
  ];

  ids = map (l: l.id) layers;

  # Eval-time self-consistency: unique ids, and every row carries all fields.
  complete = l: (l ? id) && (l ? role) && (l ? store) && (l ? authority) && (l ? access);
in
  assert ids == lib.unique ids; {
    inherit layers ids;
    complete = lib.all complete layers;
  }
