//! The reactor bank.
//!
//! Each reactor keeps its own segmentation of the document and re-lexes only the
//! window a batch touched. That is the rule the whole design turns on: six
//! reactors must not mean six passes over 10k tokens per keystroke.

use crate::constraint::{ConstraintIndex, ConstraintKind};
use crate::warning::WarningKind;
use loom_core::{AbsToken, Tokenizer};
use loom_tok::{bpe_a, bpe_b, regex_lexer, wordpiece, Bpe, RegexLexer, WordPiece};
use std::ops::Range;
use std::sync::Arc;

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Reaction {
    pub kind: WarningKind,
    pub severity: u8,
    pub start: u32,
    pub len: u16,
    pub message: String,
}

/// One coalesced batch, as every reactor sees it.
#[derive(Clone)]
pub struct BatchView {
    pub revision: u64,
    pub doc: Arc<Vec<u8>>,
    pub tokens: Arc<Vec<AbsToken>>,
    pub tok_window: Range<usize>,
    pub byte_window: Range<usize>,
    pub constraints: Arc<ConstraintIndex>,
}

impl BatchView {
    pub fn window(&self) -> &[u8] {
        let a = self.byte_window.start.min(self.doc.len());
        let b = self.byte_window.end.min(self.doc.len()).max(a);
        &self.doc[a..b]
    }

    pub fn window_tokens(&self) -> &[AbsToken] {
        let a = self.tok_window.start.min(self.tokens.len());
        let b = self.tok_window.end.min(self.tokens.len()).max(a);
        &self.tokens[a..b]
    }

    pub fn tokens_in(&self, byte: &Range<usize>) -> &[AbsToken] {
        let a = self.tokens.partition_point(|t| t.end() <= byte.start);
        let b = self.tokens.partition_point(|t| t.start < byte.end.max(byte.start + 1));
        &self.tokens[a..b.max(a)]
    }

    pub fn boundary_starts(&self, byte: &Range<usize>) -> Vec<usize> {
        self.tokens_in(byte).iter().map(|t| t.start).collect()
    }

    /// Token span covering a byte range, clamped to the batch window.
    pub fn span_of(&self, byte_start: usize, byte_end: usize) -> (u32, u16) {
        let s = self.tokens.partition_point(|t| t.end() <= byte_start);
        let e = self.tokens.partition_point(|t| t.start < byte_end.max(byte_start + 1));
        let s = s.clamp(self.tok_window.start, self.tok_window.end.max(self.tok_window.start));
        let e = e.clamp(s, self.tok_window.end.max(self.tok_window.start));
        (s as u32, (e - s).max(1).min(u16::MAX as usize) as u16)
    }

    pub fn tok_span(&self) -> (u32, u16) {
        let len = (self.tok_window.end - self.tok_window.start).max(1);
        (self.tok_window.start as u32, len.min(u16::MAX as usize) as u16)
    }
}

pub trait Reactor: Send {
    fn id(&self) -> u8;
    fn name(&self) -> &str;
    fn on_diff(&mut self, view: &BatchView) -> Vec<Reaction>;
    fn keyframe(&mut self, doc: &[u8], tokens: &[AbsToken]) -> Vec<Reaction> {
        let _ = (doc, tokens);
        Vec::new()
    }
}

/// Spans per block.
const SPANS_PER_BLOCK: usize = 256;

#[derive(Clone, Copy)]
struct Sp {
    /// Byte offset of the span inside its block.
    off: u32,
    len: u16,
    flags: u8,
}

#[derive(Clone, Default)]
struct Block {
    spans: Vec<Sp>,
}

impl Block {
    fn bytes(&self) -> usize {
        self.spans
            .last()
            .map(|s| s.off as usize + s.len as usize)
            .unwrap_or(0)
    }
}

/// A reactor's own copy of the segmentation.
///
/// Positions are stored per block, and a block's start byte is the sum of the
/// lengths of the blocks before it. That is the delta index: an edit rewrites
/// the block it lands in, and every position after it moves for free because it
/// was never stored. The alternative — one flat list — costs a walk over the
/// whole tail per batch per reactor, which is exactly the cost 1000 edits/s
/// exposes.
struct Seg {
    blocks: Vec<Block>,
    doc_len: usize,
}

/// A read cursor over a segmentation, in post-edit coordinates.
struct Walk<'a> {
    seg: &'a Seg,
    b: usize,
    i: usize,
    base: usize,
    b0: usize,
    we: usize,
    delta: i64,
}

impl<'a> Walk<'a> {
    fn new(seg: &'a Seg, b0: usize, we: usize, delta: i64, at: (usize, usize)) -> Self {
        let base = seg.base(at.0);
        Walk {
            seg,
            b: at.0,
            i: at.1,
            base,
            b0,
            we,
            delta,
        }
    }

    fn raw(&self) -> usize {
        self.base + self.seg.blocks[self.b].spans[self.i].off as usize
    }

    /// Absolute start in the document this batch produces. Blocks after the
    /// edited one, and spans past the window end inside it, sit `delta` further
    /// along than the copy still says.
    fn abs(&self) -> usize {
        let raw = self.raw();
        if self.b > self.b0 || raw >= self.we {
            (raw as i64 + self.delta).max(0) as usize
        } else {
            raw
        }
    }

    fn len(&self) -> u16 {
        self.seg.blocks[self.b].spans[self.i].len
    }

    fn next(&mut self) -> bool {
        if self.i + 1 < self.seg.blocks[self.b].spans.len() {
            self.i += 1;
            return true;
        }
        let nb = self.b + 1;
        if nb >= self.seg.blocks.len() {
            return false;
        }
        self.base += self.seg.blocks[self.b].bytes();
        self.b = nb;
        self.i = 0;
        true
    }

    fn prev(&mut self) -> bool {
        if self.i > 0 {
            self.i -= 1;
            return true;
        }
        if self.b == 0 {
            return false;
        }
        let pb = self.b - 1;
        self.base -= self.seg.blocks[pb].bytes();
        self.b = pb;
        self.i = self.seg.blocks[pb].spans.len().saturating_sub(1);
        true
    }
}

impl Seg {
    fn new() -> Self {
        Seg {
            blocks: Vec::new(),
            doc_len: 0,
        }
    }

    fn seed(&mut self, doc: &[u8], tok: &dyn Tokenizer) {
        let items: Vec<(usize, u16, u8)> = tok
            .tokenize(doc)
            .into_iter()
            .map(|s| (s.start, s.len as u16, s.flags))
            .collect();
        self.blocks = Seg::chunk_items(&items);
        self.doc_len = doc.len();
    }

    /// Cut a contiguous run of absolute spans into blocks. Every block starts at
    /// its own first span, so the run's gaps — there are none — are the only
    /// thing that could break the tiling.
    fn chunk_items(items: &[(usize, u16, u8)]) -> Vec<Block> {
        let mut out = Vec::with_capacity(items.len() / SPANS_PER_BLOCK + 1);
        for part in items.chunks(SPANS_PER_BLOCK) {
            let base = part[0].0;
            let mut b = Block {
                spans: Vec::with_capacity(part.len()),
            };
            for (abs, len, flags) in part {
                b.spans.push(Sp {
                    off: (abs - base) as u32,
                    len: *len,
                    flags: *flags,
                });
            }
            out.push(b);
        }
        out
    }

    fn base(&self, b: usize) -> usize {
        self.blocks[..b].iter().map(|x| x.bytes()).sum()
    }

    fn covered(&self) -> usize {
        match self.blocks.last() {
            Some(last) => self.base(self.blocks.len() - 1) + last.bytes(),
            None => 0,
        }
    }

    /// Block holding `byte`, and that block's start. The last block wins for a
    /// byte at or past the end.
    fn locate(&self, byte: usize) -> (usize, usize) {
        let mut base = 0usize;
        for (i, b) in self.blocks.iter().enumerate() {
            let next = base + b.bytes();
            if byte < next || i + 1 == self.blocks.len() {
                return (i, base);
            }
            base = next;
        }
        (0, 0)
    }

    /// Span starts inside `win`, in order. Walks from the block holding the
    /// window rather than from the top of the document.
    fn starts_in(&self, win: &Range<usize>) -> Vec<usize> {
        let (b0, mut base) = self.locate(win.start);
        let end = win.end.max(win.start + 1);
        let mut out = Vec::new();
        for b in self.blocks[b0..].iter() {
            if base >= end {
                break;
            }
            for s in &b.spans {
                let abs = base + s.off as usize;
                if abs >= win.start && abs < end {
                    out.push(abs);
                }
            }
            base += b.bytes();
        }
        out
    }

    /// Bring this segmentation up to date over the batch's byte window, and
    /// return the byte range that was actually re-lexed.
    fn resync(&mut self, doc: &[u8], win: &Range<usize>, tok: &dyn Tokenizer) -> Range<usize> {
        if self.blocks.is_empty() {
            self.seed(doc, tok);
            return 0..doc.len();
        }
        let delta = doc.len() as i64 - self.doc_len as i64;
        let ws = win.start.min(doc.len());
        let we = win.end.min(doc.len()).max(ws + 1).min(doc.len());
        let (b0, b0_base) = self.locate(ws);

        // First span whose end is past the window start: nothing before b0 can
        // reach the window, and inside it the walk is a handful of spans.
        let mut lo = Walk::new(self, b0, we, delta, (b0, 0));
        while lo.abs() + lo.len() as usize <= ws {
            if !lo.next() {
                break;
            }
        }
        while !tok.stable_at(doc, lo.abs()) {
            if !lo.prev() {
                break;
            }
        }
        let bs = lo.abs();
        drop(lo);

        // First span at or past the window end, widened while the tokenizer says
        // that boundary cannot be computed in isolation.
        let mut hi = Walk::new(self, b0, we, delta, (b0, 0));
        let mut hi_past = false;
        while hi.abs() < we {
            if !hi.next() {
                hi_past = true;
                break;
            }
        }
        if !hi_past {
            while !(hi.abs() >= doc.len() || tok.stable_at(doc, hi.abs())) {
                if !hi.next() {
                    hi_past = true;
                    break;
                }
            }
        }
        let be = if hi_past { doc.len() } else { hi.abs() };
        let (b1, tail_from) = if hi_past {
            let last = self.blocks.len() - 1;
            (last, self.blocks[last].spans.len())
        } else {
            (hi.b, hi.i)
        };
        drop(hi);

        if bs > be || be > doc.len() {
            self.seed(doc, tok);
            return 0..doc.len();
        }

        // head (spans of b0 before the window, unmoved) + fresh + tail (spans of
        // b1 after the window, moved by delta). The replacement starts at b0's
        // own base and ends at b1's old end plus delta, so the blocks after b1
        // still tile without being touched.
        let mut items: Vec<(usize, u16, u8)> = Vec::with_capacity((be - bs) / 3 + SPANS_PER_BLOCK);
        for s in &self.blocks[b0].spans {
            let abs = b0_base + s.off as usize;
            if abs >= bs {
                break;
            }
            items.push((abs, s.len, s.flags));
        }
        for s in tok.tokenize(&doc[bs..be]) {
            items.push((bs + s.start, s.len as u16, s.flags));
        }
        let b1_base = self.base(b1);
        for s in &self.blocks[b1].spans[tail_from..] {
            let moved = b1_base + s.off as usize;
            items.push(((moved as i64 + delta).max(0) as usize, s.len, s.flags));
        }

        #[cfg(debug_assertions)]
        debug_assert!(
            items
                .windows(2)
                .all(|w| w[0].0 + w[0].1 as usize == w[1].0),
            "spans must tile the document after a splice"
        );

        self.blocks.splice(b0..=b1, Seg::chunk_items(&items));
        self.doc_len = doc.len();

        if self.covered() != doc.len() {
            self.seed(doc, tok);
            return 0..doc.len();
        }
        #[cfg(debug_assertions)]
        self.check(doc.len());
        bs..be
    }

    /// Debug-only structural check: blocks in order, each starting at its own
    /// base, spans tiling, and the whole thing covering the document.
    #[cfg(debug_assertions)]
    fn check(&self, doc_len: usize) {
        let mut base = 0usize;
        for (k, b) in self.blocks.iter().enumerate() {
            assert!(!b.spans.is_empty(), "block {k} is empty");
            assert_eq!(b.spans[0].off, 0, "block {k} does not start at its base");
            let mut prev_end = 0u32;
            for s in &b.spans {
                assert_eq!(
                    s.off, prev_end,
                    "block {k} has a gap or an overlap at byte {prev_end}"
                );
                prev_end = s.off + s.len as u32;
            }
            base += b.bytes();
        }
        assert_eq!(base, doc_len, "segmentation does not cover the document");
    }
}

pub struct BpeAReactor {
    tok: Bpe,
    seg: Seg,
}

impl BpeAReactor {
    pub fn new() -> Self {
        BpeAReactor {
            tok: bpe_a(),
            seg: Seg::new(),
        }
    }
}

impl Reactor for BpeAReactor {
    fn id(&self) -> u8 {
        1
    }

    fn name(&self) -> &str {
        "bpe-a"
    }

    fn on_diff(&mut self, v: &BatchView) -> Vec<Reaction> {
        let win = self.seg.resync(&v.doc, &v.byte_window, &self.tok);
        let mine = self.seg.starts_in(&win);
        let theirs = v.boundary_starts(&win);
        if mine != theirs {
            let (start, len) = v.span_of(win.start, win.end);
            return vec![Reaction {
                kind: WarningKind::SpanCreep,
                severity: 3,
                start,
                len,
                message: format!(
                    "canonical segmentation drifted from the rope: {} boundaries vs {}",
                    mine.len(),
                    theirs.len()
                ),
            }];
        }
        Vec::new()
    }

    fn keyframe(&mut self, doc: &[u8], _tokens: &[AbsToken]) -> Vec<Reaction> {
        self.seg.seed(doc, &self.tok);
        Vec::new()
    }
}

pub struct BpeBReactor {
    tok: Bpe,
    seg: Seg,
}

impl BpeBReactor {
    pub fn new() -> Self {
        BpeBReactor {
            tok: bpe_b(),
            seg: Seg::new(),
        }
    }
}

impl Reactor for BpeBReactor {
    fn id(&self) -> u8 {
        2
    }

    fn name(&self) -> &str {
        "bpe-b"
    }

    fn on_diff(&mut self, v: &BatchView) -> Vec<Reaction> {
        let win = self.seg.resync(&v.doc, &v.byte_window, &self.tok);
        let mine = self.seg.starts_in(&win);
        let theirs = v.boundary_starts(&win);
        let delta = (mine.len() as i64 - theirs.len() as i64).abs();
        if delta < 2 && mine == theirs {
            return Vec::new();
        }
        let (start, len) = v.span_of(win.start, win.end);
        vec![Reaction {
            kind: WarningKind::CrossVocabDivergence,
            severity: if delta >= 2 { 2 } else { 1 },
            start,
            len,
            message: format!(
                "vocab b splits this span into {} tokens, the active vocab into {}",
                mine.len(),
                theirs.len()
            ),
        }]
    }

    fn keyframe(&mut self, doc: &[u8], _tokens: &[AbsToken]) -> Vec<Reaction> {
        self.seg.seed(doc, &self.tok);
        Vec::new()
    }
}

pub struct WordPieceReactor {
    tok: WordPiece,
    seg: Seg,
}

impl WordPieceReactor {
    pub fn new() -> Self {
        WordPieceReactor {
            tok: wordpiece(),
            seg: Seg::new(),
        }
    }
}

impl Reactor for WordPieceReactor {
    fn id(&self) -> u8 {
        3
    }

    fn name(&self) -> &str {
        "wordpiece"
    }

    fn on_diff(&mut self, v: &BatchView) -> Vec<Reaction> {
        let win = self.seg.resync(&v.doc, &v.byte_window, &self.tok);
        let mine = self.seg.starts_in(&win);
        let theirs = v.boundary_starts(&win);
        if mine == theirs {
            return Vec::new();
        }
        let flipped = mine
            .iter()
            .filter(|b| theirs.binary_search(b).is_err())
            .count()
            .max(1);
        let (start, len) = v.span_of(win.start, win.end);
        vec![Reaction {
            kind: WarningKind::BoundaryInstability,
            severity: 1,
            start,
            len,
            message: format!("wordpiece moves {flipped} boundaries in this span"),
        }]
    }

    fn keyframe(&mut self, doc: &[u8], _tokens: &[AbsToken]) -> Vec<Reaction> {
        self.seg.seed(doc, &self.tok);
        Vec::new()
    }
}

pub struct RegexLexerReactor {
    tok: RegexLexer,
    seg: Seg,
}

impl RegexLexerReactor {
    pub fn new() -> Self {
        RegexLexerReactor {
            tok: regex_lexer(),
            seg: Seg::new(),
        }
    }
}

impl Reactor for RegexLexerReactor {
    fn id(&self) -> u8 {
        4
    }

    fn name(&self) -> &str {
        "regex-lexer"
    }

    fn on_diff(&mut self, v: &BatchView) -> Vec<Reaction> {
        let win = self.seg.resync(&v.doc, &v.byte_window, &self.tok);
        for t in v.tokens_in(&win) {
            let text = &v.doc[t.start..t.end()];
            if text.len() < 2 {
                continue;
            }
            if let Some(pos) = text.iter().position(|b| self.tok.is_delimiter(*b)) {
                let (start, len) = v.span_of(t.start, t.end());
                return vec![Reaction {
                    kind: WarningKind::SpanCreep,
                    severity: 2,
                    start,
                    len,
                    message: format!(
                        "token spans delimiter '{}' at byte {}",
                        char::from(text[pos]),
                        t.start + pos
                    ),
                }];
            }
        }
        Vec::new()
    }

    fn keyframe(&mut self, doc: &[u8], _tokens: &[AbsToken]) -> Vec<Reaction> {
        self.seg.seed(doc, &self.tok);
        Vec::new()
    }
}

pub struct ConstraintCheck {
    tok: Bpe,
}

impl ConstraintCheck {
    pub fn new() -> Self {
        ConstraintCheck { tok: bpe_a() }
    }
}

impl Reactor for ConstraintCheck {
    fn id(&self) -> u8 {
        5
    }

    fn name(&self) -> &str {
        "constraint-check"
    }

    fn on_diff(&mut self, v: &BatchView) -> Vec<Reaction> {
        let lo = v.tok_window.start;
        let hi = v.tok_window.end.max(lo + 1);
        let mut out = Vec::new();
        // The index answers in bytes and errs wide; the token range decides.
        for c in v.constraints.query(
            v.byte_window.start as u32,
            v.byte_window.end as u32,
        ) {
            let anchor = c.anchor as usize;
            let span_lo = v.tokens.partition_point(|t| t.start < anchor).min(v.tokens.len());
            let span_hi = (span_lo + c.len.max(1) as usize).min(v.tokens.len());
            if span_hi <= lo || span_lo >= hi {
                continue;
            }
            match c.kind {
                ConstraintKind::MaxTokensInSpan => {
                    let n = span_hi - span_lo;
                    if n > c.param as usize {
                        out.push(Reaction {
                            kind: WarningKind::ConstraintViolation,
                            severity: 3,
                            start: span_lo as u32,
                            len: n.min(u16::MAX as usize) as u16,
                            message: format!("span holds {n} tokens, constraint {}", c.describe()),
                        });
                    }
                }
                ConstraintKind::NoTokenCrossesDelimiter => {
                    let delim = c.param as u8;
                    for t in &v.tokens[span_lo..span_hi] {
                        let text = &v.doc[t.start..t.end()];
                        if text.len() > 1 && text[1..].contains(&delim) {
                            let (s, l) = v.span_of(t.start, t.end());
                            out.push(Reaction {
                                kind: WarningKind::ConstraintViolation,
                                severity: 3,
                                start: s,
                                len: l,
                                message: format!(
                                    "token '{}' crosses the delimiter '{}'",
                                    String::from_utf8_lossy(text),
                                    char::from(delim)
                                ),
                            });
                            break;
                        }
                    }
                }
                ConstraintKind::BoundaryStableAt => {
                    if anchor <= v.doc.len() && !self.tok.stable_at(&v.doc, anchor) {
                        let (s, l) = v.span_of(anchor, anchor + 1);
                        out.push(Reaction {
                            kind: WarningKind::ConstraintViolation,
                            severity: 2,
                            start: s,
                            len: l,
                            message: format!("no stable boundary at byte {anchor}"),
                        });
                    }
                }
            }
        }
        out
    }
}

pub struct StabilityReactor {
    tok: Bpe,
    seg: Seg,
}

impl StabilityReactor {
    pub fn new() -> Self {
        StabilityReactor {
            tok: bpe_a(),
            seg: Seg::new(),
        }
    }
}

impl Reactor for StabilityReactor {
    fn id(&self) -> u8 {
        6
    }

    fn name(&self) -> &str {
        "stability"
    }

    fn on_diff(&mut self, v: &BatchView) -> Vec<Reaction> {
        let win = self.seg.resync(&v.doc, &v.byte_window, &self.tok);
        let a = win.start.saturating_sub(1);
        let b = (win.end + 1).min(v.doc.len()).max(a);
        let probe: Vec<usize> = self
            .tok
            .tokenize(&v.doc[a..b])
            .into_iter()
            .map(|s| a + s.start)
            .filter(|p| *p >= win.start && *p < win.end.max(win.start + 1))
            .collect();
        let mine = self.seg.starts_in(&win);
        if probe == mine {
            return Vec::new();
        }
        let (start, len) = v.span_of(win.start, win.end);
        vec![Reaction {
            kind: WarningKind::BoundaryInstability,
            severity: 1,
            start,
            len,
            message: "boundary moves when the window grows by one byte".to_string(),
        }]
    }

    fn keyframe(&mut self, doc: &[u8], _tokens: &[AbsToken]) -> Vec<Reaction> {
        self.seg.seed(doc, &self.tok);
        Vec::new()
    }
}

pub fn builtin_reactors() -> Vec<Box<dyn Reactor>> {
    vec![
        Box::new(BpeAReactor::new()),
        Box::new(BpeBReactor::new()),
        Box::new(WordPieceReactor::new()),
        Box::new(RegexLexerReactor::new()),
        Box::new(ConstraintCheck::new()),
        Box::new(StabilityReactor::new()),
    ]
}
