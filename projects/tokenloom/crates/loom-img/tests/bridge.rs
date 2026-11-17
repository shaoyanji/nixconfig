use loom_hilbert::{Order, Span};
use loom_img::plan::{run, ByteSpan, NamedRegion, OpSpec, Plan, Source, TokenRange, Variant};
use loom_img::{Canvas, Fill, Layout};

fn order(n: u8) -> Order {
    Order::new(n).unwrap()
}

fn stream() -> Vec<u8> {
    (0..4096u32).map(|i| (i * 7 % 251) as u8).collect()
}

fn tokens() -> Vec<Span> {
    (0..64u64).map(|i| Span::new(i * 4, 4)).collect()
}

#[test]
fn raster_round_trips() {
    for layout in [Layout::Gray8, Layout::Rgb8, Layout::Rgba8] {
        let mut c = Canvas::new(order(4), layout);
        c.fill_from(&stream(), Fill::Repeat).unwrap();
        let raster = c.raster();
        assert_eq!(raster.len(), 256 * layout.bytes());
        let back = Canvas::from_raster(order(4), layout, &raster).unwrap();
        assert_eq!(back, c);
    }
}

#[test]
fn the_first_pixel_is_the_first_byte() {
    let mut c = Canvas::new(order(3), Layout::Rgb8);
    c.fill_from(&[1, 2, 3, 4, 5, 6], Fill::Repeat).unwrap();
    assert_eq!(c.data()[..3], [1, 2, 3]);
    assert_eq!(c.point_of(0), loom_hilbert::Point::new(0, 0));
    assert_eq!(c.bytes_of(0), Span::new(0, 3));
}

#[test]
fn fill_policies_say_what_they_do() {
    let cap = Canvas::capacity(order(2), Layout::Rgb8);
    let short = vec![9u8; 5];
    let mut pad = Canvas::new(order(2), Layout::Rgb8);
    pad.fill_from(&short, Fill::Pad).unwrap();
    assert_eq!(&pad.data()[..5], &short[..]);
    assert!(pad.data()[5..].iter().all(|b| *b == 0));

    let mut repeat = Canvas::new(order(2), Layout::Rgb8);
    repeat.fill_from(&short, Fill::Repeat).unwrap();
    assert_eq!(repeat.data()[5], 9);

    let mut refuse = Canvas::new(order(2), Layout::Rgb8);
    assert!(refuse.fill_from(&short, Fill::Refuse).is_err());
    assert!(refuse.fill_from(&vec![1u8; cap + 1], Fill::Refuse).is_ok());
}

#[test]
fn himg_round_trips_and_catches_damage() {
    let mut c = Canvas::new(order(4), Layout::Rgb8);
    c.fill_from(&stream(), Fill::Repeat).unwrap();
    let bytes = c.himg();
    assert!(bytes.starts_with(b"LOOMHILB 1 order=4 layout=rgb8"));
    assert_eq!(Canvas::from_himg(&bytes).unwrap(), c);

    let mut damaged = bytes.clone();
    let at = damaged.len() - 1;
    damaged[at] ^= 0xff;
    assert!(Canvas::from_himg(&damaged).is_err());

    let truncated = &bytes[..bytes.len() - 1];
    assert!(Canvas::from_himg(truncated).is_err());
}

#[test]
fn the_text_form_round_trips() {
    let mut c = Canvas::new(order(3), Layout::Gray8);
    c.fill_from(&stream(), Fill::Repeat).unwrap();
    let text = c.hex_stream();
    assert!(text.starts_with("LOOMHILB 1 order=3 layout=gray8"));
    assert_eq!(Canvas::from_hex_stream(&text).unwrap(), c);
}

#[test]
fn ppm_carries_the_pixels_in_scan_order() {
    let mut c = Canvas::new(order(1), Layout::Rgb8);
    c.fill_from(&[10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 110, 120], Fill::Refuse)
        .unwrap();
    let ppm = c.ppm();
    let head = b"P6\n2 2\n255\n";
    assert_eq!(&ppm[..head.len()], head);
    assert_eq!(ppm.len(), head.len() + 12);
    // The pixel at curve index 0 is the top-left corner.
    assert_eq!(&ppm[head.len()..head.len() + 3], &[10, 20, 30]);
}

#[test]
fn a_plan_proves_its_variations_stayed_in_their_spans() {
    let plan = Plan {
        order: 6,
        layout: "rgb8".to_string(),
        fill: Some("repeat".to_string()),
        source: Source::Text { text: "ignored, the stream is passed in".to_string() },
        regions: vec![NamedRegion {
            name: "first".to_string(),
            tokens: TokenRange { start: 0, len: 8 },
        }],
        variants: vec![
            Variant {
                name: "roll".to_string(),
                ops: vec![OpSpec::Roll { span: ByteSpan { start: 0, len: 512 }, by: 61 }],
            },
            Variant {
                name: "two".to_string(),
                ops: vec![
                    OpSpec::Reverse { span: ByteSpan { start: 1024, len: 512 } },
                    OpSpec::Mask { span: ByteSpan { start: 2048, len: 256 } },
                ],
            },
        ],
    };
    let out = run(&plan, &stream(), &tokens()).unwrap();
    assert_eq!(out.order, order(6));
    assert_eq!(out.regions.len(), 1);
    assert_eq!(out.regions[0]["agrees_with_enumeration"], true);
    // Tokens 0..8 tile bytes 0..32.
    assert_eq!(out.regions[0]["bytes"]["start"], 0);
    assert_eq!(out.regions[0]["bytes"]["len"], 32);

    for variant in &out.variants {
        assert_eq!(variant.json["contained"], true, "{} escaped its spans", variant.name);
        assert_eq!(variant.canvas.order(), order(6));
        assert_ne!(variant.canvas, out.base);
    }
    assert_eq!(out.variants[0].json["changed"]["bytes"], 512);
}

#[test]
fn an_op_outside_the_stream_is_clipped_and_reported() {
    let plan = Plan {
        order: 6,
        layout: "gray8".to_string(),
        fill: None,
        source: Source::Text { text: String::new() },
        regions: vec![],
        variants: vec![Variant {
            name: "tail".to_string(),
            ops: vec![OpSpec::Mask { span: ByteSpan { start: 4000, len: 1000 } }],
        }],
    };
    let stream = stream();
    let out = run(&plan, &stream, &tokens()).unwrap();
    let effective = &out.variants[0].json["effective"][0];
    assert_eq!(effective["start"], 4000);
    assert_eq!(effective["len"], 96);
    let changed = out.variants[0].json["changed"]["bytes"].as_u64().unwrap();
    assert!(changed > 90 && changed <= 96, "changed {changed} of a clipped 96");
}

#[test]
fn a_token_range_outside_the_tokenizer_is_an_error() {
    let plan = Plan {
        order: 4,
        layout: "gray8".to_string(),
        fill: None,
        source: Source::Text { text: String::new() },
        regions: vec![NamedRegion {
            name: "past the end".to_string(),
            tokens: TokenRange { start: 60, len: 8 },
        }],
        variants: vec![],
    };
    assert!(run(&plan, &stream(), &tokens()).is_err());
}

#[test]
fn psnr_separates_identical_from_moved() {
    let mut a = Canvas::new(order(3), Layout::Gray8);
    a.fill_from(&stream(), Fill::Repeat).unwrap();
    let mut b = a.clone();
    assert_eq!(a.psnr(&b), f64::INFINITY);
    b.data_mut()[0] = b.data()[0].wrapping_add(64);
    let db = a.psnr(&b);
    assert!(db.is_finite() && db > 20.0 && db < 60.0, "psnr {db}");
    assert_eq!(a.diff_bounds(&b), Some(loom_hilbert::Bounds::single(loom_hilbert::Point::new(0, 0))));
}
