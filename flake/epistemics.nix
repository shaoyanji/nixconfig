# flake/epistemics.nix — which source may settle which claim, as data.
#
# The question a regex cannot answer is "is it worth reading the wiki article?"
# A match score measures textual overlap between a claim and a title, and those
# are different things. Whether a source is ENTITLED to settle a claim is a
# property of the source and of the claim — authority over a kind of knowledge,
# whether the answer can move under the source's feet, and who is accountable
# if it is wrong. So it is declared here and compiled, and the agent receives
# an ordinal answer in TOON (`toon -e` at the boundary, per
# [[flake/policies.nix#agent-boundary-is-toon]]) instead of a confidence number
# it has to interpret.
#
# The measurement that forced this into data. Every `## Claim` in the vault was
# run verbatim through the ZIM shelf on 2026-11-04: 1 of 141 supported, 22
# spurious passages (a SOPS claim quoted "Victoria's Secret"). The cause was not
# ranking. Those claims are `personal-method` — assertions about how a person
# works — and no encyclopedia article can settle one. That is a `go: false`
# knowable before a single token is spent, and 141 runs to learn it was 140 too
# many.
#
# Deliberately NOT here: a score. A number would be a guess with a version
# number, and the failure mode this replaces is exactly a threshold nobody can
# justify. The decision is ordinal — which source to read, in what order — and
# the only quantity is cost, which is measurable.
{
  lib,
  # Where the snapshot was cut. A frozen source's ability to settle a claim about
  # "now" ends here, and that is a property of the archive, not of the question.
  asOf ? "2026-11-04",
}: let
  # --- the sources -----------------------------------------------------------
  # volatility  frozen: a cut snapshot, cannot speak about what changed since
  #             live:   maintained, can be stale, can be read as current
  # standing    authored: a person asserts it and is accountable
  #             snapshot: a copy of someone else's text, no one to ask
  #             unvetted: fetched live, unattributed, unversioned
  # settles     the claim KINDS this source is authoritative for. Absence is a
  #             refusal, not a low score: no amount of extra matching words
  #             buys authority a source does not have.
  # cost        tokens to consult. The tie-break among permitted sources, never
  #             the reason one is permitted.
  #
  # `settles` is a permission, not a coverage promise. A permitted source that
  # comes back empty does not falsify the claim; it means the imperative
  # question ("does this text contain it") is still open.
  sources = {
    "repo-docs" = {
      what = "this tree — docs/, skills, AGENTS.nix, modules/*.nix";
      standing = "authored";
      volatility = "live";
      vintage = asOf;
      cost = 40;
      how = "grep/qmd this tree";
      settles = ["fleet-fact" "procedure" "decision" "software-behaviour"];
    };
    "vault-claims" = {
      what = "the zettelkasten's `## Claim` sections, carrying their own status";
      standing = "authored";
      volatility = "live";
      vintage = asOf;
      cost = 80;
      how = "the `## Claim` sections of ~/vaults/personal";
      settles = ["personal-method" "decision" "project-fact"];
    };
    "zim-shelf" = {
      what = "Kiwix ZIM archives on frieren (Wikipedia nopic, ArchWiki, Alpine)";
      standing = "snapshot";
      volatility = "frozen";
      vintage = "2026-06";
      cost = 250;
      how = "task ops:wiki:ask Q=... (one archive, one passage)";
      settles = ["software-behaviour" "config-syntax" "definition" "historical-fact"];
    };
    "web" = {
      what = "the live internet, unversioned and rate-limited";
      standing = "unvetted";
      volatility = "live";
      vintage = asOf;
      cost = 800;
      how = "web_search, then read the page";
      settles = ["current-release" "historical-fact" "definition" "software-behaviour" "config-syntax"];
    };
  };
  sourceIds = ["repo-docs" "vault-claims" "zim-shelf" "web"];

  # --- the claim shapes ------------------------------------------------------
  # `volatility` here is a property of the CLAIM: does the answer move on its
  # own? "niri reads config.kdl" stays true for years; "the newest systemd
  # release drops SysV" is false within a month.
  kinds = {
    "software-behaviour" = {
      volatility = "stable";
      what = "how a program behaves, its flags and formats";
    };
    "config-syntax" = {
      volatility = "stable";
      what = "the shape of a config file or directive";
    };
    "definition" = {
      volatility = "stable";
      what = "what a term means";
    };
    "historical-fact" = {
      volatility = "stable";
      what = "what happened, and when";
    };
    "current-release" = {
      volatility = "moving";
      what = "the version, default or state of something today";
    };
    "personal-method" = {
      volatility = "stable";
      what = "how I work, and why";
    };
    "decision" = {
      volatility = "stable";
      what = "what this fleet chose to do";
    };
    "project-fact" = {
      volatility = "stable";
      what = "a fact about my own projects";
    };
    "procedure" = {
      volatility = "stable";
      what = "the steps to accomplish something here";
    };
    "fleet-fact" = {
      volatility = "stable";
      what = "a compiled fact about these hosts";
    };
  };
  kindIds = ["software-behaviour" "config-syntax" "definition" "historical-fact" "current-release" "personal-method" "decision" "project-fact" "procedure" "fleet-fact"];

  # Evidence quality, and the only ordering the compile imposes.
  standingTier = {
    authored = 0;
    snapshot = 1;
    unvetted = 2;
  };

  # --- the three refusals ----------------------------------------------------
  # Each returns a reason, because "no-go" without one is a score with better
  # manners. `never` is a fact about the source; the caller's budget is applied
  # after this compile, by whoever holds the budget.
  judge = kind: name: let
    src = sources.${name};
    k = kinds.${kind};
  in
    if !(builtins.elem kind src.settles)
    then {
      inherit name;
      inherit (src) cost;
      go = false;
      why = "no authority over ${kind}";
    }
    else if k.volatility == "moving" && src.volatility == "frozen"
    then {
      inherit name;
      inherit (src) cost;
      go = false;
      # Its silence and its agreement are equally uninformative here.
      why = "frozen at ${src.vintage}; a snapshot cannot settle a moving fact";
    }
    else {
      inherit name;
      inherit (src) cost how;
      go = true;
      # Standing decides the tier, price decides within it. Authored outranks
      # a snapshot (someone is accountable) which outranks the open web (nobody
      # is, and it is the dearest); a cheap permitted source wins only against
      # one of equal standing.
      key = standingTier.${src.standing} * 10000 + src.cost;
      why = "${src.standing}, ${src.volatility}";
    };

  # One kind -> an ordinal answer. This is the whole product surface: which
  # source to read first, and why every other one is not worth the tokens.
  forKind = kind: let
    verdicts = map (judge kind) sourceIds;
    permitted = lib.sort (a: b: a.key < b.key) (builtins.filter (v: v.go) verdicts);
    strip = v: {inherit (v) name cost why;};
    first =
      if permitted == []
      then null
      else (builtins.head permitted);
  in {
    inherit kind;
    read =
      if first == null
      then null
      else first.name;
    # What to actually do to consult it — so the answer and the command are one
    # document, not a decision the agent has to translate.
    next =
      if first == null
      then "nothing declared can settle this: ask a person, or measure it"
      else first.how;
    order = map strip permitted;
    never = map strip (builtins.filter (v: !v.go) verdicts);
  };

  table = builtins.listToAttrs (map (k: {
      name = k;
      value = forKind k;
    })
    kindIds);

  # Programmatic entry: a claim as data in, the same answer plus the text it was
  # asked about. `task ops:claim:check` reads `table` and applies a budget, so
  # this exists for a caller that already has a claim object — it is not a
  # second rule.
  review = claim: (table.${claim.kind} or (throw "epistemics: unknown claim kind '${claim.kind}', known: ${lib.concatStringsSep ", " kindIds}")) // {inherit (claim) text;};

  # Sample claims, so the compile is inspectable without inventing an input:
  # `nix eval --json .#epistemics.all | toon -e`.
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
  inherit sources kinds judge table review samples sourceIds kindIds asOf;
  all = map review samples;
  # A kind that no declared source can settle is not a retrieval failure, and
  # naming it is the reason this is data: the answer is "ask a person", which
  # no search tool can return.
  unsettleable = map (k: k.kind) (builtins.filter (k: k.order == []) (builtins.attrValues table));
}
