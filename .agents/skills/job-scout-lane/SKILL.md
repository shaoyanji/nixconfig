---
name: job-scout-lane
description: "Scout-to-send in one task: sweep the boards, dedupe, read the JD, tailor CV and letter, build the packet, send, poll for replies, prove the CV site — each stage delegating to the verb that owns it."
version: 0.1.0
author: Shaoyan Ji (shaoyanji), Freebuff
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: ['apps', 'job-application', 'scout', 'pipeline', 'gate']
    related_skills: ['apps', 'xs-turns', 'prove-it-works']
---

# job-scout-lane — one entry point from a board listing to a sent application

Pick me when a lead has to travel from a sweep's shortlist to a sent application, or
when someone asks why one did not leave. The lane has eight verbs; this is the order
they run in and the refusal that proves each one happened.

```bash
task apps:lane STAGE=plan              # the chain, nothing written
task apps:lane STAGE=sweep SWEEP=<id>  # boards, traps, write rules
task apps:lane STAGE=jd ID=<row>       # the posting text into $APPFLOW_CONFIG/jd/<row>.txt
task apps:lane STAGE=tailor ID=<row>   # which lines the ad keeps
task apps:lane STAGE=packet ID=<row> LANGUAGE=de
task apps:lane STAGE=send ID=<row>     # dry; SEND=1 to transmit
task apps:lane STAGE=replies ID=<row>
task apps:lane STAGE=cv                # the published CV is this build
```

`STAGE=file` prints the dedupe query and the `apps:scout` invocation rather than
filing blind: a lead needs a company, a role and a family, and those come from a
read posting, not from a board card.

## What each stage proves

`sweep` proves nothing — it prints the read order and the trap each board hides, so
the next agent reads the ad rather than a listing. `jd` proves the text is an ad: a
page under 40 non-empty lines is a JavaScript gate or a stub, so the stage deletes
the file and exits 3 instead of handing a packet some navigation chrome. `tailor`
proves the projection: `agents:apps:select` reports which highlights the description
kept and which roles fell back to their lead lines. `packet` proves the document:
the page budget refuses a spill and `cv-ats-check.sh` reads the PDF back against the
record it was compiled from. `send` proves all three preconditions together — the row
sits at `prep`, its next action names a date that has passed, and a recipient exists.
`replies` proves what the archive holds, which for an unsent row is nothing.
`cv` proves the site publishes this build and every published CV is linked.

## Claims carry their evidence

Every load-bearing sentence in a packet needs one command that settles it. The
Hisolutions packet (2026-11-27) is the worked example: three lines died because
nothing backed them.

| Claim | What settles it |
| :--- | :--- |
| "25 NixOS hosts" | `nix eval --json .#inventory.hosts \| jq '[.[]\|select(.kind=="nixos")]\|length'` |
| "the same module gate per host in CI" | `task check:list KIND=host`, `.github/workflows/` |
| "gatus, alert bridge, sentinel ledger" | `hosts/delphi/configuration.nix`, `modules/services/fleet-alert-bridge/`, `task ops:health` |
| "SOPS secrets behind an SSH CA" | `modules/secrets.yaml`, `.sops.yaml` |
| "Terraform not run in production" | `find . -name '*.tf'` answers nothing |
| "no Prometheus/Grafana stack" | `hosts/gok/instance.nix` holds node_exporter only |

A claim with no row is deleted, not softened — "Prometheus und Grafana" and
"Helm-nahe Definitionen" both went that way. A claim the repo disproves becomes
the limit it is, in the letter's own words ("Terraform nicht im Produktivbetrieb
geführt").

## The traps that cost a real sweep

Fetching a Stepstone ad needs `Referer: https://www.stepstone.de/jobs/devops-engineer`
and a browser user agent; without them the page answers a challenge body, not the ad.
germantechjobs and de.talent.com serve their posting through JavaScript, so `curl`
returns roughly 6 KB of "Almost ready" and the ad is unread. Those two rows carry a
next action that says read it in a browser; a packet built on that page would be
fiction.

Most scouted leads are portal applications with no mailbox in the posting. The send
verb refuses them for that reason and no override fixes it: submitting is the
operator's click on the posting, and the ledger records `prep` until then.

A row's own next action holds the send. `appflow-send.sh` greps the first date out of
that field, so a stamped date placed in front of the hold silently unlocks it — a
poll note belongs after the hold date, never before.

One employer is one live thread. `task apps:search -- "<company>"` before
`apps:scout`; the dupes gate merges a second requisition into the tracked row instead
of filing a replacement beside it. A message already sent means the next one is a
follow-up, not another application.

Nothing job-related lives in this repo: packets, letters and JDs sit under
`~/.local/state/appflow/` and `~/.config/appflow/`, and `submissions/` is refused
even under `git add -f`.

Truth: `taskfiles/apps.yml`, `scripts/task/appflow-packet.sh`,
`scripts/task/appflow-send.sh`, `scripts/task/apps-db.sh`, `.agents/skills/apps/SKILL.md`.
