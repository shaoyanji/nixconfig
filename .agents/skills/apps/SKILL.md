---
name: apps
description: "Job application pipeline: status, mail triage, Typst documents."
version: 0.2.0
author: Shaoyan Ji (shaoyanji), Hermes Agent
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: ['apps', 'job-application', 'workflow', 'postgres']
    related_skills: []
---

# apps — the job-application pipeline

The pipeline lives in the archive database on delphi. Since `86bdb73b`
(2026-11-03) that database is the only writer: `appflow-sync.timer` advances
statuses from ATS mail hourly, and `applications.json` in the workflow checkout
is an export, not a source. Nothing imports it on a schedule.

| Where | Role |
| :--- | :--- |
| `applications` (Postgres, `email_archive`) | Source of truth |
| `application_mail` | The messages behind a record, with the rule that linked them |
| `application_document` | The job description and notes, keyed by application and kind |
| `/srv/data/projects/antigravity-application-workflow` | Typst documents only; retired as a source |
| `data/applications.json` there | Historical copy; `task apps:export` regenerates it |

## The flows

`task apps:list|search|get|update|overview|status` speak the archive API from any
tailnet host — they do not read the checkout. A status change is one command:

```bash
task apps:update -- <id> --status "Rejected (email 2026-10-23)"
```

`stage` and the next action follow from the status (`stage_of` in
`modules/plugins/appflow/sync.py`), so a rejection also clears the next action.
There is no push step and no JSON to reconcile.

`task apps:emails` shows what the hourly sync will drain. A message the rules
cannot prove stays in the queue and shows up there; a rejection the vocabulary
does not recognise is exactly the defect `checks:appflow:triage` now covers.
`apps:followups`, `apps:build` and `apps:audit` are the Typst half and need the
workflow checkout; they do not touch the pipeline rows.

Never hand-edit a JSON copy and never import it over the database: a stale file
reverts rows the mail hub discovered. If a snapshot is needed, `task apps:export`
writes one.

Truth: `taskfiles/apps.yml` and `docs/email-archive.md` — the executable contract
and the API; this page is the procedure.
