---
name: ci-failure-triage
description: "Use when CI fails: read the failing step, not the gate."
version: 0.1.0
author: Hermes Agent
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: ['ci', 'github', 'submodule', 'triage', 'checks']
    related_skills: ['checks', 'dev', 'instabox']
---

# ci-failure-triage — read the step, not the gate

A red run names a job, not a cause. The first move is to read WHICH step failed
and its error, before touching any gate the job was supposed to run.

```bash
gh run view <id> --json status,conclusion -q '.status+" "+.conclusion'
gh run view <id> --log-failed | grep -i '##\[error\]\|fatal\|denied' | head
```

## The checkout failure that looks like a gate failure

When EVERY job in a run fails at the **Sync repository** (`actions/checkout`)
step in ~10 s with:

```
fatal: Fetched in submodule path '<path>', but it did not contain <sha>.
Direct fetching of that commit failed.
```

the cause is a submodule commit the superproject PINS but that was never pushed
to the submodule's own origin. The hygiene, docs-budget, sops-drift and cv-links
gates never ran — do not debug them. This is the usual shape of "sops drift":
the secrets submodule is ahead of its origin while the superproject references
the unpushed commit.

Diagnose in three reads, no build:

```bash
git ls-tree HEAD <submodule-path>                                  # the pinned sha
git -C <submodule> log --oneline origin/<branch>..HEAD             # local, unpushed
git -C <submodule> branch -r --contains <sha>                      # empty = on no remote
```

Fix is one push: `git -C <submodule> push origin <branch>`. For a sops
secrets submodule this pushes ciphertext only — never print a decrypted value.
Then re-run CI (`task dev:ci:trigger:<host>`) and confirm jobs get PAST checkout
before attributing any later failure to a gate.

## Rules

- **The failing step is the evidence; the job name is not.** A job called
  `hygiene` that dies in `Sync repository` is a checkout problem, not a hygiene
  problem. Fix the step that failed, then re-run.
- **A pinned-but-unpushed submodule commit fails every job at once.** One missing
  push to the submodule origin breaks the whole matrix identically; do not treat
  N identical failures as N bugs.
- **Push the submodule, not a re-pin.** The superproject already references the
  commit and is on origin; making origin contain that commit is the minimal fix.
  Re-pinning to an already-pushed commit is the alternative only when the local
  commit should not exist.
- **Never force-push to clear a rejected submodule push.** A non-fast-forward or
  auth rejection is a stop-and-report, not a `--force`.

Truth: `taskfiles/checks.yml` — the gates a CI run shells into; this page is the reading order.
