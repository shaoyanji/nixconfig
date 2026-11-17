//! Tokenizer bytes read as pixels, by position on a Hilbert curve.
//!
//! The mapping is a layout and nothing more: byte `d` of the stream is the pixel
//! `d2xy(order, d)`, so no codec, no model and no entropy stage sits between the
//! tokenizer's output and the image. Two consequences are the point of the whole
//! exercise:
//!
//! - a byte range is a *set of pixels with a bounding box* the curve picks out
//!   exactly (`loom_hilbert::Span::bounds`), so "where did the tokens I changed
//!   land" has a typed answer rather than a plausible one;
//! - consecutive bytes are neighbouring pixels, so the image a tokenizer produces
//!   is smooth where its text is repetitive — locality in the stream is locality
//!   on the canvas, which is what makes a variation legible rather than noise.
//!
//! Three containers, all of the same bytes: [`Canvas`] in Hilbert order,
//! [`Canvas::raster`] in scan order, [`Canvas::ppm`] as a file. `.himg` adds a
//! one-line typed header, and [`Canvas::hex_stream`] is the whole thing as text,
//! which is the form a tokenizer can actually emit.

pub mod plan;

use loom_hilbert::{d2xy, Bounds, Order, Span};
use std::fmt;

/// How the byte stream divides into pixels.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Layout {
    Gray8,
    Rgb8,
    Rgba8,
}

impl Layout {
    pub fn bytes(self) -> usize {
        match self {
            Layout::Gray8 => 1,
            Layout::Rgb8 => 3,
            Layout::Rgba8 => 4,
        }
    }

    pub fn name(self) -> &'static str {
        match self {
            Layout::Gray8 => "gray8",
            Layout::Rgb8 => "rgb8",
            Layout::Rgba8 => "rgba8",
        }
    }

    pub fn parse(s: &str) -> Result<Layout, String> {
        match s {
            "gray8" | "grey8" => Ok(Layout::Gray8),
            "rgb8" => Ok(Layout::Rgb8),
            "rgba8" => Ok(Layout::Rgba8),
            other => Err(format!("layout `{other}` is not gray8, rgb8 or rgba8")),
        }
    }
}

impl fmt::Display for Layout {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(self.name())
    }
}

/// What to do when the stream is shorter than the canvas.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Fill {
    /// Cycle the stream. Honest for short text: the report says how many times.
    Repeat,
    /// Zero the remainder.
    Pad,
    /// Refuse the render.
    Refuse,
}

impl Fill {
    pub fn parse(s: &str) -> Result<Fill, String> {
        match s {
            "repeat" => Ok(Fill::Repeat),
            "pad" => Ok(Fill::Pad),
            "refuse" => Ok(Fill::Refuse),
            other => Err(format!("fill `{other}` is not repeat, pad or refuse")),
        }
    }

    pub fn name(self) -> &'static str {
        match self {
            Fill::Repeat => "repeat",
            Fill::Pad => "pad",
            Fill::Refuse => "refuse",
        }
    }
}

pub const MAGIC: &str = "LOOMHILB";
pub const VERSION: u32 = 1;

/// Pixels in curve order.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Canvas {
    order: Order,
    layout: Layout,
    data: Vec<u8>,
}

impl Canvas {
    pub fn new(order: Order, layout: Layout) -> Canvas {
        Canvas { order, layout, data: vec![0u8; Self::capacity(order, layout)] }
    }

    pub fn capacity(order: Order, layout: Layout) -> usize {
        order.cells() as usize * layout.bytes()
    }

    pub fn order(&self) -> Order {
        self.order
    }

    pub fn layout(&self) -> Layout {
        self.layout
    }

    pub fn side(&self) -> u32 {
        self.order.side()
    }

    pub fn data(&self) -> &[u8] {
        &self.data
    }

    pub fn data_mut(&mut self) -> &mut [u8] {
        &mut self.data
    }

    /// Read `bytes` into the canvas. Returns the number of bytes copied, which is
    /// the full capacity for every policy but a refusing one.
    pub fn fill_from(&mut self, bytes: &[u8], fill: Fill) -> Result<usize, String> {
        let cap = self.data.len();
        match fill {
            Fill::Refuse => {
                if bytes.len() < cap {
                    return Err(format!(
                        "stream is {} bytes, canvas is {cap}: fill `refuse` will not pad",
                        bytes.len()
                    ));
                }
                self.data.copy_from_slice(&bytes[..cap]);
            }
            Fill::Pad => {
                let n = bytes.len().min(cap);
                self.data[..n].copy_from_slice(&bytes[..n]);
                self.data[n..].fill(0);
            }
            Fill::Repeat => {
                if bytes.is_empty() {
                    return Err("cannot fill a canvas from an empty stream".to_string());
                }
                for (i, slot) in self.data.iter_mut().enumerate() {
                    *slot = bytes[i % bytes.len()];
                }
            }
        }
        Ok(cap)
    }

    /// The pixel a stream offset lands on.
    pub fn point_of(&self, d: u64) -> loom_hilbert::Point {
        d2xy(self.order, d.min(self.order.last()))
    }

    /// The bytes a pixel covers, in curve space.
    pub fn bytes_of(&self, d: u64) -> Span {
        let bpp = self.layout.bytes() as u64;
        Span::new(d * bpp, bpp)
    }

    /// Scan order, top-to-bottom, left-to-right, ready for an encoder that wants
    /// rows.
    pub fn raster(&self) -> Vec<u8> {
        let side = self.side() as usize;
        let bpp = self.layout.bytes();
        let mut out = vec![0u8; self.data.len()];
        for (d, chunk) in self.data.chunks_exact(bpp).enumerate() {
            let p = d2xy(self.order, d as u64);
            let at = (p.y as usize * side + p.x as usize) * bpp;
            out[at..at + bpp].copy_from_slice(chunk);
        }
        out
    }

    /// The inverse of [`Canvas::raster`], which is what the round-trip test holds.
    pub fn from_raster(order: Order, layout: Layout, raster: &[u8]) -> Result<Canvas, String> {
        let mut canvas = Canvas::new(order, layout);
        if raster.len() != canvas.data.len() {
            return Err(format!(
                "raster is {} bytes, expected {}",
                raster.len(),
                canvas.data.len()
            ));
        }
        let side = order.side() as usize;
        let bpp = layout.bytes();
        for d in 0..order.cells() as usize {
            let p = d2xy(order, d as u64);
            let at = (p.y as usize * side + p.x as usize) * bpp;
            canvas.data[d * bpp..d * bpp + bpp].copy_from_slice(&raster[at..at + bpp]);
        }
        Ok(canvas)
    }

    /// A P6 (binary RGB) PPM. Gray is replicated across the channels and alpha is
    /// dropped: stated rather than silently done.
    pub fn ppm(&self) -> Vec<u8> {
        let side = self.side();
        let bpp = self.layout.bytes();
        let raster = self.raster();
        let mut out =
            format!("P6\n{side} {side}\n255\n").into_bytes();
        out.reserve(raster.len() / bpp * 3);
        for px in raster.chunks_exact(bpp) {
            match self.layout {
                Layout::Gray8 => out.extend_from_slice(&[px[0], px[0], px[0]]),
                Layout::Rgb8 => out.extend_from_slice(px),
                Layout::Rgba8 => out.extend_from_slice(&px[..3]),
            }
        }
        out
    }

    /// The binary container: a typed header line, then the bytes.
    pub fn himg(&self) -> Vec<u8> {
        let mut out = self.header().into_bytes();
        out.extend_from_slice(&self.data);
        out
    }

    pub fn header(&self) -> String {
        format!(
            "{MAGIC} {VERSION} order={} layout={} len={} fnv={:08x}\n",
            self.order.get(),
            self.layout.name(),
            self.data.len(),
            fnv1a(&self.data)
        )
    }

    pub fn from_himg(bytes: &[u8]) -> Result<Canvas, String> {
        let split = bytes
            .iter()
            .position(|b| *b == b'\n')
            .ok_or("himg has no header line")?;
        let header = std::str::from_utf8(&bytes[..split]).map_err(|e| e.to_string())?;
        let (order, layout, len, fnv) = parse_header(header)?;
        let data = &bytes[split + 1..];
        if data.len() != len {
            return Err(format!("himg says {len} bytes, carries {}", data.len()));
        }
        if fnv1a(data) != fnv {
            return Err("himg checksum does not match its bytes".to_string());
        }
        let mut canvas = Canvas::new(order, layout);
        canvas.data.copy_from_slice(data);
        Ok(canvas)
    }

    /// The whole canvas as text: header, then hex, 32 bytes to a line. This is the
    /// form that goes through a tokenizer without a binary channel.
    pub fn hex_stream(&self) -> String {
        let mut out = self.header();
        for chunk in self.data.chunks(32) {
            for b in chunk {
                out.push_str(&format!("{b:02x}"));
            }
            out.push('\n');
        }
        out
    }

    pub fn from_hex_stream(text: &str) -> Result<Canvas, String> {
        let mut lines = text.lines();
        let header = lines.next().ok_or("hex stream is empty")?;
        let (order, layout, len, fnv) = parse_header(header)?;
        let mut data = Vec::with_capacity(len);
        for (i, line) in lines.enumerate() {
            let line = line.trim();
            if line.is_empty() {
                continue;
            }
            if line.len() % 2 != 0 {
                return Err(format!("line {} has an odd number of hex digits", i + 2));
            }
            for pair in line.as_bytes().chunks(2) {
                let pair = std::str::from_utf8(pair).map_err(|e| e.to_string())?;
                data.push(u8::from_str_radix(pair, 16).map_err(|e| e.to_string())?);
            }
        }
        if data.len() != len {
            return Err(format!("hex stream says {len} bytes, carries {}", data.len()));
        }
        if fnv1a(&data) != fnv {
            return Err("hex stream checksum does not match its bytes".to_string());
        }
        let mut canvas = Canvas::new(order, layout);
        canvas.data.copy_from_slice(&data);
        Ok(canvas)
    }

    /// Peak signal-to-noise against another canvas: how far a variation moved the
    /// picture, on the same scale image work uses everywhere else.
    pub fn psnr(&self, other: &Canvas) -> f64 {
        assert_eq!(self.data.len(), other.data.len(), "psnr needs one canvas size");
        let mse: f64 = self
            .data
            .iter()
            .zip(other.data.iter())
            .map(|(a, b)| {
                let d = *a as f64 - *b as f64;
                d * d
            })
            .sum::<f64>()
            / self.data.len() as f64;
        if mse == 0.0 {
            f64::INFINITY
        } else {
            10.0 * (255.0f64 * 255.0 / mse).log10()
        }
    }

    /// Pixels where two canvases differ, as a typed hull.
    pub fn diff_bounds(&self, other: &Canvas) -> Option<Bounds> {
        let bpp = self.layout.bytes();
        Bounds::from_points(
            self.data
                .chunks_exact(bpp)
                .zip(other.data.chunks_exact(bpp))
                .enumerate()
                .filter(|(_, (a, b))| a != b)
                .map(|(d, _)| d2xy(self.order, d as u64)),
        )
    }
}

fn parse_header(header: &str) -> Result<(Order, Layout, usize, u32), String> {
    let mut it = header.split_whitespace();
    let magic = it.next().ok_or("empty header")?;
    if magic != MAGIC {
        return Err(format!("not a {MAGIC} stream: `{magic}`"));
    }
    let version: u32 = it
        .next()
        .ok_or("header has no version")?
        .parse()
        .map_err(|e: std::num::ParseIntError| e.to_string())?;
    if version != VERSION {
        return Err(format!("himg version {version}, this build reads {VERSION}"));
    }
    let mut order = None;
    let mut layout = None;
    let mut len = None;
    let mut fnv = None;
    for field in it {
        let (k, v) = field.split_once('=').ok_or_else(|| format!("field `{field}` is not k=v"))?;
        match k {
            "order" => order = Some(Order::new(v.parse().map_err(|e: std::num::ParseIntError| e.to_string())?)?),
            "layout" => layout = Some(Layout::parse(v)?),
            "len" => len = Some(v.parse().map_err(|e: std::num::ParseIntError| e.to_string())?),
            "fnv" => fnv = Some(u32::from_str_radix(v, 16).map_err(|e| e.to_string())?),
            other => return Err(format!("header field `{other}` is not one this build knows")),
        }
    }
    let order = order.ok_or("header has no order")?;
    let layout = layout.ok_or("header has no layout")?;
    let len: usize = len.ok_or("header has no len")?;
    let fnv = fnv.ok_or("header has no checksum")?;
    if len != Canvas::capacity(order, layout) {
        return Err(format!(
            "header says {len} bytes, order {order} and {layout} need {}",
            Canvas::capacity(order, layout)
        ));
    }
    Ok((order, layout, len, fnv))
}

/// FNV-1a, the cheap check that a truncated stream did not pass for a canvas.
pub fn fnv1a(bytes: &[u8]) -> u32 {
    let mut h = 0x811c_9dc5u32;
    for b in bytes {
        h ^= *b as u32;
        h = h.wrapping_mul(0x0100_0193);
    }
    h
}
