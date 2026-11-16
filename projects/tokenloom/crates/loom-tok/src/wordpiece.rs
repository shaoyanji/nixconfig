//! Greedy longest-match word pieces, with `##` marking a continuation.

use loom_core::{flags_for_byte, is_word_byte, utf8_len, TokenSpan, Tokenizer};
use serde::Deserialize;
use std::collections::HashSet;

#[derive(Debug, Deserialize)]
struct WpDoc {
    #[allow(dead_code)]
    name: String,
    pieces: Vec<String>,
}

#[derive(Clone, Debug)]
pub struct WordPiece {
    name: String,
    pieces: HashSet<String>,
    max_len: usize,
}

impl WordPiece {
    pub fn from_json(s: &str) -> Result<Self, String> {
        let doc: WpDoc = serde_json::from_str(s).map_err(|e| e.to_string())?;
        let max_len = doc.pieces.iter().map(|p| p.len()).max().unwrap_or(1);
        Ok(WordPiece {
            name: doc.name,
            pieces: doc.pieces.into_iter().collect(),
            max_len,
        })
    }

    /// Piece lengths for a word, or `None` when some byte has no piece.
    fn match_word(&self, word: &[u8]) -> Option<Vec<usize>> {
        let s = std::str::from_utf8(word).ok()?;
        let mut out = Vec::new();
        let mut i = 0usize;
        while i < s.len() {
            let max = (s.len() - i).min(self.max_len);
            let mut found = 0usize;
            for len in (1..=max).rev() {
                let piece = &s[i..i + len];
                let key = if i == 0 {
                    piece.to_string()
                } else {
                    format!("##{piece}")
                };
                if self.pieces.contains(&key) {
                    found = len;
                    break;
                }
            }
            if found == 0 {
                return None;
            }
            out.push(found);
            i += found;
        }
        Some(out)
    }
}

impl Tokenizer for WordPiece {
    fn name(&self) -> &str {
        &self.name
    }

    fn tokenize(&self, text: &[u8]) -> Vec<TokenSpan> {
        let mut out = Vec::new();
        let mut i = 0;
        while i < text.len() {
            if is_word_byte(text[i]) {
                let start = i;
                while i < text.len() && is_word_byte(text[i]) {
                    i += 1;
                }
                match self.match_word(&text[start..i]) {
                    Some(lens) => {
                        let mut p = start;
                        for len in lens {
                            out.push(TokenSpan {
                                start: p,
                                len,
                                flags: loom_core::FLAG_WORD,
                            });
                            p += len;
                        }
                    }
                    None => {
                        for j in start..i {
                            out.push(TokenSpan {
                                start: j,
                                len: 1,
                                flags: loom_core::FLAG_WORD,
                            });
                        }
                    }
                }
            } else {
                let n = utf8_len(text[i]).min(text.len() - i);
                out.push(TokenSpan {
                    start: i,
                    len: n,
                    flags: flags_for_byte(text[i]),
                });
                i += n;
            }
        }
        out
    }
}
