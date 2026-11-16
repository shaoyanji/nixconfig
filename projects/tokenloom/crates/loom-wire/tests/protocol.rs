//! Every frame type encodes and decodes losslessly, fuzzed.

use loom_core::{NewToken, Op};
use loom_wire::{
    decode_op, decode_server, decode_server_at, encode, encode_op_frame, ConstraintView,
    ServerFrame,
};
use proptest::prelude::*;

fn text() -> impl Strategy<Value = Vec<u8>> {
    prop::collection::vec(any::<u8>(), 0..24)
}

fn token() -> impl Strategy<Value = NewToken> {
    (any::<u8>(), prop::collection::vec(any::<u8>(), 0..12))
        .prop_map(|(flags, text)| NewToken { flags, tag: 0, text })
}

fn tokens() -> impl Strategy<Value = Vec<NewToken>> {
    prop::collection::vec(token(), 0..6)
}

fn constraint_view() -> impl Strategy<Value = ConstraintView> {
    (any::<u32>(), any::<u32>(), any::<u32>(), any::<u16>(), any::<u8>(), any::<u32>())
        .prop_map(|(id, anchor, token, len, kind, param)| ConstraintView {
            id,
            anchor,
            token,
            len,
            kind,
            param,
        })
}

fn op() -> impl Strategy<Value = Op> {
    prop_oneof![
        (any::<u64>(), any::<u32>(), tokens())
            .prop_map(|(seq, offset, tokens)| Op::Insert { seq, offset, tokens }),
        (any::<u64>(), any::<u32>(), any::<u16>())
            .prop_map(|(seq, offset, count)| Op::Delete { seq, offset, count }),
        (any::<u64>(), any::<u32>(), any::<u16>())
            .prop_map(|(seq, offset, count)| Op::Merge { seq, offset, count }),
        (any::<u64>(), any::<u32>(), any::<u16>())
            .prop_map(|(seq, offset, byte_off)| Op::Split { seq, offset, byte_off }),
        (any::<u64>(), any::<u32>(), any::<u16>(), any::<u16>(), text()).prop_map(
            |(seq, offset, count, tag, bytes)| Op::Annotate { seq, offset, count, tag, bytes }
        ),
        (any::<u64>(), any::<u32>(), any::<u16>(), any::<u8>(), any::<u32>()).prop_map(
            |(seq, start, len, kind, param)| Op::ConstraintAdd { seq, start, len, kind, param }
        ),
        (any::<u64>(), any::<u32>())
            .prop_map(|(seq, id)| Op::ConstraintRemove { seq, id }),
        (any::<u64>(), any::<u32>(), any::<u8>(), any::<u32>())
            .prop_map(|(seq, id, kind, param)| Op::ConstraintUpdate { seq, id, kind, param }),
        (any::<u64>(), any::<u8>(), any::<bool>())
            .prop_map(|(seq, reactor, enabled)| Op::ReactorToggle { seq, reactor, enabled }),
        any::<u64>().prop_map(|seq| Op::Resync { seq }),
    ]
}

fn server_frame() -> impl Strategy<Value = ServerFrame> {
    prop_oneof![
        (any::<u64>(), any::<u64>()).prop_map(|(seq, revision)| ServerFrame::Ack { seq, revision }),
        (any::<u64>(), any::<u32>(), any::<u16>(), tokens())
            .prop_map(|(revision, start, deleted, inserted)| ServerFrame::Diff {
                revision,
                start,
                deleted,
                inserted
            }),
        (
            any::<u32>(),
            any::<u8>(),
            any::<u8>(),
            any::<u8>(),
            any::<u32>(),
            any::<u16>(),
            any::<u64>(),
            "[a-z ]{0,20}"
        )
            .prop_map(|(id, kind, reactor, severity, start, len, revision, message)| {
                ServerFrame::WarningRaise { id, kind, reactor, severity, start, len, revision, message }
            }),
        (any::<u32>(), any::<u64>())
            .prop_map(|(id, revision)| ServerFrame::WarningClear { id, revision }),
        (any::<u64>(), any::<u8>(), tokens())
            .prop_map(|(revision, reactors, tokens)| ServerFrame::Snapshot {
                revision,
                reactors,
                tokens
            }),
        (
            any::<u32>(),
            any::<u32>(),
            any::<u32>(),
            any::<u32>(),
            any::<u32>(),
            any::<u32>(),
            any::<u8>(),
            any::<u32>()
        )
            .prop_map(
                |(
                    p50_us,
                    p99_us,
                    retok_per_edit,
                    ripple_truncations,
                    starved,
                    window,
                    reactors,
                    constraints,
                )| {
                    ServerFrame::Metrics {
                        p50_us,
                        p99_us,
                        retok_per_edit,
                        ripple_truncations,
                        starved,
                        window,
                        reactors,
                        constraints,
                    }
                },
            ),
        (any::<u64>(), prop::collection::vec(constraint_view(), 0..5))
            .prop_map(|(revision, items)| ServerFrame::Constraints { revision, items }),
    ]
}

/// A message may carry several frames. The server packs what it wrote in the
/// same instant into one write, so a client finds the next frame from the
/// length of the one before it — and the lengths have to cover the message
/// exactly, or a packed write would hand the client a half-read frame.
#[test]
fn concatenated_frames_walk_from_their_own_lengths() {
    let frames = vec![
        ServerFrame::Ack {
            seq: 7,
            revision: 3,
        },
        ServerFrame::Diff {
            revision: 3,
            start: 1,
            deleted: 0,
            inserted: vec![NewToken {
                flags: 1,
                tag: 0,
                text: b"z".to_vec(),
            }],
        },
        ServerFrame::WarningRaise {
            id: 2,
            kind: 1,
            reactor: 3,
            severity: 2,
            start: 0,
            len: 1,
            revision: 3,
            message: "max tokens".to_string(),
        },
        ServerFrame::Constraints {
            revision: 3,
            items: vec![ConstraintView {
                id: 0,
                anchor: 0,
                token: 1,
                len: 2,
                kind: 1,
                param: 4,
            }],
        },
        ServerFrame::Metrics {
            p50_us: 120,
            p99_us: 900,
            retok_per_edit: 15,
            ripple_truncations: 0,
            starved: 0,
            window: 4,
            reactors: 0xff,
            constraints: 1,
        },
        ServerFrame::Snapshot {
            revision: 3,
            reactors: 0x3f,
            tokens: vec![NewToken {
                flags: 1,
                tag: 0,
                text: b"alpha".to_vec(),
            }],
        },
        ServerFrame::WarningClear { id: 2, revision: 3 },
    ];
    let mut message = Vec::new();
    for frame in &frames {
        message.extend_from_slice(&encode(frame).expect("an encodable frame"));
    }

    let mut at = 0;
    let mut back = Vec::new();
    while at < message.len() {
        let (frame, used) = decode_server_at(&message[at..]).expect("a frame at this offset");
        back.push(frame);
        at += used;
    }
    assert_eq!(at, message.len(), "the frames cover the message exactly");
    assert_eq!(back, frames, "and every frame came back as it was written");
}

proptest! {
    #![proptest_config(ProptestConfig { cases: 512, ..ProptestConfig::default() })]

    #[test]
    fn protocol_roundtrip_client(op in op()) {
        let bytes = encode_op_frame(&op).unwrap();
        let back = decode_op(&bytes).unwrap();
        prop_assert_eq!(op, back);
    }

    #[test]
    fn protocol_roundtrip_server(frame in server_frame()) {
        let bytes = encode(&frame).unwrap();
        let back = decode_server(&bytes).unwrap();
        prop_assert_eq!(frame, back);
    }

    /// A frame never decodes from a truncated prefix: the reader must refuse
    /// rather than invent a value.
    #[test]
    fn truncated_frames_are_refused(op in op(), cut in 0usize..40) {
        let bytes = encode_op_frame(&op).unwrap();
        if cut < bytes.len() {
            prop_assert!(decode_op(&bytes[..cut]).is_err());
        }
    }
}
