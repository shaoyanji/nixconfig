# Flix — DevOps / Cloud Infrastructure Engineer

English packet. Greenhouse req **8432987002**. Native Typst sources; the legacy read-only `lebenslauf.pdf`,
`anschreiben.pdf`, `packet` symlink into `/nix/store`, `letter.json` and `resume.json` are removed.
Status: compiled and checked, **nothing submitted**. **[applied per apps DB `flix-devops-cloud-infrastructure` — this sheet's status predates submission]**

| Field | Value |
| :--- | :--- |
| Role ID | `flix-devops-cloud-infrastructure` |
| Employer | Flix (mobility; connects the cloud platform to a new train fleet) |
| Role | DevOps / Cloud Infrastructure Engineer |
| Location | Warsaw-based per the lead; remote delivery to be confirmed |
| Contract | **B2B service agreement, not employment** — independent contractor, invoices |
| Rate | published **90–119 PLN/hour (B2B)** |
| Language | **en** |
| Apply URL | https://flix.careers/job/8432987002?gh_jid=8432987002 |
| Fit | 3 (DB entry 3 — no number was specified for this packet) |

## Measured output

| Artefact | Pages | Words | sha256 |
| :--- | :--- | :--- | :--- |
| `lebenslauf.pdf` | **2** | 881 | `c6b9118de978469bb0c09f123603424e93973e9a911da5f2ecbaa70a450b5e96` |
| `anschreiben.pdf` | **1** | 480 | `de07035d3472957c151376188e41381044b8a3d4b6b7302657c74767c882c0b2` |

Both compiled with typst at **0 warnings**; word counts measured with `pdftotext | wc -w` on the rendered PDFs.

## The commercial question comes first

Two facts decide whether this is worth an hour, and neither is technical.

**It is a service agreement, not a job.** Independent contractor, invoices, no employment. That suits a Polish entity and it means no
work permit logic at all — but it also means no notice period, no equity and no employee benefits.

**The rate is below the floor.** Published range is **90–119 PLN/h**. The outreach sheet in this repo stages **150–250 PLN/h** for a
Polish entity. At the top of Flix's band, the engagement is roughly 60% of the low end of that range. Either the scope is narrower than
a principal engagement (it reads like one senior contractor on a defined integration), or the budget will not reach the stated floor.
Decide before applying; the letter quotes no number.

**Location.** The lead records Warsaw-based, so relocation or a remote exception is the first question. The letter raises it as the
practical matter it is — the commercial form is easy, the seat is not.

## What the engagement is

Cloud infrastructure connecting onboard train systems with Flix backend services: telemetry ingestion, alerting, video streams,
remote content delivery. Build and maintain the Terraform/Terragrunt foundation, secure trains-to-cloud communication (mTLS,
certificate management, network design), agree interfaces with train manufacturers' engineers, and keep the platform observable.

## Fit map

| Requirement | Evidence | Verdict |
| :--- | :--- | :--- |
| Telemetry ingestion and alerting | Fifteen-minute ledger over job state, generation age, disk and PSI; pages on bad state and on silence | **strong** |
| Linux and virtual machines | systemd, cgroups, PSI, nftables, `strace`, `tcpdump`; microVM isolation | **strong** |
| Infrastructure as code | One repository declares thirteen hosts, inputs pinned by hash, reproducible builds | **strong**, **not Terraform** |
| Secure transport, certificates | Fleet certificate authority, short-lived credentials, TLS terminated with per-vhost certs, keys outside the tree | **strong** |
| Secrets and security fundamentals | sops/age per host, default-deny between hosts, dry-run plans | **strong** |
| CI/CD reproducibility | Same gate in CI and on the host; content-addressed builds; rollback as a pointer | **strong** |
| Scalable operations | One task surface with validation; capacity argued with numbers | **strong** |
| Terraform / Terragrunt | **none** | **gap, named** |
| AWS | **none**; rented bare metal | **gap, named** |
| mTLS at device scale, certificate lifecycle | CA and TLS discipline yes, **no vehicle fleet** | partial |
| IoT / automotive device integration | **none** | gap (nice to have) |
| JVM backend | **none**; Go and Python | gap (nice to have) |
| B2B contracting | Polish entity, invoices | **ready** |

Fit **3**: the telemetry, alerting, Linux and certificate work is the closest part of this corpus to a trains-to-cloud integration, and
remote-device telemetry is literally the sentinel pattern. It is not higher because the two named requirements — Terraform/Terragrunt
and AWS — are absent, and because the domain (vehicle integration) is new.

## The argument the letter makes

It opens with the environment: a train is a remote site with a bad network and nobody on hand to fix it, which is the situation the
fleet has been in for five years at thirteen machines. Telemetry collected on the box, written every fifteen minutes, paged on when it
stops arriving — absence as the signal that matters.

Then the infrastructure: declared not assembled, pinned by hash, rebuild as the upgrade path, shared cache and remote builders, one gate
in CI and on the target, generations with parents so rollback is a pointer.

Secure transport gets its own paragraph, because it is the heart of the Flix design: a fleet certificate authority, short-lived
credentials, per-host encrypted secrets, TLS in one declared place, default deny — and the discipline mTLS demands, where every endpoint
proves itself and no private key lives in the repository.

The gap paragraph names Terraform, Terragrunt, AWS and vehicle integration outright, offering systems reasoning in exchange rather than a
translation of the stack.

It closes with a question that separates two implementations: when a vehicle stops sending telemetry, is that detected as a missing
heartbeat per device, or inferred from the absence of downstream data? The second is cheaper and much harder to trust.

## Before applying

1. Decide on the rate: 90–119 PLN/h against a 150–250 PLN/h floor is the whole negotiation.
2. Confirm whether Warsaw presence is required or remote delivery from Germany is acceptable.
3. Apply through Greenhouse `8432987002`; attach `lebenslauf.pdf` and `anschreiben.pdf`.
