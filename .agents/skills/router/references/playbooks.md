# playbooks — one row per label

The task is the procedure: run the one under *First read* and the one under
*Gate*. A row is a route, not a runbook, so nothing here restates a taskfile.
Two playbooks in one turn: name the order before the first edit.

| Label | Lands when | First read | Gate | Must not |
| :--- | :--- | :--- | :--- | :--- |
| `host-change` | one host's config, profile or a service module it imports | `nix eval --json .#inventory.hosts.<h> \| toon -e` | `task checks:host HOST=<h>`; a rebuild is the build, not a check | `nix flake check`, a fleet sweep, a gate that compiles |
| `chain-change` | a module several feature chains import | `task ops:kg:module PATH=<file>` | `checks:host` on one host per affected chain | sweeping the fleet |
| `flake-change` | `flake/`, `lib/` wiring, outputs, checks, devshells | `nix eval --json .#inventory.hosts \| toon -e` | `checks:host`, one active host per `kind` | evaluating a host to answer a wiring question |
| `gate-change` | a check, lint or assertion | `task check:list KIND=host` | the gate failing on the real mistake, then `task check:verify` | a gate that builds, hangs, or skips itself silently |
| `task-change` | a taskfile, or a script under `scripts/task/` | `task find:<word>` | `task checks:tasks`, `task check:verify` | a new task for a fact the compiler already answers |
| `prose-change` | docs, a `SKILL.md`, or a Nix comment | `nix eval --json .#proseBudget \| toon -e` | `task checks:prose`, `task ops:docs:budget`, `task checks:nix:comments` | a new root markdown file |
| `note-change` | an `AGENTS.nix` note | `task ops:notes:near Q="<intent>"` | every ref resolving, `task checks:kg` | prose where a gate belongs |
| `bug-fix` | a symptom whose cause is unknown | `task agents:xs:list Q="<symptom>"`, `task ops:notes:near` | the command that reproduced the symptom | widening the suite first, silencing the error |
| `perf` | faster, smaller, cheaper | `task find:closure`, `ops:kg:speed` | two numbers from one instrument | a claim without a measurement |
| `incident` | a live host misbehaving now | `task ops:health`, `task ops:ledger` | the unit's state plus the next ledger row | ssh unattended, rebuilding to see |
| `secret` | sops, age keys, `hashedPassword`, a value | `docs/sops-rekey.md` | a decrypt that works on the target host | printing a value |
| `deploy` | putting a built configuration on a host | `task infra:plan:host:<h>` | `task infra:deploy:host:<h>`'s validate phase | two rebuilds on `frieren`, an unreported dirty tree |
| `research` | a question, answered not changed | `nix eval --json .#epistemics.table \| toon -e` | one named source, re-runnable | answering structure by grep, a host fact from memory |
| `decision` | which model, provider or lane | `decide models`, `jevdecide` | a label with its probability and threshold | letting a model authorise, asking one to explain |
| `novel` | nothing matches the table | `task ops:notes:near`, `task ops:notes:lineage` | a note with an exit criterion, or code that lands one | inventing a task name |
| `publish` | a site, blog post or static surface | `task help`, `task docs:build` | the compiled surface plus one live fetch | editing on the host, committing a generated artifact |
