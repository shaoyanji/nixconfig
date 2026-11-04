---
name: brainstorm
description: "Pick me when the question is what could we do rather than make this change: diverge into costed options, edit nothing, and land one AGENTS.nix note as the exit."
version: 0.1.0
platforms: [linux]
metadata:
  hermes:
    tags: ['brainstorm', 'planning', 'method']
    related_skills: ['agents-notes', 'task-plane', 'prove-it-works']
---

# `brainstorm` — diverge on purpose, land one note

A mode is an **injection**, and it is worth saying so before using it: plan mode,
brainstorm mode and this file are a prompt plus one rule about what you may write.
Nothing in the machine enforces it. The only enforcement that exists is the diff —
so make the diff the proof: while the mode is on, `git status` stays clean.

## When it is the right mode

- "What could we do with X", "find seams", "is this worth keeping", "what else is there".
- A measurement has overturned a belief and the conclusion is not obvious yet.
- An idea is half-formed and would be expensive to unwind if built.

## When it is not

- The user named the change ("cap it at 30 fps"): that is a task, not a brainstorm.
- The question is a fact ("what runs on delphi"): that is `host-facts` / `nix eval`.
- The next step is already decided and only the mechanics are open: that is a plan.

## The four rules

1. **Ask the record before proposing.** `task ops:notes:near Q="<the intent in your
   words>"` then `task ops:notes:lineage ID=<id>`. A new idea attaches to the one
   it grew out of (`from`); proposing what already sits at `PROPOSED` is the
   failure this step exists to prevent.
2. **Edit nothing.** No file, no module, no host switch, no commit — including
   "one small change to prove it". Measurements are allowed and encouraged; they
   are read-only by nature. If a measurement needs a temporary artifact, it goes
   under `/tmp` and it is deleted.
3. **Cost every option.** An option without a cost is a wish. Each one carries
   four lines: what it buys, what it costs (bytes, CPU, complexity, a new
   failure mode), the first artifact that would exist, and how it fails.
4. **End in one note.** See *Where it lands*.

## Shape of the answer

- **Three to seven options**, each a claim, not a category ("a ZIM index queried by
  the sandbox microVM", not "better knowledge access").
- **One recommendation**, with the sentence that makes it win.
- **The measurement that would kill it** — the number, and the command that
  produces it. This is what separates a brainstorm from an opinion.
- **Deliberate non-options**, named and dismissed with the reason the arithmetic
  gives ("bytes that must land at home gain nothing from a faster fetcher").
- **Prose, not a plan.** Ordered steps are plan mode; a brainstorm ends at a
  decision plus the evidence that would change it.

Stay in the mode until the user leaves it or the exit is written. When a
question is answered, go back to it — do not slide into implementation because the
next step became obvious.

## Where it lands

`AGENTS.nix`, always — never a new markdown file, never a chat transcript:

| Outcome | Note |
| :--- | :--- |
| Worth trying, artifact nameable | `kind = "experiment"`, `status = "PROPOSED"`, `from = [<ancestor>]`, refs to the module under trial |
| Agreed, not started | `kind = "proposal"`, `status = "ACCEPTED"`, plus `priority` |
| Tried and killed | `status = "REJECTED"` **with the number that killed it** |
| Just a measurement | the conclusion in an existing note's body; the raw numbers stay in the commit or the turn |

Authoring rules, templates and the verification ladder:
`agents-notes` skill. A brainstorm that ends without a note or a rejection did not
happen — it is a conversation, and the next agent re-litigates it.

## Anti-patterns

- **The plan dressed as a brainstorm** — if the output is a sequence of steps,
  the divergence never happened.
- **Building the proof** — "I'll just wire it up to check" turns a read-only mode
  into a half-finished branch.
- **Options without arithmetic** — "it could be faster" is not an option; "297 MB/s
  on delphi against 6 MB/s at home, so the ceiling is the wire" is.
- **Correcting a measurement by asserting a new one** — when the line is busy, the
  honest output is a lower bound plus the experiment that settles it.
- **Silently leaving the mode** — implementation inside a brainstorm is how the
  idea gets committed before it is decided.

Truth: `taskfiles/ops.yml` owns the note queries this mode starts and ends with;
`.agents/SCHEMA.md` §5 owns the lifecycle the exit must follow.
