//! The diff stream is the client's only model of the document.
//!
//! A page holds a token list and applies each `DIFF` as
//! `splice(start, deleted, ...inserted)`. Nothing else tells it what the
//! document is: a frame that *under-reports* `deleted` leaves a token the server
//! dropped, and every later edit lands a token off. The batch tests count frames
//! and check spans; this one keeps the client's list and asserts that after every
//! batch it equals the server's rope, token for token, across random multi-op
//! batches — inserts, deletes, merges, splits and annotations in one window,
//! which is where the pre/post mapping has to hold.
//!
//! Tags are left out of the comparison on purpose: the wire carries a token's
//! text and flags, and a client never learns a tag, so asserting on one would be
//! asserting on something the protocol does not promise.

use loom_core::{is_word_byte, flags_for_byte, NewToken, Op, FLAG_WORD};
use loom_srv::session::Session;
use loom_srv::{build_state, coalesce, AppState};
use loom_wire::{decode_server, ServerFrame};
use std::sync::Arc;
use std::time::Duration;
use tokio::sync::broadcast;
use tokio::time::timeout;

type Frames = broadcast::Receiver<Arc<Vec<u8>>>;

/// A batch the client never hears back about is a bug, not a slow window, so the
/// wait is generous: the coalescer window under test is 20 ms.
const WAIT: Duration = Duration::from_secs(2);
const BATCHES: usize = 48;

/// What a page keeps per token.
#[derive(Clone, Debug, PartialEq, Eq)]
struct Tok {
    flags: u8,
    text: Vec<u8>,
}

struct Lcg(u64);

impl Lcg {
    fn next(&mut self) -> u64 {
        self.0 = self
            .0
            .wrapping_mul(6364136223846793005)
            .wrapping_add(1442695040888963407);
        self.0 >> 11
    }
}

/// Words chosen so an insert can merge with its neighbour: `in` and `the` are
/// prefixes of longer tokens in the vocabulary, and a space ends a run.
const WORDS: &[&str] = &[
    "in", "the", "out", "a", "merge", "zi", "st", " ",
];

fn doc() -> String {
    let phrase = "the outstanding reconsideration of tokenization is that a merge can ripple past \
                  a window and the reactor bank keeps its own segmentation so six opinions cost \
                  six windows never passes boundary stability matters here when text crosses a \
                  delimiter ";
    phrase.repeat(6)
}

fn tokens_of(state: &AppState) -> Vec<Tok> {
    let s = state.session.lock().expect("the session lock");
    let doc = s.rope.doc();
    s.rope
        .abs_tokens()
        .into_iter()
        .map(|t| Tok {
            flags: t.flags,
            text: doc[t.start..t.end()].to_vec(),
        })
        .collect()
}

/// The snapshot a connecting page is handed, which is where its list starts.
fn snapshot(state: &AppState) -> Vec<Tok> {
    let s = state.session.lock().expect("the session lock");
    s.snapshot_tokens()
        .into_iter()
        .map(|t| Tok {
            flags: t.flags,
            text: t.text,
        })
        .collect()
}

fn inserted(text: &str) -> NewToken {
    NewToken {
        flags: if is_word_byte(text.as_bytes()[0]) {
            FLAG_WORD
        } else {
            flags_for_byte(text.as_bytes()[0])
        },
        tag: 0,
        text: text.as_bytes().to_vec(),
    }
}

/// Apply an op to the client-side list the way the rope will.
///
/// This copy exists to name coordinates: ops inside one batch are written against
/// the document as the client has already applied its own edits, so the second
/// op's offset is only valid after the first. It is *not* the list a diff has to
/// reproduce — retokenization may re-split anything after the batch, which is
/// exactly what the diff is there to carry.
fn shadow_apply(op: &Op, client: &mut Vec<Tok>) {
    match op {
        Op::Insert { offset, tokens, .. } => {
            let at = (*offset as usize).min(client.len());
            let fresh: Vec<Tok> = tokens
                .iter()
                .map(|t| Tok {
                    flags: t.flags,
                    text: t.text.clone(),
                })
                .collect();
            client.splice(at..at, fresh);
        }
        Op::Delete { offset, count, .. } => {
            let at = (*offset as usize).min(client.len());
            let end = (at + *count as usize).min(client.len());
            client.drain(at..end);
        }
        Op::Merge { offset, count, .. } => {
            let at = (*offset as usize).min(client.len());
            let end = (at + *count as usize).min(client.len());
            if end > at + 1 {
                let flags = client[at].flags;
                let mut text = Vec::new();
                for t in &client[at..end] {
                    text.extend_from_slice(&t.text);
                }
                client.splice(at..end, [Tok { flags, text }]);
            }
        }
        Op::Split { offset, byte_off, .. } => {
            let at = (*offset as usize).min(client.len().saturating_sub(1));
            if let Some(t) = client.get(at).cloned() {
                let cut = (*byte_off as usize).min(t.text.len().saturating_sub(1));
                if cut > 0 {
                    let (a, b) = t.text.split_at(cut);
                    client.splice(
                        at..at + 1,
                        [
                            Tok {
                                flags: t.flags,
                                text: a.to_vec(),
                            },
                            Tok {
                                flags: t.flags,
                                text: b.to_vec(),
                            },
                        ],
                    );
                }
            }
        }
        _ => {}
    }
}

/// One batch that always moves text, so the coalescer always owes a diff.
fn make_batch(rng: &mut Lcg, client: &mut Vec<Tok>, seq: &mut u64) -> Vec<Op> {
    let mut ops = Vec::new();
    let extra = (rng.next() % 4) as usize;
    for i in 0..=extra {
        *seq += 1;
        let s = *seq;
        let len = client.len();
        // The first op must change text; the rest may be anything that is valid
        // on the rope, so a batch is never a lone annotation (which owes no
        // diff) and never sends an op the server would have to resync.
        let kind = if i == 0 {
            rng.next() % 4
        } else {
            rng.next() % 7
        };
        let op = match kind {
            0 | 1 => {
                let at = (rng.next() as usize) % (len + 1);
                let n = 1 + (rng.next() % 2) as usize;
                let tokens: Vec<NewToken> = (0..n)
                    .map(|_| inserted(WORDS[(rng.next() as usize) % WORDS.len()]))
                    .collect();
                Op::Insert {
                    seq: s,
                    offset: at as u32,
                    tokens,
                }
            }
            2 => {
                let at = (rng.next() as usize) % len.max(1);
                let room = (len - at).max(1);
                Op::Delete {
                    seq: s,
                    offset: at as u32,
                    count: (1 + (rng.next() as usize) % room.min(3)) as u16,
                }
            }
            3 => {
                let at = (rng.next() as usize) % len.max(1);
                let room = len.saturating_sub(at);
                if room >= 2 {
                    Op::Merge {
                        seq: s,
                        offset: at as u32,
                        count: 2,
                    }
                } else {
                    Op::Delete {
                        seq: s,
                        offset: at as u32,
                        count: 1,
                    }
                }
            }
            4 => {
                let at = (rng.next() as usize) % len.max(1);
                let bytes = client.get(at).map(|t| t.text.len()).unwrap_or(0);
                if bytes >= 2 {
                    Op::Split {
                        seq: s,
                        offset: at as u32,
                        byte_off: 1,
                    }
                } else {
                    Op::Delete {
                        seq: s,
                        offset: at as u32,
                        count: 1,
                    }
                }
            }
            5 => Op::Annotate {
                seq: s,
                offset: ((rng.next() as usize) % len.max(1)) as u32,
                count: 1,
                tag: 3,
                bytes: b"*".to_vec(),
            },
            _ => {
                let at = (rng.next() as usize) % len.max(1);
                Op::Delete {
                    seq: s,
                    offset: at as u32,
                    count: 1,
                }
            }
        };
        shadow_apply(&op, client);
        ops.push(op);
    }
    ops
}

/// Tokens around a position, for a failure that has to show its own context:
/// length and text, because a seam that moved one byte looks like a token that
/// appeared out of nowhere.
fn window(toks: &[Tok], at: usize) -> Vec<String> {
    let lo = at.saturating_sub(4);
    let hi = (at + 5).min(toks.len());
    toks[lo..hi]
        .iter()
        .enumerate()
        .map(|(i, t)| {
            format!(
                "{}{}: {:?} ({}B)",
                lo + i,
                if lo + i == at { " <" } else { "" },
                String::from_utf8_lossy(&t.text),
                t.text.len()
            )
        })
        .collect()
}

/// Every frame of one batch, up to and including its diff.
async fn batch_frames(rx: &mut Frames) -> Vec<ServerFrame> {
    let mut frames = Vec::new();
    loop {
        match timeout(WAIT, rx.recv()).await {
            Ok(Ok(bytes)) => {
                let frame = decode_server(&bytes).expect("a frame this build wrote");
                let done = matches!(frame, ServerFrame::Diff { .. } | ServerFrame::Snapshot { .. });
                frames.push(frame);
                if done {
                    return frames;
                }
            }
            _ => return frames,
        }
    }
}

#[tokio::test]
async fn every_diff_lands_on_the_server_rope() {
    let (state, ops_rx) = build_state(Session::with_doc(&doc()), None, 20);
    let mut rx = state.shared.out.subscribe();
    tokio::spawn(coalesce(ops_rx, state.clone()));

    let mut client = snapshot(&state);
    assert_eq!(client, tokens_of(&state), "a snapshot is the whole document");
    let mut rng = Lcg(0x5eed_1a7e_9b3c_4d21);
    let mut seq = 0u64;
    let mut revision = {
        let s = state.session.lock().expect("the session lock");
        s.rope.revision()
    };
    let mut diffs = 0usize;

    for batch in 0..BATCHES {
        let mut shadow = client.clone();
        let ops = make_batch(&mut rng, &mut shadow, &mut seq);
        let expected_acks = ops.len();
        let seqs: Vec<u64> = ops.iter().map(|o| o.seq()).collect();
        for op in &ops {
            state
                .ops_tx
                .send(vec![op.clone()])
                .expect("the op reaches the coalescer");
        }

        let frames = batch_frames(&mut rx).await;
        let found: Vec<&ServerFrame> = frames
            .iter()
            .filter(|f| matches!(f, ServerFrame::Diff { .. }))
            .collect();
        assert_eq!(
            found.len(),
            1,
            "batch {batch} owes exactly one diff, got {frames:?}"
        );
        let acks = frames
            .iter()
            .filter(|f| matches!(f, ServerFrame::Ack { .. }))
            .count();
        assert_eq!(
            acks, expected_acks,
            "batch {batch} acknowledges each of {expected_acks} ops: {frames:?}"
        );
        let (rev, start, deleted, insert) = match found[0] {
            ServerFrame::Diff {
                revision,
                start,
                deleted,
                inserted,
            } => (*revision, *start as usize, *deleted as usize, inserted.clone()),
            _ => unreachable!(),
        };
        assert_eq!(
            rev,
            revision + 1,
            "batch {batch} is one revision past {revision}"
        );
        revision = rev;
        diffs += 1;

        for frame in &frames {
            if let ServerFrame::Ack { revision: r, seq } = frame {
                assert_eq!(*r, rev, "ack for op {seq} carries the batch revision");
                assert!(
                    seqs.contains(seq),
                    "batch {batch} acked {seq}, which it did not send"
                );
            }
        }

        // What the page does with the frame, and nothing else.
        let mut applied = client.clone();
        assert!(
            start + deleted <= applied.len(),
            "batch {batch}: diff replaces {deleted} at {start}, client holds {}",
            applied.len()
        );
        let fresh: Vec<Tok> = insert
            .iter()
            .map(|t| Tok {
                flags: t.flags,
                text: t.text.clone(),
            })
            .collect();
        applied.splice(start..start + deleted, fresh);

        let server = tokens_of(&state);
        if applied != server {
            let at = applied
                .iter()
                .zip(server.iter())
                .position(|(a, b)| a != b)
                .unwrap_or(applied.len().min(server.len()));
            panic!(
                "batch {batch}: diff {start} −{deleted} +{} left the client off the rope at \
                 token {at} (client {} tokens, server {}; span ends at {})\n\
                 ops {ops:#?}\n  client {:#?}\n  server {:#?}",
                insert.len(),
                applied.len(),
                server.len(),
                start + insert.len(),
                window(&applied, at),
                window(&server, at),
            );
        }
        client = applied;
    }

    assert_eq!(diffs, BATCHES, "one diff per batch, and none carried a snapshot");
    assert_eq!(
        client,
        tokens_of(&state),
        "the list built only from the snapshot and the diff stream is the rope"
    );
}
