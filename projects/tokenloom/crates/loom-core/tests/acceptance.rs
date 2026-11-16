//! The two core acceptance tests.
//!
//! `incremental_eq_rebuild` is the one that matters: if the rope and the ripple
//! re-tokenizer are right, every reactor is additive; if they are wrong, every
//! reactor multiplies the bug surface.

use loom_core::ripple::spans_to_tokens;
use loom_core::{
    retokenize_window, NewToken, RetokReport, RippleConfig, Rope, TokenSpan, Tokenizer,
    FLAG_WORD,
};
use proptest::prelude::*;

/// A deliberately merge-happy tokenizer: any two adjacent word letters whose
/// pair is in `pairs` join. It is context-sensitive across a whole word run,
/// which is what makes an unexpanded window produce a wrong answer.
struct ToyBpe {
    pairs: Vec<(&'static str, &'static str)>,
}

impl ToyBpe {
    fn new() -> Self {
        ToyBpe {
            pairs: vec![
                ("t", "h"),
                ("th", "e"),
                ("i", "n"),
                ("n", "g"),
                ("e", "r"),
                ("s", "t"),
                ("a", "n"),
                ("o", "u"),
            ],
        }
    }

    fn rank(&self, a: &[u8], b: &[u8]) -> Option<usize> {
        self.pairs
            .iter()
            .position(|(x, y)| x.as_bytes() == a && y.as_bytes() == b)
    }

    fn merge_word(&self, w: &[u8]) -> Vec<(usize, usize)> {
        let mut pieces: Vec<Vec<u8>> = w.iter().map(|b| vec![*b]).collect();
        loop {
            let mut best: Option<(usize, usize)> = None;
            for i in 0..pieces.len().saturating_sub(1) {
                if let Some(r) = self.rank(&pieces[i], &pieces[i + 1]) {
                    if best.map(|(br, _)| r < br).unwrap_or(true) {
                        best = Some((r, i));
                    }
                }
            }
            let Some((_, at)) = best else { break };
            let target = {
                let mut v = pieces[at].clone();
                v.extend_from_slice(&pieces[at + 1]);
                v
            };
            let mut out: Vec<Vec<u8>> = Vec::with_capacity(pieces.len());
            let mut i = 0;
            while i < pieces.len() {
                if i + 1 < pieces.len()
                    && pieces[i] == pieces[at]
                    && pieces[i + 1] == pieces[at + 1]
                    && i == at
                {
                    out.push(target.clone());
                    i += 2;
                } else {
                    out.push(pieces[i].clone());
                    i += 1;
                }
            }
            pieces = out;
        }
        let mut spans = Vec::with_capacity(pieces.len());
        let mut p = 0usize;
        for piece in pieces {
            spans.push((p, piece.len()));
            p += piece.len();
        }
        spans
    }
}

impl Tokenizer for ToyBpe {
    fn name(&self) -> &'static str {
        "toy-bpe"
    }

    fn tokenize(&self, text: &[u8]) -> Vec<TokenSpan> {
        let mut out = Vec::new();
        let mut i = 0;
        while i < text.len() {
            if loom_core::is_word_byte(text[i]) {
                let s = i;
                while i < text.len() && loom_core::is_word_byte(text[i]) {
                    i += 1;
                }
                for (st, ln) in self.merge_word(&text[s..i]) {
                    out.push(TokenSpan { start: s + st, len: ln, flags: FLAG_WORD });
                }
            } else {
                let n = loom_core::utf8_len(text[i]).min(text.len() - i);
                out.push(TokenSpan {
                    start: i,
                    len: n,
                    flags: loom_core::flags_for_byte(text[i]),
                });
                i += n;
            }
        }
        out
    }
}

fn rebuild(doc: &[u8], tok: &dyn Tokenizer) -> Vec<(usize, usize, u8)> {
    tok.tokenize(doc)
        .into_iter()
        .map(|s| (s.start, s.len, s.flags))
        .collect()
}

fn current(rope: &Rope) -> Vec<(usize, usize, u8)> {
    rope.abs_tokens()
        .into_iter()
        .map(|t| (t.start, t.len as usize, t.flags))
        .collect()
}

fn word_strategy() -> impl Strategy<Value = Vec<u8>> {
    let word = "[a-z]{1,8}";
    let sep = prop_oneof![Just(" "), Just(" "), Just(", "), Just(". "), Just("\n")];
    prop::collection::vec((word, sep), 1..24).prop_map(|parts| {
        let mut s = String::new();
        for (w, sep) in parts {
            s.push_str(&w);
            s.push_str(sep);
        }
        s.into_bytes()
    })
}

/// Random single edit against a live rope, retokenized the way the session
/// does it: seed the dirty range, ripple, splice.
fn random_edit(rope: &mut Rope, tok: &dyn Tokenizer, cfg: &RippleConfig, pick: &[u8]) -> RetokReport {
    let len = rope.len_tokens();
    let nonce = pick[0] as usize;
    match nonce % 6 {
        0 | 1 => {
            let at = if len == 0 { 0 } else { (pick[1] as usize * 31) % (len + 1) };
            let text = match pick[2] % 5 {
                0 => b"the".to_vec(),
                1 => b"in".to_vec(),
                2 => b" ".to_vec(),
                3 => b"st".to_vec(),
                _ => vec![b'a' + (pick[3] % 26)],
            };
            let flags = if loom_core::is_word_byte(text[0]) { FLAG_WORD } else { loom_core::flags_for_byte(text[0]) };
            let eo = rope.edit_at(at, 0, &[NewToken { flags, tag: 0, text }]);
            retokenize_window(rope, eo.tok_start..eo.tok_start + eo.new_count, tok, cfg)
        }
        2 => {
            if len == 0 {
                return RetokReport::default();
            }
            let at = (pick[1] as usize * 17) % len;
            let count = 1 + (pick[2] as usize % 3).min(len - at - 1);
            let eo = rope.edit_at(at, count, &[]);
            retokenize_window(rope, eo.tok_start..eo.tok_start, tok, cfg)
        }
        3 => {
            if len < 2 {
                return RetokReport::default();
            }
            let at = (pick[1] as usize * 13) % (len - 1);
            let eo = rope.merge_tokens(at, 2).unwrap();
            retokenize_window(rope, eo.tok_start..eo.tok_start + eo.new_count, tok, cfg)
        }
        4 => {
            if len == 0 {
                return RetokReport::default();
            }
            let at = (pick[1] as usize * 7) % len;
            let n = rope.abs(at).unwrap().len;
            if n < 2 {
                return RetokReport::default();
            }
            let off = 1 + (pick[2] as u16) % (n - 1);
            let eo = rope.split_token(at, off).unwrap();
            retokenize_window(rope, eo.tok_start..eo.tok_start + eo.new_count, tok, cfg)
        }
        _ => {
            if len == 0 {
                return RetokReport::default();
            }
            let at = (pick[1] as usize) % len;
            rope.set_tag(at, 1, 7);
            RetokReport::default()
        }
    }
}

proptest! {
    #![proptest_config(ProptestConfig { cases: 256, ..ProptestConfig::default() })]

    /// Random document, random op sequence: the incrementally maintained token
    /// array must equal a full rebuild, byte for byte.
    #[test]
    fn incremental_eq_rebuild(doc in word_strategy(), ops in prop::collection::vec(prop::collection::vec(any::<u8>(), 4), 1..40)) {
        let tok = ToyBpe::new();
        let cfg = RippleConfig::default();
        let spans = tok.tokenize(&doc);
        let mut rope = Rope::from_tokens(&spans_to_tokens(&doc, &spans));
        prop_assert_eq!(current(&rope), rebuild(&doc, &tok));

        for pick in ops {
            random_edit(&mut rope, &tok, &cfg, &pick);
            let want = rebuild(&rope.doc(), &tok);
            prop_assert_eq!(
                current(&rope),
                want,
                "incremental segmentation drifted from a full rebuild"
            );
        }
    }

    /// No edit re-tokenizes more than the configured window, and a normal word
    /// run never forces the over-budget widening.
    #[test]
    fn ripple_bounded(doc in word_strategy(), ops in prop::collection::vec(prop::collection::vec(any::<u8>(), 4), 1..60)) {
        let tok = ToyBpe::new();
        let cfg = RippleConfig::default();
        let max_window = 1024usize;
        let spans = tok.tokenize(&doc);
        let mut rope = Rope::from_tokens(&spans_to_tokens(&doc, &spans));
        let mut worst = 0usize;
        for pick in ops {
            let r = random_edit(&mut rope, &tok, &cfg, &pick);
            worst = worst.max(r.bytes_retokenized);
            prop_assert!(
                r.bytes_retokenized <= max_window,
                "retokenized {} bytes, window cap {}",
                r.bytes_retokenized,
                max_window
            );
            prop_assert!(!r.truncated, "ripple hit its step bound on ordinary text");
        }
        // The relative bound is only meaningful once the document is larger
        // than a window; a 2-byte document cannot keep one under a tenth.
        let bytes = rope.len_bytes();
        prop_assert!(
            bytes < 512 || worst <= bytes / 10,
            "window was {} bytes of a {}-byte document",
            worst,
            bytes
        );
    }
}
