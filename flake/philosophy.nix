# The mathematical lenses offered to the fleet, as data (v1.0.0rc). A lens is a
# candidate primitive with its evidence — adopted means a consumer shipped,
# deferred means the recorded measurement does not pay. Rationale: AGENTS.nix
# `intent-capability-spec`; reader `nix eval --json .#philosophy | toon -e`.
_: let
  lenses = {
    quotient-class = {
      lens = "quotient caching (equivalence-class keys): x ~ y iff canonical(x) == canonical(y), so two requests in one class share one slot";
      identity = "x ~ y iff canonical(x) == canonical(y)";
      claim = "two dispatches with the same kind over the same claims are one intent re-sent";
      status = "adopted";
      adoptedBy = "flake/intents.nix classOf via lib/quotient-hash.nix";
      basis = {
        note = "intent-capability-spec";
        evidence = "the steward re-sent the same dispatch five times in one session and the lane re-answered each — the class had no name until this";
      };
      revisit = "extends to build artifacts the day a build request carries an intent-shaped key";
    };
    zeckendorf-epoch = {
      lens = "Zeckendorf epoch — every n uniquely as non-consecutive Fibonacci terms — as an epoch-partitioned incremental cache (build-order/cache-block proxy)";
      claim = "doc-only kg misses can skip a full re-eval inside an epoch";
      status = "deferred";
      basis = {
        note = "kg-zeck-cache";
        instrument = "task checks:kg:zeck (stays green so re-measuring is one command)";
        measured = {
          incrementalMs = 589;
          headDiffMs = 562;
          warmHitMs = 761;
          baselineHitMs = 35;
        };
        gate = "flake/daemons.nix Kelly: require save > 0 and ev > 0";
        verdict = "fails save > 0 — 589 > 562 on the miss, 761 > 35 on the hit; no doc-only-miss fraction p clears it, so the opt-in stays opt-in";
        remeasured = {
          host = "frieren";
          date = "2026-11-26";
          incrementalMs = 882;
          headDiffMs = 2514;
          warmHitOneShotMs = 994;
          warmHitInProcessMs = 136;
          baselineHitMs = 175;
          verdict = "miss leg saves on frieren; hit leg still loses one-shot. ev turns on miss fraction ≥ ~33% — measured, not assumed";
        };
      };
      revisit = "the miss leg now pays on frieren: measure the real doc-only-miss fraction p; if p ≥ ~33% the Kelly gate clears and the opt-in becomes a candidate default";
    };
    cassini-checksum = {
      lens = "Cassini identity F(n-1)·F(n+1) − F(n)² = (−1)ⁿ — an O(1) checksum over any 3-window of a Fibonacci-partitioned sequence; no such sequence exists in the fleet, the turn ledger is append-only";
      claim = "a Fibonacci-partitioned artifact table gains an O(1) triple integrity check";
      status = "deferred";
      basis = {
        note = "intent-capability-spec";
        verdict = "rides with zeckendorf-epoch: the checksum is meaningful only on a Fibonacci-partitioned table, and that is the table the deferred option was for";
      };
      revisit = "adopt the moment a build or artifact ledger is Fibonacci-partitioned — the identity then costs three multiplies per window";
    };
  };
  lensIds = builtins.attrNames lenses;

  adopted = lensIds |> builtins.filter (l: lenses.${l}.status == "adopted");
  deferred = lensIds |> builtins.filter (l: lenses.${l}.status == "deferred");
in {
  inherit lenses lensIds adopted deferred;
}
