---
name: no-comments
description: "Pick me on a diff or named files to strip comments that restate code. A second, blind read judges each comment: keep few, delete the rest, encode real constraints as a check instead."
version: 0.1.0
author: Lauren Tan (poteto), adapted for nixconfig
license: MIT
platforms: [linux, darwin]
metadata:
  hermes:
    tags: ['pstack', 'method', 'comments', 'refactor', 'review']
    related_skills: ['correct', 'prove-it-works', 'checks']
---

# no-comments: the author of a comment will defend it

Adapted from pstack (`no-comments`, MIT, cursor/plugins). Upstream spawns a `comment-sicko` subagent; that subagent does not exist here, so the equivalent is defined in step 1.

## Scope

The caller's files, or the current diff against `main` including the working tree:

```bash
git diff main... -- . | head -400     # or: git diff --staged, git diff <files>
```

## Steps

1. **Review blind.** Give the diff to a fresh context with only the questions in step 2. If a delegate agent is available (`skill: crush`, `skill: reasonix`), hand it the diff and forbid writes; otherwise do a separate read-only pass yourself, after a gap, reading only the diff. Do not let the pass see your intent.

2. **Verdict per comment: KEEP, KILL, or ENCODE.**
   - KEEP only: a license header, a doc comment on a public API, a link that explains what the code cannot, or behaviour forced by an external dependency you cannot change.
   - KILL: restating the code, section banners, changelog narration, `TODO` with no owner, a comment that explains what the code should obviously do.
   - ENCODE: a claimed constraint (`do not remove`, `keep in sync`, `must match`, `must stay`).

3. **A comment explaining something odd is a bug report.** Fix the code or delete the comment, never polish it.

4. **Encode before deleting.** A constraint in a comment is a constraint no check enforces. Give it one owner: a Nix assertion, a `checks:` gate, a shared `lib/` derivation, or a value read from the one place that owns it. Then delete the comment. If the encoding is out of scope, delete the comment anyway and report the constraint as open.

5. **History is not a comment.** A dated incident narrative belongs in `AUDIT.md`. Banner rules (`# =====`) carry no information: delete on sight.

6. **Report** the deletion count, what you kept and the proof it is about something you cannot change, the encodings, and the constraints left open.

## Evidence this repo has, as of 2026-10-20

- 5,220 comment lines in 236 `.nix` files, 17% of non-blank Nix.
- 66 banner rules across 19 files.
- 86 dated incident narratives in `.nix`/`.sh` while `AUDIT.md` is the ledger.

Start with the diff in front of you. Do not sweep the tree in one pass.
