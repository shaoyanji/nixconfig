---
name: apps
description: "Job application pipeline: add and track applications from any host, the mail loop, Typst documents."
version: 0.3.0
author: Shaoyan Ji (shaoyanji), Hermes Agent
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: ['apps', 'job-application', 'workflow', 'postgres']
    related_skills: []
---
# apps — the job-application pipeline

One Postgres table on delphi is the pipeline; the archive API at
`https://delphi.cloudforest-kardashev.ts.net:8450` is its writer from any host,
`applications.json` an export never a source. `task apps:doctor` probes each
transport once, bounded, on an unfamiliar client.

## Add a job

```bash
task apps:add -- --company Flox --role "MTS, Infrastructure" \
  --apply-url https://… --notes "nix required"
```

`--company` and `--role` are required; the id defaults to a slug of the two, so
a re-run updates rather than duplicates — `--id` reuses a scan's slug, `--dry`
prints without writing, the other flags override `lead` defaults. A JSON or
TOON record pipes in whole (`task apps:upsert -- < record.toon` — decode is the
shared toon_ingest contract). The mail hub adds rows too (`origin`
`agent-scan`/`discovered`): `agents:apps:discovered`.

A lead a sweep turned up is not an application already sent, so it goes in
through `task apps:scout`: `--family devops|sre|platform|infrastructure`
required, plus `--company`, `--role` and a one-line `--summary`. The family
becomes `origin` `scout:<family>`, the summary `notes`, and the owner rides the
status line because the table has no owner column. `--next-action` lands with
the row, so a lead is never stored without the thing that moves it, and the
same company plus role updates one row instead of adding a second.

An employer that already has a live row is a duplicate whatever the title: the
dupes gate closes the second row and the lead is lost. `task apps:search --
<company>` before scouting, and treat a second requisition at the same employer
as a replacement for the tracked row, not an addition.

A job board's employer label is not the employer: arbeitnow's "Coda" is
`coda.co`, and "Microsoftcorporation" is Microsoft. Read the posting's
`hiringOrganization` (or the apply host) before writing `--company`, or two rows
for one employer sit in the table spelling its name differently, which the
dupes gate cannot see.

An empty ATS feed is not an employer without openings: the EU open-source
vendors (LINBIT, B1 Systems, Univention, Open-Xchange, Proxmox) post only on
their own careers page or a Personio/join.com widget, so a guessed greenhouse
slug answers `[]` and reads like "no roles". Fetch the careers page before
writing a vendor off — `linbit.com/jobs`, `b1-systems.de/jobs-karriere` and
`open-xchange.com/careers` all list live engineering reqs that no aggregator
in this lane carries.

Fetching a careers page is not reading the posting. `curl | sed` on a WordPress
page returns CSS and jQuery (`elementor-widget-nav-menu …`), which a packet will
gladly project onto; `lynx -dump -nolist -width=110 | awk 'NF'` gives the ad. And
a 200 is not proof of reachability: `linbit.com/jobs/<anything>` answers 200 and
`/jobs/` listing text carries the title, yet every direct posting path is 403 to
a non-browser fetch — so a short JD file is a stub, not a description, and
the row's `next_action` says so instead of a packet built on nav text.

## Track

```bash
task apps:overview        # stage → count → with next action
task apps:list            # every row, newest activity first
task apps:search -- nix   # id, company, role, status, next action
task apps:get -- <id>     # one record plus its linked mail
task apps:status          # totals, newest change, queue depth
```

Every read emits TOON; `FORMAT=text` prints a table for a person.

`stage` derives from status text: `interview|trial` → interview, `rejected…` →
rejected, `applied…`/`application received` → applied, `lead…`/`rezi…` → lead,
`screening`/`follow-up required` → screening, `draft|packet|jd` → prep, else
other. The writer computes it — `task apps:update -- <id> --status "…"` moves
both, and a rejection clears the next action. Sparse upserts null fields:
correct one row with `update`, not `add`.

## The mail loop

`appflow-sync.timer` on delphi drains `agent:apps` mail hourly, then
`appflow-resolve` reads what the rules could not decide. From a client:
`task apps:emails` shows the wait; `task agents:apps:sync DRY=1` previews a
drain; `task apps:queue:resolve` closes what rules prove (auto rules-only
off-loopback); `task agents:apps:pipeline` is the stage report plus open mail.

## Documents

`task apps:docs` lists stored text, `apps:docs:show -- <id>` prints it,
`apps:docs:import` loads `$APPFLOW_JD_DIR`. `agents:apps:select ID=<id>` shows
the projection; `agents:apps:packet ID=<id>` builds the PDFs. Replies are
mailbox DRAFTS, never sent: `agents:apps:draft ID=<id> BODY=file DRY=1`;
`agents:apps:drafts` lists them — both need himalaya; Typst needs /srv/data.

Packets are built to a store path and linked under
`${APPFLOW_PACKETS:-~/.local/state/appflow/submissions}/<id>` — that is also
where every sheet, JD copy and tailored packet lives (legacy material moved
there 2026-11-22, `95ba04a1`). Nothing job-related lives in the repo: a packet
is private — a phone number and a street address — and this tree is public, so
`submissions/` is gitignored, the pre-commit hook refuses a staged
`submissions/` path even under `git add -f`, and `appflow-packet.sh --out`
inside the repo exits 2. The built-packet links sit under
`~/.local/state/email-archive/packets/`, JDs at `~/.config/appflow/jd/<id>.txt`
(or `apps:docs`), and every record in the delphi hub DB.

Truth: `taskfiles/apps.yml`, `taskfiles/agents.yml`, `modules/plugins/appflow/`, `docs/email-archive.md`.
