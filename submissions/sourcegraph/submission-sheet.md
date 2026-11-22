# Sourcegraph — Software Engineer, Platform [IC3]

Greenhouse posting, globally distributed with a Europe preference. English packet. Native Typst sources; the legacy
`packet` symlink into `/nix/store` and `jd.json` are removed.
Status: compiled and checked, **nothing submitted**.

| Field | Value |
| :--- | :--- |
| Role ID | `sourcegraph` |
| Employer | Sourcegraph |
| Role | Software Engineer - Platform [IC3] |
| Location | Europe preferred; **20 h/week overlap with EST required** |
| Language | **en** |
| Fit | 3 (DB entry 4) |

## What the role actually is

The Platform team builds **Sourcegraph Cloud**, the managed SaaS product: inter-cloud connectivity for enterprise
customers in regulated industries, a **control plane that orchestrates a fleet of single-tenant instances**, complex
infrastructure exposed as API to internal customers, upstream patching of CDKTF and GCP Terraform providers, advocacy
for reliable services, and on-call against contractual SLAs. IC3. Pay bands published: zone 2 $148k, zone 3 $111k,
zone 4 $74k.

## Fit map

| Requirement | Evidence | Verdict |
| :--- | :--- | :--- |
| Go, or another strongly typed language | Go service with tests, `fibtransponder` streaming protocol with benchmarks | strong |
| Control plane / fleet orchestration | 13 hosts as declared generations, rollback as a pointer, one entry surface | **analogous, not identical** |
| Expose infrastructure as API | Task surface with named arguments and machine-readable JSON | partial |
| Kubernetes | **none** | **gap** |
| Terraform / CDKTF, IaC | Nix is declarative IaC; **no Terraform** | **gap** |
| Public cloud (GCP, AWS, Azure) | **none** | **gap** |
| Debugging distributed systems at OS level | cgroups/PSI, `tcpdump` MTU work, `strace`, nftables | strong |
| Reliable services, on-call, SLA | Gate identical in CI and host, telemetry loop, silence as fault | strong on posture, **no contractual SLA** |
| Written communication | Handbook-style docs, sheets, skills in the repo | strong |
| Location / EST overlap | Germany, willing to work to 21:00 CET | workable |

Four gaps named deliberately: Kubernetes, Terraform/CDKTF, public cloud, multi-tenant SaaS with a contractual SLA.
The letter says the gap is the part of the role that would be learning, and does not dress Nix up as Kubernetes.

## The argument the letter makes

A control plane's hard part is not creating a hundred instances — it is that each has an identity, a history and a
way back, and that whoever is paged can see which of the three changed. That is the property built into the fleet
here, so the shape is familiar while the scale is not.

Concretely: every deployment a generation with a parent, so rollback is a pointer; a gate identical in CI and on the
host, so a failing check leaves the previous generation serving; and the pieces a control plane would supply (entry
surface, named arguments, machine-readable output, audit trail) built because the fleet needed them.

## Checks

| Check | Result |
| :--- | :--- |
| `packet` symlink into `/nix/store` | removed |
| `jd.json` | removed |
| `chmod u+w *.pdf` | applied |
| `typst compile lebenslauf.typ` | exit 0, no warnings |
| `typst compile anschreiben.typ` | exit 0, no warnings |
| `pdfinfo lebenslauf.pdf` | **2 pages** |
| `pdfinfo anschreiben.pdf` | **1 page** |
| Markers CV | `generation`, `control plane`, `PSI`, `content-addressed` |
| Markers letter | `Platform team`, `control plane`, `EST`, `Kubernetes` (as gap) |
| `task checks:prose` | 243 prose files, exit 0 |
| sha256 CV | `f7f3d837c0e9a83c254af0545ad66924ec64a51a6d9d5805bf3b7bd33bb7927a` |
| sha256 letter | `25260e4b2c35a7fa28712f56872d0161f257832f830233aef8f9233b8bd4b7e7` |
| DB read-back | verified after upsert |

## Next steps

1. Apply through Greenhouse; no cover-letter field is guaranteed, so paste the letter if there is one.
2. Expect the take-home to be Go against a control-plane-shaped problem — that is the closest thing to a fair test
   in this process.
3. Ask what "single-tenant instance" means in practice — one cluster per customer, or one namespace — since that
   determines how much of the fleet work is orchestration and how much is isolation.
