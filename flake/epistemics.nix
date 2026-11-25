# Authority over a claim, as data: `settles` per source, a route per transport, a
# measured `spend` per claim kind. Rationale: AGENTS.nix `epistemics-declared`;
# reader `task ops:claim:check`, gate `checks.<system>.epistemics`.
{
  lib,
  # Where a snapshot was cut. A frozen source's ability to settle a claim about
  # "now" ends here, and that is a property of the archive, not of the question.
  asOf ? "2026-11-04",
  # The Kelly arithmetic is not restated here: flake/daemons.nix owns the formula
  # and this is its second consumer. Same expression, different unit (tokens
  # earned against tokens spent, where a daemon earns seconds).
  daemons ? import ./daemons.nix {inherit lib;},
}: let
  sources = {
    "repo-docs" = {
      what = "this tree — docs/, skills, AGENTS.nix, modules/*.nix";
      standing = "authored";
      volatility = "live";
      vintage = asOf;
      settles = ["fleet-fact" "procedure" "decision" "software-behaviour"];
      routes = {
        local = {
          how = "grep/qmd this tree";
          cost = 40;
          offline = true;
          metered = "none";
          fanout = true;
        };
      };
    };
    "vault-claims" = {
      what = "the zettelkasten's `## Claim` sections, carrying their own status";
      standing = "authored";
      volatility = "live";
      vintage = asOf;
      settles = ["personal-method" "decision" "project-fact"];
      routes = {
        local = {
          how = "the `## Claim` sections of ~/vaults/personal";
          cost = 80;
          offline = true;
          metered = "none";
          fanout = true;
        };
      };
    };
    "zim-shelf" = {
      what = "Kiwix ZIM archives on frieren (Wikipedia nopic, ArchWiki, Alpine)";
      standing = "snapshot";
      volatility = "frozen";
      vintage = "2026-06";
      settles = ["software-behaviour" "config-syntax" "definition" "historical-fact"];
      routes = {
        frieren = {
          how = "task ops:wiki:ask Q=... (one archive, one passage)";
          cost = 250;
          # No internet egress: the shelf is a store path. That is why it is the
          # first thing to try when a metered surface would otherwise be asked.
          offline = true;
          metered = "none";
          fanout = true;
        };
      };
    };
    "upstream-repo" = {
      what = "a third-party repository's own files at a pinned rev, read through the GitHub API rather than a rendered page";
      standing = "authored";
      volatility = "live";
      vintage = asOf;
      settles = ["upstream-declaration" "software-behaviour" "config-syntax" "current-release"];
      routes = {
        # The route is a REPO-WIDE search on purpose. "Ryoku ships no cache" was
        # answered from one fetch of its flake.nix, where nixConfig would have
        # listed it — but the substituter is declared in a module and in the
        # installer, so the answer was wrong and the host's real value (the
        # retired Ryoku profile's `binaryCache.enable`) went unchecked. A search
        # across the repository costs one request and cannot miss a module.
        "repo-search" = {
          how = "gh api -X GET search/code -f q='<term> repo:<owner>/<repo>' — then read the file at the rev that matched";
          cost = 80;
          offline = false;
          metered = "upstream";
          fanout = true;
        };
      };
    };
    "jev-decide" = {
      what = "a decision model's label for one request (TypeSafe Jev), with its probability and margin";
      standing = "unvetted";
      volatility = "live";
      vintage = "2026-11-17";
      settles = ["model-label"];
      routes = {
        classify = {
          how = "jev-decide classify --provider typesafe --text <request> --criteria <labels>";
          cost = 400;
          offline = false;
          metered = "quota";
          fanout = false;
        };
      };
    };
    "web" = {
      what = "the live internet — unversioned, unattributed, and somebody's quota";
      standing = "unvetted";
      volatility = "live";
      vintage = asOf;
      settles = ["current-release" "historical-fact" "definition" "software-behaviour" "config-syntax"];
      routes = {
        # Self-hosted SearXNG on the tailnet: ours to fan out, but the engines
        # behind it throttle delphi's address, so the label is `upstream`, not
        # `none` — there is no free search, only one nobody bills us for.
        "searx-tailnet" = {
          how = "curl -s 'https://delphi.cloudforest-kardashev.ts.net:8447/search?q=<urlencoded>&format=json'";
          cost = 120;
          offline = false;
          metered = "upstream";
          fanout = true;
          # Live since 2026-11-04: delphi switched with `search.formats =
          # ["html" "json"]`, and `format=json` answers 200 with results from
          # this fleet (measured from frieren; it answered 403 html-only before).
          # A route that cannot answer is declared with `needs`, not assumed to
          # work — this one no longer needs anything.
        };
        # The same search on envs.net's public instance, for the case the route
        # above cannot cover at all: delphi down, or a client with no tailnet,
        # where today there is no search here. HTML ONLY (measured 2026-11-05:
        # `format=json` is 403 on that instance, the page is 200 with ~23
        # results in 0.15 s, `a.url_header` and `h3` carry URL and title), so the
        # caller pays for a parse and the cost says so.
        "searx-envs" = {
          how = "curl -s 'https://searx.envs.net/search?q=<urlencoded>' and read the result links (a.url_header, h3) — this instance serves no format=json";
          cost = 220;
          offline = false;
          metered = "upstream";
          # Sequential only: a community instance, and a fallback asking it in
          # parallel is a fallback that gets the fleet throttled.
          fanout = false;
        };
        "web-search" = {
          how = "web_search, then read the page";
          cost = 800;
          offline = false;
          metered = "quota";
          fanout = false;
        };
      };
    };
  };
  sourceIds = ["repo-docs" "vault-claims" "zim-shelf" "upstream-repo" "web" "jev-decide"];

  # --- precedence ------------------------------------------------------------
  # Epistemics outranks policy: a policy is a JUDGMENT ("this protects
  # something"), a fact is not, so a fact can invalidate a judgment and never the
  # reverse. The override is itself a fact — `because` says what the rule fails to
  # protect, `evidence` is what makes that true — so it cannot silence a gate: the
  # failure is still reported, with the fact attached.
  # Rationale: AGENTS.nix `epistemics-declared`.
  overrides = {};

  # --- the claim shapes ------------------------------------------------------
  # `volatility` is a property of the CLAIM: does the answer move on its own?
  #
  # `persist` is where the distilled answer is FILED, and it is the reason the
  # ladder gets cheaper over time: an expensive read that lands in an authored
  # source is a cheap read forever after. A finding with nowhere to go is a
  # finding that will be researched again.
  kinds = {
    "software-behaviour" = {
      volatility = "stable";
      evidenceFloor = "resolved";
      what = "how a program behaves, its flags and formats";
      persist = "a vault claim citing the passage, or a skill line if it changes what an agent does";
    };
    "config-syntax" = {
      volatility = "stable";
      evidenceFloor = "resolved";
      what = "the shape of a config file or directive";
      persist = "a vault claim citing the passage — the syntax is the claim";
    };
    "definition" = {
      volatility = "stable";
      evidenceFloor = "asserted";
      what = "what a term means";
      persist = "a vault claim, so the next question is a lookup";
    };
    "historical-fact" = {
      volatility = "stable";
      evidenceFloor = "resolved";
      what = "what happened, and when";
      persist = "a vault claim with the date and the source";
    };
    "current-release" = {
      volatility = "moving";
      evidenceFloor = "resolved";
      what = "the version, default or state of something today";
      persist = "nothing durable — record the date and version in the answer, not the corpus";
    };
    "personal-method" = {
      volatility = "stable";
      evidenceFloor = "asserted";
      what = "how I work, and why";
      persist = "the doc that governs how we work, or a new `## Claim` in the vault with its status";
    };
    "decision" = {
      volatility = "stable";
      evidenceFloor = "asserted";
      what = "what this fleet chose to do";
      persist = "an AGENTS.nix note (kind=decision) plus the doc the decision governs";
    };
    "project-fact" = {
      volatility = "stable";
      evidenceFloor = "asserted";
      what = "a fact about my own projects";
      persist = "a `## Claim` in the vault";
    };
    "procedure" = {
      volatility = "stable";
      evidenceFloor = "asserted";
      what = "the steps to accomplish something here";
      persist = "docs/, a skill body, or a playbook row — a procedure an agent cannot follow is a paragraph";
    };
    "fleet-fact" = {
      volatility = "stable";
      evidenceFloor = "resolved";
      what = "a compiled fact about these hosts";
      persist = "the compiled source (inventory.toml or the module), never a prose copy";
    };
    "model-label" = {
      volatility = "moving";
      evidenceFloor = "extracted";
      what = "which playbook a request belongs to, as a probability";
      persist = "the turn log, with the label and its margin — never a fact";
    };
    "upstream-declaration" = {
      volatility = "moving";
      evidenceFloor = "resolved";
      what = "what a third-party project declares or omits — a substituter, a default, a pin — and what our host therefore inherits by using it. An ABSENCE is the claim that needs the most care: one file answering 'no' is not evidence, because the declaration is usually in a module the flake does not mention";
      persist = "an AGENTS.nix note only when it changes what this fleet does; cite the rev, because the project's own file is the record and it moves";
    };
  };
  kindIds = ["software-behaviour" "config-syntax" "definition" "historical-fact" "current-release" "personal-method" "decision" "project-fact" "procedure" "fleet-fact" "upstream-declaration" "model-label"];

  rankOf = tier:
    if builtins.hasAttr tier evidence
    then evidence.${tier}.rank
    else 99;

  carries = kind: tier:
    builtins.hasAttr kind kinds
    && builtins.hasAttr tier evidence
    && rankOf tier <= rankOf kinds.${kind}.evidenceFloor;

  canCarry = tier: kindIds |> builtins.filter (k: carries k tier);

  standingTier = {
    authored = 0;
    snapshot = 1;
    unvetted = 2;
  };
  # Whose quota a consultation spends. This is the resource axis: `none` costs
  # nothing but our own CPU, and everything else has a ceiling somebody enforces.
  meteredTier = {
    none = 0;
    upstream = 1;
    quota = 2;
    paid = 3;
  };

  evidence = {
    asserted = {
      rank = 0;
      producedBy = "person";
      what = "a person wrote it down; it holds because it was declared, not because a tool confirmed it";
      cannot = "that the world agrees: an assertion is accountable, not verified — read the artifact it predicts";
      promote = "the artifact it names exists and is referenced from the compiled source: a task, a module, a gate";
    };
    resolved = {
      rank = 1;
      producedBy = "compiler";
      what = "the far end was looked up in a registry and exists; the link is proven, the meaning is not";
      cannot = "intent or agreement: a resolved id proves the target exists, never that the sentence about it is true";
      promote = "a person adopts the resolved target in a declaration — asserted is stronger for intent, resolved for existence, and neither is both";
    };
    extracted = {
      rank = 2;
      producedBy = "machine";
      what = "a token or an import path matched the text; a candidate for a relation, never a proof";
      cannot = "a relation: the same word can name two things, and an import can sit on a branch no host enables";
      promote = "resolve the match — parse the frontmatter, look the id up in its registry, or read the file — and it becomes the resolved tier";
    };
  };
  evidenceIds = ["asserted" "resolved" "extracted"];

  noteClaims = {
    decision = "decision";
    proposal = "decision";
    open = "project-fact";
    experiment = "project-fact";
    handoff = "procedure";
    reference = "definition";
  };

  # --- measured settling rates ----------------------------------------------
  # Only where somebody ran the measurement. `save` is what going elsewhere would
  # have cost, so `ev` is in tokens: expected tokens saved minus expected tokens
  # spent on a miss. A negative `ev` is a source that looks authoritative and is
  # not worth the money, which is exactly what a 0.7% hit rate is.
  spend = {
    "zim-shelf" = {
      "personal-method" = {
        p = 0.007;
        save = 800.0;
        measured = "2026-11-04 · every `## Claim` in the vault run verbatim (141): 1 supported";
      };
      "software-behaviour" = {
        # Selection-biased: eight concrete queries were picked because the shelf
        # was expected to cover them. Recorded as an upper bound, not a rate.
        p = 0.5;
        save = 800.0;
        measured = "2026-11-04 · 8 concrete software queries, hand-picked (biased high): 4 supported";
      };
    };
  };

  # --- routes ----------------------------------------------------------------
  # Cheapest route first: unmetered before metered, then price. A source is only
  # ever consulted through its preferred route unless a caller overrides it.
  # `or 99` rather than a crash: an unlabelled `metered` is a mistake the check
  # reports by name (`routes.<r>.metered must be none/upstream/quota/paid`), and a
  # missing-attribute error at the sort would hide that message.
  preferredRoute = src: let
    ranked =
      (src.routes |> lib.mapAttrsToList (n: v: v // {name = n;}))
      |> lib.sort (a: b: let
        ka = (meteredTier.${a.metered} or 99) * 10000 + a.cost;
        kb = (meteredTier.${b.metered} or 99) * 10000 + b.cost;
      in
        ka < kb);
  in
    ranked |> builtins.head;

  spendFor = name: kind:
    (spend.${name} or {}).${kind} or null;

  # --- the four refusals -----------------------------------------------------
  judge = kind: name: let
    src = sources.${name};
    k = kinds.${kind};
    route = preferredRoute src;
    s = spendFor name kind;
    ev =
      if s == null
      then null
      else daemons.ev s.p s.save route.cost;
    base = {
      inherit name;
      inherit (route) cost offline metered fanout how;
      inherit ev;
    };
  in
    if !(builtins.elem kind src.settles)
    then
      base
      // {
        go = false;
        why = "no authority over ${kind}";
      }
    else if k.volatility == "moving" && src.volatility == "frozen"
    then
      base
      // {
        go = false;
        # Its silence and its agreement are equally uninformative here.
        why = "frozen at ${src.vintage}; a snapshot cannot settle a moving fact";
      }
    else if ev != null && ev <= 0.0
    then
      base
      // {
        go = false;
        why = "kelly ${lib.strings.floatToString ev}: measured p ${lib.strings.floatToString s.p} does not pay for ${toString route.cost} tokens";
      }
    else
      base
      // {
        go = true;
        # Standing first (who is accountable), then whose quota, then price.
        key = standingTier.${src.standing} * 1000000 + meteredTier.${route.metered} * 10000 + route.cost;
        why = "${src.standing}, ${src.volatility}, ${route.metered}";
      };

  forKind = kind: let
    verdicts = sourceIds |> map (judge kind);
    permitted =
      verdicts
      |> builtins.filter (v: v.go)
      |> lib.sortOn (x: x.key);
    strip = v: {
      inherit (v) name cost why offline metered fanout ev;
    };
    first =
      if permitted == []
      then null
      else (permitted |> builtins.head);
  in {
    inherit kind;
    read =
      if first == null
      then null
      else first.name;
    next =
      if first == null
      then "nothing declared can settle this: ask a person, or measure it"
      else first.how;
    # Where the answer goes once it is known — the step that makes the next
    # lookup an offline one.
    inherit (kinds.${kind}) persist;
    floor = kinds.${kind}.evidenceFloor;
    evidenceRank = rankOf kinds.${kind}.evidenceFloor;
    order = permitted |> map strip;
    never =
      verdicts
      |> builtins.filter (v: !v.go)
      |> map strip;
  };

  table =
    kindIds
    |> map (k: {
      name = k;
      value = forKind k;
    })
    |> builtins.listToAttrs;

  review = claim: let
    t =
      table.${claim.kind}
      or (throw "epistemics: unknown claim kind '${claim.kind}', known: ${lib.concatStringsSep ", " kindIds}");
  in
    t
    // {inherit (claim) text;}
    // (
      if !(claim ? evidence)
      then {}
      else if !(builtins.hasAttr claim.evidence evidence)
      then {
        evidence = {
          inherit (claim) evidence;
          ok = false;
          why = "unknown evidence tier; declared: ${lib.concatStringsSep ", " evidenceIds}";
        };
      }
      else {
        evidence = {
          inherit (claim) evidence;
          inherit (kinds.${claim.kind}) evidenceFloor;
          ok = carries claim.kind claim.evidence;
          promote = evidence.${claim.evidence}.promote;
        };
      }
    );

  samples = [
    {
      text = "btrfs scrub repairs from redundancy using checksums";
      kind = "software-behaviour";
    }
    {
      text = "niri reads ~/.config/niri/config.kdl";
      kind = "config-syntax";
    }
    {
      text = "WireGuard was merged in Linux 5.6";
      kind = "historical-fact";
    }
    {
      text = "the newest systemd release drops SysV init support";
      kind = "current-release";
    }
    {
      text = "a flat checkbox todo list is the lowest-friction capture layer";
      kind = "personal-method";
    }
    {
      text = "frieren runs the ZIM shelf";
      kind = "fleet-fact";
    }
  ];
in {
  inherit sources kinds judge table review samples sourceIds kindIds asOf spend;
  inherit evidence evidenceIds noteClaims carries canCarry;
  inherit overrides;
  # The precedence as a function, so the gate applies it rather than re-deriving
  # "is this overridden" in a second place.
  overturns = ids: ids |> builtins.filter (id: !(overrides ? ${id}));
  overturnedBy = id: overrides.${id} or null;
  overturned = overrides |> builtins.attrNames;
  all = samples |> map review;
  # The resource ladder, independent of any claim: which transports exist, what
  # they spend, and whether they may be asked many times at once.
  routes = sources |> lib.mapAttrs (_: s: s.routes |> lib.mapAttrs (_: r: r));
  unsettleable = table |> builtins.attrValues |> builtins.filter (k: k.order == []) |> builtins.catAttrs "kind";
  # A kind that can be settled but whose answer has nowhere to live is researched
  # forever; this is empty by construction, and the check keeps it that way.
  persistable = table |> builtins.attrValues |> builtins.filter (k: k.persist == "") |> builtins.catAttrs "kind";
}
