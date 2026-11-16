//! An append-only log of applied batches, and a snapshot that shortens it.
//!
//! Records hold the ops, not the resulting tokens: replay re-applies them and
//! retokenizes, which is the only way the log can prove the incremental path
//! agrees with a full rebuild. Constraint ops ride the same log, so a restart
//! comes back with the spans that were planted rather than a document wearing
//! every edit and none of its constraints.

use crate::session::{apply_with_anchors, plant_constraint, Session};
use loom_core::{NewToken, Op, Rope, Tokenizer};
use loom_react::{ConstraintIndex, ConstraintKind};
use serde::{Deserialize, Serialize};
use std::fs::{self, File, OpenOptions};
use std::io::{self, BufWriter, Read, Write};
use std::path::{Path, PathBuf};
use std::time::{Duration, Instant};

pub const LOG_FILE: &str = "session.edits";
pub const SNAP_FILE: &str = "session.snap";
pub const SNAPSHOT_EVERY_REVISIONS: u64 = 500;
pub const SNAPSHOT_IDLE: Duration = Duration::from_secs(5);

/// Marks a snapshot that carries its constraints and its reactor bank. An older
/// magic, or none at all, still reads: the fields that snapshot could not have
/// known default to their startup value, so an existing session directory
/// survives the upgrade.
const SNAP_MAGIC: &[u8; 4] = b"LMS3";
const SNAP_MAGIC_V2: &[u8; 4] = b"LMS2";

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct BatchRecord {
    pub revision: u64,
    pub ops: Vec<Op>,
}

/// A constraint as the session held it: the wire names tokens, but the index
/// keeps a byte anchor, and that is what has to be written down.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct StoredConstraint {
    pub anchor: u32,
    pub len: u16,
    pub kind: u8,
    pub param: u32,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct SnapshotFile {
    pub revision: u64,
    pub tokens: Vec<NewToken>,
    pub constraints: Vec<StoredConstraint>,
    /// Which reactors were on. A toggle outlives the client that sent it, so it
    /// is written down beside the document rather than left to the next page.
    pub reactors: [bool; 8],
}

#[derive(Deserialize)]
struct SnapshotV2 {
    revision: u64,
    tokens: Vec<NewToken>,
    constraints: Vec<StoredConstraint>,
}

#[derive(Deserialize)]
struct SnapshotV1 {
    revision: u64,
    tokens: Vec<NewToken>,
}

impl SnapshotFile {
    fn decode(bytes: &[u8]) -> Option<SnapshotFile> {
        if let Some(rest) = bytes.strip_prefix(SNAP_MAGIC) {
            return bincode::deserialize(rest).ok();
        }
        if let Some(rest) = bytes.strip_prefix(SNAP_MAGIC_V2) {
            return bincode::deserialize::<SnapshotV2>(rest)
                .ok()
                .map(|s| SnapshotFile {
                    revision: s.revision,
                    tokens: s.tokens,
                    constraints: s.constraints,
                    reactors: [true; 8],
                });
        }
        bincode::deserialize::<SnapshotV1>(bytes)
            .ok()
            .map(|s| SnapshotFile {
                revision: s.revision,
                tokens: s.tokens,
                constraints: Vec::new(),
                reactors: [true; 8],
            })
    }
}

fn write_blob(w: &mut impl Write, bytes: &[u8]) -> io::Result<()> {
    let len = u32::try_from(bytes.len())
        .map_err(|_| io::Error::new(io::ErrorKind::InvalidInput, "record too large"))?;
    w.write_all(&len.to_le_bytes())?;
    w.write_all(bytes)
}

fn read_blob(r: &mut impl Read) -> io::Result<Option<Vec<u8>>> {
    let mut hdr = [0u8; 4];
    match r.read_exact(&mut hdr) {
        Ok(()) => {}
        Err(e) if e.kind() == io::ErrorKind::UnexpectedEof => return Ok(None),
        Err(e) => return Err(e),
    }
    let n = u32::from_le_bytes(hdr) as usize;
    let mut buf = vec![0u8; n];
    r.read_exact(&mut buf)?;
    Ok(Some(buf))
}

pub fn load(dir: &Path) -> io::Result<(Option<SnapshotFile>, Vec<BatchRecord>)> {
    let snap = match File::open(dir.join(SNAP_FILE)) {
        Ok(mut f) => {
            let mut buf = Vec::new();
            f.read_to_end(&mut buf)?;
            SnapshotFile::decode(&buf)
        }
        Err(_) => None,
    };
    let mut records = Vec::new();
    if let Ok(mut f) = File::open(dir.join(LOG_FILE)) {
        loop {
            let Some(blob) = read_blob(&mut f)? else { break };
            match bincode::deserialize::<BatchRecord>(&blob) {
                Ok(r) => records.push(r),
                // A torn tail is what a kill mid-write looks like; the snapshot
                // behind it is still good.
                Err(_) => break,
            }
        }
    }
    let snap_rev = snap.as_ref().map(|s| s.revision).unwrap_or(0);
    records.retain(|r| r.revision > snap_rev);
    Ok((snap, records))
}

pub struct Persist {
    dir: PathBuf,
    log: BufWriter<File>,
    last_snapshot_rev: u64,
    last_activity: Instant,
}

impl Persist {
    pub fn open(dir: impl AsRef<Path>) -> io::Result<(Self, Option<SnapshotFile>, Vec<BatchRecord>)> {
        let dir = dir.as_ref().to_path_buf();
        fs::create_dir_all(&dir)?;
        let (snap, records) = load(&dir)?;
        let log = OpenOptions::new().create(true).append(true).open(dir.join(LOG_FILE))?;
        let last_snapshot_rev = snap.as_ref().map(|s| s.revision).unwrap_or(0);
        Ok((
            Persist {
                dir,
                log: BufWriter::new(log),
                last_snapshot_rev,
                last_activity: Instant::now(),
            },
            snap,
            records,
        ))
    }

    pub fn append(&mut self, rec: &BatchRecord) -> io::Result<()> {
        let bytes =
            bincode::serialize(rec).map_err(|e| io::Error::new(io::ErrorKind::InvalidData, e))?;
        write_blob(&mut self.log, &bytes)?;
        self.log.flush()?;
        self.last_activity = Instant::now();
        Ok(())
    }

    pub fn snapshot(&mut self, sess: &Session) -> io::Result<()> {
        let doc = sess.rope.doc();
        let tokens: Vec<NewToken> = sess
            .rope
            .abs_tokens()
            .into_iter()
            .map(|t| NewToken {
                flags: t.flags,
                tag: t.tag,
                text: doc[t.start..t.end()].to_vec(),
            })
            .collect();
        let constraints: Vec<StoredConstraint> = sess
            .constraints
            .iter()
            .map(|c| StoredConstraint {
                anchor: c.anchor,
                len: c.len,
                kind: c.kind as u8,
                param: c.param,
            })
            .collect();
        let snap = SnapshotFile {
            revision: sess.rope.revision(),
            tokens,
            constraints,
            reactors: sess.reactors,
        };
        let mut bytes = SNAP_MAGIC.to_vec();
        bytes.extend(
            bincode::serialize(&snap).map_err(|e| io::Error::new(io::ErrorKind::InvalidData, e))?,
        );
        let tmp = self.dir.join(format!("{SNAP_FILE}.tmp"));
        fs::write(&tmp, &bytes)?;
        fs::rename(&tmp, self.dir.join(SNAP_FILE))?;
        self.last_snapshot_rev = snap.revision;
        self.last_activity = Instant::now();
        Ok(())
    }

    pub fn last_snapshot_rev(&self) -> u64 {
        self.last_snapshot_rev
    }

    pub fn maybe_snapshot(&mut self, sess: &Session) -> io::Result<bool> {
        let rev = sess.rope.revision();
        let many = rev.saturating_sub(self.last_snapshot_rev) >= SNAPSHOT_EVERY_REVISIONS;
        let idle = rev > self.last_snapshot_rev && self.last_activity.elapsed() >= SNAPSHOT_IDLE;
        if many || idle {
            self.snapshot(sess)?;
            return Ok(true);
        }
        Ok(false)
    }
}

/// The constraint index a snapshot recorded, rebuilt in its original order so
/// ids come back the same and a warning that names one still names it.
pub fn constraint_index(stored: &[StoredConstraint]) -> ConstraintIndex {
    let mut index = ConstraintIndex::new();
    for c in stored {
        if let Some(kind) = ConstraintKind::from_u8(c.kind) {
            index.add(c.anchor, c.len, kind, c.param);
        }
    }
    index
}

/// Replay records onto a rope and its constraint index, retokenizing after each
/// so the result is what the live path produced rather than what the ops
/// nominally said. Constraint ops re-plant through the same conversion the
/// session used, and text ops move anchors through the same shift.
pub fn replay(
    mut rope: Rope,
    mut constraints: ConstraintIndex,
    mut reactors: [bool; 8],
    records: &[BatchRecord],
    tok: &dyn Tokenizer,
) -> (Rope, ConstraintIndex, [bool; 8]) {
    for rec in records {
        for op in &rec.ops {
            match op {
                Op::ConstraintAdd { start, len, kind, param, .. } => {
                    plant_constraint(&rope, &mut constraints, *start, *len, *kind, *param);
                }
                // A toggle moves no text but is session state all the same: it
                // decides which reactors get to speak. Replay it, or a restart
                // comes back with every reactor on and warnings the operator had
                // switched off.
                Op::ReactorToggle { reactor, enabled, .. } => {
                    let i = (*reactor as usize) % reactors.len();
                    reactors[i] = *enabled;
                }
                // A resync asks for a frame the client that sent it is gone.
                Op::Resync { .. } => {}
                _ => {
                    apply_with_anchors(op, &mut rope, &mut constraints);
                }
            }
        }
        rope.retokenize_all(tok);
        rope.set_revision(rec.revision);
    }
    (rope, constraints, reactors)
}

/// Rebuild a session from a snapshot plus the log tail.
pub fn restore(snap: &SnapshotFile, records: &[BatchRecord], tok: &dyn Tokenizer) -> Session {
    let mut sess = Session::from_snapshot(&snap.tokens, snap.revision);
    let index = constraint_index(&snap.constraints);
    let (rope, constraints, reactors) = replay(sess.rope.clone(), index, snap.reactors, records, tok);
    sess.rope = rope;
    sess.constraints = constraints;
    sess.reactors = reactors;
    sess
}
