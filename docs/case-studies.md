# Case studies — three incidents the architecture caught

Each story is one commit away in `git log`. The point is not the bug; it is
which plane of the repo caught it, and what that plane cost to build.

## 1. The graph gate caught a refactor regression a typecheck couldn't

During a repo-wide style sweep (`3bcadc64`), a hand-rolled helper was piped
backwards — `fmList` takes `content` first, and `content |> fmList "about"`
inverted the argument order. Every `.#knowledgeGraph` surface still **evaluated
cleanly**: Nix is lazy, the error path was never forced, and a JSON diff of the
wrapper attr reported identical output.

`task checks:kg` counts real edges in the real graph. `about` edges went 13 → 0
and the gate refused the refactor. One inverted argument, caught by a census —
the same census that exists so "the graph still builds" and "the graph still
describes the repo" are different sentences.

*What it proves:* a check that counts the artifact beats a check that compiles
it. `flake/checks.nix` is ~50 sites of that shape.

## 2. A decision router that knows why a provider failed

The fleet's `/v1/decide` router (`modules/services/llm-decision-router`) sat in
front of a hosted classifier with a local model as fallback — and fell back on
**every** non-200. A malformed request (a request-side 4xx, the caller's own
fault) was silently re-asked of the weaker local model, and the caller could
not tell which provider had answered.

`26f3a06e` split the failure classes: transport errors, 5xx, auth, payment and
rate-limit failures fail over; request-side 4xx return verbatim. Every response
now carries `X-Decision-Provider`. The same commit found the router's chat
upstream pointing at a port a dead service used to own — the config had been
"correct" for weeks because nothing observable distinguished silent fallback
from success.

*What it proves:* fail-closed means errors stay errors. The skill that governs
this plane (`jevdecide`) states it as a rule — a model routes work, it never
authorises it — and the router now enforces it in code.

## 3. A $5 spend-guard with CI teeth

The generative agent runs on a deliberately $0 budget: a prepaid reseller route
whose *account-scoped* daily quota is shared by every `:free` model id on it.
On 2026-11-19 a single billed model pick — one keypress past a picker that
offered paid ids — spent the balance that kept the free lane working.

The fix is `scripts/task/infron-check.sh`: 57 assertions. The picker denylist
hides every billable vendor, the fallback chain's free contracts are structural
(`:free` suffix, closed free catalogs, a keyless terminal lane), and the guard
asserts lane count and independence — including that the terminal lane is one
that can never bill by construction.

*What it proves:* the constraint is the design. A spend-guard as a gate means
"free" is a checked property, not a remembered price.

---

More: `docs/` and `.agents/skills/*/SKILL.md` carry the runbooks; `AGENTS.nix`
carries the 185-note decision log these stories index into.
