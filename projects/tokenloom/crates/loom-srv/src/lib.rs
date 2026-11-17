//! Session wiring: one document, one coalescer, six reactors, one broadcast.

pub mod persist;
pub mod session;
pub mod ws;

use loom_core::Op;
use loom_react::{
    builtin_reactors, key_of, BatchView, EngineEvent, Key, Pool, PoolConfig, PoolEvent,
    WarningEngine,
};
use loom_wire::{encode_diff_into, encode_into, ServerFrame};
use session::Session;
use std::collections::{HashMap, HashSet};
use std::path::PathBuf;
use std::sync::atomic::{AtomicBool, AtomicU32, Ordering};
use std::sync::{Arc, Mutex, OnceLock};
use std::time::{Duration, Instant};
use tokio::sync::{broadcast, mpsc};

pub const REACTORS: usize = 6;
const BROADCAST_CAPACITY: usize = 256;
const METRICS_EVERY: Duration = Duration::from_millis(250);

pub fn now_ms() -> u64 {
    static T0: OnceLock<Instant> = OnceLock::new();
    T0.get_or_init(Instant::now).elapsed().as_millis() as u64
}

pub struct Shared {
    pub engine: Mutex<WarningEngine>,
    pub out: broadcast::Sender<Arc<Vec<u8>>>,
    pub reactors_on: [AtomicBool; 8],
    pub starved: AtomicU32,
}

/// One batch's stamps on the monotonic clock, for the bench's tail split.
///
/// The bench runs the client and the server in one process, so these stamps and
/// the client's are the same clock and the segments add up to the number the
/// gate quotes. Collected only when `LOOM_TRACE` is set: one field read per
/// batch otherwise.
#[derive(Clone, Copy, Debug)]
pub struct StageTimes {
    /// First op of the batch.
    pub seq: u64,
    /// The coalescer took that op: the window starts here.
    pub queued: Instant,
    /// The session lock was taken and apply began.
    pub apply_at: Instant,
    /// `apply_batch` returned.
    pub applied_at: Instant,
    /// Every frame of the batch was in the broadcast.
    pub sent_at: Instant,
}

#[derive(Default)]
pub struct Trace {
    pub on: bool,
    entries: Mutex<Vec<StageTimes>>,
}

impl Trace {
    fn push(&self, at: StageTimes) {
        if let Ok(mut v) = self.entries.lock() {
            v.push(at);
        }
    }

    /// Every batch stamped so far, oldest first.
    pub fn entries(&self) -> Vec<StageTimes> {
        self.entries.lock().map(|v| v.clone()).unwrap_or_default()
    }
}

pub struct AppState {
    pub session: Mutex<Session>,
    pub shared: Arc<Shared>,
    pub trace: Arc<Trace>,
    pub pool: Pool,
    pub ops_tx: mpsc::UnboundedSender<Vec<Op>>,
    pub persist: Mutex<Option<persist::Persist>>,
    scratch: Mutex<Vec<u8>>,
    last_metrics: Mutex<Instant>,
    pub coalesce_ms: u64,
}

impl AppState {
    pub fn revision(&self) -> u64 {
        self.session.lock().map(|s| s.rope.revision()).unwrap_or(0)
    }
}

pub fn build_state(
    sess: Session,
    data_dir: Option<PathBuf>,
    coalesce_ms: u64,
) -> (Arc<AppState>, mpsc::UnboundedReceiver<Vec<Op>>) {
    let (out, _rx) = broadcast::channel(BROADCAST_CAPACITY);
    // A restored session arrives with its reactor bank; a fresh one has them
    // all on, which is the same default the page draws.
    let mut on = [const { AtomicBool::new(true) }; 8];
    for (i, flag) in on.iter_mut().enumerate() {
        flag.store(sess.reactors.get(i).copied().unwrap_or(true), Ordering::Relaxed);
    }
    let shared = Arc::new(Shared {
        engine: Mutex::new(WarningEngine::new()),
        out,
        reactors_on: on,
        starved: AtomicU32::new(0),
    });

    let sink_shared = shared.clone();
    let pool = Pool::new(PoolConfig::default(), builtin_reactors(), move |ev: PoolEvent| {
        on_pool_event(&sink_shared, ev);
    });

    let persist = data_dir.and_then(|d| match persist::Persist::open(d) {
        Ok((p, _, _)) => Some(p),
        Err(e) => {
            eprintln!("loom: persistence disabled: {e}");
            None
        }
    });

    let (ops_tx, ops_rx) = mpsc::unbounded_channel();
    let state = Arc::new(AppState {
        session: Mutex::new(sess),
        shared,
        pool,
        ops_tx,
        persist: Mutex::new(persist),
        scratch: Mutex::new(Vec::with_capacity(4096)),
        last_metrics: Mutex::new(Instant::now()),
        coalesce_ms,
        trace: Arc::new(Trace {
            on: std::env::var_os("LOOM_TRACE").is_some(),
            ..Trace::default()
        }),
    });
    (state, ops_rx)
}

fn reactor_enabled(shared: &Shared, reactor: u8) -> bool {
    shared.reactors_on[(reactor as usize) % shared.reactors_on.len()].load(Ordering::Relaxed)
}

fn on_pool_event(shared: &Shared, ev: PoolEvent) {
    let now = now_ms();
    let mut eng = match shared.engine.lock() {
        Ok(e) => e,
        Err(_) => return,
    };
    let mut per_reactor: HashMap<u8, HashSet<Key>> = HashMap::new();
    let mut events: Vec<EngineEvent> = Vec::new();

    for (reactor, reaction) in &ev.reactions {
        if !reactor_enabled(shared, *reactor) {
            continue;
        }
        per_reactor
            .entry(*reactor)
            .or_default()
            .insert(key_of(*reactor, reaction));
        events.extend(eng.raise(*reactor, reaction, ev.revision, now));
    }

    let empty = HashSet::new();
    for reactor in &ev.ran {
        if reactor_enabled(shared, *reactor) {
            let raised = per_reactor.get(reactor).unwrap_or(&empty);
            events.extend(eng.pass(*reactor, &ev.tok_window, now, raised));
        } else {
            events.extend(eng.pass(*reactor, &(0..usize::MAX), now, &empty));
        }
    }
    events.extend(eng.expire(now));
    drop(eng);

    for e in events {
        broadcast_event(shared, e);
    }
}

fn broadcast_event(shared: &Shared, e: EngineEvent) {
    let frame = match e {
        EngineEvent::Raise(w) => ServerFrame::WarningRaise {
            id: w.id,
            kind: w.kind as u8,
            reactor: w.reactor,
            severity: w.severity,
            start: w.start,
            len: w.len,
            revision: w.revision,
            message: w.message,
        },
        EngineEvent::Clear { id, revision } => ServerFrame::WarningClear { id, revision },
    };
    if let Ok(bytes) = loom_wire::encode(&frame) {
        let _ = shared.out.send(Arc::new(bytes));
    }
}

/// Expire absent warnings on a clock, not on the next edit.
///
/// A warning has to clear when its condition goes away, and a reactor toggle
/// changes the condition with no edit at all: without this tick a cleared feed
/// would wait for the next keystroke.
pub async fn ticker(state: Arc<AppState>) {
    let mut interval = tokio::time::interval(Duration::from_millis(100));
    loop {
        interval.tick().await;
        let now = now_ms();
        let events = match state.shared.engine.lock() {
            Ok(mut eng) => eng.expire(now),
            Err(_) => Vec::new(),
        };
        for e in events {
            broadcast_event(&state.shared, e);
        }
    }
}

/// Batch everything that arrives inside the coalescing window into one revision.
pub async fn coalesce(mut rx: mpsc::UnboundedReceiver<Vec<Op>>, state: Arc<AppState>) {
    let window = Duration::from_millis(state.coalesce_ms.max(1));
    while let Some(first) = rx.recv().await {
        // The window starts when this task takes the op, not when it was typed:
        // that is the segment the trace calls the wait.
        let queued = Instant::now();
        let mut batch = first;
        let deadline = tokio::time::Instant::now() + window;
        loop {
            match tokio::time::timeout_at(deadline, rx.recv()).await {
                Ok(Some(more)) => batch.extend(more),
                _ => break,
            }
        }
        handle_batch(&state, batch, queued);
    }
}

fn handle_batch(state: &Arc<AppState>, batch: Vec<Op>, queued: Instant) {
    let toggled_off = now_ms();
    let mut toggle_events: Vec<EngineEvent> = Vec::new();
    for op in &batch {
        if let Op::ReactorToggle { reactor, enabled, .. } = op {
            if !*enabled {
                // A disabled reactor is not going to evaluate its span again,
                // so its warnings are absent from this moment: they clear on
                // the quiet period instead of waiting for an edit.
                if let Ok(mut eng) = state.shared.engine.lock() {
                    toggle_events.extend(eng.pass(
                        *reactor,
                        &(0..usize::MAX),
                        toggled_off,
                        &HashSet::new(),
                    ));
                }
            }
        }
    }
    for e in toggle_events {
        broadcast_event(&state.shared, e);
    }

    let apply_at = Instant::now();
    let (outcome, revision, snap_tokens, view, applied_at) = {
        let mut s = match state.session.lock() {
            Ok(s) => s,
            Err(_) => return,
        };
        let outcome = s.apply_batch(&batch);
        let applied_at = Instant::now();
        // The session is where a toggle is written down; the pool's copy is a
        // mirror so its sink reads a flag without waiting on this lock.
        for (i, flag) in state.shared.reactors_on.iter().enumerate() {
            if let Some(on) = s.reactors.get(i) {
                flag.store(*on, Ordering::SeqCst);
            }
        }
        let revision = s.rope.revision();
        let view = outcome.applied.as_ref().map(|a| {
            Arc::new(BatchView {
                revision: a.revision,
                doc: a.doc.clone(),
                tokens: a.abs.clone(),
                tok_window: a.tok_window.clone(),
                byte_window: a.byte_window.clone(),
                constraints: Arc::new(s.constraints.clone()),
            })
        });
        let snap = if outcome.resync {
            Some((s.snapshot_tokens(), s.reactor_bits()))
        } else {
            None
        };
        state
            .shared
            .starved
            .store(state.pool.starved_total() as u32, Ordering::Relaxed);
        (outcome, revision, snap, view, applied_at)
    };

    if let Ok(mut buf) = state.scratch.lock() {
        for seq in &outcome.seqs {
            buf.clear();
            if encode_into(
                &ServerFrame::Ack {
                    seq: *seq,
                    revision,
                },
                &mut buf,
            )
            .is_ok()
            {
                let _ = state.shared.out.send(Arc::new(buf.clone()));
            }
        }
        if let Some(a) = &outcome.applied {
            if !outcome.resync {
                buf.clear();
                if encode_diff_into(a.revision, a.start as u32, a.deleted, &a.tokens, &mut buf).is_ok()
                {
                    let _ = state.shared.out.send(Arc::new(buf.clone()));
                }
            }
        }
        if let Some((tokens, reactors)) = snap_tokens {
            buf.clear();
            if encode_into(
                &ServerFrame::Snapshot { revision, reactors, tokens },
                &mut buf,
            )
            .is_ok()
            {
                let _ = state.shared.out.send(Arc::new(buf.clone()));
            }
        }
    }

    // Stamped for the bench: the gate quotes one number, and this is the split
    // that says which of its parts a miss belongs to. Off unless `LOOM_TRACE`.
    if state.trace.on {
        state.trace.push(StageTimes {
            seq: batch.first().map(|o| o.seq()).unwrap_or(0),
            queued,
            apply_at,
            applied_at,
            sent_at: Instant::now(),
        });
    }

    // The sidebar's list changes on a plant, a removal and a retune, and all
    // three are rare: answer with the whole index rather than a delta a client
    // would have to apply to a list it only half knows. The session reports the
    // change instead of this function comparing lengths, because a retune moves
    // the length not at all.
    if outcome.constraints || outcome.resync {
        broadcast_constraints(state);
    }

    if let Some(view) = view {
        state.pool.submit(view);
    }

    if let Ok(mut guard) = state.persist.lock() {
        if let Some(p) = guard.as_mut() {
            let _ = p.append(&persist::BatchRecord {
                revision,
                ops: batch,
            });
            if let Ok(s) = state.session.lock() {
                let _ = p.maybe_snapshot(&s);
            }
        }
    }

    emit_metrics(state, false);
}

fn metrics_frame(state: &AppState) -> Option<Vec<u8>> {
    let s = state.session.lock().ok()?;
    let (p50_us, p99_us) = s.percentiles();
    let frame = ServerFrame::Metrics {
        p50_us,
        p99_us,
        retok_per_edit: s.retok_per_edit_bp(),
        ripple_truncations: s.ripple_truncations.min(u32::MAX as u64) as u32,
        starved: state.shared.starved.load(Ordering::Relaxed),
        window: s.last_window(),
        reactors: s.reactor_bits(),
        constraints: s.constraints.len().min(u32::MAX as usize) as u32,
    };
    loom_wire::encode(&frame).ok()
}

/// Broadcast the pill's numbers, at most once per [`METRICS_EVERY`] unless the
/// caller is the clock.
///
/// A batch and the clock share one deadline, so a burst of edits still yields a
/// single frame per window and an idle session still yields frames.
fn emit_metrics(state: &AppState, force: bool) {
    if !force {
        let due = state
            .last_metrics
            .lock()
            .map(|mut last| {
                if last.elapsed() >= METRICS_EVERY {
                    *last = Instant::now();
                    true
                } else {
                    false
                }
            })
            .unwrap_or(false);
        if !due {
            return;
        }
    }
    if let Some(bytes) = metrics_frame(state) {
        let _ = state.shared.out.send(Arc::new(bytes));
    }
}

/// The whole constraint index, for the sidebar panel. Sent when a client
/// connects (the snapshot carries tokens, not spans), after a batch that
/// planted one, and after a resync.
pub fn constraints_frame(state: &AppState) -> Option<Vec<u8>> {
    let s = state.session.lock().ok()?;
    let frame = ServerFrame::Constraints {
        revision: s.rope.revision(),
        items: s.constraint_views(),
    };
    loom_wire::encode(&frame).ok()
}

fn broadcast_constraints(state: &AppState) {
    if let Some(bytes) = constraints_frame(state) {
        let _ = state.shared.out.send(Arc::new(bytes));
    }
}

/// Push the metrics on a clock, not only on a batch.
///
/// The pill reports the session, so a page with no edit of its own still has to
/// see a reactor switched off in another tab or a constraint planted there.
/// Without this the readout is the last edit's, which is what made a switch look
/// unapplied until the page happened to type.
pub async fn metrics_ticker(state: Arc<AppState>) {
    let mut interval = tokio::time::interval(METRICS_EVERY);
    loop {
        interval.tick().await;
        emit_metrics(&state, true);
    }
}

/// Token count and byte count, for the health line and the CLI.
pub fn stats(sess: &Session) -> (u64, usize, usize) {
    (sess.rope.revision(), sess.rope.len_tokens(), sess.rope.len_bytes())
}
