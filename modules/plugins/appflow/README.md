# appflow — the job-application plugin (a guest)

A plugin of the mail hub on delphi. It owns the pipeline tables, the endpoints that
read and write them, the routing rules that send application mail its way, and the
importer/sync that keeps the rows current. The hub knows none of that: it knows
`rules`, `sql`, `schema` and `packages` (`services.emailArchive.plugins`).

**It is not a first-class citizen, and it is not the upstream project.** The
workflow at `shaoyanji/antigravity-application-workflow` is a data source: its
`applications.json` is imported, its per-company Typst directories, its CSV, its
Supabase migration and its CLI are not reproduced here. One template and a
database diff replace sixty copies of the same layout.

## What it adds

| Path | Owner |
| :--- | :--- |
| `schema.sql` | `applications`, `application_mail` — applied after the core schema on every activation |
| `sql/` | the endpoints (`/api/applications`, `/api/application-get`, …) |
| `sync.py` | import the JSON, link mail, write status from ATS mail, export, discover — and close what proves nothing (job alerts, events the stage already holds) so the queue cannot refill |
| `packet.nix` | the PDF build: typst in the sandbox, artifact is a store path |
| `templates/` | two templates, localized through `strings.json`, no personal data |

## Removal

Delete `services.appflowPlugin.enable` from the host and this directory stops being
imported. Its tables and endpoints go with it; the routing rules vanish because the
classifier reads them from config, not from a hardcoded list.

## Commands

```bash
task agents:apps:import FILE=<applications.json>   # import + link (FILE=- for stdin)
task agents:apps:sync                              # write status from ATS mail (DRY=1 to preview)
task agents:apps:export OUT=data/applications.json # the DB as the workflow's JSON
task agents:apps:packet ID=<application>           # build a packet through nix
task agents:apps:packet EXAMPLE=1                  # fictional data, proves the toolchain
task agents:apps:draft ID=<app> BODY=<file> ATTACH=<pdf>   # a DRAFT in the mailbox, never sent
task agents:apps:drafts                            # what sits in Drafts
task agents:hub                                    # every plugin's queue depth
```

Drafts are the safe half of sending: `--draft` writes into the mailbox's Drafts
folder, where a person reads, edits or discards it, and reports the attachment it
carried. No verb here can send mail. Reporting tasks print TOON, which is what an
agent reads; `FORMAT=text` gives a person a table and `FORMAT=json` a machine.

**The queue drains itself.** `appflow-sync.timer` runs `--sync --apply` hourly
(11 minutes after the classifier files the mail at :49), so a status update or a
new application does not wait for someone to type the task. `sync.enable = false`
turns the drainer off and leaves the verbs above.

## Personal data

The repository is public. The base file is `~/.config/appflow/resume.json` — a
[JSON Resume](https://jsonresume.org) with the contact block, work and education;
it is never committed, and `templates/example/resume.json` is the fictional stand-in
that lets the build be tested. A per-application `letter.json` is passed with
`--letter` and stays where the operator keeps it.

Language is not a second document: the application record picks `de` or `en`, the
templates read their headings from `strings.json`, and the CV section titles and
month names come from the same table.
