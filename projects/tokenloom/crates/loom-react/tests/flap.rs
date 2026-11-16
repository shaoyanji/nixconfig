//! Break and restore a condition ten times in a second: one raise, one clear.

use loom_react::{EngineEvent, Reaction, WarningEngine, WarningKind, QUIET_PERIOD_MS};
use std::collections::HashSet;

fn violation() -> Reaction {
    Reaction {
        kind: WarningKind::ConstraintViolation,
        severity: 3,
        start: 10,
        len: 4,
        message: "span holds 6 tokens, constraint max 4".to_string(),
    }
}

#[test]
fn flap_suppression() {
    let mut eng = WarningEngine::new();
    let r = violation();
    let reactor = 5u8;
    let mut raises = 0usize;
    let mut clears = 0usize;
    let mut ids = HashSet::new();

    for cycle in 0..10u64 {
        let now = cycle * 100;
        for ev in eng.raise(reactor, &r, 1 + cycle, now) {
            match ev {
                EngineEvent::Raise(w) => {
                    raises += 1;
                    ids.insert(w.id);
                }
                EngineEvent::Clear { .. } => clears += 1,
            }
        }
        // Condition gone for 40ms: marked absent, kept alive by the quiet period.
        eng.pass(reactor, &(9..15), now + 10, &HashSet::new());
        for ev in eng.expire(now + 40) {
            if matches!(ev, EngineEvent::Clear { .. }) {
                clears += 1;
            }
        }
    }

    assert_eq!(raises, 1, "ten breaks in one second must raise once");
    assert_eq!(ids.len(), 1, "a re-raise must keep the warning id");
    assert_eq!(clears, 0, "a 40ms absence is inside the quiet period");
    let flaps = eng.active()[0].flap_count;
    assert!(flaps >= 9, "the engine must count the flaps, got {flaps}");
    assert_eq!(eng.len(), 1);

    // The quiet clock runs from the last *absence marking* — cycle nine's pass at
    // 910ms — not from the last raise.
    let quiet_from = 910;
    assert!(eng.expire(quiet_from + QUIET_PERIOD_MS).is_empty());
    let tail = eng.expire(quiet_from + QUIET_PERIOD_MS + 1);
    assert_eq!(tail.len(), 1, "quiet for the quiet period clears once");
    for ev in tail {
        if matches!(ev, EngineEvent::Clear { .. }) {
            clears += 1;
        }
    }
    assert_eq!(clears, 1, "exactly one clear for ten breaks");
    assert_eq!(eng.len(), 0);
}

#[test]
fn raised_key_is_not_marked_absent() {
    let mut eng = WarningEngine::new();
    let r = violation();
    let key = loom_react::key_of(5, &r);
    assert_eq!(eng.raise(5, &r, 1, 0).len(), 1);

    let mut raised = HashSet::new();
    raised.insert(key);
    eng.pass(5, &(9..15), 10, &raised);
    assert!(eng.expire(10 + QUIET_PERIOD_MS * 4).is_empty());

    eng.pass(5, &(9..15), 3000, &HashSet::new());
    assert_eq!(eng.expire(3000 + QUIET_PERIOD_MS + 1).len(), 1);
}

#[test]
fn span_buckets_absorb_small_drift() {
    let mut eng = WarningEngine::new();
    let r = violation();
    assert_eq!(eng.raise(5, &r, 1, 0).len(), 1);
    let moved = Reaction { start: r.start + 3, ..r.clone() };
    assert!(eng.raise(5, &moved, 2, 10).is_empty(), "drift must reuse the id");
    assert_eq!(eng.len(), 1);
}
