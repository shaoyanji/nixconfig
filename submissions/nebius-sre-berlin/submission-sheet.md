# Nebius — Senior Site Reliability Engineer (SRE)

Berlin, office/hybrid. English packet. Native Typst sources; `selection.json` and the old Nix-built PDFs are removed.
Status: compiled and checked, **nothing submitted**.

| Field | Value |
| :--- | :--- |
| Role ID | `nebius-sre-berlin` |
| Employer | Nebius (Nasdaq: NBIS) |
| Role | Senior Site Reliability Engineer (SRE) |
| Location | Berlin; the Greenhouse posting also lists Remote - Europe |
| Language | **en** |
| Apply URL | https://www.arbeitnow.com/jobs/companies/nebius/senior-site-reliability-engineer-sre-berlin-252266 |
| Real ATS | Greenhouse **4376374101** — https://job-boards.greenhouse.io/nebius/jobs/4376374101 |
| Compensation | not published; staged target 130,000–160,000 EUR, **not quoted in the letter** |
| Fit | 3 (DB entry 4) |

## What the posting asks

Fault tolerance, scale and uninterrupted operation; cloud technology applied to infrastructure problems; CI/CD
improvement. Requirements: **Go, Python or C++**; classic algorithms and data structures; **commercial experience with
and deep understanding of Unix systems and network technology**; containerisation and configuration management —
**Ansible, Salt, Terraform, Docker, Kubernetes, Helm**. Bonus: backend development, high-load distributed systems,
several cloud platforms. Coding interviews are part of the process.

## Fit map

| Requirement | Evidence | Verdict |
| :--- | :--- | :--- |
| Unix systems depth | systemd, cgroups, PSI, signals, `strace`, memory-capped slices | **strong** |
| Network technology | nftables, WireGuard, own DNS, SSH CA, MTU proven with `tcpdump` | **strong** |
| Go / Python | Go service with tests, Python tooling | strong |
| Classic algorithms and data structures | Zobrist hashing and benchmarks in `fibtransponder`; no interview-style drilling claimed | partial |
| CI/CD | Gate identical in CI and host, inventory-driven matrix | strong |
| Fault tolerance, uninterrupted operation | Generation rollback, canary, telemetry that pages on silence | strong at small scale |
| Docker / Kubernetes / Helm | **none** | **gap, required** |
| Ansible / Salt / Terraform | **none**; configuration management is a Nix flake | **gap, required** |
| High-load distributed systems | **none at that scale** | gap, bonus only |
| Cloud platforms | bare metal only | gap, bonus only |
| Work authorisation in Germany | permanent residence, no sponsorship | fulfilled |
| Location | Germany; Berlin hybrid acceptable | workable |

Fit **3**. Two of the strongest columns in this corpus — Unix internals and network troubleshooting — are exactly what the
posting names as its differentiator, and the containerisation/configuration-management list is entirely absent. Sheet says
3; the DB keeps the instructed 4.

## Location discrepancy, worth settling first

The aggregator listing says **Berlin, remote: no**. The Greenhouse posting for the same role lists eight locations
including **Berlin** and **Remote - Europe**. The letter states the candidate is in Germany, works hybrid in Berlin, and
asks what office rhythm the team actually keeps. Confirm before accepting a process built around daily presence.

## The argument the letter makes

A GPU cloud is a bet that software can make expensive, failure-prone hardware behave like a dependable service, and that
bet is won in the boring places: a node that loses its network being noticed before a customer notices, a bad rollout with
a way back that does not depend on the shipper being awake, and page numbers that mean something. The packet then argues
the small version of that problem honestly — thirteen bare-metal hosts, a gate identical in CI and host, generations with
parents, a ledger that pages on silence — and stops where the experience stops.

The gap paragraph is explicit: no Kubernetes, Docker or Helm in production, no Ansible, Salt or Terraform, thirteen
machines rather than a GPU fleet. One line carries the honesty without apology: *my configuration management is a flake,
which is a real answer to the same problem and not the same tool.*

## Checks

| Check | Result |
| :--- | :--- |
| `selection.json`, old Nix-built PDFs | removed |
| `chmod u+w *.pdf` | applied |
| `typst compile lebenslauf.typ` | exit 0, no warnings |
| `typst compile anschreiben.typ` | exit 0, no warnings |
| `pdfinfo lebenslauf.pdf` | **2 pages** |
| `pdfinfo anschreiben.pdf` | **1 page** |
| Markers CV | `PSI`, `strace`, `tcpdump`, `cgroups` |
| Markers letter | `Kubernetes` (gap), `terraform` (gap), `Berlin`, `silence` |
| `task checks:prose` | 248 prose files, exit 0 |
| sha256 CV | `4ab205d5daba0e403fe8442ea8db65e079706d81ff16a2cc1da7a4d4d34b7073` |
| sha256 letter | `cbc576e15174d2450ef1f9f98c0d47d4173364dd7c7cd6b00d2a7d26ceb41fa6` |
| DB read-back | verified after upsert |

## Next steps

1. Apply through Greenhouse 4376374101, not the aggregator.
2. Confirm the office expectation and the remote-Europe option, since the two listings disagree.
3. The process includes coding interviews: expect algorithms and a networked-systems problem, and prepare the Zobrist and
   `fibtransponder` work as the honest sample.
