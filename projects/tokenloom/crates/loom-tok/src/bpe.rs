//! Byte-pair encoding over word runs.
//!
//! The vocabulary is an ordered list of merge pairs; lower index wins. Merging
//! is confined to a run of word bytes, so the segmentation of a run depends on
//! that run and nothing else.

use loom_core::{flags_for_byte, is_word_byte, utf8_len, TokenSpan, Tokenizer};
use serde::Deserialize;
use std::collections::HashMap;

#[derive(Debug, Deserialize)]
struct BpeDoc {
    #[allow(dead_code)]
    name: String,
    merges: Vec<(String, String)>,
}

#[derive(Clone, Debug)]
pub struct Bpe {
    name: String,
    ranks: HashMap<Vec<u8>, u32>,
}

impl Bpe {
    pub fn from_json(s: &str) -> Result<Self, String> {
        let doc: BpeDoc = serde_json::from_str(s).map_err(|e| e.to_string())?;
        let mut ranks = HashMap::with_capacity(doc.merges.len());
        for (i, (a, b)) in doc.merges.into_iter().enumerate() {
            ranks.entry(pair_key(a.as_bytes(), b.as_bytes())).or_insert(i as u32);
        }
        Ok(Bpe { name: doc.name, ranks })
    }

    pub fn merge_count(&self) -> usize {
        self.ranks.len()
    }

    fn merge_word(&self, word: &[u8], out: &mut Vec<(usize, usize)>) {
        let mut pieces: Vec<Vec<u8>> = word.iter().map(|b| vec![*b]).collect();
        let mut key: Vec<u8> = Vec::with_capacity(16);
        loop {
            let mut best: Option<(u32, usize)> = None;
            for i in 0..pieces.len().saturating_sub(1) {
                key.clear();
                key.extend_from_slice(&pieces[i]);
                key.push(0);
                key.extend_from_slice(&pieces[i + 1]);
                if let Some(&rank) = self.ranks.get(&key) {
                    if best.map(|(br, _)| rank < br).unwrap_or(true) {
                        best = Some((rank, i));
                    }
                }
            }
            let Some((_, at)) = best else { break };
            let (left, right) = (pieces[at].clone(), pieces[at + 1].clone());
            let mut merged: Vec<Vec<u8>> = Vec::with_capacity(pieces.len());
            let mut i = 0;
            while i < pieces.len() {
                if i + 1 < pieces.len() && pieces[i] == left && pieces[i + 1] == right {
                    let mut v = left.clone();
                    v.extend_from_slice(&right);
                    merged.push(v);
                    i += 2;
                } else {
                    merged.push(pieces[i].clone());
                    i += 1;
                }
            }
            pieces = merged;
        }
        let mut p = 0usize;
        for piece in pieces {
            out.push((p, piece.len()));
            p += piece.len();
        }
    }
}

fn pair_key(a: &[u8], b: &[u8]) -> Vec<u8> {
    let mut k = Vec::with_capacity(a.len() + 1 + b.len());
    k.extend_from_slice(a);
    k.push(0);
    k.extend_from_slice(b);
    k
}

impl Tokenizer for Bpe {
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
                let mut spans = Vec::new();
                self.merge_word(&text[start..i], &mut spans);
                for (off, len) in spans {
                    out.push(TokenSpan {
                        start: start + off,
                        len,
                        flags: loom_core::FLAG_WORD,
                    });
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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn merges_a_word_and_tiles_the_slice() {
        let bpe = crate::bpe_a();
        let text = b"the in thing";
        let spans = bpe.tokenize(text);
        assert!(spans.len() < text.len(), "merges must reduce the count");
        let mut pos = 0;
        for s in &spans {
            assert_eq!(s.start, pos);
            pos = s.end();
        }
        assert_eq!(pos, text.len());
    }

    #[test]
    fn two_vocabs_disagree_somewhere() {
        let a = crate::bpe_a();
        let b = crate::bpe_b();
        let text = b"outstanding reconsider";
        let ca = a.tokenize(text).len();
        let cb = b.tokenize(text).len();
        assert_ne!(ca, cb, "toy vocabs are supposed to argue about segmentation");
    }
}
