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

/// Microseconds a batch spent in each phase, summed over the batches measured.
///
/// The gate reports one number for the segment an editor feels, and that number
/// is the one that has to hold. This is the diagnostic beside it: when the gate
/// misses on a large document, the phase that grew with the document is the one
/// to open, and saying which one it is beats guessing from the total.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct PhaseTotals {
    /// Applying the ops to the rope, anchors and constraint index included.
    pub ops_us: u64,
    /// Widening, re-lexing and splicing the dirty window.
    pub retok_us: u64,
    /// Copying out the document and the token array the send path and the
    /// reactors read.
    pub materialize_us: u64,
}

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

/// Map an offset in the space one op was written in back to the batch's starting
/// space.
///
/// Ops inside a batch are written against the document as the client has already
/// applied its own edits, so the second delete in a burst names the token *after*
/// the first one shifted the rope. `deltas` holds each splice's position in
/// starting coordinates and its token delta, sorted: within the segment between
/// two splices the shift is the sum of the deltas before it, so the inverse is a
/// walk over those segments rather than an arithmetic guess.
fn to_pre(at: usize, deltas: &[(usize, i64)]) -> usize {
    let mut shift = 0i64;
    for &(p, d) in deltas {
        let x = at as i64 - shift;
        if x < p as i64 {
            return x.max(0) as usize;
        }
        shift += d;
    }
    (at as i64 - shift).max(0) as usize
}

/// A starting-space position carried forward past the splices that end before it:
/// the first token of the region a splice inserted, not the token after it.
fn to_post_before(pre: usize, deltas: &[(usize, i64)]) -> usize {
    let shift: i64 = deltas
        .iter()
        .take_while(|&&(p, _)| p < pre)
        .map(|&(_, d)| d)
        .sum();
    (pre as i64 + shift).max(0) as usize
}

/// The same for an exclusive end: every splice at or before it counts, so a run
/// of appends at one position ends after all of them.
fn to_post_through(pre: usize, deltas: &[(usize, i64)]) -> usize {
    let shift: i64 = deltas
        .iter()
        .take_while(|&&(p, _)| p <= pre)
        .map(|&(_, d)| d)
        .sum();
    (pre as i64 + shift).max(0) as usize
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
    phases: PhaseTotals,
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
            phases: PhaseTotals::default(),
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
        let mut text_changed = false;
        let mut planted = false;
        let mut removed = false;
        let mut updated = false;
        let mut toggled = false;
        let mut resync = false;
        let mut diverged = false;
        // Each splice as (start in the batch's starting coordinates, tokens it
        // replaced), plus the delta map that puts a later op's offset back into
        // that space. Both are what make the frame span the whole batch.
        let mut pre_spans: Vec<(usize, usize)> = Vec::new();
        let mut deltas: Vec<(usize, i64)> = Vec::new();
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
                        let pre_start = to_pre(eo.tok_start, &deltas);
                        pre_spans.push((pre_start, eo.old_count));
                        let delta = eo.new_count as i64 - eo.old_count as i64;
                        let slot = deltas
                            .binary_search_by_key(&pre_start, |&(p, _)| p)
                            .unwrap_or_else(|i| i);
                        deltas.insert(slot, (pre_start, delta));
                        text_changed = true;
                    } else if matches!(op, Op::Merge { .. } | Op::Split { .. }) {
                        diverged = true;
                        text_changed = true;
                    }
                }
            }
        }

        let ops_us = started.elapsed().as_micros() as u64;

        if pre_spans.is_empty() {
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

        // The union in starting coordinates, widened where an op that landed
        // after an earlier splice was shifted by it: the window can be a token
        // too wide (the trim recovers the minimal diff) but never one too
        // narrow, which is a token the client would keep.
        let mut base = pre_spans.iter().map(|(s, _)| *s).min().unwrap_or(0);
        let mut end = pre_spans
            .iter()
            .map(|(s, c)| s + c)
            .max()
            .unwrap_or(base)
            .max(base);

        let mut retok = RetokReport::default();
        let mut retok_us = 0u64;
        if text_changed {
            let seed = to_post_before(base, &deltas)..to_post_through(end, &deltas);
            let t = Instant::now();
            retok = retokenize_window(&mut self.rope, seed.clone(), &*self.tok, &self.cfg);
            retok_us = t.elapsed().as_micros() as u64;
            // The ripple widens to a stable boundary, so it can rewrite a token
            // the batch's own spans never named — the word the edit landed
            // beside, or the one that ends the window. A frame that stopped at
            // the spans would leave the client holding its old copy of that
            // token, and from there on every token is one off: the document
            // looks right for a keystroke and then edits land in the wrong
            // place. So the frame spans the union of what the batch named and
            // what the ripple touched, mapped back into starting coordinates.
            let touched = retok.tok_start + retok.old_count;
            if retok.tok_start < seed.start || touched > seed.end {
                let lo = seed.start.min(retok.tok_start);
                let hi = seed.end.max(touched);
                base = base.min(to_pre(lo, &deltas));
                end = end.max(to_pre(hi, &deltas));
            }
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
        debug_assert!(
            base + inserted <= post_len,
            "the widened frame runs past the document: {base}+{inserted} > {post_len}"
        );

        let t_mat = Instant::now();
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
        let materialize_us = t_mat.elapsed().as_micros() as u64;
        self.phases.ops_us += ops_us;
        self.phases.retok_us += retok_us;
        self.phases.materialize_us += materialize_us;
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

    /// Where the edits that [`Session::percentiles`] timed actually went.
    pub fn phases(&self) -> PhaseTotals {
        self.phases
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
