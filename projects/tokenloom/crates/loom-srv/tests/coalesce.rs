//! A burst is one revision.
//!
//! Ten ops that arrive inside the window are applied once, so they cost one
//! diff and one revision stamp — and the client is never shown an intermediate
//! document. The same ten sent across two windows cost two. Both halves are
//! checked here, because a test that only counts one batch would still pass if
//! the window coalesced nothing and the client simply merged the diffs itself.

use loom_core::{NewToken, Op};
use loom_srv::session::Session;
use loom_srv::{build_state, coalesce, AppState};
use loom_wire::{decode_server, ServerFrame};
use std::sync::Arc;
use std::time::Duration;
use tokio::sync::broadcast;
use tokio::time::timeout;

type Frames = broadcast::Receiver<Arc<Vec<u8>>>;

/// Quiet is the only end-of-batch signal a client has: read until nothing has
/// arrived for longer than a window, then say what came.
const QUIET: Duration = Duration::from_millis(300);

fn word() -> NewToken {
    NewToken {
        flags: 1,
        tag: 0,
        text: b"z".to_vec(),
    }
}

fn insert_at(_state: &AppState, seq: u64, at: usize) -> Op {
    Op::Insert {
        seq,
        offset: at as u32,
        tokens: vec![word()],
    }
}

/// The rope as a session sees it: token count and text. Text is what the
/// inserts have to add up to — retokenization is free to move token boundaries,
/// so counting tokens would be counting the tokenizer's choice, not the edits.
fn rope(state: &AppState) -> (usize, String) {
    let s = state.session.lock().expect("the session lock");
    (
        s.rope.len_tokens(),
        String::from_utf8_lossy(&s.rope.doc()).into_owned(),
    )
}

async fn drain(rx: &mut Frames) -> Vec<ServerFrame> {
    let mut frames = Vec::new();
    while let Ok(Ok(bytes)) = timeout(QUIET, rx.recv()).await {
        frames.push(decode_server(&bytes).expect("a frame this build wrote"));
    }
    frames
}

fn counts(frames: &[ServerFrame]) -> (usize, usize) {
    let acks = frames
        .iter()
        .filter(|f| matches!(f, ServerFrame::Ack { .. }))
        .count();
    let diffs = frames
        .iter()
        .filter(|f| matches!(f, ServerFrame::Diff { .. }))
        .count();
    (acks, diffs)
}

async fn running(window_ms: u64) -> (Arc<AppState>, Frames) {
    let (state, ops_rx) = build_state(Session::with_doc("alpha beta gamma"), None, window_ms);
    let rx = state.shared.out.subscribe();
    tokio::spawn(coalesce(ops_rx, state.clone()));
    (state, rx)
}

#[tokio::test]
async fn a_burst_inside_one_window_is_one_revision_and_one_diff() {
    let (state, mut rx) = running(20).await;
    let rev0 = state.revision();
    let len0 = rope(&state).0;
    let was = rope(&state).1;

    for i in 0..10u64 {
        let op = insert_at(&state, i + 1, len0 + i as usize);
        state
            .ops_tx
            .send(vec![op])
            .expect("the op reaches the coalescer");
    }

    let frames = drain(&mut rx).await;
    let (acks, diffs) = counts(&frames);
    assert_eq!(acks, 10, "every op is acknowledged: {frames:?}");
    assert_eq!(
        diffs, 1,
        "ten ops inside one window are one diff, not ten: {frames:?}"
    );
    let diff = frames
        .iter()
        .find_map(|f| match f {
            ServerFrame::Diff {
                revision,
                deleted,
                inserted,
                ..
            } => Some((*revision, *deleted, inserted.len())),
            _ => None,
        })
        .expect("the diff");
    assert_eq!(diff.1, 0, "nothing was deleted");
    assert_eq!(diff.2, 10, "the one diff carries the whole burst");
    assert_eq!(
        state.revision(),
        rev0 + 1,
        "and the burst is one revision, not ten"
    );
    assert_eq!(diff.0, rev0 + 1, "the diff is stamped with that revision");
    let (_, doc) = rope(&state);
    assert_eq!(
        doc,
        format!("{was}zzzzzzzzzz"),
        "the rope took all ten inserts; it reads {doc:?}"
    );
}

#[tokio::test]
async fn the_same_burst_across_two_windows_is_two_revisions() {
    let (state, mut rx) = running(20).await;
    let rev0 = state.revision();
    let len0 = rope(&state).0;

    for i in 0..5u64 {
        let op = insert_at(&state, i + 1, len0 + i as usize);
        state.ops_tx.send(vec![op]).expect("the op reaches the coalescer");
    }
    let first = drain(&mut rx).await;
    let (acks, diffs) = counts(&first);
    assert_eq!((acks, diffs), (5, 1), "the first five are one batch");
    assert_eq!(state.revision(), rev0 + 1);

    let len1 = rope(&state).0;
    for i in 0..5u64 {
        let op = insert_at(&state, 6 + i, len1 + i as usize);
        state.ops_tx.send(vec![op]).expect("the op reaches the coalescer");
    }
    let second = drain(&mut rx).await;
    let (acks, diffs) = counts(&second);
    assert_eq!((acks, diffs), (5, 1), "and the next five are a second batch");
    assert_eq!(
        state.revision(),
        rev0 + 2,
        "two windows, two revisions — the count is not just the burst's"
    );
}

#[tokio::test]
async fn a_delete_burst_and_a_retune_in_one_window_are_one_revision_and_one_diff() {
    let (state, mut rx) = running(20).await;

    // The plant gets its own window: the burst under test is the deletes plus
    // the retune, so the plant's revision must not be inside the count.
    state
        .ops_tx
        .send(vec![Op::ConstraintAdd {
            seq: 1,
            start: 0,
            len: 2,
            kind: 1,
            param: 4,
        }])
        .expect("the plant reaches the coalescer");
    let planted = drain(&mut rx).await;
    assert_eq!(
        counts(&planted),
        (1, 0),
        "a plant moves no text, so it costs a list and no diff: {planted:?}"
    );
    let id = planted
        .iter()
        .find_map(|f| match f {
            ServerFrame::Constraints { items, .. } => items.first().map(|c| c.id),
            _ => None,
        })
        .expect("the list a plant sends");

    let (len0, was) = rope(&state);
    let rev0 = state.revision();
    // Where the trailing two tokens begin. The burst removes both from the end,
    // so the document has to end exactly here afterwards.
    let tail_start = {
        let s = state.session.lock().expect("the session lock");
        let abs = s.rope.abs_tokens();
        abs[abs.len() - 2].start
    };

    // Separate sends, so the window is what makes this one batch. Each delete
    // names the token that is last at the time it lands; the retune names the id
    // the plant handed out.
    for (seq, offset) in [(2u64, len0 - 1), (3, len0 - 2)] {
        state
            .ops_tx
            .send(vec![Op::Delete {
                seq,
                offset: offset as u32,
                count: 1,
            }])
            .expect("the delete reaches the coalescer");
    }
    state
        .ops_tx
        .send(vec![Op::ConstraintUpdate {
            seq: 4,
            id,
            kind: 2,
            param: 0,
        }])
        .expect("the retune reaches the coalescer");

    let frames = drain(&mut rx).await;
    let (acks, diffs) = counts(&frames);
    assert_eq!(acks, 3, "every op is acknowledged: {frames:?}");
    assert_eq!(
        diffs, 1,
        "two deletes and a retune inside one window are one diff: {frames:?}"
    );

    let (revision, start, deleted, inserted) = frames
        .iter()
        .find_map(|f| match f {
            ServerFrame::Diff {
                revision,
                start,
                deleted,
                inserted,
            } => Some((*revision, *start, *deleted, inserted.len())),
            _ => None,
        })
        .expect("the diff");
    assert_eq!(deleted, 2, "the one diff carries both deletes");
    assert_eq!(
        inserted, 0,
        "and puts nothing back: the diff is the removed tokens, not a rewrite"
    );
    assert_eq!(
        start as usize, len0 - 2,
        "the diff starts where the deleted run did, not at the head of the document"
    );
    assert_eq!(revision, rev0 + 1, "the whole burst is one revision");
    assert_eq!(state.revision(), rev0 + 1, "and the session agrees");
    let (_, doc) = rope(&state);
    assert_eq!(
        doc.as_bytes(),
        &was.as_bytes()[..tail_start],
        "the rope lost exactly those two tokens; it reads {doc:?}"
    );

    let lists: Vec<&ServerFrame> = frames
        .iter()
        .filter(|f| matches!(f, ServerFrame::Constraints { .. }))
        .collect();
    assert_eq!(
        lists.len(),
        1,
        "one list for the batch, not one per op: {frames:?}"
    );
    match lists[0] {
        ServerFrame::Constraints { items, .. } => {
            assert_eq!(items.len(), 1, "the span survives the deletes");
            let span = &items[0];
            assert_eq!(span.id, id, "a retune keeps the id the plant handed out");
            assert_eq!(
                (span.kind, span.param),
                (2, 0),
                "and carries the rule it was retuned to"
            );
            assert_eq!(span.len, 2, "the span's length did not move");
            assert_eq!(span.anchor, 0, "the deletes landed behind it, so it stayed put");
        }
        _ => unreachable!(),
    }
}

#[tokio::test]
async fn an_idle_socket_is_not_a_frame() {
    let (_state, mut rx) = running(20).await;
    let frames = drain(&mut rx).await;
    assert!(frames.is_empty(), "nothing was edited, nothing is written");
}
