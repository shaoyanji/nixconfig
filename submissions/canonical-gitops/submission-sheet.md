# Canonical — Senior Site Reliability / GitOps Engineer (Information Systems)

**Status: packet staged, not submitted.** **[applied per apps DB `canonical-senior-site-reliability-gitops-engineer` — this sheet's status predates submission]** Prepared 2026-11-21. Nothing sent.

## Role

| Field | Value |
| :--- | :--- |
| Company | Canonical |
| Role | Senior Site Reliability / Gitops Engineer |
| Team | Information Systems (IS) |
| Role ID | `canonical-senior-site-reliability-gitops-engineer` |
| Apply URL | https://job-boards.greenhouse.io/canonical/jobs/5517891 |
| Greenhouse job id | 5517891 (posting updated 2026-10-09) |
| Location | Home based – Worldwide |
| Employment | Full-time |
| Compensation | Not published. Target **EUR 130,000 – 150,000** (or **USD 140,000 – 165,000**). |
| Category / language | `tech`, `en` |
| JD | `job-description.txt` (HTML stripped for the selector; the raw source stays at `~/.config/appflow/jd/canonical-senior-site-reliability-gitops-engineer.txt`) |

## Candidate facts

| Field | Value |
| :--- | :--- |
| Name | Matt Ji |
| Address | Am Burgerhof 4, 79261 Gutach im Breisgau, Germany |
| Email | matt@bountystash.com |
| Phone | +49 1733281570 |
| LinkedIn | https://linkedin.com/in/mattji |
| GitHub | https://github.com/shaoyanji |
| Website | https://www.bountystash.com |
| Citizenship | United States |
| Residence | Germany — unbefristete Niederlassungserlaubnis (permanent) |
| Work authorization | US and Germany/EU; no visa sponsorship required |
| German | C1 (verhandlungssicher) |
| English | Native |
| Availability | 01.12.2026 |

## Files

- `lebenslauf.pdf` — **2 pages** A4, PDF/UA-1 tagged, page budget enforced by `lib/typeset.nix`
- `anschreiben.pdf` — **1 page** A4
- `selection.json` — engineering evidence; projects `nixconfig`, `email-archive`, `bountystash`, `fibtransponder`
- `job-description.txt` — cleaned JD used by the selector
- `submission-sheet.md` — this file

Build: `scripts/task/appflow-packet.sh` → `modules/plugins/appflow/packet.nix`; typst in the Nix sandbox, `cv-ats-check.sh` read the finished PDFs back against `work/resume.json` in the same derivation. Budgets reported 2 / 1, zero page-budget errors.

## Live Greenhouse form — fields and staged answers

Fields, ids and option sets read from the boards API on 2026-11-21. **This form has no cover-letter upload field** — `anschreiben.pdf` is reference material for interviews, not an upload.

| Field | Id | Required | Answer |
| :--- | :--- | :--- | :--- |
| First Name | `first_name` | yes | Matt |
| Last Name | `last_name` | yes | Ji |
| Email | `email` | yes | matt@bountystash.com |
| Phone | `phone` | no | +49 1733281570 |
| Resume/CV | `resume` | yes | `lebenslauf.pdf` |
| Own-words / no-AI attestation | `question_44059544` | yes | **Hold** — this packet was drafted with AI assistance; Matt must rewrite the essays in his own words before selecting Yes |
| Most notable SRE experience | `question_44059545` | yes | Draft below |
| Most notable software development experience | `question_44059546` | yes | Draft below |
| Homelab / self-hosted services | `question_44059547` | no | The fleet is the answer: thirteen NixOS hosts, a PostgreSQL mail archive, a media relay, CI and a binary cache. Note: the live option set for this question is a Python-proficiency scale, which looks like a form-building error — check it in the browser before answering |
| High-school mathematics | `question_44059549` | yes | **Cannot recall — PROVISIONAL** (options: Cannot recall / Not a strength / Top 50% … Top 0.01% in the region) |
| High-school native language | `question_44059550` | yes | **Cannot recall — PROVISIONAL** |
| Rationale for high-school selections | `question_44059551` | yes | No class rank, SAT or ACT on file, so "cannot recall" rather than an undocumented band. Verifiable: 3.2/4.0 GPA in Petroleum Engineering (Colorado School of Mines, 2010, calculus-bearing); MSc Renewable Energy Management, University of Freiburg, 1.8/5.0 (1.0 best) with a neural-network thesis |
| Bachelor's degree result | `question_44059552` | yes | `3.2/4.0 GPA (US 4.0 scale) — BSc Petroleum Engineering, Colorado School of Mines, 2010`; MSc `1.8/5.0 (German scale, 1.0 best) — Renewable Energy Management, University of Freiburg, 2014` |
| Travel 2–4 times a year, 1–2 weeks | `question_44059553` | yes | Yes |
| Region/timezone | `question_44059554` | yes | Europe — CET/CEST (Germany) |
| Current country of work | `question_44059555` | yes | Germany |
| Website | `question_44059556` | no | https://www.bountystash.com |
| LinkedIn | `question_44059557` | no | https://linkedin.com/in/mattji |
| Privacy notice | `question_44059558` | yes | Read, then acknowledge |
| Companies in the past ten years | `question_55251288` | yes | **2** — O3 Energy (2016–2020) and Bountystash (2020–2025, own company; EWE and Landvest were contracting under it) |
| Gender | `question_55390616` | yes | Prefer not to say |
| Nationality | `question_65123586[]` | yes | American |
| Race or ethnicity | `question_65123601` | yes | Prefer not to say |

### Draft — most notable SRE experience (`question_44059545`)

> A thirteen-host NixOS estate that I designed, operate and gate alone. The notable part is not the size but the loop: every host is a feature list in one repository, a change is evaluated by the same per-host gate in CI and on the machine, builds are hermetic and hash-pinned, a microvm canary boots before a rollout, and rollback is a generation switch. A sentinel records job status, generation age, disk and PSI every fifteen minutes and pages when a job goes silent. The services on it include a PostgreSQL mail archive with full-text search and SQL endpoints, and a media relay. Access is an SSH certificate authority with short-lived certificates plus per-host SOPS secrets, so there are no standing credentials.

### Draft — most notable software development experience (`question_44059546`)

> Bountystash, a Go service I built and still run: a request becomes an immutable, content-addressed specification with append-only events, exact hashes over canonical JSON and a quotient hash over the fields a reviewer sees, with Go tests and a keyboard-driven TUI rendered from the same binary. Notable for me is that the design work was about making disagreement legible — the hashes exist so a reviewer can see exactly what changed — and that the corpus's own benchmark later falsified a claim in fibtransponder, which I narrowed instead of defending. Before that, C++ software for a heliostat interferometer at Fraunhofer ISE.

## Staged answers for the recruiter call

**Compensation.** EUR 130,000 – 150,000 base, or USD 140,000 – 165,000 for a USD contract. Canonical publishes no band.

**Work authorization.** US citizen with permanent German residence (unbefristete Niederlassungserlaubnis); full right to work in Germany/EU and the US, no sponsorship now or later.

**Timezone.** Germany, CET/CEST; Canonical's IS team is distributed, and the listing is home-based worldwide.

## Fit map

| Requirement | Evidence | Assessment |
| :--- | :--- | :--- |
| Infrastructure as code, GitOps | One flake declares 13 hosts; every change is a reviewed commit; gate = CI and host | **Strong**, though Nix rather than Terraform/Ansible |
| Automation-first, product mindset | Hosts as feature lists, services as modules; platform used by the services it hosts | Strong in shape, single-operator scale |
| Python software development, large projects | Python for selector/analysis tooling, not large projects | **Gap**, stated in the letter |
| Kubernetes / container orchestration | Consumer-level only | **Gap**, stated |
| Linux networking, routing, firewalls | WireGuard mesh, networkd, PXE/TFTP/HTTP boot, nftables | Meets |
| Linux storage, Ceph to databases | ZFS/NVMe, PostgreSQL, backup and restore drills; no Ceph | Partial |
| Enterprise Linux administration | Daily NixOS; Debian/Ubuntu as consumer and debugger | Partial |
| Observability: Prometheus, Grafana, Elasticsearch | Own sentinel + Gatus paging; not the named tools | Adjacent, **gap** on tooling |
| Cloud computing concepts | AWS/GCP familiarity in skills; no production ownership | Partial |
| Troubleshooting kernel to web | Kernel pinning, systemd, networking, Go services, Postgres | Meets |
| Open source / Ubuntu affinity | Public repos, NixOS, Ubuntu consumer; no upstream Ubuntu contributions | Partial — do not overclaim |
| Location / authorization | Germany, permanent residence, no sponsorship | **Strong** |

## Before submitting

- [ ] Matt to rewrite both essays in his own words and own the attestation.
- [ ] Answer the two high-school ratings (only unsupported answers).
- [ ] Check the homelab question in the browser — its live option set is a Python scale, likely a form error.
- [ ] Confirm the EUR 130–150k proposal.
- [ ] Attach the CV only; there is no cover-letter field.
- [ ] Submit only on explicit instruction.

No application was submitted.
