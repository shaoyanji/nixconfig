//! Hilbert index arithmetic, and the typed span algebra the image bridge reasons with.
//!
//! A curve of order `n` visits every cell of a `2^n × 2^n` square exactly once, so
//! a one-dimensional byte stream has a canonical two-dimensional reading: byte `d`
//! is the pixel `d2xy(order, d)`. The convention is the one `shaoyanji/hilbert`
//! ships in `lib/hilbert.js` — `test/loom-parity.js` in that repo compares this
//! implementation against it, cell for cell, rather than trusting the comment.
//!
//! Three properties the rest of the crate builds on, each held by test:
//!
//! - a run of `4^k` indices aligned to `4^k` is exactly one square of side `2^k`,
//!   so a span's bounding box is a union of `O(n)` known squares, not a scan;
//! - consecutive indices are neighbours (Chebyshev distance 1);
//! - the map is a bijection, so "which pixels does this byte range touch" has one
//!   answer and no approximations.
//!
//! Nothing here allocates per point and nothing depends on a crate.

use std::fmt;

/// Curve order: a `2^order` square. Bounded so a canvas stays addressable.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord)]
pub struct Order(u8);

impl Order {
    pub const MAX: u8 = 12;

    pub fn new(n: u8) -> Result<Order, String> {
        if n == 0 || n > Self::MAX {
            return Err(format!("order {n} outside 1..={}", Self::MAX));
        }
        Ok(Order(n))
    }

    pub fn get(self) -> u8 {
        self.0
    }

    /// Cells on one edge, `2^n`.
    pub fn side(self) -> u32 {
        1u32 << self.0
    }

    /// Cells in the square, `4^n`.
    pub fn cells(self) -> u64 {
        1u64 << (2 * self.0 as u32)
    }

    /// Highest valid index.
    pub fn last(self) -> u64 {
        self.cells() - 1
    }
}

impl fmt::Display for Order {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{} ({}×{})", self.0, self.side(), self.side())
    }
}

/// A cell in the square.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub struct Point {
    pub x: u32,
    pub y: u32,
}

impl Point {
    pub fn new(x: u32, y: u32) -> Point {
        Point { x, y }
    }

    /// Position along the curve.
    pub fn index(self, order: Order) -> u64 {
        xy2d(order, self)
    }

    /// Grid distance, which is what "neighbouring along the curve" means here.
    pub fn chebyshev(self, other: Point) -> u32 {
        self.x.abs_diff(other.x).max(self.y.abs_diff(other.y))
    }
}

/// Inclusive rectangle.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Bounds {
    pub x0: u32,
    pub y0: u32,
    pub x1: u32,
    pub y1: u32,
}

impl Bounds {
    pub fn new(x0: u32, y0: u32, x1: u32, y1: u32) -> Result<Bounds, String> {
        if x0 > x1 || y0 > y1 {
            return Err(format!("inverted bounds ({x0},{y0})-({x1},{y1})"));
        }
        Ok(Bounds { x0, y0, x1, y1 })
    }

    pub fn single(p: Point) -> Bounds {
        Bounds { x0: p.x, y0: p.y, x1: p.x, y1: p.y }
    }

    pub fn from_points(points: impl IntoIterator<Item = Point>) -> Option<Bounds> {
        let mut acc: Option<Bounds> = None;
        for p in points {
            acc = Some(match acc {
                Some(b) => b.union(Bounds::single(p)),
                None => Bounds::single(p),
            });
        }
        acc
    }

    pub fn width(&self) -> u32 {
        self.x1 - self.x0 + 1
    }

    pub fn height(&self) -> u32 {
        self.y1 - self.y0 + 1
    }

    pub fn area(&self) -> u64 {
        self.width() as u64 * self.height() as u64
    }

    pub fn contains(&self, p: Point) -> bool {
        p.x >= self.x0 && p.x <= self.x1 && p.y >= self.y0 && p.y <= self.y1
    }

    pub fn union(self, other: Bounds) -> Bounds {
        Bounds {
            x0: self.x0.min(other.x0),
            y0: self.y0.min(other.y0),
            x1: self.x1.max(other.x1),
            y1: self.y1.max(other.y1),
        }
    }

    pub fn overlaps(&self, other: &Bounds) -> bool {
        self.x0 <= other.x1 && other.x0 <= self.x1 && self.y0 <= other.y1 && other.y0 <= self.y1
    }
}

/// Half-open index run `[start, start + len)`.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord)]
pub struct Span {
    pub start: u64,
    pub len: u64,
}

impl Span {
    pub fn new(start: u64, len: u64) -> Span {
        Span { start, len }
    }

    pub fn point(start: u64) -> Span {
        Span { start, len: 1 }
    }

    pub fn end(&self) -> u64 {
        self.start + self.len
    }

    pub fn is_empty(&self) -> bool {
        self.len == 0
    }

    pub fn contains(&self, i: u64) -> bool {
        i >= self.start && i < self.end()
    }

    pub fn overlaps(&self, other: &Span) -> bool {
        self.start < other.end() && other.start < self.end()
    }

    /// This span and `other` as one span, when they touch.
    pub fn merge(self, other: Span) -> Option<Span> {
        let (a, b) = if self.start <= other.start { (self, other) } else { (other, self) };
        if b.start <= a.end() {
            Some(Span { start: a.start, len: a.end().max(b.end()) - a.start })
        } else {
            None
        }
    }

    /// Clip to the curve's index range. Named this way because `Ord::clamp`
    /// already means something else and would win the call.
    pub fn clipped(self, order: Order) -> Span {
        let cells = order.cells();
        let start = self.start.min(cells);
        let len = self.len.min(cells - start);
        Span { start, len }
    }

    pub fn points(&self) -> impl Iterator<Item = u64> {
        self.start..self.end()
    }

    /// The squares that tile this span. Every block is curve-aligned, so each one
    /// is a filled square of known origin and side.
    pub fn blocks(&self, order: Order) -> Vec<Block> {
        let s = self.clipped(order);
        let mut out = Vec::new();
        if s.is_empty() {
            return out;
        }
        let mut d = s.start;
        let end = s.end();
        for level in (0..=order.0).rev() {
            let size = 1u64 << (2 * level as u32);
            while d + size <= end && d % size == 0 {
                out.push(Block { level, d0: d });
                d += size;
            }
        }
        out
    }

    /// Exact bounding box, in `O(order)` work and no scan of the span.
    pub fn bounds(&self, order: Order) -> Option<Bounds> {
        self.blocks(order)
            .into_iter()
            .map(|b| b.bounds(order))
            .reduce(|a, b| a.union(b))
    }

    /// The oracle `bounds` is tested against: ask every point and take the hull.
    pub fn bounds_by_enumeration(&self, order: Order) -> Option<Bounds> {
        let s = self.clipped(order);
        Bounds::from_points(s.points().map(|d| d2xy(order, d)))
    }
}

/// One curve-aligned square: `4^level` consecutive indices starting at `d0`.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Block {
    pub level: u8,
    pub d0: u64,
}

impl Block {
    pub fn size(&self) -> u64 {
        1u64 << (2 * self.level as u32)
    }

    pub fn side(&self) -> u32 {
        1u32 << self.level
    }

    /// The square this block fills. The high base-4 digits of the index pick the
    /// square; the low ones only walk inside it, which is why this is a scale of
    /// the lower-order curve rather than a lookup.
    pub fn bounds(&self, order: Order) -> Bounds {
        assert!(self.level <= order.0, "block level above the curve");
        let s = self.side() - 1;
        if self.level == order.0 {
            return Bounds { x0: 0, y0: 0, x1: s, y1: s };
        }
        let outer = Order::new(order.0 - self.level).expect("below the curve's order");
        let origin = d2xy(outer, self.d0 >> (2 * self.level as u32));
        Bounds {
            x0: origin.x << self.level,
            y0: origin.y << self.level,
            x1: (origin.x << self.level) + s,
            y1: (origin.y << self.level) + s,
        }
    }
}

/// A set of indices, kept sorted and disjoint, with its own bounds.
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct Region {
    spans: Vec<Span>,
}

impl Region {
    pub fn from_spans(spans: impl IntoIterator<Item = Span>) -> Region {
        let mut sorted: Vec<Span> = spans.into_iter().filter(|s| !s.is_empty()).collect();
        sorted.sort_by_key(|s| (s.start, s.end()));
        let mut merged: Vec<Span> = Vec::with_capacity(sorted.len());
        for s in sorted {
            match merged.last().copied().and_then(|last| last.merge(s)) {
                Some(joined) => {
                    let last = merged.len() - 1;
                    merged[last] = joined;
                }
                None => merged.push(s),
            }
        }
        Region { spans: merged }
    }

    pub fn spans(&self) -> &[Span] {
        &self.spans
    }

    pub fn is_empty(&self) -> bool {
        self.spans.is_empty()
    }

    /// How many indices the region holds.
    pub fn count(&self) -> u64 {
        self.spans.iter().map(|s| s.len).sum()
    }

    pub fn contains(&self, i: u64) -> bool {
        self.spans.iter().any(|s| s.contains(i))
    }

    /// Every index of `span` is in the region.
    pub fn covers(&self, span: Span) -> bool {
        if span.is_empty() {
            return true;
        }
        self.spans
            .iter()
            .any(|s| s.start <= span.start && s.end() >= span.end())
    }

    pub fn bounds(&self, order: Order) -> Option<Bounds> {
        self.spans
            .iter()
            .filter_map(|s| s.bounds(order))
            .reduce(|a, b| a.union(b))
    }
}

/// Index → cell, the traversal itself.
pub fn d2xy(order: Order, d: u64) -> Point {
    assert!(d < order.cells(), "index {d} outside curve {order}");
    let mut t = d;
    let mut x = 0i64;
    let mut y = 0i64;
    let side = order.side() as i64;
    let mut s = 1i64;
    while s < side {
        let rx = ((t >> 1) & 1) as i64;
        let ry = ((t ^ rx as u64) & 1) as i64;
        if ry == 0 {
            if rx == 1 {
                x = s - 1 - x;
                y = s - 1 - y;
            }
            std::mem::swap(&mut x, &mut y);
        }
        x += s * rx;
        y += s * ry;
        t >>= 2;
        s *= 2;
    }
    Point { x: x as u32, y: y as u32 }
}

/// Cell → index, the same traversal backwards.
pub fn xy2d(order: Order, p: Point) -> u64 {
    let side = order.side();
    assert!(p.x < side && p.y < side, "({},{}) outside curve {order}", p.x, p.y);
    let mut x = p.x as i64;
    let mut y = p.y as i64;
    let mut d = 0u64;
    let mut s = side as i64 / 2;
    while s > 0 {
        let rx = ((x & s) != 0) as i64;
        let ry = ((y & s) != 0) as i64;
        d += (s * s) as u64 * (((3 * rx) ^ ry) as u64);
        if ry == 0 {
            if rx == 1 {
                x = s - 1 - x;
                y = s - 1 - y;
            }
            std::mem::swap(&mut x, &mut y);
        }
        s /= 2;
    }
    d
}

/// Chebyshev walk over a grid of `nx × ny`, padding to a power of two and
/// skipping the padding — the same `hilbertGrid` the JS encoder orders tiles by.
pub fn grid(nx: u32, ny: u32) -> Vec<Point> {
    let side = nx.max(ny).max(1).next_power_of_two();
    let order = Order::new(side.trailing_zeros() as u8).unwrap_or_else(|_| Order(1));
    let mut out = Vec::with_capacity((nx as usize) * (ny as usize));
    for d in 0..order.cells() {
        let p = d2xy(order, d);
        if p.x < nx && p.y < ny {
            out.push(p);
        }
    }
    out
}
