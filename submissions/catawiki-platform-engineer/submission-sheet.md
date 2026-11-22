# Catawiki — Platform Engineer

Greenhouse job `8405079`, fetched 2026-11-22 (posted 2026-11-20). Packet built the same day, **nothing
submitted**. Self-contained Typst sources beside the PDFs.

| Field | Value |
| :--- | :--- |
| Role ID | `catawiki-platform-engineer` |
| Employer | Catawiki, Amsterdam (marketplace, 800+ staff) |
| Role | Platform Engineer, Platform Horizontal |
| Location | Amsterdam, hybrid **minimum 2 days/week**; relocation support offered |
| Language | English |
| Salary | not published ("competitive annual gross base") |
| Fit | **3** (DB row records 4 as instructed) |

## Match analysis

| Requirement (advert) | Evidence | Verdict |
| :--- | :--- | :--- |
| 5+ years production Kubernetes, container orchestration | **None.** Containers as pinned build environments | **gap, and it is the headline requirement** |
| Cloud platform (GCP, AWS or Azure) | Oracle Cloud hosts, one AWS Lambda project | **gap** |
| Terraform or Ansible | NixOS modules and flake wiring: declarative, gated, versioned | gap in tool, concept present |
| CI/CD and GitOps workflows, reusable templates | Same module gate in CI and on the host; rollback by generation; task surface as the shared entry point | strong in design, different tooling |
| Observability with Prometheus, Grafana, ELK or OpenTelemetry | Custom ledger (job status, generation age, disk, PSI), journald, paging on state ≠ ok | strong practice, **named tools absent** |
| Self-service developer platform, developer experience | One task surface, compiled skill index, runbooks, docs budget gate | strong |
| Reliability: fault tolerance, DR, scaling | Reversible changes, previous generation on failure, bare-metal rebuild path | strong at fleet scale |
| FinOps / cost efficiency | ARM over x86, microVMs, build cache and store substitution | strong, small scale |
| Collaboration with product teams | Client-facing scoping as director and consultant; instruction of field staff | partial, not internal platform customers |

## Scoring it honestly

Four of the advert's hard requirements are cloud-native, and **three are missing outright**: production
Kubernetes, a named cloud, and the observability toolchain. Terraform/Ansible is a fourth, softened only by
the "or equivalent" framing the advert does not actually offer. Fit **3** reflects a real developer-experience
match sitting under a cloud-native bar the profile does not clear — the DB carries 4 as instructed, and this
sheet is the record of why that number is generous.

What makes the application worth sending: Catawiki's own text says to apply even without every requirement,
and the self-service argument is unusually concrete here — a task surface, gates that fail closed, docs that
fail like code, and a graph that answers impact questions by query.

## Amsterdam and authorisation

- Hybrid at **2 days/week** in Amsterdam; Gutach im Breisgau is ~700 km, so this is relocation.
- Catawiki offers **visa sponsorship and relocation support**; the letter accepts the relocation and names
  the Dutch permit route rather than claiming sponsorship is unnecessary. German permanent residence does
  not transfer to the Netherlands, and saying otherwise would fail at offer stage.

## Checks

| Check | Result |
| :--- | :--- |
| `typst compile lebenslauf.typ` | exit 0, no warnings |
| `typst compile anschreiben.typ` | exit 0, no warnings |
| `pdfinfo lebenslauf.pdf` | **2 pages** (budget 2) |
| `pdfinfo anschreiben.pdf` | **1 page** (budget 1) |
| `task checks:prose` | 234 prose files, exit 0 |
| sha256 Lebenslauf | `a86eaf78770005f00ff5bb74dba291f1ae8d0130ab2a8aa360e59bf3648c0a00` |
| sha256 Anschreiben | `3d4dde453737a4819657d8709ded2c5ea4c060e4e4e84b94286cacb60d7534b7` |

## Next steps

1. Apply via Greenhouse with CV and cover letter (the posting asks for both, in English).
2. Be ready to answer the Kubernetes question directly: no cluster operated, and a plan for closing it.
3. Confirm the permit route and relocation package in the first call, before any technical round.
