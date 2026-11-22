# Flix — DevOps / Cloud Infrastructure Engineer (train fleet telemetry)

**Greenhouse `8432987002`.** Status: packet prepared, **nothing submitted**. Board entry updated
2026-11-10; location Warsaw. This is a **B2B service agreement**, not an employment contract.

| Field | Value |
| :--- | :--- |
| Role ID | `flix-devops-cloud-infrastructure` |
| Greenhouse id | `8432987002` |
| Employer | Flix |
| Location | Warsaw, Poland |
| Contract | service agreement (B2B / freelance), contractor invoices |
| Posted rate | **90 – 119 PLN/hour** |
| Language | `en` |
| Apply URL | https://flix.careers/job/8432987002?gh_jid=8432987002 |

## The two questions this packet answers before anything else

**Location.** The form's first required question is whether you are currently based in Poland. The
candidate is not — he is in Gutach im Breisgau, Germany. He holds German permanent residence and US
citizenship; neither gives him the right to work in Poland, so the sponsorship question
(`question_39110159002`) is **yes** if the engagement requires Polish presence. The letter offers the
alternative: remote from Germany under the same B2B agreement, if Flix's collaboration model allows it.

**Contract form.** B2B is accepted — `question_39110156002` is answered **yes**. The open point is the
entity: `question_39110157002` asks whether a Polish business entity exists or can be set up. That is
**to confirm** with the operator before submitting; the letter says exactly that rather than presuming.

## Rate: the arithmetic the posting hides

The band is 90–119 PLN/h. At 160 billable hours a month and roughly 4.3 PLN/EUR:

| Basis | PLN/hour | PLN/month | ≈ EUR/month | ≈ EUR/year |
| :--- | ---: | ---: | ---: | ---: |
| Band floor | 90 | 14.400 | ≈ 3.350 | ≈ 40.200 |
| Band ceiling | 119 | 19.040 | ≈ 4.430 | ≈ 53.100 |
| Ask | 150 | 24.000 | ≈ 5.580 | ≈ 67.000 |

150 PLN/h is the floor of the operator's own consultancy rate card (150–250 PLN/h), so the posted
band sits below it. The letter states 150 and offers the alternative of a narrower scope at the top of
the band, which is an honest negotiation rather than a silent mismatch. If the form requires a number,
answer **150** and let the conversation decide.

## Fit map

| Requirement (description) | Evidence | Verdict |
| :--- | :--- | :--- |
| Cloud infrastructure linking onboard systems to backend services | Fleet telemetry ledger and host provisioning; no onboard or device-to-cloud integration | partial — pattern yes, domain no |
| Telemetry ingestion and alerting | Sentinel writes job status, generation age, disk and PSI every 15 minutes and pages on any non-ok state | strong |
| Know what is happening before users do | Alerts fire on state, close on state, and every repeated manual check becomes a gate | strong |
| Terraform / Terragrunt codebase | **Not used.** Infrastructure as code is Nix: pinned inputs, declarative hosts, reviewed plans | **gap** in tool |
| AWS (preferred) | Small AWS Lambda project; Oracle Cloud hosts in production; no multi-account estate | partial |
| Systems architecture, challenging decisions | One declaration for thirteen hosts, module boundaries, rollback by pointer; decisions recorded as notes | strong at small scale |
| Networking, mTLS, SSL/TLS | nftables default-deny, DNS/MTU/TLS diagnosis with tcpdump and openssl, in-house CA with short-lived certificates; mTLS as a service policy layer not deployed | partial |
| Security applied in everyday infrastructure | SOPS/age per host, SSH CA, default-deny, KEV-based vulnerability practice | strong |
| Remote device fleets | PXE/iVentoy provisioning, first-boot join, rebuild — machines as declared members, not pets | strong adjacency |
| IoT / automotive integrations | None | **gap** |
| Backend / JVM | Go and Python services with PostgreSQL; no JVM work | **gap** |
| Linux and virtual machines | NixOS, systemd, cgroups, microVMs as declared guests | strong |

## Greenhouse schema (live, read 2026-11-22)

| Field | Answer | Question id |
| :--- | :--- | :--- |
| First Name * | Matt | `first_name` |
| Last Name * | Ji | `last_name` |
| Email * | matt@bountystash.com | `email` |
| Phone * | +49 1733281570 | `phone` |
| Resume/CV * | `lebenslauf.pdf` (2 pages) | `resume` |
| Poland-based? * | **No** — Gutach im Breisgau, Germany | `question_39110155002` |
| Open to B2B? * | **Yes** | `question_39110156002` |
| Polish entity or able to set one up? * | **To confirm** — the letter says it is not settled | `question_39110157002` |
| B2B rate, PLN per hour * | **150** net (band 90–119; see arithmetic above) | `question_39110158002` |
| Visa/residence sponsorship for Poland? * | **Yes** | `question_39110159002` |
| Current location * | Gutach im Breisgau, Germany | `question_39110160002` |
| Earliest start * | immediate or by agreement | `question_39110161002` |

## What the CV and letter do

The CV opens on telemetry ingestion and the sentinel, then provisioning, declarations, certificates
and Linux debugging. Measured on the built PDF: **telemetry, sentinel, alerting, PXE, Linux, systemd,
PSI, cgroup** present; **Terraform, mTLS, AWS, IoT zero times** — the tools the engagement names that
this fleet does not run stay out of the CV and are named in the letter instead.

The letter's third paragraph is the concession list: no Terraform/Terragrunt (Nix instead), AWS only
as a small Lambda project, certificates without an mTLS policy layer, no IoT/automotive, no JVM. The
fourth is the contract paragraph — B2B yes, Polish entity to confirm, relocation and permit if
presence is required, 150 PLN/h against the posted band.

## Checks

| Check | Result |
| :--- | :--- |
| `pdfinfo lebenslauf.pdf` | **2 pages** (budget 2) |
| `pdfinfo anschreiben.pdf` | **1 page** (budget 1) |
| `task checks:prose` | 209 prose files, exit 0 |
| selection | 10/24 highlights, 4/9 projects |
| sha256 CV | `acc95577ed50814ffd42e2160f35eb9f4d9abdce22e635a54721276f18a91523` |
| sha256 letter | `10883bc562aa1ef232bdc9ac30fd02fd93e73b74250a35349cbdf8b8065976a0` |

## Next actions

1. Confirm the Polish-entity answer before submitting — it is a required field and the one thing the
   packet deliberately leaves open.
2. Decide the location line: if remote from Germany is refused, the engagement means a Polish permit
   and a move, and that changes the rate conversation.
3. Submit through Greenhouse `8432987002` and record the rate answer as 150 PLN/h.
