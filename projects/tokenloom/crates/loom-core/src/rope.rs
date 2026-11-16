//! A piece table whose pieces are token runs.
//!
//! Each chunk owns a text buffer and the tokens that tile it, with
//! `Token::byte_start` relative to the chunk. An edit splits the chunks that
//! straddle it, merges that (short) span into one working buffer, applies the
//! change, and re-splits if the result is too large to be a piece. Nothing
//! copies the document.

/// Tokens per chunk. Small enough that a splice copies little, large enough
/// that a 10k-token document is ~40 chunks.
pub const CHUNK_MAX_TOKENS: usize = 256;

#[derive(Clone, Copy, Debug, PartialEq, Eq, Default)]
pub struct Token {
    pub chunk_id: u32,
    /// Byte offset inside the owning chunk.
    pub byte_start: u32,
    pub byte_len: u16,
    pub flags: u8,
    pub tag: u16,
}

/// A token in document coordinates, which is what callers outside this module use.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Default)]
pub struct AbsToken {
    pub start: usize,
    pub len: u16,
    pub flags: u8,
    pub tag: u16,
}

impl AbsToken {
    pub fn end(&self) -> usize {
        self.start + self.len as usize
    }
}

/// A token handed to the rope: text plus the two metadata bytes a client owns.
#[derive(Clone, Debug, PartialEq, Eq, Default, serde::Serialize, serde::Deserialize)]
pub struct NewToken {
    pub flags: u8,
    pub tag: u16,
    pub text: Vec<u8>,
}

impl NewToken {
    pub fn word(text: &[u8]) -> Self {
        NewToken {
            flags: crate::FLAG_WORD,
            tag: 0,
            text: text.to_vec(),
        }
    }
}

/// What an edit did, in both token and byte coordinates.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct EditOut {
    pub tok_start: usize,
    pub old_count: usize,
    pub new_count: usize,
    pub byte_start: usize,
    pub old_bytes: usize,
    pub new_bytes: usize,
}

#[derive(Clone, Debug, Default)]
struct Chunk {
    text: Vec<u8>,
    tokens: Vec<Token>,
}

impl Chunk {
    fn reindex(&mut self, id: u32) {
        let mut p = 0u32;
        for t in self.tokens.iter_mut() {
            t.chunk_id = id;
            t.byte_start = p;
            p += t.byte_len as u32;
        }
    }

    fn byte_len(&self) -> usize {
        self.tokens.iter().map(|t| t.byte_len as usize).sum()
    }

    /// The chunk's tokens with their text, in order.
    ///
    /// Mutations are expressed as a new item list and rebuilt from it, so a
    /// chunk's text and its token boundaries cannot drift apart: there is no
    /// second copy of the offsets to keep in step.
    fn items(&self) -> Vec<(u8, u16, Vec<u8>)> {
        self.tokens
            .iter()
            .map(|t| {
                let s = t.byte_start as usize;
                (t.flags, t.tag, self.text[s..s + t.byte_len as usize].to_vec())
            })
            .collect()
    }

    fn set_items(&mut self, items: &[(u8, u16, Vec<u8>)]) {
        self.tokens.clear();
        self.text.clear();
        let mut p = 0u32;
        for (flags, tag, text) in items {
            assert!(text.len() <= u16::MAX as usize, "token text exceeds u16");
            self.tokens.push(Token {
                chunk_id: 0,
                byte_start: p,
                byte_len: text.len() as u16,
                flags: *flags,
                tag: *tag,
            });
            p += text.len() as u32;
            self.text.extend_from_slice(text);
        }
    }

    fn remove(&mut self, off: usize, count: usize) {
        if count == 0 {
            return;
        }
        let mut items = self.items();
        items.drain(off..off + count);
        self.set_items(&items);
    }

    fn insert(&mut self, off: usize, inserts: &[NewToken]) {
        if inserts.is_empty() {
            return;
        }
        let mut items = self.items();
        let fresh: Vec<(u8, u16, Vec<u8>)> = inserts
            .iter()
            .map(|t| (t.flags, t.tag, t.text.clone()))
            .collect();
        items.splice(off..off, fresh);
        self.set_items(&items);
    }
}

#[derive(Clone, Debug, Default)]
pub struct Rope {
    chunks: Vec<Chunk>,
    revision: u64,
}

impl Rope {
    pub fn new() -> Self {
        Rope::default()
    }

    /// Build a rope from tokens that already cover their text exactly.
    pub fn from_tokens(items: &[NewToken]) -> Self {
        let mut rope = Rope::new();
        let mut cur = Chunk::default();
        for it in items {
            if cur.tokens.len() >= CHUNK_MAX_TOKENS {
                rope.chunks.push(std::mem::take(&mut cur));
            }
            cur.tokens.push(Token {
                chunk_id: 0,
                byte_start: 0,
                byte_len: it.text.len() as u16,
                flags: it.flags,
                tag: it.tag,
            });
            cur.text.extend_from_slice(&it.text);
        }
        if !cur.tokens.is_empty() {
            rope.chunks.push(cur);
        }
        rope.fix_ids();
        rope
    }

    pub fn revision(&self) -> u64 {
        self.revision
    }

    pub fn set_revision(&mut self, r: u64) {
        self.revision = r;
    }

    pub fn bump_revision(&mut self) -> u64 {
        self.revision += 1;
        self.revision
    }

    pub fn len_tokens(&self) -> usize {
        self.chunks.iter().map(|c| c.tokens.len()).sum()
    }

    pub fn len_bytes(&self) -> usize {
        self.chunks.iter().map(|c| c.text.len()).sum()
    }

    pub fn doc(&self) -> Vec<u8> {
        let mut v = Vec::with_capacity(self.len_bytes());
        for c in &self.chunks {
            v.extend_from_slice(&c.text);
        }
        v
    }

    /// Document byte offset at which token `idx` starts (`idx == len_tokens` is
    /// the end of the document).
    pub fn byte_of_token(&self, idx: usize) -> usize {
        let mut acc = 0usize;
        let mut left = idx;
        for c in &self.chunks {
            if left == 0 {
                break;
            }
            if left >= c.tokens.len() {
                acc += c.byte_len();
                left -= c.tokens.len();
            } else {
                acc += c.tokens[left].byte_start as usize;
                left = 0;
            }
        }
        acc
    }

    /// Token containing `pos` (`after == false`) or the first token starting at
    /// or after it (`after == true`).
    pub fn token_at_byte(&self, pos: usize, after: bool) -> usize {
        let mut base = 0usize;
        let mut idx = 0usize;
        for c in &self.chunks {
            let cb = c.byte_len();
            if pos < base + cb {
                let rel = pos - base;
                let off = c.tokens.partition_point(|t| (t.byte_start as usize) < rel);
                let exact = off < c.tokens.len() && c.tokens[off].byte_start as usize == rel;
                if after {
                    return idx + off;
                }
                return idx + if exact { off } else { off.saturating_sub(1) };
            }
            base += cb;
            idx += c.tokens.len();
        }
        idx
    }

    pub fn abs(&self, i: usize) -> Option<AbsToken> {
        self.abs_range(i..i + 1).into_iter().next()
    }

    pub fn abs_tokens(&self) -> Vec<AbsToken> {
        self.abs_range(0..self.len_tokens())
    }

    pub fn abs_range(&self, range: std::ops::Range<usize>) -> Vec<AbsToken> {
        let mut out = Vec::new();
        let mut tok = 0usize;
        let mut byte = 0usize;
        for c in &self.chunks {
            let n = c.tokens.len();
            if tok + n <= range.start {
                tok += n;
                byte += c.byte_len();
                continue;
            }
            if tok >= range.end {
                break;
            }
            for t in &c.tokens {
                if tok >= range.end {
                    break;
                }
                if tok >= range.start {
                    out.push(AbsToken {
                        start: byte + t.byte_start as usize,
                        len: t.byte_len,
                        flags: t.flags,
                        tag: t.tag,
                    });
                }
                tok += 1;
            }
            byte += c.byte_len();
        }
        out
    }

    pub fn text_of(&self, tok: &AbsToken) -> Vec<u8> {
        self.doc()[tok.start..tok.end()].to_vec()
    }

    /// Replace `del` tokens at `idx` with `inserts`. Ops land here; the ripple
    /// retokenizer lands here too, one window at a time.
    pub fn edit_at(&mut self, idx: usize, del: usize, inserts: &[NewToken]) -> EditOut {
        let total = self.len_tokens();
        let idx = idx.min(total);
        let del = del.min(total - idx);
        let byte_start = self.byte_of_token(idx);
        let old_bytes = self.byte_of_token(idx + del) - byte_start;
        let new_bytes = inserts.iter().map(|t| t.text.len()).sum();

        self.split_at(idx);
        self.split_at(idx + del);

        let starts = self.chunk_starts();
        let c0 = starts.partition_point(|&s| s < idx);
        let c1 = starts.partition_point(|&s| s < idx + del);

        let mut work = Chunk::default();
        if c0 < c1 {
            for c in self.chunks.drain(c0..c1) {
                work.text.extend_from_slice(&c.text);
                work.tokens.extend_from_slice(&c.tokens);
            }
            work.reindex(0);
        }
        debug_assert_eq!(work.tokens.len(), del, "chunk range did not cover the deleted tokens");
        work.remove(0, del);
        work.insert(0, inserts);
        if !work.tokens.is_empty() {
            self.chunks.insert(c0, work);
        }

        self.normalize();
        self.fix_ids();

        EditOut {
            tok_start: idx,
            old_count: del,
            new_count: inserts.len(),
            byte_start,
            old_bytes,
            new_bytes,
        }
    }

    pub fn merge_tokens(&mut self, idx: usize, count: usize) -> Option<EditOut> {
        let total = self.len_tokens();
        if count < 2 || idx + count > total {
            return None;
        }
        let abs = self.abs_range(idx..idx + count);
        let doc = self.doc();
        let start = abs[0].start;
        let end = abs[count - 1].end();
        Some(self.edit_at(
            idx,
            count,
            &[NewToken {
                flags: abs[0].flags,
                tag: abs[0].tag,
                text: doc[start..end].to_vec(),
            }],
        ))
    }

    pub fn split_token(&mut self, idx: usize, byte_off: u16) -> Option<EditOut> {
        let a = self.abs(idx)?;
        if byte_off == 0 || byte_off as usize >= a.len as usize {
            return None;
        }
        let doc = self.doc();
        let cut = a.start + byte_off as usize;
        Some(self.edit_at(
            idx,
            1,
            &[
                NewToken { flags: a.flags, tag: a.tag, text: doc[a.start..cut].to_vec() },
                NewToken { flags: a.flags, tag: a.tag, text: doc[cut..a.end()].to_vec() },
            ],
        ))
    }

    pub fn set_tag(&mut self, idx: usize, count: usize, tag: u16) {
        let end = (idx + count).min(self.len_tokens());
        let mut tok = 0usize;
        for c in self.chunks.iter_mut() {
            let n = c.tokens.len();
            let lo = idx.max(tok);
            let hi = end.min(tok + n);
            if lo < hi {
                for t in &mut c.tokens[lo - tok..hi - tok] {
                    t.tag = tag;
                }
            }
            tok += n;
        }
    }

    /// Discard the current segmentation and take the tokenizer's.
    pub fn retokenize_all(&mut self, tok: &dyn crate::Tokenizer) {
        let doc = self.doc();
        let old = self.abs_range(0..self.len_tokens());
        let spans = tok.tokenize(&doc);
        let mut items = Vec::with_capacity(spans.len());
        for s in spans {
            items.push(NewToken {
                flags: s.flags,
                tag: tag_at(&old, s.start),
                text: doc[s.start..s.end()].to_vec(),
            });
        }
        let rev = self.revision;
        *self = Rope::from_tokens(&items);
        self.revision = rev;
    }

    fn chunk_starts(&self) -> Vec<usize> {
        let mut v = Vec::with_capacity(self.chunks.len() + 1);
        let mut acc = 0usize;
        for c in &self.chunks {
            v.push(acc);
            acc += c.tokens.len();
        }
        v.push(acc);
        v
    }

    fn split_at(&mut self, idx: usize) {
        if idx == 0 || idx >= self.len_tokens() {
            return;
        }
        let mut acc = 0usize;
        for ci in 0..self.chunks.len() {
            let n = self.chunks[ci].tokens.len();
            if idx > acc && idx < acc + n {
                let off = idx - acc;
                let c = self.chunks.remove(ci);
                let mut items = c.items();
                let tail = items.split_off(off);
                let mut a = Chunk::default();
                a.set_items(&items);
                let mut b = Chunk::default();
                b.set_items(&tail);
                self.chunks.insert(ci, b);
                self.chunks.insert(ci, a);
                return;
            }
            acc += n;
        }
    }

    fn normalize(&mut self) {
        let mut i = 0;
        while i < self.chunks.len() {
            if self.chunks[i].tokens.is_empty() {
                self.chunks.remove(i);
                continue;
            }
            if self.chunks[i].tokens.len() > CHUNK_MAX_TOKENS {
                let c = self.chunks.remove(i);
                let mid = c.tokens.len() / 2;
                let mut items = c.items();
                let tail = items.split_off(mid);
                let mut a = Chunk::default();
                a.set_items(&items);
                let mut b = Chunk::default();
                b.set_items(&tail);
                self.chunks.insert(i, b);
                self.chunks.insert(i, a);
                continue;
            }
            i += 1;
        }
    }

    fn fix_ids(&mut self) {
        for (i, c) in self.chunks.iter_mut().enumerate() {
            c.reindex(i as u32);
            debug_assert_eq!(c.byte_len(), c.text.len());
        }
    }
}

/// Tag of the token covering `pos`, which keeps annotations alive across a
/// retokenization.
pub fn tag_at(tokens: &[AbsToken], pos: usize) -> u16 {
    let i = tokens.partition_point(|t| t.start <= pos);
    if i == 0 {
        return 0;
    }
    tokens[i - 1].tag
}
