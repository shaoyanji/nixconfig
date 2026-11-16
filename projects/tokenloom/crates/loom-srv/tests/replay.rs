//! `snapshot@R + edits R..N` must reconstruct exactly `snapshot@N`.

use loom_core::{NewToken, Op, Rope, Tokenizer, FLAG_WORD};
use loom_react::ConstraintIndex;
use loom_srv::persist::{
    load, replay, restore, Persist, SnapshotFile, StoredConstraint, LOG_FILE, SNAP_FILE,
};
use loom_srv::session::Session;
use std::fs;
use std::path::PathBuf;

const DOC: &str = "\
the outstanding reconsideration of tokenization is that a merge can ripple past the window.\n\
a piece table keeps the bytes and the reactor bank keeps its own segmentation.\n";

struct Lcg(u64);

impl Lcg {
    fn next(&mut self) -> u64 {
        self.0 = self.0.wrapping_mul(6364136223846793005).wrapping_add(1442695040888963407);
        self.0 >> 11
    }
}

fn synth_ops(rope: &Rope, rng: &mut Lcg, seq: &mut u64) -> Vec<Op> {
    let mut ops = Vec::new();
    let len = rope.len_tokens();
    for _ in 0..(1 + rng.next() % 3) {
        *seq += 1;
        let at = if len == 0 { 0 } else { (rng.next() as usize) % len };
        let op = match rng.next() % 5 {
            0 => Op::Insert {
                seq: *seq,
                offset: at as u32,
                tokens: vec![NewToken {
                    flags: 1,
                    tag: 0,
                    text: b"reconsider".to_vec(),
                }],
            },
            1 => Op::Delete {
                seq: *seq,
                offset: at as u32,
                count: 1,
            },
            2 => Op::Split {
                seq: *seq,
                offset: at as u32,
                byte_off: 1,
            },
            3 => Op::Merge {
                seq: *seq,
                offset: at as u32,
                count: 2,
            },
            _ => Op::Insert {
                seq: *seq,
                offset: at as u32,
                tokens: vec![NewToken {
                    flags: 1,
                    tag: 0,
                    text: b"outstanding".to_vec(),
                }],
            },
        };
        ops.push(op);
    }
    ops
}

fn tokens(rope: &Rope) -> Vec<(usize, u16, u8)> {
    rope.abs_tokens()
        .into_iter()
        .map(|t| (t.start, t.len, t.flags))
        .collect()
}

fn temp_dir(tag: &str) -> PathBuf {
    let dir = std::env::temp_dir().join(format!("loom-{tag}-{}", std::process::id()));
    let _ = fs::remove_dir_all(&dir);
    dir
}

#[test]
fn replay_eq_snapshot() {
    let dir = temp_dir("replay");
    let mut sess = Session::with_doc(DOC);
    let mut rng = Lcg(0x1234_5678_9abc_def0);
    let mut seq = 0u64;
    let mut snap_at_12: Option<(u64, Vec<(usize, u16, u8)>)> = None;

    let (mut persist, snap, recs) = Persist::open(&dir).unwrap();
    assert!(snap.is_none() && recs.is_empty());

    for rev in 1..=40u64 {
        let ops = synth_ops(&sess.rope, &mut rng, &mut seq);
        sess.apply_batch(&ops);
        persist
            .append(&loom_srv::persist::BatchRecord {
                revision: sess.rope.revision(),
                ops,
            })
            .unwrap();
        if rev == 12 {
            persist.snapshot(&sess).unwrap();
            snap_at_12 = Some((sess.rope.revision(), tokens(&sess.rope)));
        }
    }
    drop(persist);
    let live = tokens(&sess.rope);
    let live_rev = sess.rope.revision();
    let live_doc = sess.rope.doc();
    assert!(live_rev >= 40);

    // Snapshot@12 plus the log's tail must land on the live state.
    let (snap, recs) = load(&dir).unwrap();
    let snap = snap.expect("snapshot at revision 12");
    assert_eq!(Some((snap.revision, tokens(&Rope::from_tokens(&snap.tokens)))), snap_at_12);
    assert!(recs.iter().all(|r| r.revision > snap.revision));
    let (rebuilt, _, _) = replay(
        Rope::from_tokens(&snap.tokens),
        ConstraintIndex::new(),
        [true; 8],
        &recs,
        &loom_tok::bpe_a(),
    );
    assert_eq!(rebuilt.revision(), live_rev);
    assert_eq!(tokens(&rebuilt), live);
    assert_eq!(rebuilt.doc(), live_doc);

    // And a snapshot at N shortens the log to nothing.
    let dir2 = temp_dir("replay-n");
    let mut p = Persist::open(&dir2).unwrap().0;
    let mut rope = sess.rope.clone();
    p.snapshot(&sess).unwrap();
    let (thin_snap, thin_recs) = load(&dir2).unwrap();
    assert!(thin_recs.is_empty());
    let thin = thin_snap.expect("snapshot at N");
    let (thin_rope, _, _) = replay(
        Rope::from_tokens(&thin.tokens),
        ConstraintIndex::new(),
        [true; 8],
        &thin_recs,
        &loom_tok::bpe_a(),
    );
    rope = thin_rope;
    assert_eq!(tokens(&rope), live);

    let _: SnapshotFile = thin;
    for f in [LOG_FILE, SNAP_FILE] {
        assert!(dir.join(f).exists(), "{f} should exist");
    }
    let _ = fs::remove_dir_all(&dir);
    let _ = fs::remove_dir_all(&dir2);
}

#[test]
fn replay_retokenizes_rather_than_trusting_ops() {
    let dir = temp_dir("replay-lex");
    let mut sess = Session::with_doc("the outstanding reconsideration");
    let mut rng = Lcg(99);
    let mut seq = 0u64;
    let mut p = Persist::open(&dir).unwrap().0;
    for _ in 0..6 {
        let ops = synth_ops(&sess.rope, &mut rng, &mut seq);
        sess.apply_batch(&ops);
        p.append(&loom_srv::persist::BatchRecord { revision: sess.rope.revision(), ops }).unwrap();
    }
    drop(p);

    let (_, recs) = load(&dir).unwrap();
    let (replayed, _, _) =
        replay(Rope::new(), ConstraintIndex::new(), [true; 8], &recs, &loom_tok::bpe_a());
    let want: Vec<(usize, u16, u8)> = loom_tok::bpe_a()
        .tokenize(&replayed.doc())
        .into_iter()
        .map(|s| (s.start, s.len as u16, s.flags))
        .collect();
    assert_eq!(tokens(&replayed), want, "replay must end on the tokenizer's own answer");
    let _ = fs::remove_dir_all(&dir);
}

/// A snapshot written before constraints were stored must still open: falling
/// back to the empty index is right, refusing it would silently start over on a
/// document the user still has on disk.
#[test]
fn legacy_snapshot_still_loads() {
    #[derive(serde::Serialize)]
    struct SnapV1 {
        revision: u64,
        tokens: Vec<NewToken>,
    }

    let dir = temp_dir("replay-legacy");
    let sess = Session::with_doc("the outstanding reconsideration");
    let bytes = bincode::serialize(&SnapV1 {
        revision: 7,
        tokens: sess.snapshot_tokens(),
    })
    .unwrap();
    fs::create_dir_all(&dir).unwrap();
    fs::write(dir.join(SNAP_FILE), &bytes).unwrap();

    let (snap, records) = load(&dir).unwrap();
    let snap = snap.expect("an old snapshot is still a snapshot");
    assert_eq!(snap.revision, 7);
    assert!(snap.constraints.is_empty());
    assert!(records.is_empty());
    let back = restore(&snap, &records, &loom_tok::bpe_a());
    assert_eq!(back.rope.revision(), 7);
    assert_eq!(back.rope.doc(), sess.rope.doc());
    assert!(back.constraints.is_empty());

    // The shape before reactors were written down: constraints survive, and a
    // bank that was never recorded comes back with every reactor on.
    #[derive(serde::Serialize)]
    struct SnapV2 {
        revision: u64,
        tokens: Vec<NewToken>,
        constraints: Vec<StoredConstraint>,
    }
    let v2 = bincode::serialize(&SnapV2 {
        revision: 9,
        tokens: sess.snapshot_tokens(),
        constraints: vec![StoredConstraint { anchor: 0, len: 1, kind: 1, param: 4 }],
    })
    .unwrap();
    let mut with_magic = b"LMS2".to_vec();
    with_magic.extend(v2);
    fs::write(dir.join(SNAP_FILE), &with_magic).unwrap();

    let (snap, records) = load(&dir).unwrap();
    let snap = snap.expect("the constraint-carrying shape still opens");
    assert_eq!(snap.revision, 9);
    assert_eq!(snap.constraints.len(), 1);
    assert_eq!(snap.reactors, [true; 8]);
    let back = restore(&snap, &records, &loom_tok::bpe_a());
    assert_eq!(back.constraints.len(), 1);
    assert_eq!(back.reactor_bits(), 0b1111_1111);
    let _ = fs::remove_dir_all(&dir);
}

/// A switch thrown before the snapshot rides the snapshot; one thrown after it
/// rides the log. Both have to come back, or the panel shows every reactor on
/// while the server quietly skips the ones that were turned off.
#[test]
fn reactor_toggles_survive_a_restart() {
    let dir = temp_dir("replay-reactors");
    let mut sess = Session::with_doc("alpha beta gamma delta");
    let (mut persist, _, _) = Persist::open(&dir).unwrap();
    assert_eq!(sess.reactor_bits(), 0b1111_1111);

    sess.apply_batch(&[Op::ReactorToggle { seq: 1, reactor: 2, enabled: false }]);
    assert!(!sess.reactors[2]);
    persist.snapshot(&sess).unwrap();

    let toggle = vec![Op::ReactorToggle { seq: 2, reactor: 5, enabled: false }];
    sess.apply_batch(&toggle);
    let live = sess.reactors;
    assert!(!live[5]);
    persist
        .append(&loom_srv::persist::BatchRecord { revision: sess.rope.revision(), ops: toggle })
        .unwrap();
    drop(persist);

    let (snap, recs) = load(&dir).unwrap();
    let snap = snap.expect("the pinned snapshot");
    assert!(
        !snap.reactors[2],
        "a switch thrown before the snapshot is written down with it"
    );
    assert_eq!(
        recs.len(),
        1,
        "a toggle-only batch must outlive the snapshot it follows, or it is trimmed"
    );
    let back = restore(&snap, &recs, &loom_tok::bpe_a());
    assert_eq!(back.reactors, live);
    assert_eq!(back.reactor_bits(), sess.reactor_bits());
    assert_eq!(back.rope.doc(), sess.rope.doc());
    let _ = fs::remove_dir_all(&dir);
}

/// A constraint planted before the snapshot rides the snapshot; one planted
/// after it rides the log. Both have to come back on the bytes they were
/// planted on, having moved with an insert that landed ahead of them.
#[test]
fn constraints_survive_a_restart() {
    let dir = temp_dir("replay-constraints");
    let mut sess = Session::with_doc("alpha beta gamma delta");
    let (mut persist, _, _) = Persist::open(&dir).unwrap();

    let doc = sess.rope.doc();
    let beta = doc.windows(4).position(|w| w == b"beta").expect("beta in doc");
    let at_beta = sess
        .rope
        .abs_tokens()
        .iter()
        .position(|t| t.start == beta)
        .expect("token at beta");

    sess.apply_batch(&[Op::ConstraintAdd {
        seq: 1,
        start: at_beta as u32,
        len: 1,
        kind: 1,
        param: 3,
    }]);
    assert_eq!(sess.constraints.len(), 1);
    persist.snapshot(&sess).unwrap();

    // An insert ahead of the span: the anchor only comes back right if the log
    // tail is replayed onto the same coordinates.
    let insert_ops = vec![Op::Insert {
        seq: 2,
        offset: 0,
        tokens: vec![NewToken {
            flags: FLAG_WORD,
            tag: 0,
            text: b"zero ".to_vec(),
        }],
    }];
    sess.apply_batch(&insert_ops);
    persist
        .append(&loom_srv::persist::BatchRecord {
            revision: sess.rope.revision(),
            ops: insert_ops,
        })
        .unwrap();
    assert_eq!(
        sess.constraints.iter().next().map(|c| c.anchor as usize),
        Some(beta + 5),
        "the live anchor must have followed the text"
    );

    let after_snapshot = vec![Op::ConstraintAdd {
        seq: 3,
        start: 0,
        len: 2,
        kind: 2,
        param: 32,
    }];
    sess.apply_batch(&after_snapshot);
    persist
        .append(&loom_srv::persist::BatchRecord {
            revision: sess.rope.revision(),
            ops: after_snapshot,
        })
        .unwrap();
    let live: Vec<(u32, u16, u8, u32)> = sess
        .constraints
        .iter()
        .map(|c| (c.anchor, c.len, c.kind as u8, c.param))
        .collect();
    assert_eq!(live.len(), 2);
    drop(persist);

    let (snap, recs) = load(&dir).unwrap();
    let snap = snap.expect("the pinned snapshot");
    assert_eq!(snap.constraints.len(), 1, "the snapshot carries the span it saw");
    assert_eq!(recs.len(), 2, "an insert and a constraint ride the log");
    let back = restore(&snap, &recs, &loom_tok::bpe_a());

    let again: Vec<(u32, u16, u8, u32)> = back
        .constraints
        .iter()
        .map(|c| (c.anchor, c.len, c.kind as u8, c.param))
        .collect();
    assert_eq!(live, again, "a restart must rebuild the anchors the session held");
    assert_eq!(back.rope.doc(), sess.rope.doc(), "and the document bytes");

    let anchor = again[0].0 as usize;
    let doc = back.rope.doc();
    assert_eq!(
        &doc[anchor..anchor + 4],
        b"beta",
        "the restored span still names the word it was planted on"
    );
    assert!(anchor > beta, "the insert ahead of it must have moved the anchor");
    let _ = fs::remove_dir_all(&dir);
}
