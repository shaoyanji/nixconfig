# STACKIT / Schwarz Digits — Senior Kubernetes Engineer (m/f/d), GT4121

**Live.** The advert answers HTTP 200 on the English route and carries
`data-job-id="GT4121"` in its apply button. The German duplicate (`/de/jobsuche/...`)
answers 404, so `job-description.txt` is the English text with a provenance header.

| | |
| :--- | :--- |
| Role ID | `stackit-schwarz-digits-senior-kubernetes-engineer` |
| Requisition | GT4121 |
| Employer | STACKIT, part of Schwarz Digits (Schwarz Gruppe: Lidl, Kaufland, PreZero) |
| Location | Am Campus 1, 74177 Bad Friedrichshall |
| Area / level | IT — Cloud Services, experienced professional, full-time |
| Posted | 2026-07-15 |
| Recruiter | Tatjana Kirschner, recruiting@mail.schwarz |
| Language | excellent English required, German a plus |

## Candidate facts used

| Fact | Value |
| :--- | :--- |
| Name | Matt Ji |
| Address | Am Burgerhof 4, 79261 Gutach im Breisgau |
| E-mail / phone | matt@bountystash.com / +49 173 3281570 |
| Languages | German C1, English native |
| Right to work | US citizen with German permanent residence, no sponsorship needed |
| Distance to site | ~190 km, so no daily presence |
| Salary stated | **85.000 EUR** |
| Start | immediate or by agreement |

## Fit map

| Requirement (JD) | Evidence | Verdict |
| :--- | :--- | :--- |
| Architect and run scalable Kubernetes services for customers | No production Kubernetes cluster administration; the letter says so in the fourth paragraph | **gap** |
| Operations and problem solving: complex issues, root-cause analysis, lasting fixes | Single-operator fleet: incidents end with a gate or a check, not a workaround; ledger and postmortem notes in the repo | strong |
| Cluster security and compliance: RBAC, Network Policies, Kyverno, Falco, image scanning | nftables default-deny, SSH CA with short-lived certificates, SOPS/age per host. No policy engine, no Falco | partial |
| Go operators, controllers, CRDs; GitOps delivery | Go services and CLI tooling; **no operator or CRD work**, no Argo/Flux | **gap** |
| Deep K8s internals, cloud networking, storage, API design | Linux networking and storage buffering from the host side: systemd/cgroups, PSI, WireGuard mesh, DNS/MTU with tcpdump | partial |
| Gardener or ClusterAPI multi-cluster management | Not used | **gap** |
| Open-source contribution, owning features in a community | Bug bounty and internal tooling, no upstream maintainership | **gap** |
| Immutable platform automation | NixOS declarations, thirteen hosts as feature lists, rollback as a pointer, declarative MicroVM guests | strong |
| Excellent English, German a plus | English native, German C1 | strong |

## Portal schema — RocketApply (SAP BTP)

The apply button starts `hrplattformprod-rocketapply-prod-scos-rocketapply.cfapps.eu20.hana.ondemand.com/app/`
with `data-job-id="GT4121"` and `data-mmm-rocket-apply-language="en_US"`; the tunnel through
STACKIT or Schwarz Digits carries the same id. The form itself is a single-page app behind a
session, so the mapping below is the standard RocketApply candidate shape, not observed HTML —
the job id is the part that is verified.

| # | Field (standard RocketApply) | Answer |
| :-- | :--- | :--- |
| 1 | Job id (hidden) | GT4121 |
| 2 | First name | Matt |
| 3 | Last name | Ji |
| 4 | E-mail | matt@bountystash.com |
| 5 | Phone | +49 173 3281570 |
| 6 | CV upload | `lebenslauf.pdf` (2 pages, German) |
| 7 | Cover letter / message | `anschreiben.pdf` (1 page, German) |
| 8 | Salary expectation | 85.000 EUR brutto |
| 9 | Earliest start | sofort oder nach Vereinbarung |
| 10 | Location / remote | Gutach im Breisgau, ~190 km; remote share and on-call to be agreed |
| 11 | Languages | Englisch Muttersprache, Deutsch C1 |
| 12 | Work permit | unbefristetes Niederlassungsrecht, kein Sponsoring |
| 13 | How did you hear | Schwarz Digits job search |
| 14 | Data protection consent | ja |

## Compensation note

The record's earlier scan put the XING estimate for this title at 56.000 – 76.000 EUR, so 85.000
sits above the estimate. STACKIT pays for senior platform work in a group of this size; the ask is
defensible but expect the recruiter to test it.

## Tailoring notes

- The CV comes from a **packet-local corpus copy** (`lebenslauf.json` here): the canonical German
  corpus is an energy and risk CV. Five Bountystash bullets were added for declared hosts, MicroVM
  guest lifecycle, Go/Python tooling, ledger telemetry and the SSH CA mesh.
- `Kubernetes` was removed from the DevOps skill line. The JD asks for someone who has run clusters
  from scratch; a skill line claiming it would be contradicted by the letter in the same envelope.
- The keyword selector reads the advert body only, not the provenance header.

## Checks

| Check | Result |
| :--- | :--- |
| `pdfinfo lebenslauf.pdf` | **2 pages** (budget 2) |
| `pdfinfo anschreiben.pdf` | **1 page** (budget 1) |
| `task checks:prose` | 188 prose files, exit 0 |
| selection | 7/37 highlights, 0/0 projects |
| sha256 CV | `4236a8e6b3f68d8b8ed2ac7ccf0c3c2a87b7de615e901998061de36c505fa5f9` |
| sha256 letter | `7269a72b609ec209228359617cf7cc2efd16553aa761065001ed413c1179836a` |

## Next actions

1. Submit through the RocketApply button with GT4121; attach both PDFs.
2. Lead with operations and the Linux layer, not with Kubernetes — the gap is stated, so the
   interview should be about incident discipline and platform automation.
3. Ask about remote share early: 190 km makes daily presence impossible, and the posting is a
   full-time on-site listing.
