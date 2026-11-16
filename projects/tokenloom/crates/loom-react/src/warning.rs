//! Warnings and their lifecycle.
//!
//! Identity is `(kind, reactor, span bucket)`, not the exact span: an edit that
//! moves a violation by a token or two must not mint a second warning, because a
//! feed that flickers reads as broken.

use crate::reactors::Reaction;
use std::collections::{BTreeMap, HashSet};
use std::ops::Range;

pub const FLAP_WINDOW_MS: u64 = 250;
pub const QUIET_PERIOD_MS: u64 = 500;
pub const MAX_WARNINGS: usize = 512;
const SPAN_BUCKET: u32 = 8;

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, PartialOrd, Ord)]
#[repr(u8)]
pub enum WarningKind {
    BoundaryInstability = 1,
    CrossVocabDivergence = 2,
    ConstraintViolation = 3,
    SpanCreep = 4,
    MergeExplosion = 5,
    RippleTruncated = 6,
}

impl WarningKind {
    pub fn from_u8(v: u8) -> Option<Self> {
        Some(match v {
            1 => WarningKind::BoundaryInstability,
            2 => WarningKind::CrossVocabDivergence,
            3 => WarningKind::ConstraintViolation,
            4 => WarningKind::SpanCreep,
            5 => WarningKind::MergeExplosion,
            6 => WarningKind::RippleTruncated,
            _ => return None,
        })
    }

    pub fn label(self) -> &'static str {
        match self {
            WarningKind::BoundaryInstability => "boundary-instability",
            WarningKind::CrossVocabDivergence => "cross-vocab-divergence",
            WarningKind::ConstraintViolation => "constraint-violation",
            WarningKind::SpanCreep => "span-creep",
            WarningKind::MergeExplosion => "merge-explosion",
            WarningKind::RippleTruncated => "ripple-truncated",
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Warning {
    pub id: u32,
    pub kind: WarningKind,
    pub reactor: u8,
    pub severity: u8,
    pub start: u32,
    pub len: u16,
    pub revision: u64,
    pub first_seen_rev: u64,
    pub flap_count: u16,
    pub message: String,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, PartialOrd, Ord)]
pub struct Key {
    pub kind: u8,
    pub reactor: u8,
    pub bucket: u32,
}

pub fn key_of(reactor: u8, r: &Reaction) -> Key {
    Key {
        kind: r.kind as u8,
        reactor,
        bucket: r.start / SPAN_BUCKET,
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum EngineEvent {
    Raise(Warning),
    Clear { id: u32, revision: u64 },
}

struct Entry {
    key: Key,
    w: Warning,
    last_seen_ms: u64,
    absent_since: Option<u64>,
}

#[derive(Default)]
pub struct WarningEngine {
    entries: BTreeMap<u32, Entry>,
    by_key: BTreeMap<Key, u32>,
    next_id: u32,
}

impl WarningEngine {
    pub fn new() -> Self {
        WarningEngine::default()
    }

    pub fn len(&self) -> usize {
        self.entries.len()
    }

    pub fn is_empty(&self) -> bool {
        self.entries.is_empty()
    }

    pub fn active(&self) -> Vec<Warning> {
        self.entries.values().map(|e| e.w.clone()).collect()
    }

    /// Record a reactor's claim. A re-raise keeps the id and sends nothing, so
    /// the client's list is stable under thrash.
    pub fn raise(
        &mut self,
        reactor: u8,
        r: &Reaction,
        revision: u64,
        now_ms: u64,
    ) -> Vec<EngineEvent> {
        let key = key_of(reactor, r);
        if let Some(&id) = self.by_key.get(&key) {
            if let Some(e) = self.entries.get_mut(&id) {
                if now_ms.saturating_sub(e.last_seen_ms) <= FLAP_WINDOW_MS {
                    e.w.flap_count = e.w.flap_count.saturating_add(1);
                }
                e.last_seen_ms = now_ms;
                e.absent_since = None;
                e.w.revision = revision;
                e.w.severity = r.severity;
                e.w.len = r.len;
                e.w.message = r.message.clone();
                return Vec::new();
            }
        }

        let mut events = Vec::new();
        if self.entries.len() >= MAX_WARNINGS {
            events.extend(self.evict_one());
        }

        let id = self.next_id;
        self.next_id += 1;
        let w = Warning {
            id,
            kind: r.kind,
            reactor,
            severity: r.severity,
            start: r.start,
            len: r.len.max(1),
            revision,
            first_seen_rev: revision,
            flap_count: 0,
            message: r.message.clone(),
        };
        events.push(EngineEvent::Raise(w.clone()));
        self.entries.insert(
            id,
            Entry { key, w, last_seen_ms: now_ms, absent_since: None },
        );
        self.by_key.insert(key, id);
        events
    }

    /// After a reactor evaluated `tok_window`: anything it owns that intersects
    /// the window and was not re-raised is now absent, and starts its quiet
    /// clock. Nothing is cleared here — that waits for `expire`.
    pub fn pass(
        &mut self,
        reactor: u8,
        tok_window: &Range<usize>,
        now_ms: u64,
        raised: &HashSet<Key>,
    ) -> Vec<EngineEvent> {
        if tok_window.start >= tok_window.end {
            return Vec::new();
        }
        for e in self.entries.values_mut() {
            if e.w.reactor != reactor || e.absent_since.is_some() {
                continue;
            }
            if raised.contains(&e.key) || !intersects(e, tok_window) {
                continue;
            }
            e.absent_since = Some(now_ms);
        }
        Vec::new()
    }

    pub fn expire(&mut self, now_ms: u64) -> Vec<EngineEvent> {
        let stale: Vec<u32> = self
            .entries
            .values()
            .filter(|e| {
                e.absent_since
                    .map(|t| now_ms.saturating_sub(t) > QUIET_PERIOD_MS)
                    .unwrap_or(false)
            })
            .map(|e| e.w.id)
            .collect();
        let mut out = Vec::new();
        for id in stale {
            if let Some(e) = self.entries.remove(&id) {
                self.by_key.remove(&e.key);
                out.push(EngineEvent::Clear {
                    id,
                    revision: e.w.revision,
                });
            }
        }
        out
    }

    fn evict_one(&mut self) -> Vec<EngineEvent> {
        let victim = self
            .entries
            .values()
            .min_by_key(|e| (e.w.severity, e.w.id))
            .map(|e| e.w.id);
        let Some(id) = victim else {
            return Vec::new();
        };
        if let Some(e) = self.entries.remove(&id) {
            self.by_key.remove(&e.key);
            return vec![EngineEvent::Clear {
                id,
                revision: e.w.revision,
            }];
        }
        Vec::new()
    }
}

fn intersects(e: &Entry, win: &Range<usize>) -> bool {
    let s = e.w.start as usize;
    let end = s + e.w.len.max(1) as usize;
    s < win.end && end > win.start
}
