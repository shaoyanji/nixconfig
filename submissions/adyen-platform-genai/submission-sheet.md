# Application — Adyen, Senior Platform Engineer - GenAI

Date: 22 November 2026
Fit: 4
Language: English

## Role

| Field | Value |
| :--- | :--- |
| Employer | Adyen |
| Role | Senior Platform Engineer - GenAI |
| Location | Amsterdam or Madrid, office-first |
| Source | Greenhouse job API, HTTP 200 on 22.11.2026 |
| Req | 8163866 |
| Salary | not stated in the posting; no number in the letter |

## Documents

| Document | File | Note |
| :--- | :--- | :--- |
| Letter | `anschreiben.pdf` | One page, English, names the relocation |
| CV | `lebenslauf.pdf` | Two pages, English |
| Sources | `lebenslauf.typ`, `anschreiben.typ` | Typst, compile standalone |
| Certificates | none | still missing |

State on arrival: the directory was empty; the DB row already existed with the note "Amsterdam or Madrid, office-first. K8s/GitOps/Python platform; Nix instead of Argo CD is the tooling gap." No legacy `packet/` directory or `letter.json` existed to remove.

## Fit map

| Requirement | Evidence | Assessment |
| :--- | :--- | :--- |
| Linux infrastructure | 13-host fleet, systemd, cgroups, nftables, networking, storage | Strong |
| AI inference pipelines | Qwen3-TTS, Parakeet, Qwen-Image served behind OpenAI-compatible endpoints | Strong (single-host) |
| GPU orchestration | A guard that yields compute to other workloads; no cluster scheduling or MIG | Partial |
| cgroups and resource bounds | Services bounded, limits debugged as outages | Strong |
| Telemetry | Gatus probes, 15-minute JSONL ledger, PSI and disk pressure | Strong |
| Hermetic builds | Pinned inputs, identical builds, rollback by generation | Strong |
| Zero-downtime deployment | Health-gated rollout and rollback; per-host restarts are not zero-downtime | Partial |
| Kubernetes | Not held | **Gap** |
| vLLM at fleet scale | Not held | **Gap** |
| Payments domain | Not held | **Gap** |
| Office-first in Amsterdam or Madrid | Candidate in Germany, willing to relocate | **Condition** |

## Fit reasoning: 4 of 5

Four, as briefed. The platform discipline is evidenced, and the GenAI part is not a claim: a working inference environment with router, on-demand loading and a resource guard was built and operated by the same person who owns the platform under it.

Not 5, because Kubernetes and fleet-scale serving are absent, and because the role is office-first in another country. Four means: a conversation is plausible, relocation and Kubernetes are real conditions.

## Open items

1. **Kubernetes and vLLM** named in the letter, not hidden.
2. **Zero-downtime** is stated as health-gated rollout, not as a guarantee the record cannot support.
3. **Relocation** to Amsterdam or Madrid is stated in the letter as a willingness, not assumed.
4. Certificates still missing.

## Package

| File | Content |
| :--- | :--- |
| `job-description.txt` | Full posting plus cross-check note. |
| `lead.md` | Fit, gaps, route, salary. |
| `lebenslauf.typ` | Typst source, two pages. |
| `anschreiben.typ` | Typst source, one page. |
| `lebenslauf.pdf` | Two pages. |
| `anschreiben.pdf` | One page. |
| `submission-sheet.md` | This overview. |
