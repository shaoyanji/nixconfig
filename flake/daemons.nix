# Daemon Kelly gate: ev = p*save - (1-p)*cost, enable only if save>0 and ev>0.
# Rule and numbers: docs/nix-patterns.md §"A daemon must clear the Kelly gate"
# [[flake/policies.nix#daemon-clears-kelly]].
{lib}: let
  # Generated tokens per second; a faster model raises it and makes daemons harder
  # to justify, which is the correct direction.
  tokenRate = 50.0;
  bytesPerToken = 4.0;
  # The one Kelly expression in the tree: a second consumer (flake/epistemics.nix,
  # which gates a lookup by its measured settle rate) must not restate it.
  ev = p: save: cost: p * save - (1.0 - p) * cost;
  mk = d: let
    evd = ev d.p d.save d.cost;
  in
    d
    // {
      ev = evd;
      clears = d.save > 0.0 && evd > 0.0;
    };
in rec {
  inherit tokenRate ev;

  tokens = bytes: bytes / bytesPerToken;
  seconds = toks: toks / tokenRate;

  daemons = lib.mapAttrs (_: mk) {
    # `kg-sidecar` (Elixir, 27 MB resident, 1383 lines) is gone as of 2026-11-07:
    # re-measured at 28 ms against jq's 53 ms over the content-keyed graph file,
    # so its 25 ms bought a resident BEAM and a parity gate. `task ops:kg:speed`
    # is the harness; the numbers are in docs/nix-patterns.md.

    selector = {
      # Wanted, per the exit criterion in AGENTS.nix `daemon-earns-it-by-
      # compression`: answered-case p >= 0.3 at S >= 3 s, refusal <= 100 ms, and
      # this entry clearing. All three hold. The unit is
      # modules/user/selector-daemon.nix: it holds stage 1 so a question does not
      # pay interpreter start per call, and `checks:selector:sidecar` proves it
      # answers byte-identically to the interpreter it accelerates.
      unit = "selector.service";
      replaces = "one whole compiled registry read and scan: `nix eval --json .#inventory.hosts` (75 KB), `.#agentsNotes.notes` (325 KB) or `task --list-all --json` (275 KB)";
      # End to end, not the executor alone: 1.0 is stage 1 turning the battery's
      # English prompts into row sets that match gold, over the 21 it answered.
      # Coverage is the other half and it is 21/28: one question refuses.
      p = 1.0;
      save = 942.94;
      cost = 1.2;
      wanted = true;
      measured = "2026-11-03 · checks:selector (executor p 1.0, S 942.94 s, refusal 71 ms; stage 1 p 1.0 on 21 of 21 answered, coverage 21/28, 6/6 abstain declined, held-out 0.978 at 0.92 over 491 pairs) · checks:selector:sidecar (answer 180 ms resident vs 250 ms cold, refusal 37 vs 105 ms)";
      note = "the arithmetic is cleared and selector.service is behind it; `q.sh --question` falls back to the interpreter on a host without the unit";
    };

    edge-caller = {
      unit = "edge-caller.service";
      replaces = "the agent naming the pattern itself: `task ops:kg:host HOST=fern`";
      p = 0.5;
      # Negative by measurement: 54 B generated against 40, 605 B read against
      # 217, 1073 ms against 145. A correct answer is still a net loss.
      save = -1.0;
      cost = 1.2;
      wanted = false;
      measured = "2026-11-02 · toolcall-battery (8/11 top-1, 3/6 model-exact) · direct 145 ms vs 1073 ms";
      note = "the win case is a loss; kept as a pipeline API (agents:call:batch)";
    };
  };

  wanted = lib.filterAttrs (_: d: d.wanted) daemons;
  failing = lib.filterAttrs (_: d: d.wanted && !d.clears) daemons;
  unmeasured = lib.filterAttrs (_: d: d.measured == "" || d.p <= 0.0) daemons;
  disabled = lib.filterAttrs (_: d: !d.wanted) daemons;
}
