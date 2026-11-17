//! A fixed pool of reactor shards.
//!
//! Shards own reactors, not diffs: a batch goes to every shard so each reactor
//! sees it, and a shard whose queue is full drops to keyframe mode — re-lex the
//! whole document on the next idle moment and count the starvation. Dropping
//! diffs silently would make the feed wrong; counting it makes the cost visible.

use crate::reactors::{BatchView, Reaction, Reactor};
use loom_core::AbsToken;
use std::ops::Range;
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::mpsc::{sync_channel, RecvTimeoutError, SyncSender, TrySendError};
use std::sync::{Arc, Mutex};
use std::thread::{self, JoinHandle};
use std::time::Duration;

pub struct PoolConfig {
    pub shards: usize,
    pub max_queue: usize,
}

impl Default for PoolConfig {
    fn default() -> Self {
        let cpus = thread::available_parallelism()
            .map(|n| n.get())
            .unwrap_or(1);
        // One shard per two cores, capped at four. A shard per core sounds
        // right and measures wrong: six reactors on four threads leave the
        // runtime's workers and the socket path queued behind them, and that
        // is a delivery tail rather than reactor throughput. At 40 125 tokens
        // over 600 edits, four shards put the edit-to-diff p99 at 5.70 ms with
        // 1.96 ms of it on the way out; two put it at 4.21 ms with 56 µs out,
        // while 1000 batches/s still lands 2000 shard events with 0 starved.
        // One shard measures 3.78 ms but makes every reactor wait for the
        // slowest, so two is the default and not the floor.
        let shards = cpus.div_ceil(2).clamp(1, 4);
        PoolConfig {
            shards,
            max_queue: 32,
        }
    }
}

#[derive(Clone, Debug)]
pub struct PoolEvent {
    pub revision: u64,
    pub ran: Vec<u8>,
    pub reactions: Vec<(u8, Reaction)>,
    pub tok_window: Range<usize>,
    pub keyframe: bool,
}

enum Job {
    Diff(Arc<BatchView>),
    Keyframe,
}

type Sink = Arc<dyn Fn(PoolEvent) + Send + Sync>;

struct Latest {
    revision: u64,
    doc: Arc<Vec<u8>>,
    tokens: Arc<Vec<AbsToken>>,
}

pub struct Pool {
    senders: Vec<SyncSender<Job>>,
    starved: Vec<Arc<AtomicBool>>,
    starved_total: Arc<AtomicU64>,
    latest: Arc<Mutex<Option<Latest>>>,
    stop: Arc<AtomicBool>,
    handles: Vec<JoinHandle<()>>,
}

impl Pool {
    pub fn new(
        cfg: PoolConfig,
        reactors: Vec<Box<dyn Reactor>>,
        sink: impl Fn(PoolEvent) + Send + Sync + 'static,
    ) -> Self {
        let sink: Sink = Arc::new(sink);
        let shards = cfg.shards.max(1);
        let mut buckets: Vec<Vec<Box<dyn Reactor>>> = (0..shards).map(|_| Vec::new()).collect();
        for (i, r) in reactors.into_iter().enumerate() {
            buckets[i % shards].push(r);
        }

        let latest = Arc::new(Mutex::new(None));
        let stop = Arc::new(AtomicBool::new(false));
        let starved_total = Arc::new(AtomicU64::new(0));
        let mut senders = Vec::with_capacity(shards);
        let mut starved = Vec::with_capacity(shards);
        let mut handles = Vec::with_capacity(shards);

        for mut reactors in buckets.drain(..) {
            let (tx, rx) = sync_channel::<Job>(cfg.max_queue.max(1));
            let flag = Arc::new(AtomicBool::new(false));
            let sink = sink.clone();
            let latest = latest.clone();
            let stop_flag = stop.clone();
            let flag_thread = flag.clone();
            let handle = thread::spawn(move || {
                while !stop_flag.load(Ordering::Relaxed) {
                    match rx.recv_timeout(Duration::from_millis(10)) {
                        Ok(Job::Diff(view)) => {
                            let mut ran = Vec::with_capacity(reactors.len());
                            let mut reactions = Vec::new();
                            for r in reactors.iter_mut() {
                                ran.push(r.id());
                                for re in r.on_diff(&view) {
                                    reactions.push((r.id(), re));
                                }
                            }
                            sink(PoolEvent {
                                revision: view.revision,
                                ran,
                                reactions,
                                tok_window: view.tok_window.clone(),
                                keyframe: false,
                            });
                        }
                        Ok(Job::Keyframe) => run_keyframe(&mut reactors, &latest, &sink),
                        Err(RecvTimeoutError::Timeout) => {
                            if flag_thread.swap(false, Ordering::SeqCst) {
                                run_keyframe(&mut reactors, &latest, &sink);
                            }
                        }
                        Err(RecvTimeoutError::Disconnected) => break,
                    }
                }
            });
            senders.push(tx);
            starved.push(flag);
            handles.push(handle);
        }

        Pool {
            senders,
            starved,
            starved_total,
            latest,
            stop,
            handles,
        }
    }

    pub fn submit(&self, view: Arc<BatchView>) {
        if let Ok(mut slot) = self.latest.lock() {
            *slot = Some(Latest {
                revision: view.revision,
                doc: view.doc.clone(),
                tokens: view.tokens.clone(),
            });
        }
        for (tx, flag) in self.senders.iter().zip(self.starved.iter()) {
            match tx.try_send(Job::Diff(view.clone())) {
                Ok(()) => {}
                Err(TrySendError::Full(_)) => {
                    flag.store(true, Ordering::SeqCst);
                    self.starved_total.fetch_add(1, Ordering::Relaxed);
                }
                Err(TrySendError::Disconnected(_)) => {}
            }
        }
    }

    pub fn starved_total(&self) -> u64 {
        self.starved_total.load(Ordering::Relaxed)
    }
}

fn run_keyframe(
    reactors: &mut [Box<dyn Reactor>],
    latest: &Arc<Mutex<Option<Latest>>>,
    sink: &Sink,
) {
    let snapshot = latest.lock().ok().and_then(|l| {
        l.as_ref().map(|l| (l.revision, l.doc.clone(), l.tokens.clone()))
    });
    let Some((revision, doc, tokens)) = snapshot else {
        return;
    };
    let mut ran = Vec::with_capacity(reactors.len());
    let mut reactions = Vec::new();
    for r in reactors.iter_mut() {
        ran.push(r.id());
        for re in r.keyframe(&doc, &tokens) {
            reactions.push((r.id(), re));
        }
    }
    sink(PoolEvent {
        revision,
        ran,
        reactions,
        tok_window: 0..tokens.len(),
        keyframe: true,
    });
}

impl Drop for Pool {
    fn drop(&mut self) {
        self.stop.store(true, Ordering::SeqCst);
        for tx in &self.senders {
            let _ = tx.try_send(Job::Keyframe);
        }
        for h in self.handles.drain(..) {
            let _ = h.join();
        }
    }
}
