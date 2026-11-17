# playbooks — the router's reference files

One playbook per shape of work. Read the one the label names, not all sixteen.
Each section answers the same six questions, in the same order, so a half-read
section still says what ends the turn.

A playbook is a procedure, not a policy. Where it names a rule, the rule lives
in `flake/policies.nix` and the gate that enforces it is named beside it.

## host-change

**Lands here.** The ask edits `hosts/<h>/`, a profile, or a service module that
one host imports.

**First read.** `nix eval --json .#inventory.hosts.<h> | toon -e` for kind,
system and status, then `git status` — the host may already carry work.

**Steps.**
1. Edit the smallest module that owns the fact; constants come from
   `modules/global/user.nix`, never a literal.
2. `task checks:host HOST=<h>` — the module system and every assertion, one host,
   no build (7.6–13.2 s, 720–965 MiB).
3. Only for a change that adds derivations: `task infra:warm:host:<h>`, then
   `task infra:deploy:host:<h>`. A rebuild is the build, not a check.

**Gate.** `checks:host` exit 0 for that one host.

**Stop.** `status = "preserved"` exits 0 by design; report it instead of setting
`ALLOW_PRESERVED=1`. If the edit is in a module several hosts import, this was
`chain-change` — say so and switch.

**Must not.** `nix flake check`, a fleet sweep, or `--print-out-paths` inside the
gate. Each is the same mistake: spending build budget to answer a question about
config.

## chain-change

**Lands here.** The ask edits `modules/global/`, `modules/profiles/`,
`modules/roles/`, a shared `modules/services/` module, or a `modules.toml` entry.

**First read.** `task ops:kg:module PATH=<file>` for the importers, and
`task docs:build` for the chain table, which names the hosts per chain.

**Steps.**
1. Find the affected chains, then one active host per chain. A feature list is a
   cost every host in it pays.
2. Batch the checks in one bash loop, one process per host.
3. `task checks:quick` when `modules.toml` moved, since the registry is data.

**Gate.** Every named host passes `checks:host`; the registry renders.

**Stop.** A preserved host is out of scope; another host per chain adds cost and
no proof.

**Must not.** Sweep the fleet. Edit a chain module and gate one host that is not
in the chain.

## flake-change

**Lands here.** `flake/`, `lib/` wiring, `flake/host-inventory.nix`, the
`.#nixFiles`/`.#modules` registries, checks, devshells, outputs.

**First read.** `nix eval --json .#inventory.hosts | toon -e`, and
`task check:list KIND=host` for the checks the change will move.

**Steps.**
1. Edit the projector, not the projected output.
2. One active host per `kind` — nixos, darwin, home — as `checks:host`.
3. Build the one check that changed, not the flake: `--builders ""`, `--no-link`.
4. `git add` an untracked `.md` before evaluating it: eval-time `readFile` is
   flake-scoped.

**Gate.** One host per kind at exit 0, and the changed output evaluating.

**Stop.** `checks:flake` only where the machine can hold it: it refuses below
16384 MiB because one process holds every output.

**Must not.** Evaluate a whole host to answer a wiring question, or add a file
the registry does not name.

## gate-change

**Lands here.** The ask adds or changes anything under `checks:*`, a lint, or an
assertion.

**First read.** `task check:list KIND=host` and the `taskfiles/checks.toml` row
format; the policy id the gate is supposed to enforce in `flake/policies.nix`.

**Steps.**
1. Write the gate against a real past mistake.
2. Run it before it is wired, against the file or commit that had the bug, and
   keep that output: a check that has never failed is a ritual.
3. Make it pass, add the task and its `.toml` row, then `task check:verify` —
   108 rows against 108 live tasks is the shape that has to agree.
4. Keep the summary under the 600-character budget; `checks:tasks` reads it.

**Gate.** The gate failed before it passed, and `check:verify` exits 0.

**Stop.** Once is an incident, twice is a class. With one instance, write the
note (`correct`).

**Must not.** A check that can build, a check that can hang, or a check that
skips itself without a line naming why.

## task-change

**Lands here.** `taskfiles/*.yml`, `taskfiles/checks.toml`, a script under
`scripts/task/`.

**First read.** `task find:<word>` and `task --list-all --json`; the ladder is in
`task-plane`.

**Steps.**
1. Walk eval → jq → Nix lib → check → task → script → Go, and stop at the first
   rung that holds.
2. `task checks:tasks` — the graph, the name parity against go-task, the desc
   and summary budgets.
3. `task check:verify`, and `task checks:skills:mirror` if a skill table names
   the task.

**Gate.** `checks:tasks` exit 0, and the task reachable by intent through
`task help`.

**Stop.** A second name for an existing task is a rename, not an addition. A task
may not be `internal: true`.

**Must not.** Add a task for a fact a compiler already answers, or put a shard
in a new file without a row in the ownership map.

## prose-change

**Lands here.** `docs/`, a `SKILL.md`, an `AGENTS.md` line, or a Nix comment.

**First read.** `nix eval --json .#proseBudget | toon -e` for that page's
recorded body count, and `task ops:notes:near Q="<the idea>"` so the page is not
a second narrative of a note.

**Steps.**
1. Edit the page. Record its new body count in `flake/prose-budget.nix` in the
   same change; over 200 lines also needs a line in `notes` saying why it earns
   them.
2. `task checks:prose` — the unslop vocabulary, read from
   `modules/config/prose-tells.tsv`.
3. `task ops:docs:budget`, then `task checks:nix:comments` if a `.nix` file's
   header moved: the census only shrinks.
4. `task docs:build` when the change feeds a generated artifact.

**Gate.** Prose, budget and census at exit 0.

**Stop.** A new root markdown file is closed. A procedure belongs in `docs/` or a
skill; a fact belongs in the compiler.

**Must not.** Grow a skill past 400 lines, restate a task's `desc` in a table
(`checks:skills:mirror`), or add a comment that restates the code beside it.

## note-change

**Lands here.** An `AGENTS.nix` entry: a decision, experiment, open todo or
handoff.

**First read.** `task ops:notes:near Q="<intent>"`, then
`task ops:notes:lineage ID=<id>` for ancestry — the same note may already exist
in a status you were about to duplicate.

**Steps.**
1. Pick the kind and status from `agents-notes`; the template is there.
2. Write refs that resolve — a note whose ref does not name a file is prose.
3. `task ops:notes` to read it back, `task checks:kg` for the note node and its
   lineage edges.

**Gate.** Every ref resolves, and the graph emits the note plus its edges.

**Stop.** An experiment ends at an exit criterion. When the answer is code, the
note is done and the code is the deliverable.

**Must not.** Write the narrative a skill already carries; leave a decision in a
turn log alone when it needs the design record.

## bug-fix

**Lands here.** A symptom whose cause is unknown.

**First read.** Turn the symptom into two or three falsifiable hypotheses, with
the cheapest observation that kills each. `git log --oneline -30`,
`task agents:xs:list Q="<symptom>"` and `task ops:notes:near` may have seen it.

**Steps.**
1. Reproduce with the smallest command that fails.
2. Bisect the space — which host, which module, which task, which flag — instead
   of reading more code.
3. One change at a time, and rerun the failing command, not a broad suite.
4. When it passes, rerun only the check that covers the change.

**Gate.** The command that reproduced the symptom now exits 0, with its status
kept through any pipe.

**Stop.** Three hypotheses with no repro means the cause is not yet visible: say
what is untested instead of shipping a speculative fix.

**Must not.** Silence the error, widen the assertion, or call an eval a fix.

## perf

**Lands here.** Faster, smaller, cheaper.

**First read.** The instrument the repo already has: `ops:kg:speed` for graph
queries, `task find:closure` for size, `checks:build:route` for whether this host
must compile.

**Steps.**
1. Measure a baseline with the exact command that will measure the result.
2. Change one thing.
3. Measure again, same conditions.

**Gate.** Two numbers from the same instrument.

**Stop.** No number, no claim. "Feels faster" is not a result.

**Must not.** Quote a speedup from a different machine, a cold cache, or a
narrower slice of the work than the baseline covered.

## incident

**Lands here.** A live host misbehaving now.

**First read.** `task ops:health`, then the unit itself — `systemctl status`,
`journalctl` — and the sentinel ledger through `fleet-sentinel`, which carries
job results, generation age, disk and PSI every 15 minutes.

**Steps.**
1. Read the ledger before the config: a green socket is not a successful job.
2. `task infra:logs:host:<h> UNIT=<unit>` for the unit's own history.
3. Fix the cause. If the cause is config, this becomes `host-change`; if it is a
   stuck generation, the deploy notes for that host own the recovery.

**Gate.** The unit's state plus the next ledger row, not a rebuild.

**Stop.** A dormant host is dormant by design (`status = "preserved"`), not a
symptom.

**Must not.** ssh in an unattended path (the browser check hangs), or rebuild to
see whether it helps.

## secret

**Lands here.** sops, age keys, `hashedPassword`, any value that must not be
read aloud.

**First read.** `docs/sops-rekey.md` for the two files and the two identity
planes, and `.sops.yaml` for who can decrypt what.

**Steps.**
1. Decrypt once to check the value, and never print it.
2. `task infra:sops:update-keys` after any `.sops.yaml` change.
3. A new server's age key, from its `ssh_host_ed25519_key`, must be in
   `.sops.yaml` before `hashedPassword` will decrypt.

**Gate.** A decrypt that works on the target host.

**Stop.** A keyless environment can eval but not `checks:quick`, which reads sops
drift. Say which side of that line the turn is on.

**Must not.** Put a value in a summary, a note, a test fixture or a commit
message.

## deploy

**Lands here.** Put a built configuration on a host.

**First read.** `task infra:plan:host:<h>`, the host's page under
`.agents/deploy/hosts/`, and for `frieren` its own topology — nightly window, one
rebuild at a time.

**Steps.**
1. Gate: `task checks:host HOST=<h>`.
2. Plan, then apply: `task infra:deploy:host:<h>`.
3. Validate. Keep `task infra:rollback:host:<h>` in hand.

**Gate.** `infra:deploy`'s validate phase.

**Stop.** A preserved host exits 0 before any eval. Two rebuilds on `frieren` is
not a race worth running.

**Must not.** Deploy from a tree with unreported local edits, or re-deploy to fix
a validation failure you have not read.

## research

**Lands here.** A question: what, which, why, where, has this been tried.

**First read.** `nix eval --json .#epistemics.table | toon -e` says which source
settles which claim kind. For a host fact, `host-facts`. For structure,
`task ops:kg:*` rather than a grep.

**Steps.**
1. Answer from the compiled source.
2. Name the source and its scope in the answer.
3. When two sources disagree, say which is authoritative and cite the table that
   decided it.

**Gate.** One named source, re-runnable by the reader.

**Stop.** No edit. If the answer is "this should change", say so and leave the
change to its playbook.

**Must not.** Answer a host fact from memory, or a structural question by
grep — word overlap is not authority.

## decision

**Lands here.** Which model, provider, lane or option should answer.

**First read.** `jevdecide` for the call and thresholds, `decision-picker` for
which model fits the input, and `decide models` for readiness.

**Steps.**
1. Write the options as labels that describe what the reader does.
2. One call, provider always named: the CLI's default answers HTTP 402.
3. Read probability and margin, then carry out the lane yourself.

**Gate.** A label with its probability and the threshold it cleared.

**Stop.** A decision is a signal, never an authorisation; delete, deploy, push
and send still go through `confirm-before-destructive`.

**Must not.** Ask the model to explain itself (it returns a label), or act on a
`needs_review`.

## novel

**Lands here.** Nothing in the table, or the rule table fired twice.

**First read.** `task ops:notes:near Q="<the intent>"`, then
`task ops:notes:lineage`, then `task help`.

**Steps.**
1. Check the design record: unheard-of work is usually a note one status away.
2. If it is genuinely new, diverge into costed options (`brainstorm`) and land
   one `AGENTS.nix` note.
3. If the answer is code, write the note's exit criterion and implement it in the
   same change.

**Gate.** A note with an exit criterion, or a diff that meets one.

**Stop.** Prose is the last resort in the `correct` ladder, not the first.

**Must not.** Invent a task name, or add a script before walking the ladder.

## publish

**Lands here.** A site, blog post or static surface going out.

**First read.** `task help` for the owning shard — `dev:site:*`, `neocities:*`,
`envs:*`, `dev:blog:*` — and `docs:build` for the compiled artifact.

**Steps.**
1. Edit the source in the repo.
2. Compile: `task docs:build` (or the site's own target).
3. Deploy by task, then fetch the served page.

**Gate.** The compiled surface plus one fetch of the live URL.

**Stop.** A rendered surface compiles from one registry; a change to one vhost
that re-derives markdown is a second renderer.

**Must not.** Edit anything on the host, or commit a generated artifact.

## Chaining

A turn can need two playbooks. Say so before the first edit, name the order, and
gate each one — "gate-change, then host-change to apply it" is a plan; discovering
the second one halfway through is a surprise the operator pays for.
