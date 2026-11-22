# Application: Flix - DevOps / Cloud Infrastructure Engineer

Prepared: 22 November 2026
Greenhouse requisition: 8432987002
Fit: 3

## Role

| Field | Value |
| :--- | :--- |
| Employer | FlixMobility Tech GmbH, brand FlixTech |
| Role | DevOps / Cloud Infrastructure Engineer |
| Location | Warsaw, Poland |
| Contract | Cooperation on a service agreement (B2B / freelance), not an employment contract |
| Rate | 90 to 119 PLN per hour, B2B |
| Start | 2026-03-01 (planned) |
| Contact | Anna Symonenko |
| Listing | https://flix.careers/job/8432987002?gh_jid=8432987002 |
| Posted | 2026-11-10 |

The listing metadata says "Regular, full time" while the body says B2B service agreement. Both cannot be true in the German sense. Treat the body as binding and ask before signing: contractor status, invoicing entity, VAT treatment, and whether the Warsaw location is required on site.

## Application route

Greenhouse, through the Flix careers page. The form was not rendered, so no field IDs are asserted here and nothing was submitted.

Job data is readable without a browser at `https://boards-api.greenhouse.io/v1/boards/flix/jobs/8432987002`, which is where the text in this packet came from.

### Documents

| Document | File | Note |
| :--- | :--- | :--- |
| CV | `lebenslauf.pdf` | Two pages, English |
| Cover letter | `anschreiben.pdf` | One page, English |
| References | none | Provide if the form asks |

The files carry German names because the packet pipeline uses them; the content is English, matching the posting and the record's `language: en`.

## Candidate

| Field | Value |
| :--- | :--- |
| Name | Matt Ji |
| Address | Am Burgerhof 4, 79261 Gutach im Breisgau, Germany |
| Email | matt@bountystash.com |
| Phone | +49 1733281570 |
| Languages | German C1, English native |
| Degree | M.Sc. Renewable Energy Management, University of Freiburg, 2014 |
| Experience | Ten years, five of them running Linux infrastructure directly |
| Work authorisation | US citizen, permanent German residence permit; no visa support needed |
| Invoicing | Own company available for a B2B agreement |
| Availability | Immediately; posting plans a 2026-03-01 start |

## Fit against the posting

| Requirement | Evidence | Verdict |
| :--- | :--- | :--- |
| Design and run cloud infrastructure connecting devices to backend services | Thirteen-host fleet, remote access through a WireGuard tailnet, no public ports | Partial: fleet yes, cloud no |
| Telemetry ingestion | Sentinel writes job status, generation age, disk and PSI pressure to JSONL every 15 minutes | Strong |
| Alerting pipelines | Gatus probes plus a Go bridge that confirms delivery before an alert counts | Strong |
| Infrastructure as code, clean and scalable for others | Entire fleet declarative in Nix, module boundaries enforced, one file per service | Strong, wrong tool |
| Terraform / Terragrunt | Not used; declarative work is Nix | Gap, stated in the letter |
| AWS or another major cloud | No cloud account in production; hardware owned | Gap, stated in the letter |
| Secure device-to-cloud communication, mTLS, certificate management | Own SSH CA with short-lived certificates, WireGuard-only access | Partial: certificates yes, X.509 mTLS no |
| Networking, SSL/TLS | Firewall and network as code, Tailscale, reverse proxy termination | Partial |
| Architecture leadership across backend and infrastructure | Design decisions live in the repository as policies and notes with explicit reasoning | Strong |
| Reliability, observability, security | Ledger, endpoint probes, delivery-confirmed alerts, sops/age, rollback per generation | Strong |
| IoT, automotive or remote device integration | None | Gap |
| JVM backend experience | None; Go, Python, Bash | Gap |
| Linux and virtual machines | Linux daily, thirteen hosts across three hardware generations | Strong |

## Compensation

The posting pays 90 to 119 PLN per hour on a B2B contract. At a full-time month that lands far below the 85,000 to 95,000 EUR figure used elsewhere in this search, and it carries no employer social contributions, no paid leave and no notice period. The letter names no number.

Before applying, decide whether a contractor rate at this level is acceptable at all. If not, this application should not be sent, because the rate is published and there is nothing to negotiate upward except the hour count.

Questions to ask if it proceeds: monthly hour cap, invoicing currency (PLN or EUR), payment terms, who carries the currency risk, and whether the Warsaw location implies on-site days.

## Greenhouse form mapping

The form was not rendered. Values only, no field IDs; check labels before submitting.

| Label | Value |
| :--- | :--- |
| First name | Matt |
| Last name | Ji |
| Email | matt@bountystash.com |
| Phone | +49 1733281570 |
| Location | Gutach im Breisgau, Germany |
| Resume | `lebenslauf.pdf` |
| Cover letter | `anschreiben.pdf` |
| Work authorisation | German residence permit, no sponsorship required |
| Referral | none |

## Open items

1. Decide on the B2B rate before anything else. This is the one posting in the stack where the money is published and low.
2. Decide on Warsaw. The record already flags relocation as the first question; the letter does not claim willingness to move.
3. Confirm the contract form: the metadata says regular employment, the body says service agreement.
4. Ask who employs the contractor entity and how VAT crosses the border.
5. Do not dress up the Terraform and AWS gaps; the letter names both in paragraph three.
6. The record sits at `stage: other`; after submission it should move to `applied`.

## Packet

| File | Content |
| :--- | :--- |
| `job-description.txt` | Posting text from the Greenhouse API. |
| `lebenslauf.pdf` | Two-page English CV. |
| `anschreiben.pdf` | One-page English letter naming the gaps. |
| `selection.json` | Selector audit. |
| `submission-sheet.md` | This sheet. |
