//! `loom-cli bench`, `fuzz`, `replay`.
//!
//! `bench` is the gate: it runs the server on a loopback port and times send →
//! diff over the real protocol, coalescer window included — the same segment
//! `web/window.mjs` times from the browser, against the same 5 ms target.
//! `bench --core` times apply → ripple → encode alone: that is the floor under
//! the number, not a gate of its own.

mod e2e;

use loom_core::{NewToken, Op, Rope, Tokenizer, FLAG_WORD};
use loom_srv::session::Session;
use loom_wire::encode_diff_into;
use std::path::Path;
use std::time::Instant;

const USAGE: &str = "\
usage: loom-cli <command>

  bench [--relax] [edits]  edit → diff over a socket, window included: the 5ms gate
                           (default 200 edits: at 1000 the doc grows by 1000 tokens)
  bench --core [edits]     apply → ripple → encode alone, no window, no gate
        --doc N            document size in tokens (default 10000)
        --window N         coalescer window in ms (default 2, or LOOM_COALESCE_MS)
  fuzz [batches]           random batches, assert incremental == full rebuild
  replay [dir]             load snapshot + log, replay, report
";

const WORDS: &[&str] = &[
    "the", "outstanding", "reconsideration", "of", "tokenization", "is", "that", "a", "merge",
    "can", "ripple", "past", "window", "and", "reactor", "bank", "keeps", "its", "own",
    "segmentation", "so", "six", "opinions", "cost", "windows", "never", "passes", "boundary",
    "stability", "matters", "here", "when", "text", "crosses", "delimiter",
];

struct Lcg(u64);

impl Lcg {
    fn next(&mut self) -> u64 {
        self.0 = self
            .0
            .wrapping_mul(6364136223846793005)
            .wrapping_add(1442695040888963407);
        self.0 >> 11
    }
}

fn build_doc(target_tokens: usize) -> String {
    let tok = loom_tok::bpe_a();
    let mut s = String::with_capacity(target_tokens * 6);
    let mut words = 0usize;
    loop {
        s.push_str(WORDS[words % WORDS.len()]);
        s.push(' ');
        words += 1;
        if words % 32 == 0 && tok.tokenize(s.as_bytes()).len() >= target_tokens {
            return s;
        }
    }
}

fn histogram(samples: &[u32]) -> Vec<(u32, usize)> {
    let edges = [100u32, 250, 500, 1000, 2500, 5000, 10_000, 50_000];
    let mut buckets = vec![0usize; edges.len() + 1];
    for &s in samples {
        match edges.iter().position(|&e| s <= e) {
            Some(i) => buckets[i] += 1,
            None => buckets[edges.len()] += 1,
        }
    }
    edges
        .iter()
        .copied()
        .chain(std::iter::once(u32::MAX))
        .zip(buckets)
        .collect()
}

fn pct(sorted: &[u32], q: f64) -> u32 {
    if sorted.is_empty() {
        return 0;
    }
    sorted[(((sorted.len() - 1) as f64) * q).round() as usize]
}

/// The gate, and the diagnostic that explains it.
///
/// One number is quoted for edit → diff: the socket one. The core pipeline is
/// reported beside it as the floor, because a target the core meets but the
/// socket misses is a number that says nothing about the editor.
fn bench(args: &[String]) -> i32 {
    let relax = args.iter().any(|a| a == "--relax");
    let core = args.iter().any(|a| a == "--core");
    let mut edits = 200usize;
    let mut doc_tokens = 10_000usize;
    let mut window = std::env::var("LOOM_COALESCE_MS")
        .ok()
        .and_then(|v| v.parse().ok())
        .unwrap_or(2u64);
    let mut i = 0;
    while i < args.len() {
        match args[i].as_str() {
            "--doc" => {
                if let Some(n) = args.get(i + 1).and_then(|v| v.parse().ok()) {
                    doc_tokens = n;
                }
                i += 2;
            }
            "--window" => {
                if let Some(n) = args.get(i + 1).and_then(|v| v.parse().ok()) {
                    window = n;
                }
                i += 2;
            }
            flag if flag.starts_with("--") => i += 1,
            n => {
                if let Ok(v) = n.parse() {
                    edits = v;
                }
                i += 1;
            }
        }
    }

    if !core {
        let doc = build_doc(doc_tokens);
        let rt = match tokio::runtime::Builder::new_multi_thread().enable_all().build() {
            Ok(rt) => rt,
            Err(e) => {
                eprintln!("loom-cli: no runtime for the socket bench: {e}");
                return 1;
            }
        };
        return rt.block_on(e2e::measure(&doc, edits, window, relax));
    }
    core_bench(edits, relax)
}

fn core_bench(edits: usize, relax: bool) -> i32 {
    let doc = build_doc(10_000);
    let mut sess = Session::with_doc(&doc);
    let tokens = sess.rope.len_tokens();
    let bytes = sess.rope.len_bytes();
    println!("document: {tokens} tokens, {bytes} bytes");

    let mut rng = Lcg(0x9e37_79b9_7f4a_7c15);
    let mut lat = Vec::with_capacity(edits);
    let mut ratio = Vec::with_capacity(edits);
    let mut truncations = 0usize;
    let mut encode_ns: u128 = 0;
    let mut scratch: Vec<u8> = Vec::with_capacity(4096);
    let cap_before = scratch.capacity();

    for i in 0..edits {
        let len = sess.rope.len_tokens();
        let at = (rng.next() as usize) % len;
        let word = WORDS[(rng.next() as usize) % WORDS.len()];
        let op = match rng.next() % 4 {
            0 => Op::Insert {
                seq: i as u64,
                offset: at as u32,
                tokens: vec![NewToken {
                    flags: FLAG_WORD,
                    tag: 0,
                    text: word.as_bytes().to_vec(),
                }],
            },
            1 => Op::Delete {
                seq: i as u64,
                offset: at as u32,
                count: 1,
            },
            2 => Op::Split {
                seq: i as u64,
                offset: at as u32,
                byte_off: 1,
            },
            _ => Op::Merge {
                seq: i as u64,
                offset: at as u32,
                count: 2,
            },
        };
        let t = Instant::now();
        let out = sess.apply_batch(std::slice::from_ref(&op));
        lat.push(t.elapsed().as_micros().min(u32::MAX as u128) as u32);
        if let Some(a) = &out.applied {
            let doc_bytes = sess.rope.len_bytes().max(1);
            ratio.push((a.retok.bytes_retokenized * 10_000 / doc_bytes) as u32);
            if a.retok.truncated {
                truncations += 1;
            }
            let t = Instant::now();
            for _ in 0..50 {
                scratch.clear();
                let _ = encode_diff_into(a.revision, a.start as u32, a.deleted, &a.tokens, &mut scratch);
            }
            encode_ns += t.elapsed().as_nanos() / 50;
        }
    }

    let mut sorted = lat.clone();
    sorted.sort_unstable();
    let mut ratios = ratio.clone();
    ratios.sort_unstable();

    println!("\nedit → diff latency (µs), core pipeline:");
    for (edge, n) in histogram(&lat) {
        let label = if edge == u32::MAX {
            "> 50ms".to_string()
        } else {
            format!("≤ {edge:>5}µs")
        };
        let bar = "█".repeat(((n as f64 / edits as f64) * 48.0).round() as usize);
        println!("  {label}  {n:>5}  {bar}");
    }
    println!(
        "  p50 {}µs · p90 {}µs · p99 {}µs · max {}µs",
        pct(&sorted, 0.50),
        pct(&sorted, 0.90),
        pct(&sorted, 0.99),
        sorted.last().copied().unwrap_or(0)
    );
    println!(
        "  re-tokenized per edit: p50 {:.2}% · p99 {:.2}% of the document",
        pct(&ratios, 0.50) as f64 / 100.0,
        pct(&ratios, 0.99) as f64 / 100.0
    );
    println!(
        "  ripple truncations: {truncations} of {edits} edits ({:.3}%)",
        truncations as f64 * 100.0 / edits as f64
    );
    println!(
        "  diff encode: {encode_ns}ns/frame, encoder buffer {cap_before} → {} bytes (no growth ⇒ no allocation)",
        scratch.capacity()
    );

    let med = pct(&ratios, 0.50);
    let p99r = pct(&ratios, 0.99);
    let reactors_ok = reactor_phase(&sess);
    let ok = med < 200
        && p99r < 1_000
        && (truncations as f64) < edits as f64 * 0.001
        && reactors_ok;
    println!(
        "\ntargets (core): median < 2% [{}] · p99 < 10% [{}] · truncations < 0.1% [{}] · reactors [{}]",
        if med < 200 { "ok" } else { "MISS" },
        if p99r < 1_000 { "ok" } else { "MISS" },
        if (truncations as f64) < edits as f64 * 0.001 { "ok" } else { "MISS" },
        if reactors_ok { "ok" } else { "MISS" }
    );
    println!(
        "  the 5 ms edit → diff target is gated over the socket: `loom-cli bench` without --core"
    );
    if ok || relax {
        0
    } else {
        1
    }
}

/// Drive the real reactor pool at 1000 batches/s while the document changes.
///
/// The window walks across the document and every batch inserts a word, so each
/// reactor runs a block splice with a non-zero delta. Reactor 1 re-lexes
/// independently and complains (`span-creep`) if its own segmentation disagrees
/// with the rope's tokens: that is the assertion, and it is the one a broken
/// position index would fail silently.
fn reactor_phase(sess: &Session) -> bool {
    use loom_react::{
        builtin_reactors, BatchView, ConstraintIndex, Pool, PoolConfig, PoolEvent, WarningKind,
    };
    use std::sync::atomic::{AtomicU64, Ordering};
    use std::sync::Arc;
    use std::time::Duration;

    const SUBMITS: usize = 1000;
    const INTERVAL: Duration = Duration::from_micros(1000);

    let done = Arc::new(AtomicU64::new(0));
    let creep = Arc::new(AtomicU64::new(0));
    let reactions = Arc::new(AtomicU64::new(0));
    let counted = done.clone();
    let crept = creep.clone();
    let reacted = reactions.clone();
    let cfg = PoolConfig::default();
    let shards = cfg.shards.max(1) as u64;
    let pool = Pool::new(cfg, builtin_reactors(), move |ev: PoolEvent| {
        if ev.keyframe {
            return;
        }
        counted.fetch_add(1, Ordering::Relaxed);
        for (reactor, re) in &ev.reactions {
            reacted.fetch_add(1, Ordering::Relaxed);
            if *reactor == 1 && re.kind == WarningKind::SpanCreep {
                crept.fetch_add(1, Ordering::Relaxed);
            }
        }
    });

    let text = String::from_utf8_lossy(&sess.rope.doc()).to_string();
    let mut live = Session::with_doc(&text);
    let constraints = Arc::new(ConstraintIndex::new());
    let started = Instant::now();

    for revision in 0..SUBMITS {
        let len = live.rope.len_tokens().max(2);
        let at = (revision.wrapping_mul(7919) % (len - 1)) + 1;
        let op = Op::Insert {
            seq: revision as u64,
            offset: at as u32,
            tokens: vec![NewToken {
                flags: FLAG_WORD,
                tag: 0,
                text: b"loom".to_vec(),
            }],
        };
        if let Some(a) = live.apply_batch(std::slice::from_ref(&op)).applied {
            pool.submit(Arc::new(BatchView {
                revision: a.revision,
                doc: a.doc.clone(),
                tokens: a.abs.clone(),
                tok_window: a.tok_window.clone(),
                byte_window: a.byte_window.clone(),
                constraints: constraints.clone(),
            }));
        }
        // Pace to an absolute deadline, so the rate is the requested one and any
        // shard that falls behind shows up as starvation instead of as a slower
        // clock.
        let due = started + INTERVAL * revision as u32;
        std::thread::sleep(due.saturating_duration_since(Instant::now()));
    }
    let submitted = started.elapsed();
    // Let the last shard drain before the counters are read.
    std::thread::sleep(Duration::from_millis(600));
    let events = done.load(Ordering::Relaxed);
    let creep = creep.load(Ordering::Relaxed);
    let starved = pool.starved_total();
    let doc_tokens = live.rope.len_tokens();
    drop(pool);
    println!(
        "  reactors: {SUBMITS} batches in {:.2}s ({:.0}/s), {events} shard events over {shards} shards, {} reactions, {starved} starved, {creep} span-creep (doc {doc_tokens} tokens)",
        submitted.as_secs_f64(),
        SUBMITS as f64 / submitted.as_secs_f64().max(1e-9),
        reactions.load(Ordering::Relaxed),
    );
    // Every shard must see every batch: a dropped diff is a silently wrong feed.
    starved == 0 && events == SUBMITS as u64 * shards && creep == 0
}

fn fuzz(args: &[String]) -> i32 {
    let batches: usize = args.iter().find_map(|a| a.parse().ok()).unwrap_or(200);
    let doc = build_doc(2_000);
    let tok = loom_tok::bpe_a();
    let mut sess = Session::with_doc(&doc);
    let mut rng = Lcg(0xdead_beef_1234_5678);
    let mut seq = 0u64;

    for i in 0..batches {
        let mut ops = Vec::new();
        let len = sess.rope.len_tokens();
        for _ in 0..(1 + rng.next() % 4) {
            seq += 1;
            let at = (rng.next() as usize) % len.max(1);
            let op = match rng.next() % 6 {
                0 | 1 => Op::Insert {
                    seq,
                    offset: at as u32,
                    tokens: vec![NewToken {
                        flags: FLAG_WORD,
                        tag: 0,
                        text: WORDS[(rng.next() as usize) % WORDS.len()].as_bytes().to_vec(),
                    }],
                },
                2 => Op::Delete { seq, offset: at as u32, count: 1 + (rng.next() % 3) as u16 },
                3 => Op::Merge { seq, offset: at as u32, count: 2 },
                4 => Op::Split { seq, offset: at as u32, byte_off: 1 },
                _ => Op::Annotate { seq, offset: at as u32, count: 1, tag: 7, bytes: b"*".to_vec() },
            };
            ops.push(op);
        }
        sess.apply_batch(&ops);

        let doc = sess.rope.doc();
        let want: Vec<(usize, u16, u8)> = tok
            .tokenize(&doc)
            .into_iter()
            .map(|s| (s.start, s.len as u16, s.flags))
            .collect();
        let got: Vec<(usize, u16, u8)> = sess
            .rope
            .abs_tokens()
            .into_iter()
            .map(|t| (t.start, t.len, t.flags))
            .collect();
        if want != got {
            eprintln!("drift after batch {i}: {} tokens incremental, {} rebuilt", got.len(), want.len());
            return 1;
        }
    }
    println!("{batches} batches, no drift: incremental == full rebuild");
    0
}

fn replay(args: &[String]) -> i32 {
    let dir = args
        .first()
        .cloned()
        .unwrap_or_else(|| "session".to_string());
    match loom_srv::persist::load(Path::new(&dir)) {
        Ok((snap, records)) => {
            let tok = loom_tok::bpe_a();
            let base = match &snap {
                Some(s) => {
                    println!(
                        "snapshot at revision {} · {} constraints",
                        s.revision,
                        s.constraints.len()
                    );
                    Rope::from_tokens(&s.tokens)
                }
                None => Rope::new(),
            };
            let stored = snap.as_ref().map(|s| s.constraints.clone()).unwrap_or_default();
            let index = loom_srv::persist::constraint_index(&stored);
            let bank = snap.as_ref().map(|s| s.reactors).unwrap_or([true; 8]);
            let (rope, constraints, reactors) =
                loom_srv::persist::replay(base, index, bank, &records, &tok);
            let doc = rope.doc();
            let want: Vec<(usize, u16, u8)> = tok
                .tokenize(&doc)
                .into_iter()
                .map(|s| (s.start, s.len as u16, s.flags))
                .collect();
            let got: Vec<(usize, u16, u8)> = rope
                .abs_tokens()
                .into_iter()
                .map(|t| (t.start, t.len, t.flags))
                .collect();
            let off: Vec<String> = reactors
                .iter()
                .enumerate()
                .filter(|(_, on)| !**on)
                .map(|(i, _)| i.to_string())
                .collect();
            println!(
                "replayed {} batches → revision {}, {} tokens, {} bytes, {} constraints, reactors off [{}]",
                records.len(),
                rope.revision(),
                got.len(),
                doc.len(),
                constraints.len(),
                off.join(" ")
            );
            if want == got {
                println!("replay agrees with a full rebuild");
                0
            } else {
                eprintln!("replay disagrees with a full rebuild");
                1
            }
        }
        Err(e) => {
            eprintln!("cannot read {dir}: {e}");
            1
        }
    }
}

fn main() {
    let args: Vec<String> = std::env::args().skip(1).collect();
    let code = match args.first().map(|s| s.as_str()) {
        Some("bench") => bench(&args[1..]),
        Some("fuzz") => fuzz(&args[1..]),
        Some("replay") => replay(&args[1..]),
        _ => {
            print!("{USAGE}");
            0
        }
    };
    std::process::exit(code);
}
