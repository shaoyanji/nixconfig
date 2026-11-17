//! A declarative plan of typed range operations over the canvas byte stream.
//!
//! The canvas stream is the tokenizer's bytes as the canvas holds them — repeated
//! or padded to `4^order × bytes_per_pixel` — so an offset in a plan is an offset
//! in the image, and a declared span maps to pixels once rather than once per
//! copy of the text.
//!
//! A variant names itself and lists operations. Every operation carries the span
//! it is allowed to touch, and the report proves what it did: the indices that
//! actually changed, their exact pixel bounds, whether every changed index lies in
//! a declared span, and how far the picture moved in dB. Nothing here guesses a
//! region and nothing re-derives one from a model — the span is the input and the
//! bounding box is arithmetic on the curve.
//!
//! The declarative surface is the JSON [`Plan`]; the executable surface is
//! [`run`]. There is no intermediate representation to drift.

use crate::{Canvas, Fill, Layout};
use loom_hilbert::{d2xy, Bounds, Order, Region, Span};
use serde::Deserialize;
use serde_json::{json, Value};

/// What the plan reads its token stream from.
#[derive(Debug, Clone, Deserialize)]
#[serde(untagged)]
pub enum Source {
    /// Inline text: the tokenizer's input lives in the plan.
    Text { text: String },
    /// A file beside the plan.
    File { file: String },
}

#[derive(Debug, Clone, Deserialize)]
pub struct Plan {
    pub order: u8,
    #[serde(default = "default_layout")]
    pub layout: String,
    /// `repeat` (default), `pad` or `refuse`, for a stream shorter than the canvas.
    #[serde(default)]
    pub fill: Option<String>,
    pub source: Source,
    /// Token ranges to locate on the canvas before any variation runs.
    #[serde(default)]
    pub regions: Vec<NamedRegion>,
    #[serde(default)]
    pub variants: Vec<Variant>,
}

fn default_layout() -> String {
    "rgb8".to_string()
}

#[derive(Debug, Clone, Deserialize)]
pub struct NamedRegion {
    pub name: String,
    pub tokens: TokenRange,
}

/// A range of *tokens*, which is the unit a tokenizer reasons in.
#[derive(Debug, Clone, Copy, Deserialize)]
pub struct TokenRange {
    pub start: u64,
    pub len: u64,
}

/// A range of *bytes*, which is the unit the canvas is laid out in.
#[derive(Debug, Clone, Copy, Deserialize)]
pub struct ByteSpan {
    pub start: u64,
    pub len: u64,
}

impl ByteSpan {
    pub fn span(self) -> Span {
        Span::new(self.start, self.len)
    }
}

#[derive(Debug, Clone, Deserialize)]
pub struct Variant {
    pub name: String,
    pub ops: Vec<OpSpec>,
}

/// One typed operation. `span` is the declaration; the return of [`OpSpec::apply`]
/// is what it managed to touch, clipped to the stream.
#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum OpSpec {
    /// Rotate the bytes inside the span, cyclically, by `by`.
    Roll { span: ByteSpan, by: i64 },
    /// Overwrite the span with bytes read from `from`, wrapping at the stream end.
    Splice { span: ByteSpan, from: u64 },
    /// Reverse the span in place.
    Reverse { span: ByteSpan },
    /// Multiply every byte in the span, saturating at 255.
    Gain { span: ByteSpan, factor: f32 },
    /// Zero the span.
    Mask { span: ByteSpan },
}

impl OpSpec {
    pub fn span(&self) -> Span {
        match self {
            OpSpec::Roll { span, .. }
            | OpSpec::Splice { span, .. }
            | OpSpec::Reverse { span }
            | OpSpec::Gain { span, .. }
            | OpSpec::Mask { span } => span.span(),
        }
    }

    /// Apply in place and return the span actually affected, clipped to `buf`.
    pub fn apply(&self, buf: &mut [u8]) -> Result<Span, String> {
        let n = buf.len();
        let clip = |s: Span| Span {
            start: s.start.min(n as u64),
            len: s.len.min(n as u64 - s.start.min(n as u64)),
        };
        let span = clip(self.span());
        let (start, len) = (span.start as usize, span.len as usize);
        if len == 0 {
            return Ok(span);
        }
        match self {
            OpSpec::Roll { by, .. } => {
                if *by != 0 {
                    let shift = ((*by as i128).rem_euclid(len as i128)) as usize;
                    let slice = &mut buf[start..start + len];
                    slice.rotate_left(shift);
                }
            }
            OpSpec::Splice { from, .. } => {
                if n == 0 {
                    return Err("cannot splice into an empty stream".to_string());
                }
                let src: Vec<u8> = (0..len)
                    .map(|i| buf[(*from as usize + i) % n])
                    .collect();
                buf[start..start + len].copy_from_slice(&src);
            }
            OpSpec::Reverse { .. } => buf[start..start + len].reverse(),
            OpSpec::Gain { factor, .. } => {
                if !factor.is_finite() {
                    return Err(format!("gain factor {factor} is not finite"));
                }
                for b in &mut buf[start..start + len] {
                    *b = (*b as f32 * factor).round().clamp(0.0, 255.0) as u8;
                }
            }
            OpSpec::Mask { .. } => buf[start..start + len].fill(0),
        }
        Ok(span)
    }
}

/// One rendered variant, with its canvas and the JSON that describes it.
pub struct VariantOut {
    pub name: String,
    pub canvas: Canvas,
    pub json: Value,
}

/// Everything a run produced.
pub struct Outcome {
    pub order: Order,
    pub layout: Layout,
    pub base: Canvas,
    pub variants: Vec<VariantOut>,
    pub regions: Vec<Value>,
    pub stream_bytes: usize,
    pub tokens: usize,
    pub fill: Fill,
}

impl Outcome {
    pub fn report(&self) -> Value {
        json!({
            "format": "loom-image/1",
            "order": self.order.get(),
            "side": self.order.side(),
            "layout": self.layout.name(),
            "fill": self.fill.name(),
            "stream": {
                "bytes": self.stream_bytes,
                "tokens": self.tokens,
                "canvas_bytes": self.base.data().len(),
                "repeats": round2(self.base.data().len() as f64 / self.stream_bytes.max(1) as f64),
            },
            "regions": self.regions,
            "variants": self.variants.iter().map(|v| v.json.clone()).collect::<Vec<_>>(),
        })
    }
}

/// Tokenizer input → byte stream → canvas → variants, with a report that proves
/// the ranges. `tokens` are the tokenizer's byte spans over `stream`.
pub fn run(plan: &Plan, stream: &[u8], tokens: &[Span]) -> Result<Outcome, String> {
    let order = Order::new(plan.order)?;
    let layout = Layout::parse(&plan.layout)?;
    let fill = match plan.fill.as_deref() {
        None => Fill::Repeat,
        Some(s) => Fill::parse(s)?,
    };
    if stream.is_empty() {
        return Err("the token stream is empty".to_string());
    }
    let filled = fill_canvas(stream, Canvas::capacity(order, layout), fill)?;
    let mut base = Canvas::new(order, layout);
    base.fill_from(&filled, Fill::Refuse)?;

    let mut regions = Vec::with_capacity(plan.regions.len());
    for r in &plan.regions {
        let bytes = token_bytes(tokens, r.tokens)?;
        let span = bytes.clipped(order);
        if span.is_empty() {
            return Err(format!("region `{}` covers no canvas byte", r.name));
        }
        let bounds = span.bounds(order);
        let enumerated = span.bounds_by_enumeration(order);
        regions.push(json!({
            "name": r.name,
            "tokens": { "start": r.tokens.start, "len": r.tokens.len },
            "bytes": { "start": span.start, "len": span.len },
            "bounds": bounds.map(bounds_json),
            "bounds_by_enumeration": enumerated.map(bounds_json),
            "agrees_with_enumeration": bounds == enumerated,
            "blocks": span.blocks(order).len(),
        }));
    }

    let mut variants = Vec::with_capacity(plan.variants.len());
    for v in &plan.variants {
        let mut buf = filled.clone();
        let mut declared = Vec::with_capacity(v.ops.len());
        let mut effective: Vec<Span> = Vec::with_capacity(v.ops.len());
        for op in &v.ops {
            let touched = op.apply(&mut buf)?;
            declared.push(op.span().clipped(order));
            if !touched.is_empty() {
                effective.push(touched);
            }
        }
        let changed: Vec<u64> = (0..buf.len() as u64)
            .filter(|&i| buf[i as usize] != filled[i as usize])
            .collect();
        let region = Region::from_spans(effective.iter().copied());
        let bpp = layout.bytes() as u64;
        let pixels: std::collections::BTreeSet<u64> = changed.iter().map(|i| i / bpp).collect();
        let changed_span = pixels
            .iter()
            .next()
            .zip(pixels.iter().next_back())
            .map(|(a, b)| Span::new(*a, b - a + 1));
        let changed_bounds = Bounds::from_points(pixels.iter().map(|&p| d2xy(order, p)));
        let contained = changed.iter().all(|&i| region.contains(i));
        let mut canvas = Canvas::new(order, layout);
        canvas.fill_from(&buf, Fill::Refuse)?;
        let psnr = base.psnr(&canvas);
        variants.push(VariantOut {
            name: v.name.clone(),
            canvas,
            json: json!({
                "name": v.name,
                "ops": v.ops.len(),
                "declared": declared.iter().map(|s| span_json(*s, order)).collect::<Vec<_>>(),
                "effective": effective.iter().map(|s| span_json(*s, order)).collect::<Vec<_>>(),
                "changed": {
                    "bytes": changed.len(),
                    "pixels": pixels.len(),
                    "span": changed_span.map(|s| span_json(s, order)),
                    "bounds": changed_bounds.map(bounds_json),
                },
                "contained": contained,
                "psnr_db": if psnr.is_finite() { json!(round2(psnr)) } else { json!("identical") },
            }),
        });
    }

    Ok(Outcome {
        order,
        layout,
        base,
        variants,
        regions,
        stream_bytes: stream.len(),
        tokens: tokens.len(),
        fill,
    })
}

/// The token bytes as the canvas holds them. Variations act on this, so their
/// spans are image offsets and their bounds are the pixels they moved.
fn fill_canvas(stream: &[u8], cap: usize, fill: Fill) -> Result<Vec<u8>, String> {
    if stream.is_empty() {
        return Err("the token stream is empty".to_string());
    }
    let mut out = Vec::with_capacity(cap);
    match fill {
        Fill::Repeat => {
            for i in 0..cap {
                out.push(stream[i % stream.len()]);
            }
        }
        Fill::Pad => {
            out.extend_from_slice(stream);
            out.resize(cap, 0);
        }
        Fill::Refuse => {
            if stream.len() < cap {
                return Err(format!(
                    "stream is {} bytes, canvas is {cap}: fill `refuse` will not pad",
                    stream.len()
                ));
            }
            out.extend_from_slice(&stream[..cap]);
        }
    }
    Ok(out)
}

/// The token range as one byte span: from the first token's start to the last's
/// end, which is exactly the bytes those tokens tile.
pub fn token_bytes(tokens: &[Span], range: TokenRange) -> Result<Span, String> {
    let start = range.start as usize;
    let end = start
        .checked_add(range.len as usize)
        .ok_or("token range overflows")?;
    if range.len == 0 || end > tokens.len() {
        return Err(format!(
            "token range {}..{} outside {} tokens",
            start,
            end,
            tokens.len()
        ));
    }
    let first = tokens[start];
    let last = tokens[end - 1];
    Ok(Span::new(first.start, last.end() - first.start))
}

fn span_json(span: Span, order: Order) -> Value {
    json!({
        "start": span.start,
        "len": span.len,
        "blocks": span.blocks(order).len(),
        "bounds": span.bounds(order).map(bounds_json),
    })
}

fn bounds_json(b: Bounds) -> Value {
    json!({
        "x0": b.x0,
        "y0": b.y0,
        "x1": b.x1,
        "y1": b.y1,
        "width": b.width(),
        "height": b.height(),
        "area": b.area(),
    })
}

fn round2(x: f64) -> f64 {
    (x * 100.0).round() / 100.0
}
