//! `loom-cli image`: the tokenizer's byte stream read as pixels on a Hilbert curve.
//!
//! No model and no codec sit between tokenizer output and the image: the bytes
//! *are* the picture, in curve order, so the mapping is explainable by
//! construction. What this command adds is the bookkeeping that makes it usable —
//! a typed header per canvas, a text form a tokenizer can emit, exact pixel bounds
//! for every declared byte span, and a report that shows whether each variation
//! stayed inside the spans it declared.
//!
//! `loom-cli hilbert` prints the curve itself, which is how `shaoyanji/hilbert`
//! checks this implementation against its own.

use loom_core::Tokenizer;
use loom_hilbert::{d2xy, Order, Span};
use loom_img::plan::{self, Plan, Source};
use loom_img::Canvas;
use std::path::{Path, PathBuf};

const TOKENIZERS: &str = "bpe_a, bpe_b, wordpiece, regex_lexer";

pub fn image(args: &[String]) -> i32 {
    let mut plan_path: Option<PathBuf> = None;
    let mut out_dir = PathBuf::from(".");
    let mut tok_name = String::from("bpe_a");
    let mut i = 0;
    while i < args.len() {
        match args[i].as_str() {
            "--plan" => {
                plan_path = args.get(i + 1).map(PathBuf::from);
                i += 2;
            }
            "--out" => {
                if let Some(v) = args.get(i + 1) {
                    out_dir = PathBuf::from(v);
                }
                i += 2;
            }
            "--tok" => {
                if let Some(v) = args.get(i + 1) {
                    tok_name = v.clone();
                }
                i += 2;
            }
            _ => i += 1,
        }
    }
    let Some(plan_path) = plan_path else {
        eprintln!("image: --plan <file.json> is required");
        return 2;
    };
    match render(&plan_path, &out_dir, &tok_name) {
        Ok(()) => 0,
        Err(e) => {
            eprintln!("image: {e}");
            1
        }
    }
}

fn tokenizer(name: &str) -> Result<Box<dyn Tokenizer>, String> {
    Ok(match name {
        "bpe_a" => Box::new(loom_tok::bpe_a()),
        "bpe_b" => Box::new(loom_tok::bpe_b()),
        "wordpiece" => Box::new(loom_tok::wordpiece()),
        "regex_lexer" | "lexer" => Box::new(loom_tok::regex_lexer()),
        other => return Err(format!("tokenizer `{other}` is not one of {TOKENIZERS}")),
    })
}

fn render(plan_path: &Path, out_dir: &Path, tok_name: &str) -> Result<(), String> {
    let raw = std::fs::read_to_string(plan_path)
        .map_err(|e| format!("{}: {e}", plan_path.display()))?;
    let plan: Plan =
        serde_json::from_str(&raw).map_err(|e| format!("{}: {e}", plan_path.display()))?;
    let text = match &plan.source {
        Source::Text { text } => text.clone(),
        Source::File { file } => {
            let base = plan_path.parent().unwrap_or(Path::new("."));
            std::fs::read_to_string(base.join(file)).map_err(|e| format!("{file}: {e}"))?
        }
    };
    let tokenizer = tokenizer(tok_name)?;
    let stream = text.as_bytes();
    let tokens: Vec<Span> = tokenizer
        .tokenize(stream)
        .into_iter()
        .map(|s| Span::new(s.start as u64, s.len as u64))
        .collect();
    let outcome = plan::run(&plan, stream, &tokens)?;

    std::fs::create_dir_all(out_dir).map_err(|e| format!("{}: {e}", out_dir.display()))?;
    write_canvas(&out_dir.join("source"), &outcome.base)?;
    for v in &outcome.variants {
        write_canvas(&out_dir.join(&v.name), &v.canvas)?;
    }
    let report = outcome.report();
    std::fs::write(
        out_dir.join("report.json"),
        serde_json::to_string_pretty(&report).map_err(|e| e.to_string())?,
    )
    .map_err(|e| e.to_string())?;

    println!(
        "{} → {} → order {} · {} · {} tokens · {} bytes → {} canvas bytes ({:.1}×)",
        tok_name,
        plan_path.display(),
        outcome.order,
        outcome.layout,
        outcome.tokens,
        outcome.stream_bytes,
        outcome.base.data().len(),
        outcome.base.data().len() as f64 / outcome.stream_bytes as f64,
    );
    for r in &outcome.regions {
        let b = &r["bounds"];
        println!(
            "  region {:<10} tokens {}..{} · bytes {}..{} · x{}..{} y{}..{}",
            r["name"].as_str().unwrap_or("?"),
            r["tokens"]["start"],
            r["tokens"]["start"].as_u64().unwrap_or(0) + r["tokens"]["len"].as_u64().unwrap_or(0),
            r["bytes"]["start"],
            r["bytes"]["start"].as_u64().unwrap_or(0) + r["bytes"]["len"].as_u64().unwrap_or(0),
            b["x0"],
            b["x1"],
            b["y0"],
            b["y1"],
        );
    }
    for v in &outcome.variants {
        let c = &v.json["changed"];
        let b = &c["bounds"];
        println!(
            "  variant {:<12} {:>5} bytes changed · x{}..{} y{}..{} · {} dB · contained {}",
            v.name,
            c["bytes"],
            b["x0"],
            b["x1"],
            b["y0"],
            b["y1"],
            v.json["psnr_db"],
            v.json["contained"],
        );
    }
    let mut checked = 0usize;
    for v in outcome.variants.iter() {
        let bytes = std::fs::read(out_dir.join(format!("{}.himg", v.name)))
            .map_err(|e| format!("{}: {e}", v.name))?;
        let back = Canvas::from_himg(&bytes)?;
        if back != v.canvas {
            return Err(format!("{} does not survive its own container", v.name));
        }
        let text = std::fs::read_to_string(out_dir.join(format!("{}.hex", v.name)))
            .map_err(|e| format!("{}: {e}", v.name))?;
        if Canvas::from_hex_stream(&text)? != v.canvas {
            return Err(format!("{} does not survive its text form", v.name));
        }
        checked += 1;
    }
    println!("  wrote {} canvases, .himg and text both round-trip", checked + 1);
    Ok(())
}

fn write_canvas(base: &Path, canvas: &Canvas) -> Result<(), String> {
    for (ext, bytes) in [
        ("himg", canvas.himg()),
        ("ppm", canvas.ppm()),
        ("hex", canvas.hex_stream().into_bytes()),
    ] {
        let path = base.with_extension(ext);
        std::fs::write(&path, bytes).map_err(|e| format!("{}: {e}", path.display()))?;
    }
    Ok(())
}

/// The curve and its range arithmetic, as JSON, for the JS side to check against.
pub fn hilbert(args: &[String]) -> i32 {
    match args.first().map(|s| s.as_str()) {
        Some("--table") => {
            let n: u8 = args.get(1).and_then(|v| v.parse().ok()).unwrap_or(4);
            let order = match Order::new(n) {
                Ok(o) if n <= 8 => o,
                Ok(_) => {
                    eprintln!("hilbert: --table tops out at order 8");
                    return 2;
                }
                Err(e) => {
                    eprintln!("hilbert: {e}");
                    return 2;
                }
            };
            let mut out = format!("{{\"order\":{n},\"side\":{},\"points\":[", order.side());
            for d in 0..order.cells() {
                let p = d2xy(order, d);
                if d > 0 {
                    out.push(',');
                }
                out.push_str(&format!("[{},{}]", p.x, p.y));
            }
            out.push_str("]}");
            println!("{out}");
            0
        }
        Some("--span") => {
            let n: u8 = args.get(1).and_then(|v| v.parse().ok()).unwrap_or(4);
            let order = match Order::new(n) {
                Ok(o) => o,
                Err(e) => {
                    eprintln!("hilbert: {e}");
                    return 2;
                }
            };
            let start: u64 = args.get(2).and_then(|v| v.parse().ok()).unwrap_or(0);
            let len: u64 = args.get(3).and_then(|v| v.parse().ok()).unwrap_or(order.cells());
            let span = Span::new(start, len).clipped(order);
            let fast = span.bounds(order);
            let slow = span.bounds_by_enumeration(order);
            let blocks = span.blocks(order);
            println!(
                "{}",
                serde_json::json!({
                    "order": n,
                    "span": { "start": span.start, "len": span.len },
                    "blocks": blocks.iter().map(|b| serde_json::json!({
                        "level": b.level,
                        "d0": b.d0,
                        "side": b.side(),
                    })).collect::<Vec<_>>(),
                    "bounds": fast.map(|b| serde_json::json!({
                        "x0": b.x0, "y0": b.y0, "x1": b.x1, "y1": b.y1, "area": b.area(),
                    })),
                    "bounds_by_enumeration": slow.map(|b| serde_json::json!({
                        "x0": b.x0, "y0": b.y0, "x1": b.x1, "y1": b.y1, "area": b.area(),
                    })),
                    "agrees": fast == slow,
                })
            );
            0
        }
        _ => {
            eprintln!("usage: loom-cli hilbert --table <order≤8>\n       loom-cli hilbert --span <order> <start> <len>");
            2
        }
    }
}
