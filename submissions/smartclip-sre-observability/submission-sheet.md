# smartclip Europe GmbH — Site Reliability Engineer (f/m/d) — Observability & Internal Tools

**Status: packet prepared, nothing submitted.** Source is a hiddenjobs.dev listing, last verified by
the board on 2026-11-22; it publishes no salary, experience level or employment type.

| Field | Value |
| :--- | :--- |
| Role ID | `smartclip-sre-observability` |
| Employer | smartclip Europe GmbH |
| Location | Germany, **remote-first**; Berlin/Cologne for larger initiatives |
| Language | `en` (the description is in English) |
| Salary target | **80.000 – 85.000 EUR** |
| Benefits | 30 days + 24/31 Dec, optional four-day week (focus Fridays), transport subsidy, bike leasing, health offers |
| Apply URL | https://hiddenjobs.dev/company/smartclip-europe-gmbh/jobs/site-reliability-engineer-f-m-d-observability-internal-tools-0cdc83e8/ |

## Candidate facts used

| Fact | Value |
| :--- | :--- |
| Name | Matt Ji |
| Address | Am Burgerhof 4, 79261 Gutach im Breisgau, Germany |
| E-mail / phone | matt@bountystash.com / +49 1733281570 |
| Languages | English native, German C1 |
| Right to work | German permanent residence, no sponsorship needed |
| Start | immediately or by agreement |

## The observability claim, checked against the repository

The role is centred on Prometheus, Grafana and Forgejo, so the packet separates what exists from
what does not. This is the same test the letter applies:

| Thing | In this fleet? | Where |
| :--- | :--- | :--- |
| `node_exporter` | **yes**, declared on a fleet host | `hosts/gok/instance.nix`, `:9100` |
| Prometheus server / Alertmanager | **no** | nothing in `modules/`, `hosts/`, `flake/` |
| Grafana | **no** | nothing in the tree |
| gatus health checks | **yes** | 9 files, `modules/services` and taskfiles |
| Sentinel ledger (job status, generation age, disk, PSI, 15 min) | **yes** | `modules/services/fleet-sentinel.nix` |
| Forgejo | **as a remote**, through its REST API | `scripts/task/gitenvs.sh`, `taskfiles/envs.yml` (`git.envs.net`) |
| Self-hosted forge | **no** | the fleet uses that remote, it does not run one |
| GitOps in substance (repo is desired state, host pulls) | **yes** | `nixconfig` flake, one declaration for thirteen hosts |

Measured on the built CV: **Linux ×3, cgroup ×3, PSI ×2, node_exporter ×2, GitOps ×2, gatus ×1,
telemetry ×1, observability ×1**, and **Prometheus, Grafana, Forgejo, SLO zero times**. The CV does
not borrow the posting's vocabulary for tools the fleet does not run; the letter names them and says
where the line is.

## Fit map

| Requirement (description) | Evidence | Verdict |
| :--- | :--- | :--- |
| Own the observability ecosystem: Prometheus, Grafana, Forgejo | node_exporter on a fleet host, gatus, sentinel ledger, Forgejo REST API. No Prometheus server, Alertmanager or Grafana | partial — exporter and practice yes, the two servers no |
| Turn monitoring into a platform-grade capability | Telemetry, alerting, health checks and runbooks live in the same repository as the hosts | strong in substance |
| Actionable alerts, SLOs, reactive → proactive | Alerts fire on state, and a repeated manual check becomes a gate. Formal SLOs with error budgets are new | partial |
| Evaluate open-source alternatives to proprietary software | The fleet is built from open components; the site, CV and tools are self-hosted | strong |
| Security embedded in the delivery pipeline | SOPS/age, SSH CA with short-lived certificates, nftables default-deny, gates in CI and on the host, KEV-based vulnerability practice | strong |
| Linux internals and distributed tooling | systemd, cgroups, PSI, tcpdump, DNS/MTU; thirteen hosts, not a distributed system | strong Linux, gap on distributed |
| Infrastructure as code | One flake, pinned inputs, feature-list hosts, declarative secrets | strong |
| Building rather than configuring, portfolio that ships | Public `nixconfig`, Go/Python services, site and CV built from source | strong |
| Enable other engineers through automation | Task control plane as the single operator surface; every repeated operation becomes a command with a check | strong |

## Application route

hiddenjobs.dev is an aggregator; the listing does not expose an application form or an employer ATS
in the fetched page. Submit through the listing's outbound link when it resolves, and if it forwards
to a smartclip careers page, use that form with the documents below. Nothing about the employer's
own schema could be read, so no field mapping is invented here.

| Document | File |
| :--- | :--- |
| CV | `lebenslauf.pdf` (2 pages) |
| Cover letter | `anschreiben.pdf` (1 page) |
| Letter source | `letter.json` |
| Corpus | `resume.json` |
| Projection audit | `packet/selection.json` |

## What the letter says

It opens on the "guardian and architect" framing and owns it: the platform, monitoring and runbooks
are his. The second paragraph is the platform — one flake, repository as desired state, task control
plane, forge REST API, releases and rollback, security in the path. The third is the observability
paragraph and the decisive one: the ledger, gatus, node_exporter on `:9100` — then the explicit
statement that no Prometheus server, Alertmanager or Grafana has been operated, and that formal SLOs
are new. The fourth offers the builder record and concedes the scale (thirteen hosts, not a shared
platform). The fifth states the range, the start date and the remote-in-Germany fit.

## Checks

| Check | Result |
| :--- | :--- |
| `pdfinfo lebenslauf.pdf` | **2 pages** (budget 2) |
| `pdfinfo anschreiben.pdf` | **1 page** (budget 1) |
| `task checks:prose` | 207 prose files, exit 0 |
| selection | 12/26 highlights, 4/9 projects |
| sha256 CV | `2bbfd44c135051c7a7ed1365813150c7f404381d08407c1932fe8d8249b9bb2b` |
| sha256 letter | `8887bb2e53560135c17fd1a92b646540c1748fadc6f19ae39f1a30bf6e964119` |

## Next actions

1. Resolve the listing's outbound link to the employer form; the aggregator page carries none.
2. Lead the first call with the `nixconfig` repository — the posting asks for a portfolio that proves
   shipping, and this is it.
3. Be ready for the Prometheus question: the honest answer is exporter and alert design yes, server
   and Grafana dashboards no, and the ledger is the evidence that the reasoning transfers.
