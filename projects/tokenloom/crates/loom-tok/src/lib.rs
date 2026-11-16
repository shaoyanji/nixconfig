//! Tokenizers: byte-pair merges, word pieces, and a delimiter lexer.
//!
//! All three tile their input exactly and share one locality rule: a boundary
//! between two word bytes is context-sensitive (a merge may cross it), every
//! other boundary is not. That rule is what makes the ripple window finish.

pub mod bpe;
pub mod regex_lexer;
pub mod wordpiece;

pub use bpe::Bpe;
pub use regex_lexer::RegexLexer;
pub use wordpiece::WordPiece;

/// Toy vocabularies, compiled in so tests and the bench do not depend on the
/// working directory. `vocabs/*.json` holds the same files, which is what the
/// server loads when `LOOM_VOCABS` points somewhere else.
pub const BPE_A_JSON: &str = include_str!("../../../vocabs/bpe_a.json");
pub const BPE_B_JSON: &str = include_str!("../../../vocabs/bpe_b.json");
pub const WORDPIECE_JSON: &str = include_str!("../../../vocabs/wordpiece.json");
pub const DELIMS_JSON: &str = include_str!("../../../vocabs/delims.json");

pub fn bpe_a() -> Bpe {
    Bpe::from_json(BPE_A_JSON).expect("builtin bpe_a.json parses")
}

pub fn bpe_b() -> Bpe {
    Bpe::from_json(BPE_B_JSON).expect("builtin bpe_b.json parses")
}

pub fn wordpiece() -> WordPiece {
    WordPiece::from_json(WORDPIECE_JSON).expect("builtin wordpiece.json parses")
}

pub fn regex_lexer() -> RegexLexer {
    RegexLexer::from_json(DELIMS_JSON).expect("builtin delims.json parses")
}
