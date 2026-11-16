//! Constraints over byte anchors.
//!
//! A constraint is anchored at a byte offset, not at a token index. "Token 40"
//! means a different piece of text the moment anything before it is inserted;
//! a byte anchor moves with the text, so a span keeps pointing at what it was
//! planted on.
//!
//! The index is a bucket list over anchor blocks, and its query is a superset:
//! a reactor maps the anchor to tokens and decides overlap in token space, so a
//! widened hint can only add candidates, never drop one.

pub const BLOCK: u32 = 128;

/// Upper bound on bytes per token, used to widen an anchor into blocks. Errs
/// wide on purpose.
const MAX_TOKEN_BYTES: u32 = 16;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
#[repr(u8)]
pub enum ConstraintKind {
    MaxTokensInSpan = 1,
    NoTokenCrossesDelimiter = 2,
    BoundaryStableAt = 3,
}

impl ConstraintKind {
    pub fn from_u8(v: u8) -> Option<Self> {
        Some(match v {
            1 => ConstraintKind::MaxTokensInSpan,
            2 => ConstraintKind::NoTokenCrossesDelimiter,
            3 => ConstraintKind::BoundaryStableAt,
            _ => return None,
        })
    }

    pub fn label(self) -> &'static str {
        match self {
            ConstraintKind::MaxTokensInSpan => "max-tokens-in-span",
            ConstraintKind::NoTokenCrossesDelimiter => "no-token-crosses-delimiter",
            ConstraintKind::BoundaryStableAt => "boundary-stable-at",
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Constraint {
    pub id: u32,
    /// Byte offset of the span start, kept current as text moves before it.
    pub anchor: u32,
    /// Span length in tokens, as counted when the constraint was planted.
    pub len: u16,
    pub kind: ConstraintKind,
    pub param: u32,
}

impl Constraint {
    /// Far end of the anchor in bytes, widened by the widest a token can be.
    pub fn end_hint(&self) -> u32 {
        self.anchor
            .saturating_add(self.len.max(1) as u32 * MAX_TOKEN_BYTES)
    }

    pub fn describe(&self) -> String {
        match self.kind {
            ConstraintKind::MaxTokensInSpan => format!("max {} tokens", self.param),
            ConstraintKind::NoTokenCrossesDelimiter => {
                format!("no token crosses '{}'", char::from(self.param as u8))
            }
            ConstraintKind::BoundaryStableAt => {
                format!("stable boundary at byte {}", self.anchor)
            }
        }
    }
}

#[derive(Clone, Debug, Default)]
pub struct ConstraintIndex {
    items: Vec<Constraint>,
    blocks: Vec<Vec<u32>>,
    next_id: u32,
}

impl ConstraintIndex {
    pub fn new() -> Self {
        ConstraintIndex::default()
    }

    pub fn len(&self) -> usize {
        self.items.len()
    }

    pub fn is_empty(&self) -> bool {
        self.items.is_empty()
    }

    pub fn iter(&self) -> impl Iterator<Item = &Constraint> {
        self.items.iter()
    }

    pub fn add(&mut self, anchor: u32, len: u16, kind: ConstraintKind, param: u32) -> u32 {
        let id = self.next_id;
        self.next_id += 1;
        let c = Constraint {
            id,
            anchor,
            len,
            kind,
            param,
        };
        let lo = c.anchor / BLOCK;
        let hi = c.end_hint() / BLOCK;
        for b in lo..=hi {
            let b = b as usize;
            if self.blocks.len() <= b {
                self.blocks.resize(b + 1, Vec::new());
            }
            self.blocks[b].push(id);
        }
        self.items.push(c);
        id
    }

    /// Text at `at` changed: `old_bytes` removed and `new_bytes` inserted.
    ///
    /// Every anchor after the edit follows it. An anchor inside the replaced
    /// bytes collapses to the edit point, which is where that text now starts.
    pub fn shift(&mut self, at: u32, old_bytes: usize, new_bytes: usize) {
        if self.items.is_empty() {
            return;
        }
        let old_bytes = old_bytes.min(u32::MAX as usize) as u32;
        let new_bytes = new_bytes.min(u32::MAX as usize) as u32;
        let old_end = at.saturating_add(old_bytes);
        let mut moved = false;
        for c in &mut self.items {
            if c.anchor <= at {
                continue;
            }
            if c.anchor < old_end {
                c.anchor = at;
            } else {
                let next = c.anchor as i64 - old_bytes as i64 + new_bytes as i64;
                c.anchor = next.max(0) as u32;
            }
            moved = true;
        }
        if moved {
            self.reindex();
        }
    }

    fn reindex(&mut self) {
        self.blocks.clear();
        let ranges: Vec<(u32, u32, u32)> = self
            .items
            .iter()
            .map(|c| (c.id, c.anchor / BLOCK, c.end_hint() / BLOCK))
            .collect();
        for (id, lo, hi) in ranges {
            for b in lo..=hi {
                let b = b as usize;
                if self.blocks.len() <= b {
                    self.blocks.resize(b + 1, Vec::new());
                }
                self.blocks[b].push(id);
            }
        }
    }

    /// Constraints whose anchored span could reach `[byte_start, byte_end)`.
    pub fn query(&self, byte_start: u32, byte_end: u32) -> Vec<Constraint> {
        let end = byte_end.max(byte_start.saturating_add(1));
        let lo = byte_start / BLOCK;
        let hi = end.saturating_sub(1) / BLOCK;
        let mut ids: Vec<u32> = Vec::new();
        for b in lo..=hi {
            if let Some(block) = self.blocks.get(b as usize) {
                ids.extend_from_slice(block);
            }
        }
        ids.sort_unstable();
        ids.dedup();
        ids.into_iter()
            .filter_map(|id| self.items.iter().find(|c| c.id == id).copied())
            .filter(|c| c.anchor < end && c.end_hint() > byte_start)
            .collect()
    }
}
