//! Hand-rolled binary protocol: little-endian, hand-rolled, one opcode byte.
//!
//! The client frames *are* [`loom_core::Op`], so an op cannot drift between the
//! session and the socket. Text travels inline for the MVP; if a profile shows
//! the text dominating a frame the next step is a chunk reference, not a bigger
//! buffer.

use loom_core::{NewToken, Op};
use std::fmt;

pub const OP_INSERT: u8 = 0x01;
pub const OP_DELETE: u8 = 0x02;
pub const OP_MERGE: u8 = 0x03;
pub const OP_SPLIT: u8 = 0x04;
pub const OP_ANNOTATE: u8 = 0x05;
pub const OP_CONSTRAINT_ADD: u8 = 0x06;
pub const OP_REACTOR_TOGGLE: u8 = 0x07;
pub const OP_RESYNC: u8 = 0x08;
pub const OP_CONSTRAINT_REMOVE: u8 = 0x09;
pub const OP_CONSTRAINT_UPDATE: u8 = 0x0a;

pub const OP_ACK: u8 = 0x80;
pub const OP_DIFF: u8 = 0x81;
pub const OP_WARNING_RAISE: u8 = 0x82;
pub const OP_WARNING_CLEAR: u8 = 0x83;
pub const OP_SNAPSHOT: u8 = 0x84;
pub const OP_METRICS: u8 = 0x85;
pub const OP_CONSTRAINTS: u8 = 0x86;

/// A constraint as a client lists it: the byte anchor the index keeps, the span
/// length in tokens it was planted with, and what it forbids. No token index,
/// because the anchor is what stays true as text moves.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct ConstraintView {
    pub id: u32,
    pub anchor: u32,
    /// The token the anchor covers when the frame is written. The page keeps no
    /// byte index of its own, so the server does the mapping once here and the
    /// page shifts the result with the diffs it already receives.
    pub token: u32,
    pub len: u16,
    pub kind: u8,
    pub param: u32,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum ServerFrame {
    Ack { seq: u64, revision: u64 },
    Diff { revision: u64, start: u32, deleted: u16, inserted: Vec<NewToken> },
    WarningRaise {
        id: u32,
        kind: u8,
        reactor: u8,
        severity: u8,
        start: u32,
        len: u16,
        revision: u64,
        message: String,
    },
    WarningClear { id: u32, revision: u64 },
    Snapshot {
        revision: u64,
        /// Bit per reactor id, bit `i` = reactor `i` (ids are 1-based): whether
        /// it is on. A client that reloads draws the server's bank, not its own
        /// default.
        reactors: u8,
        tokens: Vec<NewToken>,
    },
    Metrics {
        p50_us: u32,
        p99_us: u32,
        retok_per_edit: u32,
        ripple_truncations: u32,
        /// Batches a shard dropped to keyframe mode, cumulative.
        starved: u32,
        /// Tokens the reactors saw in the last batch window.
        window: u32,
        /// The session's reactor bank, bit `i` = reactor `i`, as `SNAPSHOT`
        /// carries it. Sent with the metrics so a toggle is visible without a
        /// reload.
        reactors: u8,
        /// Constraints the session holds, so a plant that landed without
        /// raising is still something the page can see.
        constraints: u32,
    },
    /// Every constraint the session holds, so a page can list the spans rather
    /// than only count them.
    Constraints { revision: u64, items: Vec<ConstraintView> },
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum WireError {
    Short,
    Opcode(u8),
    BadUtf8,
    TextTooLong(usize),
    TooManyTokens(usize),
}

impl fmt::Display for WireError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            WireError::Short => write!(f, "frame ended mid-field"),
            WireError::Opcode(o) => write!(f, "unknown opcode 0x{o:02x}"),
            WireError::BadUtf8 => write!(f, "warning message was not utf-8"),
            WireError::TextTooLong(n) => write!(f, "token text of {n} bytes exceeds u16"),
            WireError::TooManyTokens(n) => write!(f, "{n} tokens exceeds u16"),
        }
    }
}

impl std::error::Error for WireError {}

fn text_len(text: &[u8]) -> Result<u16, WireError> {
    u16::try_from(text.len()).map_err(|_| WireError::TextTooLong(text.len()))
}

fn count_len(n: usize) -> Result<u16, WireError> {
    u16::try_from(n).map_err(|_| WireError::TooManyTokens(n))
}

fn put_tokens(out: &mut Vec<u8>, tokens: &[NewToken]) -> Result<(), WireError> {
    out.extend_from_slice(&count_len(tokens.len())?.to_le_bytes());
    for t in tokens {
        out.extend_from_slice(&text_len(&t.text)?.to_le_bytes());
        out.push(t.flags);
        out.extend_from_slice(&t.text);
    }
    Ok(())
}

/// Encode one server frame into a caller-owned buffer, appending. The diff send
/// path keeps one buffer for the process lifetime, so steady state allocates
/// nothing here.
pub fn encode_into(frame: &ServerFrame, out: &mut Vec<u8>) -> Result<(), WireError> {
    match frame {
        ServerFrame::Ack { seq, revision } => {
            out.push(OP_ACK);
            out.extend_from_slice(&seq.to_le_bytes());
            out.extend_from_slice(&revision.to_le_bytes());
        }
        ServerFrame::Diff { revision, start, deleted, inserted } => {
            encode_diff_into(*revision, *start, *deleted, inserted, out)?;
        }
        ServerFrame::WarningRaise {
            id,
            kind,
            reactor,
            severity,
            start,
            len,
            revision,
            message,
        } => {
            out.push(OP_WARNING_RAISE);
            out.extend_from_slice(&id.to_le_bytes());
            out.push(*kind);
            out.push(*reactor);
            out.push(*severity);
            out.extend_from_slice(&start.to_le_bytes());
            out.extend_from_slice(&len.to_le_bytes());
            out.extend_from_slice(&revision.to_le_bytes());
            out.extend_from_slice(&text_len(message.as_bytes())?.to_le_bytes());
            out.extend_from_slice(message.as_bytes());
        }
        ServerFrame::WarningClear { id, revision } => {
            out.push(OP_WARNING_CLEAR);
            out.extend_from_slice(&id.to_le_bytes());
            out.extend_from_slice(&revision.to_le_bytes());
        }
        ServerFrame::Snapshot { revision, reactors, tokens } => {
            out.push(OP_SNAPSHOT);
            out.extend_from_slice(&revision.to_le_bytes());
            out.push(*reactors);
            out.extend_from_slice(&u32::try_from(tokens.len()).unwrap_or(u32::MAX).to_le_bytes());
            for t in tokens {
                out.extend_from_slice(&text_len(&t.text)?.to_le_bytes());
                out.push(t.flags);
                out.extend_from_slice(&t.text);
            }
        }
        ServerFrame::Metrics {
            p50_us,
            p99_us,
            retok_per_edit,
            ripple_truncations,
            starved,
            window,
            reactors,
            constraints,
        } => {
            out.push(OP_METRICS);
            out.extend_from_slice(&p50_us.to_le_bytes());
            out.extend_from_slice(&p99_us.to_le_bytes());
            out.extend_from_slice(&retok_per_edit.to_le_bytes());
            out.extend_from_slice(&ripple_truncations.to_le_bytes());
            out.extend_from_slice(&starved.to_le_bytes());
            out.extend_from_slice(&window.to_le_bytes());
            out.push(*reactors);
            out.extend_from_slice(&constraints.to_le_bytes());
        }
        ServerFrame::Constraints { revision, items } => {
            out.push(OP_CONSTRAINTS);
            out.extend_from_slice(&revision.to_le_bytes());
            out.extend_from_slice(&u32::try_from(items.len()).unwrap_or(u32::MAX).to_le_bytes());
            for c in items {
                out.extend_from_slice(&c.id.to_le_bytes());
                out.extend_from_slice(&c.anchor.to_le_bytes());
                out.extend_from_slice(&c.token.to_le_bytes());
                out.extend_from_slice(&c.len.to_le_bytes());
                out.push(c.kind);
                out.extend_from_slice(&c.param.to_le_bytes());
            }
        }
    }
    Ok(())
}

/// The hot frame, encoded without building a `ServerFrame` first.
///
/// This is the path the coalescer runs per batch; it appends to a reused
/// buffer, so steady state allocates nothing inside the encoder.
pub fn encode_diff_into(
    revision: u64,
    start: u32,
    deleted: u16,
    inserted: &[NewToken],
    out: &mut Vec<u8>,
) -> Result<(), WireError> {
    out.push(OP_DIFF);
    out.extend_from_slice(&revision.to_le_bytes());
    out.extend_from_slice(&start.to_le_bytes());
    out.extend_from_slice(&deleted.to_le_bytes());
    put_tokens(out, inserted)
}

pub fn encode(frame: &ServerFrame) -> Result<Vec<u8>, WireError> {
    let mut out = Vec::with_capacity(64);
    encode_into(frame, &mut out)?;
    Ok(out)
}

pub fn encode_op(op: &Op, out: &mut Vec<u8>) -> Result<(), WireError> {
    match op {
        Op::Insert { seq, offset, tokens } => {
            out.push(OP_INSERT);
            out.extend_from_slice(&seq.to_le_bytes());
            out.extend_from_slice(&offset.to_le_bytes());
            put_tokens(out, tokens)?;
        }
        Op::Delete { seq, offset, count } => {
            out.push(OP_DELETE);
            out.extend_from_slice(&seq.to_le_bytes());
            out.extend_from_slice(&offset.to_le_bytes());
            out.extend_from_slice(&count.to_le_bytes());
        }
        Op::Merge { seq, offset, count } => {
            out.push(OP_MERGE);
            out.extend_from_slice(&seq.to_le_bytes());
            out.extend_from_slice(&offset.to_le_bytes());
            out.extend_from_slice(&count.to_le_bytes());
        }
        Op::Split { seq, offset, byte_off } => {
            out.push(OP_SPLIT);
            out.extend_from_slice(&seq.to_le_bytes());
            out.extend_from_slice(&offset.to_le_bytes());
            out.extend_from_slice(&byte_off.to_le_bytes());
        }
        Op::Annotate { seq, offset, count, tag, bytes } => {
            out.push(OP_ANNOTATE);
            out.extend_from_slice(&seq.to_le_bytes());
            out.extend_from_slice(&offset.to_le_bytes());
            out.extend_from_slice(&count.to_le_bytes());
            out.extend_from_slice(&tag.to_le_bytes());
            out.extend_from_slice(&text_len(bytes)?.to_le_bytes());
            out.extend_from_slice(bytes);
        }
        Op::ConstraintAdd { seq, start, len, kind, param } => {
            out.push(OP_CONSTRAINT_ADD);
            out.extend_from_slice(&seq.to_le_bytes());
            out.extend_from_slice(&start.to_le_bytes());
            out.extend_from_slice(&len.to_le_bytes());
            out.push(*kind);
            out.extend_from_slice(&param.to_le_bytes());
        }
        Op::ConstraintRemove { seq, id } => {
            out.push(OP_CONSTRAINT_REMOVE);
            out.extend_from_slice(&seq.to_le_bytes());
            out.extend_from_slice(&id.to_le_bytes());
        }
        Op::ConstraintUpdate { seq, id, kind, param } => {
            out.push(OP_CONSTRAINT_UPDATE);
            out.extend_from_slice(&seq.to_le_bytes());
            out.extend_from_slice(&id.to_le_bytes());
            out.push(*kind);
            out.extend_from_slice(&param.to_le_bytes());
        }
        Op::ReactorToggle { seq, reactor, enabled } => {
            out.push(OP_REACTOR_TOGGLE);
            out.extend_from_slice(&seq.to_le_bytes());
            out.push(*reactor);
            out.push(u8::from(*enabled));
        }
        Op::Resync { seq } => {
            out.push(OP_RESYNC);
            out.extend_from_slice(&seq.to_le_bytes());
        }
    }
    Ok(())
}

pub struct Reader<'a> {
    buf: &'a [u8],
    pos: usize,
}

impl<'a> Reader<'a> {
    pub fn new(buf: &'a [u8]) -> Self {
        Reader { buf, pos: 0 }
    }

    fn take(&mut self, n: usize) -> Result<&'a [u8], WireError> {
        let end = self.pos.checked_add(n).ok_or(WireError::Short)?;
        if end > self.buf.len() {
            return Err(WireError::Short);
        }
        let s = &self.buf[self.pos..end];
        self.pos = end;
        Ok(s)
    }

    fn u8(&mut self) -> Result<u8, WireError> {
        Ok(self.take(1)?[0])
    }

    fn u16(&mut self) -> Result<u16, WireError> {
        Ok(u16::from_le_bytes(self.take(2)?.try_into().unwrap()))
    }

    fn u32(&mut self) -> Result<u32, WireError> {
        Ok(u32::from_le_bytes(self.take(4)?.try_into().unwrap()))
    }

    fn u64(&mut self) -> Result<u64, WireError> {
        Ok(u64::from_le_bytes(self.take(8)?.try_into().unwrap()))
    }

    fn bytes16(&mut self) -> Result<Vec<u8>, WireError> {
        let n = self.u16()? as usize;
        Ok(self.take(n)?.to_vec())
    }

    fn text16(&mut self) -> Result<String, WireError> {
        let n = self.u16()? as usize;
        String::from_utf8(self.take(n)?.to_vec()).map_err(|_| WireError::BadUtf8)
    }

    /// `count × (len u16, flags u8, text)`
    fn tokens(&mut self, count: usize) -> Result<Vec<NewToken>, WireError> {
        let mut v = Vec::with_capacity(count.min(4096));
        for _ in 0..count {
            let len = self.u16()? as usize;
            let flags = self.u8()?;
            let text = self.take(len)?.to_vec();
            v.push(NewToken { flags, tag: 0, text });
        }
        Ok(v)
    }
}

pub fn decode_op(buf: &[u8]) -> Result<Op, WireError> {
    let mut r = Reader::new(buf);
    let opcode = r.u8()?;
    Ok(match opcode {
        OP_INSERT => {
            let seq = r.u64()?;
            let offset = r.u32()?;
            let count = r.u16()? as usize;
            Op::Insert { seq, offset, tokens: r.tokens(count)? }
        }
        OP_DELETE => Op::Delete { seq: r.u64()?, offset: r.u32()?, count: r.u16()? },
        OP_MERGE => Op::Merge { seq: r.u64()?, offset: r.u32()?, count: r.u16()? },
        OP_SPLIT => Op::Split { seq: r.u64()?, offset: r.u32()?, byte_off: r.u16()? },
        OP_ANNOTATE => {
            let seq = r.u64()?;
            let offset = r.u32()?;
            let count = r.u16()?;
            let tag = r.u16()?;
            Op::Annotate { seq, offset, count, tag, bytes: r.bytes16()? }
        }
        OP_CONSTRAINT_ADD => Op::ConstraintAdd {
            seq: r.u64()?,
            start: r.u32()?,
            len: r.u16()?,
            kind: r.u8()?,
            param: r.u32()?,
        },
        OP_CONSTRAINT_REMOVE => Op::ConstraintRemove { seq: r.u64()?, id: r.u32()? },
        OP_CONSTRAINT_UPDATE => Op::ConstraintUpdate {
            seq: r.u64()?,
            id: r.u32()?,
            kind: r.u8()?,
            param: r.u32()?,
        },
        OP_REACTOR_TOGGLE => Op::ReactorToggle {
            seq: r.u64()?,
            reactor: r.u8()?,
            enabled: r.u8()? != 0,
        },
        OP_RESYNC => Op::Resync { seq: r.u64()? },
        other => return Err(WireError::Opcode(other)),
    })
}

pub fn encode_op_frame(op: &Op) -> Result<Vec<u8>, WireError> {
    let mut out = Vec::with_capacity(64);
    encode_op(op, &mut out)?;
    Ok(out)
}

pub fn decode_server(buf: &[u8]) -> Result<ServerFrame, WireError> {
    let mut r = Reader::new(buf);
    let opcode = r.u8()?;
    Ok(match opcode {
        OP_ACK => ServerFrame::Ack { seq: r.u64()?, revision: r.u64()? },
        OP_DIFF => {
            let revision = r.u64()?;
            let start = r.u32()?;
            let deleted = r.u16()?;
            let count = r.u16()? as usize;
            ServerFrame::Diff { revision, start, deleted, inserted: r.tokens(count)? }
        }
        OP_WARNING_RAISE => ServerFrame::WarningRaise {
            id: r.u32()?,
            kind: r.u8()?,
            reactor: r.u8()?,
            severity: r.u8()?,
            start: r.u32()?,
            len: r.u16()?,
            revision: r.u64()?,
            message: r.text16()?,
        },
        OP_WARNING_CLEAR => ServerFrame::WarningClear { id: r.u32()?, revision: r.u64()? },
        OP_SNAPSHOT => {
            let revision = r.u64()?;
            let reactors = r.u8()?;
            let count = r.u32()? as usize;
            let mut tokens = Vec::with_capacity(count.min(4096));
            for _ in 0..count {
                let len = r.u16()? as usize;
                let flags = r.u8()?;
                let text = r.take(len)?.to_vec();
                tokens.push(NewToken { flags, tag: 0, text });
            }
            ServerFrame::Snapshot { revision, reactors, tokens }
        }
        OP_METRICS => ServerFrame::Metrics {
            p50_us: r.u32()?,
            p99_us: r.u32()?,
            retok_per_edit: r.u32()?,
            ripple_truncations: r.u32()?,
            starved: r.u32()?,
            window: r.u32()?,
            reactors: r.u8()?,
            constraints: r.u32()?,
        },
        OP_CONSTRAINTS => {
            let revision = r.u64()?;
            let count = r.u32()? as usize;
            let mut items = Vec::with_capacity(count.min(256));
            for _ in 0..count {
                items.push(ConstraintView {
                    id: r.u32()?,
                    anchor: r.u32()?,
                    token: r.u32()?,
                    len: r.u16()?,
                    kind: r.u8()?,
                    param: r.u32()?,
                });
            }
            ServerFrame::Constraints { revision, items }
        }
        other => return Err(WireError::Opcode(other)),
    })
}
