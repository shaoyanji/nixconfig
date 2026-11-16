//! Token stream as a chunked piece table, plus the ripple re-tokenizer.
//!
//! The invariant the whole system rests on: after any sequence of edits, the
//! incrementally maintained token array equals a full retokenization of the
//! document bytes. `tests/acceptance.rs::incremental_eq_rebuild` holds it.

pub mod diff;
pub mod op;
pub mod ripple;
pub mod rope;

pub use diff::{batch_frame, trim_affix};
pub use op::Op;
pub use ripple::{retokenize_window, RetokReport, RippleConfig};
pub use rope::{tag_at, AbsToken, EditOut, NewToken, Rope, Token};

/// Token is a whole word run member.
pub const FLAG_WORD: u8 = 0b0000_0001;
/// Token is punctuation (or a single non-word, non-space byte).
pub const FLAG_PUNCT: u8 = 0b0000_0010;
/// Token is whitespace.
pub const FLAG_WS: u8 = 0b0000_0100;

/// Byte class that tokenizers are allowed to merge across.
///
/// A boundary between two word bytes is *not* stable: a merge rule may join
/// them, so a window edge there cannot be re-lexed in isolation. Every other
/// boundary is stable, which is what lets the ripple loop terminate.
pub fn is_word_byte(b: u8) -> bool {
    b.is_ascii_alphanumeric() || b == b'_'
}

/// Length in bytes of the UTF-8 scalar starting at `b`, clamped to 4.
pub fn utf8_len(b: u8) -> usize {
    match b {
        0x00..=0x7f => 1,
        0xc0..=0xdf => 2,
        0xe0..=0xef => 3,
        0xf0..=0xf7 => 4,
        _ => 1,
    }
}

/// One token produced by a tokenizer, relative to the slice it was given.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct TokenSpan {
    pub start: usize,
    pub len: usize,
    pub flags: u8,
}

impl TokenSpan {
    pub fn end(&self) -> usize {
        self.start + self.len
    }
}

/// A tokenizer must tile its input exactly: spans in order, no gaps, no
/// overlaps. `stable_at` says whether the boundary at `pos` may be computed
/// without looking past it.
pub trait Tokenizer: Send + Sync {
    fn name(&self) -> &str;

    fn tokenize(&self, text: &[u8]) -> Vec<TokenSpan>;

    fn stable_at(&self, text: &[u8], pos: usize) -> bool {
        if pos == 0 || pos >= text.len() {
            return true;
        }
        !(is_word_byte(text[pos - 1]) && is_word_byte(text[pos]))
    }
}

/// Flags for a single non-word byte, distinguishing whitespace from punctuation.
pub fn flags_for_byte(b: u8) -> u8 {
    if b.is_ascii_whitespace() {
        FLAG_WS
    } else {
        FLAG_PUNCT
    }
}
