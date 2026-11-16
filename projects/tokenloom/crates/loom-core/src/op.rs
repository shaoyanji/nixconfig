//! Token-level edit operations. The wire carries these verbatim, so the
//! protocol has one definition rather than one per side.

use crate::rope::{EditOut, NewToken, Rope};

#[derive(Clone, Debug, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
pub enum Op {
    Insert { seq: u64, offset: u32, tokens: Vec<NewToken> },
    Delete { seq: u64, offset: u32, count: u16 },
    Merge { seq: u64, offset: u32, count: u16 },
    Split { seq: u64, offset: u32, byte_off: u16 },
    Annotate { seq: u64, offset: u32, count: u16, tag: u16, bytes: Vec<u8> },
    ConstraintAdd { seq: u64, start: u32, len: u16, kind: u8, param: u32 },
    /// Take a span back out of the index, by the id the server handed out.
    ConstraintRemove { seq: u64, id: u32 },
    ReactorToggle { seq: u64, reactor: u8, enabled: bool },
    Resync { seq: u64 },
}

impl Op {
    pub fn seq(&self) -> u64 {
        match self {
            Op::Insert { seq, .. }
            | Op::Delete { seq, .. }
            | Op::Merge { seq, .. }
            | Op::Split { seq, .. }
            | Op::Annotate { seq, .. }
            | Op::ConstraintAdd { seq, .. }
            | Op::ConstraintRemove { seq, .. }
            | Op::ReactorToggle { seq, .. }
            | Op::Resync { seq } => *seq,
        }
    }

    /// Annotate and the control ops move no bytes, so they cannot dirty the
    /// token stream and must not trigger a retokenization.
    pub fn changes_text(&self) -> bool {
        matches!(
            self,
            Op::Insert { .. } | Op::Delete { .. } | Op::Merge { .. } | Op::Split { .. }
        )
    }

    /// Apply the rope-level ops. Control ops return `None` and are handled by
    /// the session.
    pub fn apply_to(&self, rope: &mut Rope) -> Option<EditOut> {
        match self {
            Op::Insert { offset, tokens, .. } => Some(rope.edit_at(*offset as usize, 0, tokens)),
            Op::Delete { offset, count, .. } => {
                Some(rope.edit_at(*offset as usize, *count as usize, &[]))
            }
            Op::Merge { offset, count, .. } => {
                rope.merge_tokens(*offset as usize, *count as usize)
            }
            Op::Split { offset, byte_off, .. } => rope.split_token(*offset as usize, *byte_off),
            Op::Annotate { offset, count, tag, .. } => {
                rope.set_tag(*offset as usize, *count as usize, *tag);
                None
            }
            _ => None,
        }
    }
}
