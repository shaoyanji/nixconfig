# smartclip Europe GmbH — Site Reliability Engineer (f/m/d), Observability & Internal Tools

English packet. Native Typst sources, `packet` symlink and JSON leftovers removed.
Status: built and checked, **nothing submitted**.

| Field | Value |
| :--- | :--- |
| Role ID | `smartclip-sre-observability` |
| Employer | smartclip Europe GmbH, Hamburg |
| Role | Site Reliability Engineer (f/m/d) — Observability & Internal Tools |
| Language | **English** |
| Compensation | no band published; no figure in the letter |
| Fit | 3 (DB entry 4) |

## Fit map

| Requirement | Evidence | Verdict |
| :--- | :--- | :--- |
| Observability design, signal over volume | Fifteen-minute ledger, any-state-short-of-ok, blindness as fault | strong |
| Alerting that carries a decision | Alerts routed on measured state, not on thresholds alone | strong |
| Linux internals | systemd, journald, cgroups/PSI, tcpdump, strace, nftables | strong |
| Declarative / GitOps thinking | One declaration for thirteen hosts, gate identical in CI and host | strong |
| Internal tools | Task surface with named arguments, Go service on PostgreSQL, data pipeline | strong |
| SLO reasoning | Rollback by generation, records answering "what changed, how to go back" | strong in practice, no formal SLO programme |
| Prometheus / PromQL | **not operated in production** | **gap** |
| Grafana | **not used** | **gap** |
| Kubernetes | **not administered** | **gap** |
| Forgejo / self-hosted git | self-hosted git remote in own fleet; no Forgejo administration | partial |
| German C1 / English native | German CVs and letters across the queue; English native | fulfilled |

## The three claims in the brief that the corpus does not support

The assignment asked to highlight **Prometheus**, **Grafana** and **declarative GitOps**. Prometheus and Grafana
are not in the profile, so both appear in the letter's fourth paragraph as absences rather than as skills — the
same rule that removed them from the mittwald and Actian packets. GitOps is present only in the honest form: a
declaration that gates changes and rolls back by generation, self-hosted rather than vendor-managed.

This matters more than usual here: an observability SRE interview will ask which metrics you would instrument and
why, and a candidate who claims Prometheus without having written a recording rule is exposed in the first
fifteen minutes.

## What carries the application

The argument is that **alert quality is a design decision, not a tooling purchase**: fewer signals, each carrying
an action; silence treated as a fault; PSI and cgroups used to turn "it feels slow" into "this host is thrashing
on I/O, not short on memory". That transfers to any stack, including one built on Prometheus. The internal-tools
half is equally concrete — one command surface with help text, a Go service, a data pipeline — which is what the
role's second half asks for.

## Checks

| Check | Result |
| :--- | :--- |
| `packet` symlink | removed |
| Legacy JSON | removed |
| `chmod u+w *.pdf` | applied |
| `typst compile lebenslauf.typ` | exit 0, no warnings |
| `typst compile anschreiben.typ` | exit 0, no warnings |
| `pdfinfo lebenslauf.pdf` | **2 pages** |
| `pdfinfo anschreiben.pdf` | **1 page** |
| Markers | `Prometheus`, `Grafana` (as gaps), `SLO`, `PSI`, `Forgejo`/self-hosted |
| `task checks:prose` | 241 prose files, exit 0 |
| sha256 CV | `8a6f21c09f2060c1b4f55c4170d4e7cd33a7e51acfbd6a838b60607a34d0a420` |
| sha256 letter | `1512a08a255515e0eb85002739d7abe4ebd3cba5b9173508d9b0512e79fb34fb` |

## Next steps

1. Apply through smartclip's careers channel; the letter is English, so the CV stays English too.
2. Ask in the first call which observability stack is in place now — if it is a Prometheus estate, ask what the
   onboarding expectation is.
3. Keep the German C1 line visible; smartclip Hamburg works in English but German helps with local teams.
