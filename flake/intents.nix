# Intent and capability, as data (v1.0.0rc). `flake/epistemics.nix` says which
# source may settle a claim and `flake/ontology.nix` which things a claim can be
# filed on; this file declares the *request side* — what an intent is, which
# lanes may serve it, and how the two compose.
#
# The measured motivation is AGENTS.nix `agent-lane-plane`: xs subjects are
# coordination labels, not intents — jev-decide selected 0/15 on them because
# nothing here says what the classes are. This file says it.
#
# Reader: `nix eval --json .#intents | toon -e`; gate `task checks:intents`;
# the graph projection emits `capability`/`intent` nodes and `serves` edges.
{
  lib,
  epistemics ? import ./epistemics.nix {inherit lib;},
  # Equivalence classes for intent keys — the first production consumer of
  # lib/quotient-hash.nix. Two dispatches spelling the same work land in one
  # quotient class, which is the dedup the turn ledger otherwise has no name
  # for (the steward re-sends a dispatch and the lane re-answers it).
  qh ? import ../lib/quotient-hash.nix {inherit lib;},
  # xs turn fields the schema validates against, from the committed snapshot.
  # A lane absent here is a lane the spec has never seen post.
  turns ? lib.importJSON ../lib/agent-turns/turns.json,
  # Task names a kind's `gate` must resolve to (the compiled task list).
  taskIds ? [],
}: let
  # --- the intent record ------------------------------------------------------
  # An intent is the request side of a turn arc: the coordination key, the work
  # class, the paths it may touch, and the gate that ends it. The outcome is not
  # part of the intent — it is what the arc records about it.
  intentFields = ["subject" "kind" "claims" "gate"];

  # The six work classes observed in the ledger's ACTION field. A dispatch that
  # names none of them is `drive` bookkeeping or a refusal, not a work intent.
  kinds = {
    "chain-change" = {
      what = "module and feature wiring: imports, chains, shared module surface under modules/ and hosts/";
      gate = "checks:drv-equality";
      floor = "resolved";
      persists = "the code itself, plus a decision note only when the chain's shape changed";
    };
    "gate-change" = {
      what = "the checks surface: a gate, its fixture, a script under scripts/task or a checks.yml entry";
      gate = "checks:quick";
      floor = "resolved";
      persists = "the gate and its fixture — a gate that cannot fail is no gate";
    };
    "flake-change" = {
      what = "flake wiring: outputs, inventories, input updates, derivation shape";
      gate = "checks:nix:lint";
      floor = "resolved";
      persists = "the wiring; input bumps ride the flake.lock diff, not a note";
    };
    "note-change" = {
      what = "the record: AGENTS.nix notes, docs/, a skill body — a claim about what was decided or learned";
      gate = "checks:prose";
      floor = "asserted";
      persists = "the note or page itself; the xs turn carries the landing";
    };
    "publish" = {
      what = "a rendered surface crosses the wire: a site, a doc build, content to a host";
      gate = "checks:docs:links";
      floor = "resolved";
      persists = "the deployed artifact and its generation stamp";
    };
    "drive" = {
      what = "coordination only: a steward dispatch, a claim, a pane nudge — routes work, does none";
      gate = "agents:xs:list";
      floor = "asserted";
      persists = "the turn log; a drive intent that lands code has mislabelled itself";
    };
  };
  kindIds = builtins.attrNames kinds;

  # The xs ACTION vocabulary — what a record says happened, distinct from what
  # the work IS. Turn verbs are the ledger's tense; kinds are its cases.
  verbs = {
    claim = "the lane took subject and paths before starting";
    start = "work began; the claim is live";
    landed = "work is committed; names commit and gate";
    done = "the arc closed green";
    drove = "the steward dispatched work to a pane";
    incident = "a breakage or a surprise worth the record";
    publish = "a surface was pushed live";
    blocked = "a hard stop: a credential or an operator action, named";
    "no" = "a refusal or a no-op reported honestly";
  };
  verbIds = builtins.attrNames verbs;

  # --- the capability record --------------------------------------------------
  # A capability is a lane's declared provides: the intent kinds it may admit,
  # the path prefixes it may touch (its blast radius), and the evidence floor
  # its closed turns must carry. `name` is the xs `source` string — that is the
  # identity, not a display label.
  capabilities = {
    tmux-pane-steward = {
      what = "the hermes steward: routes dispatches to panes, keeps them busy";
      provides = ["drive"];
      claims = [];
      floor = "asserted";
      via = "the steward panes on frieren/netbook";
    };
    devin = {
      what = "the refactor/engineering lane in this checkout";
      provides = ["chain-change" "gate-change" "flake-change" "note-change"];
      claims = ["modules/" "flake/" "lib/" "hosts/" "taskfiles/" "scripts/" "tests/" "docs/" "AGENTS.nix" ".agents/"];
      floor = "resolved";
      via = "the devin pane; this session";
    };
    buffy = {
      what = "the site/content lane: renders, writes, pushes surfaces";
      provides = ["publish" "note-change"];
      claims = ["docs/" "lib/" "sites/"];
      floor = "resolved";
      via = "the buffy pane";
    };
    freebuff = {
      what = "the delegated headless lane (Tier 2 cascade)";
      provides = ["chain-change" "note-change"];
      claims = ["modules/" "hosts/" "AGENTS.nix"];
      floor = "resolved";
      via = "freebuff-headless dispatch";
    };
    image-daily = {
      what = "the image pipeline's own cron lane — it closes its own gate";
      provides = ["gate-change"];
      claims = ["tools/os/internal/image" "scripts/task/drv-equality.py"];
      floor = "resolved";
      via = "the image-daily unit";
    };
    micro-turn = {
      what = "turn-ledger housekeeping posts";
      provides = ["note-change"];
      claims = ["lib/agent-turns/"];
      floor = "asserted";
      via = "the xs runtime";
    };
  };
  capabilityIds = builtins.attrNames capabilities;

  # --- composition ------------------------------------------------------------
  # admit: may this lane take this intent? Three refusals, mirroring
  # ontology.admit's verdict shape so a caller reads one contract: the kind must
  # be declared, the lane must provide it, and every claimed path must sit under
  # one of the lane's declared prefixes. A `drive` lane that admits a
  # chain-change is the failure mode this exists to refuse — "route, do not
  # execute" made a predicate.
  admit = {
    intent,
    capability,
  }: let
    cap = capabilities.${capability} or null;
    k = kinds.${intent.kind or ""} or null;
    claims = intent.claims or [];
    uncovered = claims |> builtins.filter (c: !(cap.claims |> builtins.any (p: lib.hasPrefix p c)));
    verdict = ok: why: {
      inherit (intent) subject;
      inherit (intent) kind;
      inherit capability;
      inherit ok why;
    };
  in
    if cap == null
    then verdict false "no capability '${capability}' is declared"
    else if k == null
    then verdict false "no intent kind '${toString (intent.kind or "")}' is declared"
    else if !(builtins.elem intent.kind cap.provides)
    then verdict false "${capability} does not provide ${intent.kind} (route, do not execute)"
    else if uncovered != []
    then verdict false "claims outside ${capability}'s radius: ${lib.concatStringsSep ", " uncovered}"
    else verdict true "${capability} admits ${intent.kind} under ${k.gate}";

  # The equivalence class: two dispatches with the same kind over the same
  # claims are the same intent re-sent. `classOf` is the quotient — the class a
  # steward can ask "have I already sent this" about before it re-dispatches.
  keyOf = intent: "${intent.kind}|${lib.concatStringsSep "," (builtins.sort builtins.lessThan intent.claims)}";
  classOf = intent: (qh.quotientHash {key = keyOf intent;}).quotient;

  # --- the ledger projection --------------------------------------------------
  # Observed turn sources and ACTION prefixes from the committed snapshot. A
  # source with no capability declaration is a hard gap: every lane that posts
  # must be declared. An ACTION prefix the verb table does not name is a
  # report, not a failure — the field is free prose, and the honest measure is
  # coverage, not a closed vocabulary it never had.
  observedSources = (turns.turns or []) |> map (t: t.source) |> lib.unique;
  undeclaredSources = observedSources |> builtins.filter (s: !(builtins.elem s capabilityIds));
  observedVerbs =
    (turns.turns or [])
    |> map (t: let
      m = builtins.match "^([a-z-]+)[: ].*" t.action;
    in
      if m == null
      then "?"
      else builtins.head m)
    |> lib.unique;
  undeclaredVerbs = observedVerbs |> builtins.filter (v: !(builtins.elem v verbIds));

  # The self-check the gate asserts: every declared kind's gate resolves to a
  # real task, every capability provides only declared kinds, the ledger's
  # observed sources and verbs are all declared, and every sample's admit
  # verdict is the one the schema intends.
  gateReport = let
    kindGateMisses = kindIds |> builtins.filter (k: taskIds != [] && !(builtins.elem kinds.${k}.gate taskIds));
    capKindMisses =
      capabilityIds
      |> lib.concatMap (c: capabilities.${c}.provides |> builtins.filter (p: !(builtins.elem p kindIds)) |> map (p: "${c} provides undeclared '${p}'"));
    capFloorMisses = capabilityIds |> builtins.filter (c: !(builtins.hasAttr capabilities.${c}.floor epistemics.evidence));
    samples = [
      {
        intent = {
          subject = "nixconfig:steward-devin-drive-x";
          kind = "chain-change";
          claims = ["modules/" "hosts/"];
          gate = "checks:drv-equality";
        };
        capability = "devin";
        want = true;
      }
      {
        intent = {
          subject = "nixconfig:steward-devin-drive-x";
          kind = "chain-change";
          claims = ["modules/"];
          gate = "checks:drv-equality";
        };
        capability = "tmux-pane-steward";
        want = false;
      }
      {
        intent = {
          subject = "nixconfig:buffy-publish-x";
          kind = "publish";
          claims = ["docs/" "lib/"];
          gate = "checks:docs:links";
        };
        capability = "buffy";
        want = true;
      }
      {
        intent = {
          subject = "nixconfig:freebuff-x";
          kind = "chain-change";
          claims = ["lib/agent-turns/"];
          gate = "checks:drv-equality";
        };
        capability = "freebuff";
        want = false;
      }
    ];
    verdicts = samples |> map (s: s // {got = (admit {inherit (s) intent capability;}).ok;});
    sampleMisses = verdicts |> builtins.filter (v: v.want != v.got);
    failures =
      kindGateMisses
      ++ capKindMisses
      ++ (capFloorMisses |> map (c: "${c} names an undeclared evidence floor"))
      ++ (sampleMisses |> map (v: "sample ${v.subject} on ${v.capability}: want ${toString v.want}, got ${toString v.got}"))
      ++ (undeclaredSources |> map (s: "xs source '${s}' has no capability declaration"));
  in {
    inherit kindGateMisses capKindMisses capFloorMisses sampleMisses undeclaredSources undeclaredVerbs verdicts failures;
    ok = failures == [];
  };
in {
  inherit intentFields kinds kindIds verbs verbIds capabilities capabilityIds;
  inherit admit keyOf classOf gateReport;
  inherit observedSources undeclaredSources observedVerbs undeclaredVerbs;
}
