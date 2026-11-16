---
name: apps
description: "Job application pipeline: status, mail triage, Typst documents."
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

The pipeline is the archive database on delphi, and a tailnet client needs one
thing to use it: `https://delphi.cloudforest-kardashev.ts.net:8450`. Since
`86bdb73b` (2026-11-03) that database is the only writer; `appflow-sync.timer`
advances statuses from ATS mail hourly, and `applications.json` in the workflow
checkout is an export, not a source.

## What runs where

`task apps:doctor` probes every transport below in one call, each probe bounded,
so a missing piece answers no instead of stalling the shell. Run it on an
unfamiliar client before anything else.

| Transport | Needs | Gives |
| :--- | :--- | :--- |
| archive API | tailnet reach to 8450 | list, search, get, update, upsert, overview, queue, status, export |
| SQL | nothing extra — `/api/pipeline-sql` is on the API | `apps:query` |
| Typst checkout | `/srv/data` mounted (`APPS_DIR`) | build, audit, followups |
| sops identity | this host's age key | `apps:pii:sync` |

`query` used to be the exception: no route, so it needed a psql role or an ssh
session on delphi, and on a client with neither it waited four minutes on a
Tailscale auth check before failing. The route is `POST /api/pipeline-sql`, one
read-only statement, refused unless it starts with `select` or `with` and carries
no write verb. psql and a bounded ssh (`BatchMode`, 5 s connect timeout) remain as
the fallback for an archive older than the route. `APPFLOW_API` moves the mount
and `DELPHI_HOST` the ssh target.

## The flows

`task apps:list|search|get|update|overview|status` speak the API from any host,
and a status change is one command:

```bash
task apps:update -- <id> --status "Rejected (email 2026-10-23)"
```

`stage` and the next action follow from the status (`stage_of` in
`modules/plugins/appflow/sync.py`), so a rejection also clears the next action.
There is no push step and no JSON to reconcile.

`task apps:emails` shows what the hourly sync will drain. A message the rules
cannot prove stays in the queue, and a rejection the vocabulary does not
recognise is the case `checks:appflow:triage` covers.

The Typst half (`apps:followups`, `apps:build`, `apps:audit`) reads the checkout,
so it runs where `/srv/data` is mounted. It does not touch pipeline rows.

Never hand-edit a JSON copy or import one over the database: a stale file reverts
rows the mail hub discovered. `task apps:export` writes a snapshot on demand.

Truth: `taskfiles/apps.yml` and `docs/email-archive.md`.
