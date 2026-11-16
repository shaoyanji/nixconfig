//! A constraint planted with no edit still has to reach a page. The sidebar
//! lists spans, so the list is a frame of its own — not something a diff happens
//! to carry, and not something a page only sees on reload.

use loom_core::Op;
use loom_srv::session::Session;
use loom_srv::{build_state, coalesce, constraints_frame, AppState};
use loom_wire::{decode_server, ConstraintView, ServerFrame};
use std::sync::Arc;
use std::time::Duration;
use tokio::sync::broadcast;
use tokio::time::timeout;

type Frames = broadcast::Receiver<Arc<Vec<u8>>>;

/// Read up to the next list, reporting the frames that came before it: a plant
/// that needed a diff to reach the page would show up in `seen`.
async fn next_list(rx: &mut Frames) -> (Vec<ConstraintView>, Vec<String>) {
    let mut seen = Vec::new();
    for _ in 0..16 {
        let bytes = timeout(Duration::from_secs(5), rx.recv())
            .await
            .expect("a frame inside the window")
            .expect("the broadcast is open");
        match decode_server(&bytes).expect("a frame this build can read") {
            ServerFrame::Constraints { items, .. } => return (items, seen),
            other => seen.push(format!("{other:?}")),
        }
    }
    panic!("no constraints frame arrived; saw {seen:?}");
}

async fn running() -> (Arc<AppState>, Frames) {
    let (state, ops_rx) = build_state(Session::with_doc("alpha beta gamma delta"), None, 1);
    let rx = state.shared.out.subscribe();
    tokio::spawn(coalesce(ops_rx, state.clone()));
    (state, rx)
}

fn tokens(state: &AppState) -> usize {
    state.session.lock().expect("the session lock").rope.len_tokens()
}

#[tokio::test]
async fn a_plant_with_no_edit_reaches_the_sidebar() {
    let (state, mut rx) = running().await;
    let text = tokens(&state);

    state
        .ops_tx
        .send(vec![Op::ConstraintAdd {
            seq: 1,
            start: 1,
            len: 2,
            kind: 1,
            param: 4,
        }])
        .expect("the batch reaches the coalescer");

    let (items, seen) = next_list(&mut rx).await;
    assert_eq!(
        items.len(),
        1,
        "the plant is in the list; frames before it: {seen:?}"
    );
    let planted = items[0];
    assert_eq!(planted.kind, 1, "max-tokens, as it was planted");
    assert_eq!(planted.len, 2, "the span it was planted on");
    assert_eq!(planted.param, 4, "the rule, not the anchor");
    assert_eq!(planted.token, 1, "the server resolves the anchor to a token");
    assert!(
        seen.iter().any(|f| f.starts_with("Ack")),
        "the session has to take the op before the page can list it: {seen:?}"
    );
    assert!(
        !seen.iter().any(|f| f.starts_with("Diff")),
        "a plant moves no text, so nothing may ride a diff: {seen:?}"
    );
    assert_eq!(tokens(&state), text, "and the rope is untouched");

    // A page that connects now is handed the same list beside its snapshot: the
    // snapshot carries tokens, not spans.
    let joined = constraints_frame(&state).expect("a list to send on connect");
    match decode_server(&joined).expect("a readable frame") {
        ServerFrame::Constraints { items, .. } => assert_eq!(items, vec![planted]),
        other => panic!("connect sent {other:?}"),
    }

    // A retune keeps the id and the count: the span is the same span and only
    // the rule on it changed, so the page is told rather than asked to replant.
    state
        .ops_tx
        .send(vec![Op::ConstraintUpdate {
            seq: 2,
            id: planted.id,
            kind: 2,
            param: 32,
        }])
        .expect("the retune reaches the coalescer");
    let (items, seen) = next_list(&mut rx).await;
    assert_eq!(items.len(), 1, "a retune moves no count; frames: {seen:?}");
    assert_eq!(items[0].id, planted.id, "the span keeps its id through a retune");
    assert_eq!(items[0].kind, 2, "and takes the new rule");
    assert_eq!(items[0].param, 32);
    assert_eq!(items[0].anchor, planted.anchor, "the anchor does not move");
    assert_eq!(items[0].len, planted.len, "and neither does the span length");

    // And the panel takes it back out again.
    state
        .ops_tx
        .send(vec![Op::ConstraintRemove {
            seq: 3,
            id: planted.id,
        }])
        .expect("the removal reaches the coalescer");

    let (items, seen) = next_list(&mut rx).await;
    assert!(
        items.is_empty(),
        "the removed span is gone from the list; frames before it: {seen:?}"
    );
    assert_eq!(tokens(&state), text, "a removal moves no text either");
    let after = constraints_frame(&state).expect("the emptied list is still a list");
    match decode_server(&after).expect("a readable frame") {
        ServerFrame::Constraints { items, .. } => {
            assert!(items.is_empty(), "a reload must not bring the span back");
        }
        other => panic!("the emptied list came back as {other:?}"),
    }
}

/// Identity through a run of retunes, with a neighbour planted beside the span.
///
/// The page keeps one row per id and repaints it in place, which is only sound
/// if the protocol holds four things: the retuned span keeps its id, its anchor
/// and its length; the span that was not retuned does not move; the list still
/// holds one entry per span; and the next plant takes a fresh id rather than one
/// the retune handed out. Those are checked here because a browser is not needed
/// to check them, and a browser test that fails on them says less about where.
#[tokio::test]
async fn a_retune_keeps_every_span_where_it_was() {
    let (state, mut rx) = running().await;
    let text = tokens(&state);

    // Two plants in two batches, so a page would have handed out #0 and #1.
    state
        .ops_tx
        .send(vec![Op::ConstraintAdd {
            seq: 1,
            start: 1,
            len: 2,
            kind: 1,
            param: 4,
        }])
        .expect("the first plant reaches the coalescer");
    let (first, _) = next_list(&mut rx).await;
    assert_eq!(first.len(), 1, "one plant, one entry");
    state
        .ops_tx
        .send(vec![Op::ConstraintAdd {
            seq: 2,
            start: 3,
            len: 1,
            kind: 2,
            param: b' ' as u32,
        }])
        .expect("the second plant reaches the coalescer");
    let (two, _) = next_list(&mut rx).await;
    assert_eq!(two.len(), 2, "a second span is a second entry");
    let (a, b) = (two[0], two[1]);
    assert_eq!(a.id, first[0].id, "the first span kept the id it was handed");
    assert_ne!(a.id, b.id, "two spans are two ids");

    // 20 retunes of `a`, each to a rule it does not already have, while `b` sits
    // beside it untouched.
    let mut rev = state.revision();
    for i in 0..20u32 {
        state
            .ops_tx
            .send(vec![Op::ConstraintUpdate {
                seq: 10 + i as u64,
                id: a.id,
                kind: 1,
                param: 100 + i,
            }])
            .expect("the retune reaches the coalescer");
        let (items, seen) = next_list(&mut rx).await;
        assert_eq!(
            items.len(),
            2,
            "a retune moves no count; frames before the list: {seen:?}"
        );
        assert_eq!(
            items.iter().map(|c| c.id).collect::<Vec<_>>(),
            vec![a.id, b.id],
            "round {i}: the ids, in plant order, are the ids the page holds"
        );
        for (got, was) in items.iter().zip([a, b]) {
            assert_eq!(got.anchor, was.anchor, "round {i}: an anchor does not move");
            assert_eq!(got.len, was.len, "round {i}: nor does a span length");
            assert_eq!(
                got.token, was.token,
                "round {i}: so the anchor still covers the same token"
            );
        }
        assert_eq!(
            items[0].kind, 1,
            "round {i}: the retuned span wears the rule it was given"
        );
        assert_eq!(items[0].param, 100 + i, "round {i}: and that rule's number");
        assert_eq!(
            (items[1].kind, items[1].param),
            (b.kind, b.param),
            "round {i}: the neighbour keeps its own rule"
        );
        let now = state.revision();
        assert!(
            now > rev,
            "round {i}: a retune bumps the revision ({rev} -> {now}), or its log record is trimmed as covered"
        );
        rev = now;
    }

    // The next plant must take an id no retune used: a page keyed by id would
    // otherwise repaint a row that is already on screen.
    state
        .ops_tx
        .send(vec![Op::ConstraintAdd {
            seq: 40,
            start: 0,
            len: 1,
            kind: 1,
            param: 2,
        }])
        .expect("the third plant reaches the coalescer");
    let (three, seen) = next_list(&mut rx).await;
    assert_eq!(three.len(), 3, "three spans, three entries: {seen:?}");
    let ids: Vec<u32> = three.iter().map(|c| c.id).collect();
    assert_eq!(ids[..2], [a.id, b.id], "the planted spans keep their ids");
    assert!(
        ids[2] > b.id,
        "a new span takes a fresh id, not one a retune handed out: {ids:?}"
    );
    assert_eq!(tokens(&state), text, "and no retune moved any text");
}
