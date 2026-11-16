//! One document, one session: apply a batch, retokenize the window, describe
//! the minimal diff.
//!
//! Ops inside a batch are applied verbatim and retokenized once afterwards. That
//! ordering is not an optimization: retokenizing between ops would change the
//! token indices the client's next op refers to, and the op would land on a
//! different token than the one the user clicked.

use loom_core::{
    batch_frame, retokenize_window, ripple::spans_to_tokens, AbsToken, EditOut, NewToken, Op,
    RetokReport, RippleConfig, Rope, Tokenizer,
};
use loom_react::{ConstraintIndex, ConstraintKind};
use loom_tok::bpe_a;
use loom_wire::ConstraintView;
use std::collections::VecDeque;
use std::ops::Range;
use std::sync::Arc;
use std::time::Instant;

pub const MAX_CONSTRAINTS: usize = 256;
const METRIC_SAMPLES: usize = 1024;

/// Plant a constraint named by tokens, anchored on the byte its span starts at.
///
/// The wire speaks tokens because that is what a client has, but the index
/// keeps bytes so the span follows its text. The live batch path and replay
/// both convert here, so a restart cannot land a span somewhere the session
/// that recorded it would not have.
pub fn plant_constraint(
    rope: &Rope,
    index: &mut ConstraintIndex,
    start: u32,
    len: u16,
    kind: u8,
    param: u32,
) -> bool {
    let Some(kind) = ConstraintKind::from_u8(kind) else {
        return false;
    };
    if index.len() >= MAX_CONSTRAINTS {
        return false;
    }
    let anchor = rope.byte_of_token(start as usize).min(u32::MAX as usize) as u32;
    let param = if matches!(kind, ConstraintKind::BoundaryStableAt) {
        anchor
    } else {
        param
    };
    index.add(anchor, len, kind, param);
    true
}

/// Apply one rope op and move the anchors that edit moved.
///
/// One implementation for the live path and for replay: a shift that happens in
/// only one of them is a constraint that moves in the session and stays put
/// after a restart.
pub fn apply_with_anchors(
    op: &Op,
    rope: &mut Rope,
    constraints: &mut ConstraintIndex,
) -> Option<EditOut> {
    let out = op.apply_to(rope);
    if let Some(eo) = out {
        constraints.shift(eo.byte_start as u32, eo.old_bytes, eo.new_bytes);
    }
    out
}

/// The batch's changed token range in post-batch coordinates, shifted per op by
/// the deltas of the ops that came after it. Exact even when an op's offset had
/// to be clamped, which is when the affine pre/post mapping is not.
fn seed_union(
    splices: &[(usize, usize, i64)],
    total_delta: i64,
    total: usize,
) -> std::ops::Range<usize> {
    let mut lo = usize::MAX;
    let mut hi = 0usize;
    for (start, new_count, cum_after) in splices {
        let shifted = (*start as i64 + (total_delta - *cum_after)).max(0) as usize;
        lo = lo.min(shifted.min(total));
        hi = hi.max((shifted + *new_count).min(total));
    }
    if lo == usize::MAX {
        0..0
    } else {
        lo..hi.max(lo)
    }
}

#[derive(Clone, Debug)]
pub struct Applied {
    pub revision: u64,
    pub start: usize,
    pub deleted: u16,
    pub inserted: usize,
    pub tokens: Vec<NewToken>,
    pub tok_window: Range<usize>,
    pub byte_window: Range<usize>,
    pub retok: RetokReport,
    pub latency_us: u32,
    pub doc: Arc<Vec<u8>>,
    pub abs: Arc<Vec<AbsToken>>,
}

#[derive(Default)]
pub struct BatchOutcome {
    pub seqs: Vec<u64>,
    pub applied: Option<Applied>,
    pub resync: bool,
    /// The index changed — planted, removed or retuned — even though no text
    /// moved. The caller cannot tell by comparing lengths: a retune moves none.
    pub constraints: bool,
}

pub struct Session {
    pub rope: Rope,
    tok: Box<dyn Tokenizer>,
    pub cfg: RippleConfig,
    pub constraints: ConstraintIndex,
    /// Which reactors the session believes are on. The pool keeps its own copy
    /// for its sink; this one is what a snapshot writes down.
    pub reactors: [bool; 8],
    latencies: VecDeque<u32>,
    last_window: u32,
    pub ripple_truncations: u64,
    sum_retok: u64,
    sum_doc: u64,
    retok_edits: u64,
}

impl Session {
    pub fn with_tok(tok: Box<dyn Tokenizer>) -> Self {
        Session {
            rope: Rope::new(),
            tok,
            cfg: RippleConfig::default(),
            constraints: ConstraintIndex::new(),
            reactors: [true; 8],
            latencies: VecDeque::new(),
            last_window: 0,
            ripple_truncations: 0,
            sum_retok: 0,
            sum_doc: 0,
            retok_edits: 0,
        }
    }

    pub fn with_doc(text: &str) -> Self {
        let mut s = Session::with_tok(Box::new(bpe_a()));
        s.replace_doc(text);
        s
    }

    pub fn from_snapshot(tokens: &[NewToken], revision: u64) -> Self {
        let mut s = Session::with_tok(Box::new(bpe_a()));
        s.rope = Rope::from_tokens(tokens);
        s.rope.set_revision(revision);
        s
    }

    pub fn tokenizer_name(&self) -> &str {
        self.tok.name()
    }

    pub fn replace_doc(&mut self, text: &str) {
        let doc = text.as_bytes().to_vec();
        let spans = self.tok.tokenize(&doc);
        self.rope = Rope::from_tokens(&spans_to_tokens(&doc, &spans));
    }

    pub fn snapshot_tokens(&self) -> Vec<NewToken> {
        let doc = self.rope.doc();
        self.rope
            .abs_tokens()
            .into_iter()
            .map(|t| NewToken {
                flags: t.flags,
                tag: t.tag,
                text: doc[t.start..t.end()].to_vec(),
            })
            .collect()
    }

    pub fn apply_batch(&mut self, ops: &[Op]) -> BatchOutcome {
        let started = Instant::now();
        let pre_len = self.rope.len_tokens();
        let mut cum: i64 = 0;
        let mut base: i64 = i64::MAX;
        let mut end: i64 = i64::MIN;
        let mut text_changed = false;
        let mut planted = false;
        let mut removed = false;
        let mut updated = false;
        let mut toggled = false;
        let mut resync = false;
        let mut diverged = false;
        // (tok_start, new_count, cumulative delta after this op), which is what
        // the seed window is derived from once every op has landed.
        let mut splices: Vec<(usize, usize, i64)> = Vec::new();
        let mut seqs = Vec::with_capacity(ops.len());

        for op in ops {
            seqs.push(op.seq());
            match op {
                Op::ConstraintAdd { start, len, kind, param, .. } => {
                    planted |= plant_constraint(
                        &self.rope,
                        &mut self.constraints,
                        *start,
                        *len,
                        *kind,
                        *param,
                    );
                }
                Op::ConstraintRemove { id, .. } => {
                    removed |= self.constraints.remove(*id);
                }
                Op::ConstraintUpdate { id, kind, param, .. } => {
                    if let Some(kind) = ConstraintKind::from_u8(*kind) {
                        updated |= self.constraints.update(*id, kind, *param);
                    }
                }
                Op::ReactorToggle { reactor, enabled, .. } => {
                    let i = (*reactor as usize) % self.reactors.len();
                    self.reactors[i] = *enabled;
                    toggled = true;
                }
                Op::Resync { .. } => resync = true,
                Op::Annotate { .. } => {
                    let _ = op.apply_to(&mut self.rope);
                }
                _ => {
                    let before = self.rope.len_tokens();
                    let requested = match op {
                        Op::Insert { offset, .. }
                        | Op::Delete { offset, .. }
                        | Op::Merge { offset, .. }
                        | Op::Split { offset, .. } => *offset as usize,
                        _ => 0,
                    };
                    // An offset past the end, or a merge/split that did nothing,
                    // means the sender and this rope disagree. Keep the rope
                    // correct and hand that client a snapshot rather than a diff
                    // computed from coordinates that do not line up.
                    if requested > before {
                        diverged = true;
                    }
                    if let Some(eo) =
                        apply_with_anchors(op, &mut self.rope, &mut self.constraints)
                    {
                        let pre_start = eo.tok_start as i64 - cum;
                        base = base.min(pre_start);
                        end = end.max(pre_start + eo.old_count as i64);
                        cum += eo.new_count as i64 - eo.old_count as i64;
                        splices.push((eo.tok_start, eo.new_count, cum));
                        text_changed = true;
                    } else if matches!(op, Op::Merge { .. } | Op::Split { .. }) {
                        diverged = true;
                        text_changed = true;
                    }
                }
            }
        }

        if base == i64::MAX {
            // A batch that only planted a constraint or threw a switch changed
            // the session though it moved no text. Bump so its log record is
            // newer than any snapshot the log is trimmed against: otherwise a
            // constraint planted, or a reactor switched off, after the last
            // snapshot would be dropped on the next load.
            if planted || removed || updated || toggled {
                self.rope.bump_revision();
            }
            return BatchOutcome {
                seqs,
                applied: None,
                resync,
                constraints: planted || removed || updated,
            };
        }
        resync = resync || diverged;

        let base = base.max(0) as usize;
        let end = (end.max(base as i64)) as usize;

        let mut retok = RetokReport::default();
        if text_changed {
            let seed = seed_union(&splices, cum, self.rope.len_tokens());
            retok = retokenize_window(&mut self.rope, seed, &*self.tok, &self.cfg);
            if retok.truncated {
                self.ripple_truncations += 1;
            }
            self.sum_retok += retok.bytes_retokenized as u64;
            self.sum_doc += self.rope.len_bytes().max(1) as u64;
            self.retok_edits += 1;
        }

        let post_len = self.rope.len_tokens();
        let (deleted, inserted) = batch_frame(base, end, pre_len, post_len);
        let inserted_end = (base + inserted).min(post_len);

        let doc = Arc::new(self.rope.doc());
        let abs = Arc::new(self.rope.abs_range(0..post_len));
        let tokens: Vec<NewToken> = abs[base.min(abs.len())..inserted_end]
            .iter()
            .map(|t| NewToken {
                flags: t.flags,
                tag: t.tag,
                text: doc[t.start..t.end()].to_vec(),
            })
            .collect();

        let byte_start = self.rope.byte_of_token(base);
        let byte_end = if inserted_end > base {
            abs.get(inserted_end - 1).map(|t| t.end()).unwrap_or(byte_start)
        } else {
            byte_start
        };
        let byte_window = byte_start..byte_end.max(byte_start);
        let tok_end = (base + 1).min(post_len).max(inserted_end);
        let tok_window = base.min(post_len)..tok_end;
        self.last_window = tok_window.len() as u32;

        let revision = self.rope.bump_revision();
        let latency_us = started.elapsed().as_micros().min(u32::MAX as u128) as u32;
        if text_changed {
            self.latencies.push_back(latency_us);
            if self.latencies.len() > METRIC_SAMPLES {
                self.latencies.pop_front();
            }
        }

        BatchOutcome {
            seqs,
            applied: Some(Applied {
                revision,
                start: base,
                deleted: deleted.min(u16::MAX as usize) as u16,
                inserted,
                tokens,
                tok_window,
                byte_window,
                retok,
                latency_us,
                doc,
                abs,
            }),
            resync,
            constraints: planted || removed || updated,
        }
    }

    pub fn percentiles(&self) -> (u32, u32) {
        if self.latencies.is_empty() {
            return (0, 0);
        }
        let mut v: Vec<u32> = self.latencies.iter().copied().collect();
        v.sort_unstable();
        let at = |q: f64| v[(((v.len() - 1) as f64) * q).round() as usize];
        (at(0.50), at(0.99))
    }

    /// Bytes re-tokenized per edit, in basis points of the document.
    pub fn retok_per_edit_bp(&self) -> u32 {
        if self.sum_doc == 0 {
            return 0;
        }
        (self.sum_retok.saturating_mul(10_000) / self.sum_doc).min(u32::MAX as u64) as u32
    }

    pub fn retok_edits(&self) -> u64 {
        self.retok_edits
    }

    /// Tokens the reactors saw in the last batch window.
    pub fn last_window(&self) -> u32 {
        self.last_window
    }

    /// The constraint index as a page lists it, in plant order. The page holds
    /// no index of its own, so this is the whole list rather than a delta.
    pub fn constraint_views(&self) -> Vec<ConstraintView> {
        // The page holds no byte index: an anchor becomes a token here, with one
        // partition per constraint over the rope's own starts. Doing it on the
        // server is also what keeps the page from rebuilding a byte table on
        // every diff — measured at 29.5 ms a rebuild on a 49k-token rope.
        let abs = self.rope.abs_tokens();
        let at = |anchor: u32| -> u32 {
            if abs.is_empty() {
                return 0;
            }
            let i = abs.partition_point(|t| t.start <= anchor as usize);
            i.saturating_sub(1).min(abs.len() - 1) as u32
        };
        self.constraints
            .iter()
            .map(|c| ConstraintView {
                id: c.id,
                anchor: c.anchor,
                token: at(c.anchor),
                len: c.len,
                kind: c.kind as u8,
                param: c.param,
            })
            .collect()
    }

    /// Bit per reactor id, bit `i` = reactor `i`: ids are 1-based, so bit 0 is
    /// never used and neither are the spare slots past the last reactor. The
    /// snapshot frame carries this so a fresh page draws the bank the session
    /// has, not a panel that lies.
    pub fn reactor_bits(&self) -> u8 {
        let mut bits = 0u8;
        for (i, on) in self.reactors.iter().enumerate() {
            if *on {
                bits |= 1 << i;
            }
        }
        bits
    }
}
