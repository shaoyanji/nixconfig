use loom_hilbert::{d2xy, grid, xy2d, Bounds, Order, Point, Region, Span};

fn orders() -> impl Iterator<Item = Order> {
    (1..=7u8).map(|n| Order::new(n).unwrap())
}

#[test]
fn round_trips_every_index() {
    for order in orders() {
        for d in 0..order.cells() {
            let p = d2xy(order, d);
            assert_eq!(xy2d(order, p), d, "order {order} index {d}");
        }
    }
}

#[test]
fn is_a_bijection_over_the_square() {
    let order = Order::new(5).unwrap();
    let mut seen = vec![false; order.cells() as usize];
    for d in 0..order.cells() {
        let p = d2xy(order, d);
        let at = (p.y as usize) * order.side() as usize + p.x as usize;
        assert!(!seen[at], "cell ({},{}) visited twice", p.x, p.y);
        seen[at] = true;
    }
    assert!(seen.into_iter().all(|s| s), "some cell never visited");
}

#[test]
fn consecutive_indices_are_neighbours() {
    for order in orders() {
        for d in 1..order.cells() {
            let a = d2xy(order, d - 1);
            let b = d2xy(order, d);
            assert_eq!(a.chebyshev(b), 1, "order {order} between {d} and {}", d - 1);
        }
    }
}

#[test]
fn aligned_blocks_are_filled_squares() {
    for order in orders() {
        for level in 0..=order.get() {
            let size = 1u64 << (2 * level as u32);
            for m in 0..(order.cells() / size) {
                let block = loom_hilbert::Block { level, d0: m * size };
                let square = block.bounds(order);
                assert_eq!(square.width(), block.side(), "block side at level {level}");
                for d in block.d0..block.d0 + size {
                    assert!(square.contains(d2xy(order, d)), "index {d} left its square");
                }
                assert_eq!(square.area(), size, "a square holds exactly its block");
            }
        }
    }
}

#[test]
fn bounds_match_enumeration() {
    let mut seed = 0x2545_f491_4f6c_dd1du64;
    let mut next = |m: u64| {
        seed = seed.wrapping_mul(6364136223846793005).wrapping_add(1442695040888963407);
        (seed >> 17) % m
    };
    for order in [Order::new(6).unwrap(), Order::new(8).unwrap()] {
        for _ in 0..200 {
            let len = 1 + next(order.cells());
            let start = next(order.cells() - len + 1);
            let span = Span::new(start, len);
            assert_eq!(span.bounds(order), span.bounds_by_enumeration(order), "span {span:?}");
        }
    }
}

#[test]
fn blocks_tile_the_span_exactly() {
    for order in orders() {
        let span = Span::new(order.cells() / 3, (order.cells() / 5).max(1));
        let blocks = span.blocks(order);
        assert_eq!(blocks.iter().map(|b| b.size()).sum::<u64>(), span.len);
        assert_eq!(blocks.first().unwrap().d0, span.start);
        assert_eq!(blocks.last().unwrap().d0 + blocks.last().unwrap().size(), span.end());
        assert!(blocks.windows(2).all(|w| w[0].d0 + w[0].size() == w[1].d0));
    }
}

#[test]
fn a_whole_curve_is_one_square() {
    for order in orders() {
        let b = Span::new(0, order.cells()).bounds(order).unwrap();
        assert_eq!(b, Bounds::new(0, 0, order.side() - 1, order.side() - 1).unwrap());
    }
}

#[test]
fn clamp_and_region_normalisation() {
    let order = Order::new(3).unwrap();
    assert_eq!(Span::new(60, 100).clipped(order), Span::new(60, 4));
    assert!(Span::new(64, 8).clipped(order).is_empty());

    let region = Region::from_spans([
        Span::new(10, 4),
        Span::new(0, 4),
        Span::new(4, 2),
        Span::new(40, 0),
    ]);
    assert_eq!(region.spans(), &[Span::new(0, 6), Span::new(10, 4)]);
    assert_eq!(region.count(), 10);
    assert!(region.covers(Span::new(2, 4)));
    assert!(!region.covers(Span::new(2, 6)));
    assert!(region.contains(12));
    assert!(!region.contains(9));
}

#[test]
fn grid_skips_the_padding() {
    let cells = grid(6, 3);
    assert_eq!(cells.len(), 18);
    assert!(cells.iter().all(|p| p.x < 6 && p.y < 3));
    let unique: std::collections::HashSet<Point> = cells.iter().copied().collect();
    assert_eq!(unique.len(), 18);
}
