//! A constraint is anchored at a byte offset, and the text decides where that
//! is — not a token index, which slides onto a neighbour the moment anything is
//! inserted before it.

use loom_core::{NewToken, Op, FLAG_WORD};
use loom_react::ConstraintKind;
use loom_srv::session::Session;

fn insert(seq: u64, offset: u32, text: &str) -> Op {
    Op::Insert {
        seq,
        offset,
        tokens: vec![NewToken {
            flags: FLAG_WORD,
            tag: 0,
            text: text.as_bytes().to_vec(),
        }],
    }
}

fn only(s: &Session) -> loom_react::Constraint {
    *s.constraints.iter().next().expect("one constraint")
}

#[test]
fn constraint_follows_its_text_across_edits() {
    let mut s = Session::with_doc("alpha beta gamma");
    let doc = s.rope.doc();
    let beta = doc.windows(4).position(|w| w == b"beta").expect("beta in doc");
    let tok = s
        .rope
        .abs_tokens()
        .iter()
        .position(|t| t.start == beta)
        .expect("token at beta");

    s.apply_batch(&[Op::ConstraintAdd {
        seq: 1,
        start: tok as u32,
        len: 2,
        kind: 1,
        param: 4,
    }]);
    assert_eq!(only(&s).anchor as usize, beta, "anchor starts at the span");
    assert_eq!(only(&s).kind, ConstraintKind::MaxTokensInSpan);

    // Insert before it: the anchor must move with the text, five bytes along.
    s.apply_batch(&[insert(2, 0, "zero ")]);
    let moved = only(&s);
    assert_eq!(
        moved.anchor as usize,
        beta + 5,
        "an insert before the span must drag the anchor with it"
    );
    let d = s.rope.doc();
    assert_eq!(
        &d[moved.anchor as usize..moved.anchor as usize + 4],
        b"beta",
        "the anchor must still name the same text"
    );

    // Insert after it: nothing moves.
    let end = s.rope.len_tokens() as u32;
    s.apply_batch(&[insert(3, end, "omega")]);
    assert_eq!(only(&s).anchor as usize, beta + 5, "a tail insert moves nothing");

    // Delete the inserted prefix: the anchor comes back to where it began. The
    // prefix is whatever the tokenizer made of it, so count tokens, not bytes.
    let prefix = s.rope.abs_tokens().iter().take_while(|t| t.start < 5).count() as u16;
    s.apply_batch(&[Op::Delete {
        seq: 4,
        offset: 0,
        count: prefix,
    }]);
    assert_eq!(only(&s).anchor as usize, beta, "deleting the prefix restores it");
    let d = s.rope.doc();
    assert_eq!(&d[beta..beta + 4], b"beta");
}
