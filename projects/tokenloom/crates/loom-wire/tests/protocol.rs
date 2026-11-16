//! Every frame type encodes and decodes losslessly, fuzzed.

use loom_core::{NewToken, Op};
use loom_wire::{decode_op, decode_server, encode, encode_op_frame, ServerFrame};
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
            any::<u32>()
        )
            .prop_map(|(p50_us, p99_us, retok_per_edit, ripple_truncations, starved, window)| {
                ServerFrame::Metrics {
                    p50_us,
                    p99_us,
                    retok_per_edit,
                    ripple_truncations,
                    starved,
                    window,
                }
            }),
    ]
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
