# Adyen — Senior Platform Engineer - Observability (Amsterdam)

Greenhouse req **7607691**. English packet. Native Typst sources; the old `packet/` directory (Nix-built PDFs plus
`selection.json`) and `letter.json` are removed.
Status: compiled and checked, **nothing submitted**. **[applied per apps DB `adyen-platform-observability` — this sheet's status predates submission]**

| Field | Value |
| :--- | :--- |
| Role ID | `adyen-platform-observability` |
| Employer | Adyen |
| Role | Senior Platform Engineer - Observability |
| Location | Amsterdam — **office-first, no remote-only** |
| Language | **en** |
| Apply URL | https://job-boards.greenhouse.io/adyen/jobs/7607691 |
| Compensation | not published in the posting; staged floor €95,000, not quoted in the letter |
| Fit | **2** (DB entry 4) |

## What the role actually asks

Build and run the observability pillars — logs, metrics, traces — for hundreds of product teams, on premise and on
Kubernetes: **1,500+ servers**, **petabytes** of telemetry, Elasticsearch/OpenSearch/VictoriaLogs/ClickHouse for logs,
Prometheus/VictoriaMetrics for metrics, Grafana Tempo for traces, OpenTelemetry at peak traffic. Automate operations,
build self-healing systems, add tenant quotas and guardrails, redesign for new regions with data isolation. **10+ years**
in observability or a relevant platform domain; production Kubernetes; Go or Python beyond scripting.

## Fit map

| Requirement | Evidence | Verdict |
| :--- | :--- | :--- |
| 10+ years observability / platform | ~5 years fleet and telemetry work, 5 more in data-heavy commercial roles | **short of the bar** |
| Elasticsearch / OpenSearch / VictoriaLogs / ClickHouse | **none** | **gap** |
| Prometheus / VictoriaMetrics | **none**; bespoke ledger and alerting | **gap** |
| Grafana Tempo, OpenTelemetry | **none** | **gap** |
| Production Kubernetes, kubectl primitives | **none** | **gap, required** |
| Linux at kernel level, bare metal and virtualised | cgroups, PSI, nftables, `tcpdump`, `strace`, MTU work | **strong** |
| Alerts engineered out of existence | Every repeated checklist item becomes a check in the gate | **strong** |
| Self-healing without night intervention | Bounded restarts, capped slices, declared microVMs, canary, rollback by pointer | strong in kind, small in scale |
| Go / Python tools, infrastructure as code | Go service, Python tooling, one validated entry surface | strong |
| Multi-tenant isolation, quota, cost governance | **none** | **gap, nice-to-have** |
| Regulated environments | **none** | gap, nice-to-have |
| Office-first Amsterdam | requires relocation and a Dutch permit | **decision, stated in the letter** |

Fit **2**: two of the four core columns (the data stores and the orchestrator) are absent, and the ten-year domain bar is
not met. The packet is still worth sending — the Linux and alerting columns are genuinely strong — but it should be sent
with that expectation, not as a strong-fit application.

## Location, permit, and what the letter says

The posting ends with the constraint that decides this application: *"This role is based out of our Amsterdam office. We
are an office-first company ... we do not offer remote-only roles."* Amsterdam is a move from Gutach im Breisgau, not a
commute.

- **Relocation is required**, and the letter says so in its own paragraph rather than leaving it to be discovered.
- **Permit needed.** German permanent residence does not transfer. The Dutch route is a highly-skilled-migrant
  (*kennismigrant*) permit, which requires a recognised sponsor — **confirm Adyen's sponsor status at first call**, and
  check the salary threshold for the 30+ route against the offer.
- **No published band**, so no comparison to make in advance. Do not volunteer a number first; the staged floor is
  €95,000.
- English is the office language and German C1 makes the move socially easy; the honest risk is timing, not willingness.

## The argument the letter makes

It opens on the one line in the posting that describes how this candidate actually works — participation in on-call, but
a primary focus on **engineering alerts out of existence** — and then gives the mechanism: a fifteen-minute ledger
paging on state short of ok with a timeout on silence, thresholds chosen for signal, and every twice-failed checklist
item promoted into the gate so the incident cannot return wearing a different hat. Deep troubleshooting is argued from
the kernel outward, since that is the layer the corpus genuinely knows.

The gap paragraph is the longest in the letter and names all five missing pieces, because on a platform serving hundreds
of teams the ramp is real and pretending otherwise wastes everyone's first interview.

## Checks

| Check | Result |
| :--- | :--- |
| `packet/` directory, `letter.json` | removed |
| `chmod u+w *.pdf` | applied |
| `typst compile lebenslauf.typ` | exit 0, no warnings |
| `typst compile anschreiben.typ` | exit 0, no warnings |
| `pdfinfo lebenslauf.pdf` | **2 pages** |
| `pdfinfo anschreiben.pdf` | **1 page** |
| Markers CV | `PSI`, `ledger`, `cgroups`, `rollback` |
| Markers letter | `Elasticsearch` (gap), `Kubernetes` (gap), `Amsterdam`, `silence` |
| `task checks:prose` | 246 prose files, exit 0 |
| sha256 CV | `79c2f831f2a7a3f74bdaed011222e7ded412b610e287b22e6d0ae1edb5c4fb08` |
| sha256 letter | `3a6214dcedab6213a4b1c45d88e6e047bfbe985114386d7f1883b529f94f3a49` |
| DB read-back | verified after upsert |

## Next steps

1. Confirm the sponsorship route and the salary threshold before investing in a four-week process.
2. Ask which pillar is the operational sore point — logs, metrics or traces — since the posting lists four log stores,
   which usually means at least one is legacy.
3. Expect the gap to be tested directly: the honest answer is that the stores and Kubernetes are new, the Linux and
   alerting instincts are not.
