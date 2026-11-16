//! Minimal diff helpers.

/// Common prefix and suffix length between two token runs.
pub fn trim_affix<T: PartialEq>(old: &[T], new: &[T]) -> (usize, usize) {
    let mut prefix = 0;
    while prefix < old.len() && prefix < new.len() && old[prefix] == new[prefix] {
        prefix += 1;
    }
    let mut suffix = 0;
    while suffix < old.len() - prefix
        && suffix < new.len() - prefix
        && old[old.len() - 1 - suffix] == new[new.len() - 1 - suffix]
    {
        suffix += 1;
    }
    (prefix, suffix)
}

/// One `DIFF` frame replaces `deleted` tokens at `start` with `inserted` tokens.
///
/// A batch is applied verbatim (no retokenization between ops, or a later op's
/// index would land on a token the client never saw), so the frame spans the
/// union of the batch in *pre-batch* coordinates: `base`..`end`, adjusted by the
/// document's total token delta.
pub fn batch_frame(base: usize, end: usize, pre_len: usize, post_len: usize) -> (usize, usize) {
    let deleted = end.saturating_sub(base);
    let delta = post_len as i64 - pre_len as i64;
    let inserted = (deleted as i64 + delta).max(0) as usize;
    (deleted, inserted)
}
