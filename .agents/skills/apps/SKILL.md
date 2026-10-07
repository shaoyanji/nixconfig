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

# apps — Job Application Workflow (appflow)

Drive the job-application pipeline at `/srv/data/projects/antigravity-application-workflow` (cloned from `shaoyanji/antigravity-application-workflow`). All tasks are thin wrappers around that repo's `bin/appflow` CLI (bash + uv + SQLite + Typst + Himalaya — no Node, no Playwright).

## Tasks

| Task | Description |
|------|-------------|
| `apps:list` | List tracked applications (pass extra filters via `--`) |
| `apps:search -- <query>` | Search by company, role, ID, or keywords |
| `apps:get -- <id>` | Full details of one application record |
| `apps:update -- <id> --status <S>` | Update application status or notes |
| `apps:overview` | Pipeline summary: application counts per status |
| `apps:emails [--limit N]` | Inbound Himalaya email radar + status sync |
| `apps:followups [--copy <id>]` | Recruiter follow-up notes (clipboard) |
| `apps:build [<target>\|--all]` | Compile Typst resumes/cover letters to `dist/` |
| `apps:audit` | QA layout, page budget, orphan-line audit |
| `apps:query -- "<sql>"` | Read-only SQL against `applications.db` |
| `apps:sync:status` | JSON ↔ SQLite ↔ GitHub sync state |
| `apps:sync:push` | Reconcile JSON (source of truth) → DB/CSV, commit, push |
| `apps:sync:pull` | Pull remote changes, reconcile local DB |
| `apps:git:status` | Raw git status of the workflow checkout |
| `apps:menu` | Interactive Gum menu |

## Canonical layout (inside the workflow repo)

| Path | Role |
|------|------|
| `data/applications.json` | Source of truth — wins sync conflicts, tracked in git |
| `data/applications.db` | SQLite cache, rebuilt by sync |
| `data/application_planner_master.csv` | Google Drive/Sheets mirror |
| `bin/appflow` | CLI entrypoint (invoke directly to bypass tasks) |
| `src/applications/<tech\|service>/` | Per-application Typst sources |
| `dist/` | Compiled PDFs |

## Conventions

- Status updates flow: `task apps:update -- <id> --status "Interview Scheduled"` then `task apps:sync:push` to persist JSON/DB/CSV and push to GitHub.
- Email flow: `task apps:emails` scans inbound mail (Himalaya), matches recruiter replies to applications, and updates statuses; draft/reuse follow-ups with `task apps:followups --copy <id>`.
- Never hand-edit `applications.db` — mutate `applications.json` (or use `apps:update` / `apps:emails`) and let sync reconcile.
- Heavy interactive submission automation lives in the workflow repo's own skills (`antigravity-application-workflow`, `playwright-job-submission`), not here.
