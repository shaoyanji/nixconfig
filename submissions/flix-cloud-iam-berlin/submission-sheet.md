# Flix — Cloud Engineer (Identity and Access Management)

Berlin, office-first hybrid. Greenhouse req **8836372002**. English packet. Native Typst sources; the directory held only
`job-description.txt`.
Status: compiled and checked, **nothing submitted**.

| Field | Value |
| :--- | :--- |
| Role ID | `flix-cloud-iam-berlin` |
| Employer | Flix (IT Infrastructure Services; IAM for every Flix employee) |
| Role | Cloud Engineer (Identity and Access Management) |
| Location | Berlin, office-first hybrid |
| Language | **en** |
| Apply URL | https://flix.careers/job/8836372002?gh_jid=8836372002 |
| Compensation | not published; no figure in the letter |
| Fit | 3 (DB entry 4, preserved from the scout row) |

## Measured output

| Artefact | Pages | Words | sha256 |
| :--- | :--- | :--- | :--- |
| `lebenslauf.pdf` | **2** | 916 | `dd93a57fafde5bdeb39d2888d34e08107135eb84c7dca5468e6790928ee92251` |
| `anschreiben.pdf` | **1** | 509 | `dc4809b913c68fcc6196b4e7dd2c146bdf11f8e1e4bac29e8b10a2204c223c67` |

Both compiled with typst at **0 warnings**; word counts measured with `pdftotext | wc -w` on the rendered PDFs.

## What the role is, and its unusual honesty

The team owns the IAM services every Flix employee relies on: integrating internal and external applications into identity
infrastructure (SSO), improving role-based access control concepts, consulting other teams, automating recurring tasks, and
shaping the future IT infrastructure. Requirements: 3+ years cloud infrastructure (ideally AWS), Entra ID or another IAM
platform **or a strong interest in growing into identity**, working knowledge of OIDC/OAuth 2.0/SAML **or willingness to build
it quickly**, 3+ years scripting (ideally Python), 1+ year IaC (preferably Terraform), hands-on AI tooling, API integration,
and stakeholder work across engineering, operations and business. Docker/Kubernetes, IaaS, React and Microsoft 365 are pluses.

The posting states outright: *"You don't need to be an identity specialist today."* That is why this packet argues mechanism
and judgement rather than an IdP résumé the candidate does not have.

## Fit map

| Requirement | Evidence | Verdict |
| :--- | :--- | :--- |
| Identity as a mechanism, not a policy | Fleet CA minting short-lived SSH credentials; nothing standing on disk | **strong** |
| Secrets management | sops and age per host, decrypted at activation with that host's key only | **strong** |
| Declarative access control | Grants declared in the same repository as the systems; reviewable diffs | **strong** |
| Automation of recurring tasks | Python and Go behind one task surface with validation and dry runs | **strong** |
| API and integration work | OAuth consent and token refresh against third-party APIs, expiry handled | **strong** |
| Scripting (Python) | Pipelines, tooling, tests over canonical data | **strong** |
| Stakeholder consultation | Self-service tooling, generated documentation, runbooks for the on-call reader | **strong** |
| Telemetry and alerting | Fifteen-minute ledger, paging on bad state and on silence | **strong** |
| Microsoft Entra ID / SSO platform admin | **none** | **gap, role centre** |
| SAML federation | **none** | **gap** |
| OIDC beyond OAuth consent flows | partial: OAuth 2.0 flows built, no IdP-side OIDC | partial |
| AWS | **none**; rented bare metal | **gap (ideally)** |
| Terraform | **none**; declarative NixOS instead | **gap (preferably)** |
| Docker / Kubernetes | **none** (microVMs instead) | gap (plus) |
| Microsoft 365 tenant work | **none** | gap (plus) |

Fit **3**: the mechanism-level identity work, secrets handling, declarative access and automation map closely onto what this
team actually owns, and the posting explicitly welcomes someone who grows into the platform. It is not higher because the
Entra ID / SSO / SAML surface is the role's centre and is absent, with AWS and Terraform also missing.

## The argument the letter makes

It opens on the one principle this role lives by: policy and mechanism must be the same artifact, because when they disagree
the mechanism wins. Then the concrete version — access issued rather than stored, a certificate authority minting short-lived
credentials, secrets per host decrypted only at activation, grants living in the same repository as the systems, so reviewing
access is reviewing a diff with history.

The integration paragraph is the direct match: OAuth consent and token refresh flows built against third-party APIs, including
what happens when a token expires at the wrong moment.

Then the honest paragraph, aimed exactly at the posting's own invitation to grow into identity: no Entra ID or SSO
administration, no SAML federation, no M365 tenant, no AWS or Terraform — with the counterargument that describing state and
reconciling it is the same discipline in different syntax, and that judgement about what a grant means is harder to teach than
a console.

Consultation gets its own paragraph, because the posting names it: when a team has to ask how to get access, that is a defect
in the tooling rather than a gap in their knowledge.

It closes with the question that separates a maintained IAM estate from an optimistic one: when someone leaves or changes
role, what actually removes their access — an HR sync, a scheduled review, or a person remembering?

## Before applying

1. Berlin is office-first hybrid; the letter offers the commute by arrangement rather than promising a move.
2. If a screen happens, lead with access-as-code and secrets, and name the Entra ID gap before it is asked about.
3. Apply through Greenhouse `8836372002`; attach `lebenslauf.pdf` and `anschreiben.pdf`.
