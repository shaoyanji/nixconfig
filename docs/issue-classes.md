# Issue classes

Every issue this repo has met belongs to one of four classes, and the class picks
the remedy. Fixing a symptom with a remedy from the wrong class is the failure
mode this page exists to stop: the run goes green, the cause stays, and the next
push meets it again wearing different clothes.

Classify before you edit. Name the class in the commit when it is not obvious from
the file, so the next agent reads a diagnosis instead of a narrative.

| Class | What you met | What proves the class | Standard remedy |
| :--- | :--- | :--- | :--- |
| `trust` | A source was declared without its proof: a substituter with no key, a key that is not the one the cache signs with, a narinfo rejected as unsigned. Work happens that the source had already done. | `nix store verify --store <url> --option trusted-public-keys <key> <path>` against the real cache, and the line `ignoring substitute … not signed by any of the keys` | Prove which key the source signs with, then put the declaration and the proof in one place: one key line, in every block, and on the command that matters. |
| `lint` | An artefact crossed a threshold: prose past its line budget, a task shard in the wrong bucket, a document using vocabulary the repo bans. | the gate's own output, naming the artefact and the number | Edit the artefact to fit. Never raise the budget. |
| `assert` | The same command is green on one machine and red on another: no `/dev/kvm`, a cache the runner cannot reach, less memory than the evaluation needs, the wrong binary first on `PATH`. | both runs, plus the precondition that differs | State the precondition as an assertion that refuses before the work starts. Not a retry, not `continue-on-error`. |
| `capacity` | The work did not fit a measured resource: OOM killed, cancelled at a job timeout, disk full. | elapsed time and peak RSS from the run, against the limit | Remove the work if it should not have been there, or set the limit from the measurement. Raising the limit on its own is the slop version. |

## Telling `trust` from `capacity`

Both end in an error that reads like a resource problem: `Killed`, a cancellation,
a signal. The question that separates them is whether the work had to happen at
all.

- Did the build fetch a path and then reject it? `trust`.
- Did it compile something the cache publishes, because the cache was never
  allowed to be trusted? `trust`.
- Did every input come from a source it accepted, and it still ran out? `capacity`.

## Telling `assert` from `capacity`

`assert` is about a precondition, `capacity` an amount. If the same command
succeeds elsewhere, no headroom fixes it: the machine is missing the feature, not
the memory.

The repo already refuses rather than retries in two places, and both are shapes to
copy: `checks:boot` refuses without `/dev/kvm`
[[flake/policies.nix#boot-gate-needs-kvm]], and `checks:flake` refuses below
16384 MiB [[flake/policies.nix#flake-check-memory-gated]].

## The record, 2026-11-16 and 17

| Failure | Class | Evidence | What fixed it |
| :--- | :--- | :--- | :--- |
| `nixcachix` build killed on an x86_64 runner | `trust` | `cache.numtide.com` listed with no key; 2722 paths refused as unsigned, including glibc, gcc, boost and nix-store 2.34.9 | the key numtide signs with, on one line in all four blocks and on the build command |
| `delphi` cancelled at 65 minutes on an arm runner | `trust`, not `capacity` | 2423 unsigned refusals on that runner, still compiling boost and duckdb at 14 minutes; the 60-minute budget was never the problem | the same key line |
| `docs-budget` red | `lint` | the gate names the document and the count | shorten the document |
| a verification step assumed `python3` had a YAML parser | `assert` | the tool was absent and the parser was assumed | use the tool the repo ships (`nix shell nixpkgs#yq-go`); do not hand-roll a parser |

The key numtide signs with ends `…/yaX7M4qK0g=`. A widely repeated string for the
same cache ends `…/yaX7D8qU0k=`, and `nix store verify` calls it untrusted. Check
the string against the cache instead of correcting it toward the one that looks
more familiar.

## Keep the class in the gate

A class fixed only in prose comes back. `correct` climbs architecture → type or
lint → test or gate → prose, and this page is the last of those four. The gates
that already hold each class are the ones named above; a class that arrives with
no gate is not fixed yet.

A failure routed to an agent starts at `scripts/task/ci-fix-dispatch.sh`, whose
prompt names these four classes so the agent begins from a diagnosis rather than
from the symptom in the log.
