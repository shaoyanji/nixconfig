//! A delimiter lexer: everything between delimiters is one token, and each
//! delimiter byte stands alone. Its job in the reactor bank is to notice a rope
//! token that swallowed a delimiter.

use loom_core::{flags_for_byte, TokenSpan, Tokenizer};
use serde::Deserialize;
use std::collections::HashSet;

#[derive(Debug, Deserialize)]
struct LexDoc {
    #[allow(dead_code)]
    name: String,
    delimiters: String,
}

#[derive(Clone, Debug)]
pub struct RegexLexer {
    name: String,
    delims: HashSet<u8>,
}

impl RegexLexer {
    pub fn from_json(s: &str) -> Result<Self, String> {
        let doc: LexDoc = serde_json::from_str(s).map_err(|e| e.to_string())?;
        Ok(RegexLexer {
            name: doc.name,
            delims: doc.delimiters.bytes().collect(),
        })
    }

    pub fn is_delimiter(&self, b: u8) -> bool {
        self.delims.contains(&b)
    }

    /// Length of the continued segment starting at `start`, or 0 at a delimiter.
    pub fn segment_len(&self, text: &[u8], start: usize) -> usize {
        let mut i = start;
        while i < text.len() && !self.delims.contains(&text[i]) {
            i += 1;
        }
        i - start
    }
}

impl Tokenizer for RegexLexer {
    fn name(&self) -> &str {
        &self.name
    }

    fn tokenize(&self, text: &[u8]) -> Vec<TokenSpan> {
        let mut out = Vec::new();
        let mut i = 0;
        while i < text.len() {
            if self.delims.contains(&text[i]) {
                out.push(TokenSpan {
                    start: i,
                    len: 1,
                    flags: flags_for_byte(text[i]),
                });
                i += 1;
            } else {
                let len = self.segment_len(text, i);
                out.push(TokenSpan {
                    start: i,
                    len,
                    flags: loom_core::FLAG_PUNCT,
                });
                i += len;
            }
        }
        out
    }
}
