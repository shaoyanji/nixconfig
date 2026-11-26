---
name: pipe-loop
description: "Pick me when the pipe-operator review dispatch fires: one task runs the locked tier (checks:nix:style verbatim) plus a survey of unlocked candidate classes for judgment."
version: 0.1.0
author: Devin
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: ['review', 'nix', 'refactor', 'loop', 'style']
    related_skills: ['checks', 'correct', 'no-comments', 'prove-it-works']
---

# pipe-loop — the lib/*.nix pipe-operator review loop

The standing dispatch "continue the standing code-review loop over lib/*.nix
pipe-operator code" runs this. One command produces the whole review surface:

```bash
task dev:review:pipe-loop
```

## What the loop proved, and what is left

By 2026-11-26 the conversion phase is complete: every surveyed class is either
idiomatic or gate-locked (`66d31972`, `da5bc77f`). The loop's remaining role is
verification — a locked class gaining an instance means the gate was bypassed
or mis-scoped, not that a new idiom appeared.

## Steps

1. **Survey.** `task dev:review:pipe-loop`. Locked tier = the gate verbatim;
   survey tier = the unlocked candidates with file:line for judgment.
2. **Judge each survey hit.** A hit is a review item, not a violation. Honest
   uses seen and left alone: `findFirst` over an index range, `elemAt`/`head`
   on match results and tuple rows, `listToAttrs (map {name,value})`
   (canonical). Convert only shapes that are pure indirection —
   `(xs: builtins.elemAt xs 0)` is `builtins.head`.
3. **Convert or lock.** Rewrite the idiom, or — when a class is already zero —
   add a rule to `scripts/task/nix-style-check.sh` plus a seeded case and
   honest controls in `tests/nix-style/run.sh`. The fail-on-real-mistake
   discipline cuts both ways: a rule that over-fires fails its own fixture.
4. **Blast radius, then gates.** `lib/` edits reach host derivations —
   `task checks:host HOST=<h>` on affected hosts. `flake/`/`scripts/`/`tests/`/
   `taskfiles/` edits prove on `task checks:tasks`, `task check:verify`, and
   `task checks:nix:shell`. The gate itself: `task checks:nix:style` +
   `task checks:nix:style:test`.
5. **Land.** Named-path staging only — sibling lanes leave uncommitted work in
   this tree (`lib/agent-turns/turns.json` legitimately rides along; it is the
   hook-regenerated xs snapshot). Commit, push, post the xs turn on
   `nixconfig:devin-lane` naming the commit and gate.

## Traps

- **Backreferences need PCRE.** `rg --pcre2` for `\1`; in the gate script GNU
  `grep -P` — and `grep -PE` is an error ("conflicting matchers"), it is
  `-nP` or `-nE`, never both.
- **Capturing groups renumber.** `(builtins|lib)\.map` makes the lambda var
  `\2`; use `(?:builtins|lib)` so `\1` stays the lambda var. The seeded
  fixture catches a silently-never-matching rule.
- **A line-end anchor is the false-positive guard.** `|> ...length$` cannot
  match `length` inside a filter predicate — the anchor is what lets
  `filter (n: (n |> length) > 2)` pass honestly.
- **grep vs rg syntax drift.** The gate greps `grep -P` (PCRE); ad-hoc
  surveys need `rg --pcre2`. Same pattern, different engines — test the
  seeded case, never assume.
- **Exit codes mean things.** 0 = locked tier clean, 1 = the gate refused
  (a locked class has instances), 2 = `rg` missing — a survey tier that
  cannot run must refuse, never print `none`.

Truth: `scripts/task/pipe-loop.sh`, `scripts/task/nix-style-check.sh`,
`taskfiles/dev.yml` — the loop and its gate; this page is the procedure.
