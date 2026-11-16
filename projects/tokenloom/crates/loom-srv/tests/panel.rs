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
