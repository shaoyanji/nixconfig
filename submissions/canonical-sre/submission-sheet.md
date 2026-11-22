# Canonical — Senior Site Reliability Engineer

Greenhouse **3029798** · https://job-boards.greenhouse.io/canonical/jobs/3029798 · globally remote · no published band.
Evergreen pipeline requisition: first published 2021-03-31, updated 2026-08-05. The team runs hundreds of private-cloud, Kubernetes and
application clusters with Python infrastructure-as-code, and calls the work a software engineering problem rather than a scripting one.

**Applied 2026-11-21** per the apps DB (confirmation message 310966, right to work). This sheet reflects the native rebuild.

Native English Typst, 2026-11-22 — Typst 0.15.1, DejaVu Sans only.

## Files

| File | Pages | Words | Warnings | sha256 (first 16) |
| :--- | :--- | :--- | :--- | :--- |
| `lebenslauf.pdf` | 2 | 1169 | 0 | `a61b98f52996a807` |
| `anschreiben.pdf` | 1 | 468 | 0 | `428efcf98c400f2d` |

`lebenslauf.typ`, `anschreiben.typ`, `job-description.txt`, this sheet. `selection.json` retired in this rebuild.

## What changed

The submitted CV was 642 words over two pages, generated from the application database, and — measured on its own text — said nothing about
systemd semantics, alerting thresholds, telemetry shape or canary deployment, which are exactly the four things this role is screened on. It
also ended with the standard skills block: React, Next.js, Laravel, MySQL, Django, Kubernetes, AWS, Azure, Google Cloud.

The native CV is organised around the four pillars instead. Service lifecycle: explicit ordering and dependencies, sockets and timers instead
of polling, per-slice memory limits, start limits that stop a crash loop from saturating a machine, and the rule that an accepting socket is
not evidence the work finished. Telemetry: job status, generation age, disk and PSI to a ledger every fifteen minutes. Alerting: thresholds
kept in the repository, paging on any state short of ok and on silence, and a page that repeats weekly gets fixed or retired rather than
muted. Deployment: a canary guest built from the same definitions as its host, one writer per process, no fleet-wide default.

Submitted bytes: `lebenslauf.pdf` `060a2c736f7bfd74…` (2 pages, 642 words), `anschreiben.pdf` `30de985577fa0da7…` (1 page, 382 words).

## Gaps, in both documents

No production OpenStack, Kubernetes or Ceph operations — isolation is microVMs on KVM, orchestration is NixOS and systemd. No eBPF or
in-kernel tracing; telemetry is PSI plus a ledger plus generated metrics. Nothing at hundreds-of-clusters scale. Python is strong (FastAPI,
Flask, PostgreSQL, IMAP ingestion, fleet tooling) but there is no CPython-internals work.

OpenStack, Ceph, Kubernetes and eBPF appear in the CV only inside the paragraph declaring their absence; the scan shows no other mention.

## Fit

**3 of 5.** Strong on the reliability discipline the posting actually describes — metrics-driven operations, code over toil, Linux and
networking depth, canary and rollback practice — and on the Python-plus-operations combination. Short on the platform triad the team runs
(OpenStack, Kubernetes, Ceph) and on its scale.

## Compensation and route

EUR 120,000–150,000 staged for a world-wide remote contract; Canonical publishes no band and shapes pay by geography, experience and
performance. The form's own-words attestation (`I agree to use only my own words — AI content disqualifies`) is marked **Hold**: it is the
applicant's affirmation, not an agent's, and the six free-text answers must be made his own first.

## Checks

| Gate | Result |
| :--- | :--- |
| `typst compile` both sources | 0 warnings each |
| Page budget | CV 2 pages, letter 1 page |
| `**` in sources | 0 |
| Unsupported platform claims | 0 outside the negation paragraph |
| `task checks:prose` | exit 0 |
| Commit | native rebuild, `selection.json` removed in the same commit |
