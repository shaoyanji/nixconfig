---
name: apps
description: "Job application pipeline: status, emails, Typst docs."
version: 0.1.0
author: Shaoyan Ji (shaoyanji), Hermes Agent
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: ['apps', 'job-application', 'workflow']
    related_skills: []
---

# apps — the job-application pipeline

Tasks are thin wrappers over `bin/appflow` in
`/srv/data/projects/antigravity-application-workflow` (bash + uv + SQLite +
Typst + Himalaya). Running `bin/appflow` directly is allowed; the tasks add no
logic.

| Path | Role |
| :--- | :--- |
| `data/applications.json` | Source of truth, tracked, wins conflicts |
| `data/applications.db` | SQLite cache, rebuilt by sync |
| `data/application_planner_master.csv` | Sheets mirror |
| `src/applications/<tech\|service>/` | Typst sources per application |
| `dist/` | Compiled PDFs |

## The two flows, and the one rule

A status change is `apps:update -- <id> --status "<S>"`, then `apps:sync:push`,
which reconciles JSON → DB/CSV, commits and pushes. Skip the sync and the change
exists only in the DB, which the next pull overwrites.

An inbound recruiter reply is `apps:emails` (Himalaya scan, matches replies to
applications and updates statuses); `apps:followups --copy <id>` drafts one.
`apps:audit` is the layout/page-budget check to run before `apps:build`.

Never hand-edit `applications.db`. Submission automation (Playwright) lives in
the workflow repo's own skills, not here.

Truth: `taskfiles/apps.yml` — the executable contract; this page is the procedure.
