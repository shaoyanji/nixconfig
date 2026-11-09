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
| `schema.sql` | `applications`, `application_mail`, `application_document` — applied after the core schema on every activation |
| `sql/` | the endpoints (`/api/applications`, `/api/application-get`, …) |
| `sync.py` | import the JSON, link mail, write status from ATS mail, export, discover — and close what proves nothing (job alerts, events the stage already holds) so the queue cannot refill |
| `packet.nix` | the PDF build: typst in the sandbox, artifact is a store path |
| `select.py` | the projection: one job description, one page of material out of the corpus |
| `glossary.json` | German job-ad words mapped onto the English ones the corpus uses |
| `templates/` | two templates, localized through `strings.json`, no personal data |

## Removal

Delete `services.appflowPlugin.enable` from the host and this directory stops being
imported. Its tables and endpoints go with it; the routing rules vanish because the
classifier reads them from config, not from a hardcoded list.

## The corpus and the projection

The base resume is a **corpus**, not a page. Every role keeps all its highlights,
every project stays in the file, because the budget is applied per application
rather than once by hand — a bullet that only matters for one employer is not a
reason to keep the CV short everywhere.

```bash
task agents:apps:select JD=<file>      # what this description keeps, and what it drops
task agents:apps:packet ID=<app>       # uses ~/.config/appflow/jd/<id>.txt when it exists
task agents:apps:packet ID=<app> JD=-  # read the description from stdin
```

`select.py` scores each highlight against the description: a term counts more the
rarer it is in the corpus, and a term from the resume's own keywords counts 2.5×
because it is vocabulary the operator already uses for the work. Verbs that both
a CV and an ad own (*build*, *manage*, *experience*) are dropped, because matching
one of them ranks nothing. Every role survives; a role the description says
nothing about keeps its two lead lines and the audit records `matched: false`, so
a thin role is visible rather than silently padded. Education, languages and the
list of employers are never touched.

The output is a normal JSON Resume, so the template, the site and the gist all
read it without knowing the projection happened. `selection.json` sits beside the
PDF in the store path: which lines were kept, their scores, and what was dropped.

A description in German scores against an English corpus through
`glossary.json` — *Risikomanagement* → *risk*, *Verschlüsselung* → *encryption*,
*Schlüssel* → *key*. The list is domain words only, and a missing pair shows up as
a role that falls back to its lead lines instead of a wrong selection. A term
matches its inflections and plurals, and a hyphenated compound carries its parts,
so an entry written once reaches the form the corpus happens to use: `encryption`
finds `encrypted`, `key` finds `keys`, and `SOPS-encrypted` is also `encrypted`.
Without that, a correct glossary entry scored zero and selected nothing.

## Commands

```bash
task agents:apps:import FILE=<applications.json>   # import + link (FILE=- for stdin)
task agents:apps:sync                              # write status from ATS mail (DRY=1 to preview)
task agents:apps:export OUT=data/applications.json # the DB as the workflow's JSON
task agents:apps:packet ID=<application>           # build a packet through nix
task agents:apps:packet EXAMPLE=1                  # fictional data, proves the toolchain
task agents:apps:select JD=<file>                  # the projection alone, no PDF
task checks:appflow                                 # the selector's fixture
task apps:docs:import [DIR=~/.config/appflow/jd]       # the JD text into the database
  task apps:docs                                        # what text exists, no bodies
  task apps:docs:show -- <id> [kind]                    # one document's text
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

Language is a second corpus, not a second template. The record picks `de` or
`en`; the headings, section titles and month names come from `strings.json`, and
the prose comes from the matching resume. The German one is authored in this
repo (`lib/matt/lebenslauf.json`: the same five roles and ten projects, translated
bullet for bullet) and written to `~/.config/appflow/lebenslauf.json` by
`task matt:gist:sync-de`, which also carries the contact block the public copy
does not hold.

```bash
task matt:gist:drift     # every English role and project has a German counterpart
task matt:gist:sync-de   # lib/matt/lebenslauf.json -> $APPFLOW_CONFIG/lebenslauf.json
```

A `de` application builds from the German file when it exists, and says so when
it does not: German headings over English bullets is the one failure the record's
language is supposed to prevent.

A job description is a row: `application_document`, keyed by application and
kind (`jd`, `note`, anything a caller names), with the body as text and the
caller's `sha256` beside it. `task apps:docs:import` reads the old
`$APPFLOW_CONFIG/jd/<id>.txt` files into it and skips a file whose bytes are
already stored, so the import can run from a timer. `packet` and `select` still
accept a file, because a description can be pasted in before the row exists.

## Deletion gate

The files are retired only when both halves pass: `checks:appflow:gate` proves
the database is the only copy (the export and the row list agree, sampled rows
match field for field, every stored document's digest matches its bytes), and
`task apps:gate:packet -- <id>` builds a packet whose description came from the
database. A rebuild is ~95% reproducible — pinned typst, a corpus commit and a
deterministic selection; the slack is the prose a person or an agent writes —
so the packet is built when it is sent, not stored when it is tracked.
