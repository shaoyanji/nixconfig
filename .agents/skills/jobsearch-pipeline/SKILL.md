---
name: jobsearch-pipeline
description: "Five boards, lane filter, dedupe against the whole record, rank, file through apps:scout, read the mail loop, post the turn — one entry point for the sweep-to-upsert chain."
version: 0.1.0
author: Shaoyan Ji (shaoyanji), Freebuff
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: ['job-application', 'sweep', 'dedupe', 'apps', 'xs']
    related_skills: ['apps', 'job-scout-lane', 'xs-turns', 'task-plane']
---

# jobsearch-pipeline — the sweep run for real, in one task

Pick this when the request is "run a board sweep", "find fresh SRE leads" or
"rank outreach targets" and you would otherwise hand-assemble the same five
steps: fetch, filter, dedupe, file, report.

`apps:scout:sweep` prints the read order and the trap each board hides; it is
read-only and network-free by contract. This is the same sweep executed, and it
files through `apps:scout` — the lane's own writer — so the lane still has one.

```bash
task apps:sweep:pipeline                          # sweep + rank, writes nothing
task apps:sweep:pipeline APPLY=1                  # also file the survivors
task apps:sweep:pipeline APPLY=1 MAIL=1 XS=1      # full chain, turn posted
task apps:sweep:pipeline DAYS=3 LIMIT=15 GH=1     # tighter window, GitHub attributed
```

## What it runs, in order

1. **Sweep** — `scripts/task/jobsearch-sweep.py` reads germantechjobs (`/rss`),
   We Work Remotely, RemoteOK, Stepstone (card markup), Berlin Startup Jobs
   (`/feed/` — `/rss/` returns empty) and Arbeitnow. It keeps postings matching the lane
   (DevOps, SRE, platform, infrastructure, Kubernetes, cloud) and younger than
   `DAYS`, and drops the out-of-lane families (support, ERP/SAP, junior,
   embedded, sales) before any ranking happens.
2. **Dedupe** — the record is the oracle, read through `apps:list` at
   `LIM=5000`. The normaliser strips legal suffixes, feed mojibake
   (`Wrttemberg`) and the city Stepstone glues onto the employer (`Main DENIC`,
   `Neuss Creditreform`), because a duplicate row is what the lane refuses.
3. **Validate** — a truncated name is reported under "not filed" with its
   reason, never guessed. A guessed name never matches the next sweep, so filing
   one poisons the dedupe permanently.
4. **Rank** — `score = live postings x2 + GitHub recency x2`, where recency is
   the newest `pushed_at` on the company's public org. `GH=1` makes those calls;
   without it the score is postings alone.
5. **File** (`APPLY=1`) — one `apps:scout` per survivor with `--sweep`, so the
   row carries the cycle as its origin and the family on its status line. The
   family comes from the title (`sre`, `platform`, `infrastructure`, else
   `devops`), because the writer accepts four and refuses a fifth.
6. **Mail** (`MAIL=1`) — queue depth plus the count of unlinked reply-shaped
   mail since `DAYS`. It reports; `agents:apps:sync` is still the writer.
7. **Turn** (`XS=1`) — one `agents:xs:post` for `nixconfig:job-scout`.

## Where this stops and apps:lane starts

This task ends with a filed lead. `apps:lane` carries one lead from there:
`STAGE=jd` reads the posting, `tailor` projects the CV, `packet` builds the PDFs,
`send` transmits when the row's hold date and recipient agree, `replies` polls.
Running this task instead of `apps:lane STAGE=sweep` is the difference between
reading the board list and having the rows.

## Gates it proves, and what it does not

| Step | Proves |
| :--- | :--- |
| record read | the dedupe oracle answered (under 100 employers is treated as no answer, exit 1) |
| sweep | each board was fetched or named as unavailable — a refusal is printed, not silently counted as "no leads" |
| dedupe | nothing already held is proposed |
| file | each row either landed, was refused as bad input, or is named as failed |
| mail | the reply queue was read, nothing was written |

It does **not** prove an employer is worth applying to, does not read a JD, does
not send mail, and does not move a row's stage. A sweep is discovery: the
application decision stays with `apps:lane` and a person.

## Reading the output

Exit 0 = every requested step ran; 1 = a step failed (the failing company is
named); 2 = bad usage. The table is `score, postings, age, employer, role,
board`. "not filed" is the validation list — read it before assuming a board had
nothing new, since the truncated names are the boards' own markup, not silence.

## Cost

One sweep is 5 HTTP fetches plus 24 Stepstone pages (~30 MB, ~90 s), the record
read (~1 s), and — with `GH=1` — up to three `gh api` calls per employer. No
eval, no build, no write unless `APPLY=1`.

Truth: `taskfiles/apps.yml`, `scripts/task/jobsearch-sweep.py`,
`scripts/task/apps-scout.sh`, [[flake/policies.nix#automation-is-earned]].
