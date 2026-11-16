//! Ripple re-tokenization.
//!
//! An edit dirties a token range. Re-lexing exactly that range is wrong when a
//! merge rule can join bytes across either edge, so the window is expanded by
//! `lookahead` bytes and expanded again until both edges fall on a boundary the
//! tokenizer calls stable. Bounded by `max_steps`; when the bound is hit the
//! window is widened to the enclosing word run anyway and the report says
//! `truncated`, so output stays correct and the cost is on the record instead of
//! silently wrong.

use crate::diff::trim_affix;
use crate::rope::{tag_at, NewToken, Rope};
use crate::{TokenSpan, Tokenizer};

#[derive(Clone, Copy, Debug)]
pub struct RippleConfig {
    pub lookahead: usize,
    pub max_steps: usize,
}

impl Default for RippleConfig {
    fn default() -> Self {
        RippleConfig { lookahead: 64, max_steps: 3 }
    }
}

#[derive(Clone, Copy, Debug, Default)]
pub struct RetokReport {
    pub tok_start: usize,
    pub old_count: usize,
    pub new_count: usize,
    pub bytes_retokenized: usize,
    pub steps: usize,
    pub truncated: bool,
}

impl RetokReport {
    /// Token-count change this window caused.
    pub fn delta(&self) -> i64 {
        self.new_count as i64 - self.old_count as i64
    }
}

fn stable(tok: &dyn Tokenizer, doc: &[u8], a: usize, b: usize) -> bool {
    tok.stable_at(doc, a) && tok.stable_at(doc, b)
}

/// Walk from `pos` toward one edge until the boundary is stable, or until
/// `limit` bytes have been walked.
///
/// Snapping to a *stable* boundary rather than merely a token boundary is what
/// keeps the window small: one step lands on the edge of the enclosing word run,
/// where a second step would have landed in the middle of some earlier word and
/// forced another expansion.
fn snap(doc: &[u8], tok: &dyn Tokenizer, pos: usize, right: bool, limit: usize) -> usize {
    let mut p = pos;
    let mut walked = 0usize;
    if right {
        while p < doc.len() && !tok.stable_at(doc, p) && walked < limit {
            p += 1;
            walked += 1;
        }
    } else {
        while p > 0 && !tok.stable_at(doc, p) && walked < limit {
            p -= 1;
            walked += 1;
        }
    }
    p
}

/// Re-tokenize the smallest stable window covering the dirty token range and
/// splice it back. Returns the minimal splice that was applied.
pub fn retokenize_window(
    rope: &mut Rope,
    seed: std::ops::Range<usize>,
    tok: &dyn Tokenizer,
    cfg: &RippleConfig,
) -> RetokReport {
    let total_tokens = rope.len_tokens();
    let mut lo = seed.start.min(total_tokens).saturating_sub(1);
    let mut hi = (seed.end.min(total_tokens) + 1).max(lo).min(total_tokens);
    let doc = rope.doc();
    let total_bytes = doc.len();
    let mut bs = rope.byte_of_token(lo);
    let mut be = rope.byte_of_token(hi);
    let mut steps = 0usize;
    let mut truncated = false;

    for _ in 0..cfg.max_steps.max(1) {
        if stable(tok, &doc, bs, be) {
            break;
        }
        let a = snap(&doc, tok, bs, false, cfg.lookahead.max(1));
        let b = snap(&doc, tok, be, true, cfg.lookahead.max(1));
        if a == bs && b == be {
            truncated = true;
            break;
        }
        steps += 1;
        lo = rope.token_at_byte(a, false);
        hi = rope.token_at_byte(b, true);
        bs = rope.byte_of_token(lo);
        be = rope.byte_of_token(hi);
    }

    if !stable(tok, &doc, bs, be) {
        // A word run wider than the whole ripple budget: widen to its edges
        // anyway. Correct, over budget, and counted.
        truncated = true;
        let a = snap(&doc, tok, bs, false, total_bytes);
        let b = snap(&doc, tok, be, true, total_bytes);
        lo = rope.token_at_byte(a, false);
        hi = rope.token_at_byte(b, true);
        bs = rope.byte_of_token(lo);
        be = rope.byte_of_token(hi);
    }

    let spans = tok.tokenize(&doc[bs..be]);
    let old = rope.abs_range(lo..hi);
    let mut new_items: Vec<NewToken> = Vec::with_capacity(spans.len());
    for s in &spans {
        let start = bs + s.start;
        let tag = tag_at(&old, start);
        new_items.push(NewToken {
            flags: s.flags,
            tag,
            text: doc[start..start + s.len].to_vec(),
        });
    }

    let old_keys: Vec<(u8, Vec<u8>)> = old
        .iter()
        .map(|t| (t.flags, doc[t.start..t.end()].to_vec()))
        .collect();
    let new_keys: Vec<(u8, Vec<u8>)> = new_items.iter().map(|t| (t.flags, t.text.clone())).collect();
    let (prefix, suffix) = trim_affix(&old_keys, &new_keys);

    let mid_len = old_keys.len() - prefix - suffix;
    let new_mid = &new_items[prefix..new_items.len() - suffix];

    if mid_len > 0 || !new_mid.is_empty() {
        rope.edit_at(lo + prefix, mid_len, new_mid);
    }

    RetokReport {
        tok_start: lo + prefix,
        old_count: mid_len,
        new_count: new_mid.len(),
        bytes_retokenized: be - bs,
        steps,
        truncated,
    }
}

/// Tokenizer spans as tokens over `doc`, for seeding a rope from scratch.
pub fn spans_to_tokens(doc: &[u8], spans: &[TokenSpan]) -> Vec<NewToken> {
    spans
        .iter()
        .map(|s| NewToken {
            flags: s.flags,
            tag: 0,
            text: doc[s.start..s.end()].to_vec(),
        })
        .collect()
}
