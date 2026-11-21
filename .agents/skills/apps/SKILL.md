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
prints without writing, the other flags override `lead` defaults. A tool with a
JSON record pipes it whole (`task apps:upsert -- < record.json`). The mail hub
adds rows too (`origin` `agent-scan`/`discovered`): `agents:apps:discovered`.

## Track

```bash
task apps:overview        # stage → count → with next action
task apps:list            # every row, newest activity first
task apps:search -- nix   # id, company, role, status, next action
task apps:get -- <id>     # one record plus its linked mail
task apps:status          # totals, newest change, queue depth
```

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

Truth: `taskfiles/apps.yml`, `taskfiles/agents.yml`, `modules/plugins/appflow/`, `docs/email-archive.md`.
