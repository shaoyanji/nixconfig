# Grafana Labs — Senior Software Engineer, Security Assurance

Remote (Germany eligible). Greenhouse req **6228511004**. English packet. Native Typst sources; the directory held only
`job-description.txt` until this packet.
Status: compiled and checked, **nothing submitted**. **[applied per apps DB `grafana-security-assurance` — this sheet's status predates submission]**

| Field | Value |
| :--- | :--- |
| Role ID | `grafana-security-assurance` |
| Employer | Grafana Labs (Grafana Cloud; 100% remote, 40+ countries) |
| Role | Senior Software Engineer, Security Assurance |
| Team | GRC engineering — certifications, application/build/cloud/supply-chain security, internal tooling |
| Location | Germany (remote); posting lists UK, Ireland, Spain, Germany, Sweden |
| Language | **en** |
| Apply URL | https://job-boards.greenhouse.io/grafanalabs/jobs/6228511004 |
| Greenhouse API | https://boards-api.greenhouse.io/v1/boards/grafanalabs/jobs/6228511004?questions=true |
| Posting updated | 2026-10-19 (API `updated_at`), read 2026-11-22 |
| Compensation | published for Germany: **€97,034 – €116,441** base, plus RSUs. Recorded here only; no figure in the letter |
| Fit | 3 (DB entry 4, carried from the scout row) |

## Measured output

| Artefact | Pages | Words | sha256 |
| :--- | :--- | :--- | :--- |
| `lebenslauf.pdf` | **2** | 1006 | `b4fd66b69eeba1e85ed9559180d49a8f8c3b74f2d9c999240696358f320df9e4` |
| `anschreiben.pdf` | **1** | 509 | `8fcac9608401cf42df970897dc9e771a073a8c072e7e8968d3b80c116d9f20dd` |

Both compiled with typst at **0 warnings**; word counts measured with `pdftotext | wc -w` on the rendered PDFs. No `**` in either
source. First pass ran to three pages at 1,070 words with an explicit page break before `Selected Work`; the break was removed
and the prose tightened, leaving no orphaned heading at either page foot.

Claim audit (2026-11-22, after the first commit): every assertion in both documents was checked against the repository. The
fleet count is exact — `.#inventory.hosts` holds 38 entries, of which **13 are active NixOS hosts**, the rest preserved, external,
home or darwin. `modules/ssh-ca.nix` is the certificate authority, `modules/services/fleet-sentinel.nix` defaults to a 15-minute
cadence with generation age and PSI, gatus is deployed on frieren and delphi, and the KEV projects sit in the corpus. One
correction was made: the CA issues **90-day user certificates renewed weekly by timer**, so "short-lived" overstated it and the
wording now says what the module does.

## What the role is

A hands-on keyboard engineering role on Grafana's GRC team, not a policy seat. Build observability into the security estate,
automate assurance programmes (ISO 27001, SOC 2, GDPR, NIST, PCI-DSS, TISAX as customers ask), deploy compliance checks as
guardrails and paved roads in daily workflows and build pipelines, integrate controls into the SDLC, and respond to customer
security issues and alerts. Go, TypeScript and Python in production; containerised cloud-native work, ideally Kubernetes;
multiple cloud providers a strong plus; a code screen discussing algorithms, data structures and optimisation. Frameworks matter
less than the disposition to read a standard and implement the control it actually asks for.

## Fit map

| Requirement | Evidence | Verdict |
| :--- | :--- | :--- |
| Production software in one language | Python and Go: task control plane, bountystash service, CLI tools over REST APIs | **strong** |
| Controls as code, not documents | Grants, network policy and secrets declared in the same repository as the systems they govern | **strong** |
| Automating security and compliance processes | Recurring checks behind one validated surface with dry runs and JSON output; hashed, pinned builds | **strong** |
| Security observability | Fifteen-minute ledger of job state, generation age, disk and PSI; paging on bad state and on silence | **strong** |
| Evidence that survives an audit | Build provenance is a property of the pinned artefact; access review is a diff with history | **strong** |
| Vulnerability prioritisation | CISA KEV as a time series and as effort clusters with exposure per cluster; bug bounty programme audits | **strong** |
| Guardrails and paved roads | Defaults that are correct without a conversation; one command for the safe path; generated documentation | **strong** |
| Linux and networking depth | systemd, cgroups, PSI, nftables, `strace`, `tcpdump`, an MTU fault isolated on one path | **strong** |
| Stakeholder communication | Wrote the access model for two readers: the engineer changing a grant, the auditor asking what it means | strong |
| ISO 27001 / SOC 2 / PCI-DSS as responsible engineer | **none**; no audit cycle owned | **gap (role centre)** |
| Kubernetes | **none**; microVMs and bare-metal hosts instead | **gap** |
| AWS / GCP / Azure | **none**; rented bare metal | **gap (strong plus)** |
| Terraform / Helm / Jsonnet | **none**; declarative NixOS instead | **gap** |
| TypeScript | **none** in production; Go and Python carry the work | gap (Go is the stated alternative) |
| Grafana OSS / Prometheus / Loki / Mimir | **none**; own ledger and gatus paging, not Grafana tooling | gap (bonus) |
| Degree in CS or security | M.Sc. Renewable Energy Management, B.Sc. Petroleum Engineering — neither field | equivalent experience claimed instead |

Fit **3**: the engineering half of this role — automating controls, producing evidence from systems rather than spreadsheets,
building tooling, and communicating it to two audiences — is what the last five years actually were. It is not higher because the
cloud-native and framework half is absent: no Kubernetes, no hyperscaler, no Terraform, no owned certification cycle. Grafana
says the disposition to learn quickly outranks rote framework knowledge, and the letter answers that directly rather than
overclaiming.

## The argument the letter makes

It opens on evidence that exists on a Tuesday afternoon, months after the control was designed, and argues that the control and
its proof should be one artefact. Then the concrete estate: sops/age per host with only that host's key, short-lived SSH
credentials from a certificate authority (90-day user certificates renewed by timer), default-deny with declared grants, so the
diff is the audit trail.

The second paragraph meets the posting's own language — guardrails and paved roads rather than gates — and adds the property
that makes a paved road trustworthy: it carries its own alarm, so a control that stopped reporting is visible, not silent. The
KEV paragraph follows, because it is the clearest evidence of turning a security dataset into an ordered decision.

The gap paragraph is explicit: no ISO 27001 or SOC 2 cycle owned, no Kubernetes, no AWS/GCP/Azure, no Terraform/Helm/Jsonnet,
and a non-security degree. It then names the compensating habit — read the standard, find the control it is asking for,
implement that as code with evidence attached — and the audit translation problem.

It closes with the question that measures the whole programme: if an auditor asked today who could read customer data in March,
how long would the answer take from the system rather than from memory.

## Greenhouse form — staged answers

13 questions, labels and ids read from the boards API on 2026-11-22.

| Field | Id | Required | Staged answer |
| :--- | :--- | :--- | :--- |
| First Name | `first_name` | yes | Matt |
| Last Name | `last_name` | yes | Ji |
| Preferred First Name | `preferred_name` | no | leave empty |
| Email | `email` | yes | matt@bountystash.com |
| Phone | `phone` | yes | +49 1733281570 |
| Resume/CV | `resume` | yes | `lebenslauf.pdf` |
| LinkedIn Profile | `question_20328376004` | yes | https://linkedin.com/in/mattji |
| Current company | `question_20328377004` | no | Bountystash (own company, founded 2020, wound down Aug 2025) |
| Eligible to work in country of residence | `question_20328378004` | yes | Yes — German permanent residence (Niederlassungserlaubnis) |
| Require visa sponsorship | `question_20328379004` | yes | No |
| Anything else to share | `question_20328380004` | no | **Free text, see below** |
| Which best describes you | `question_20328381004` | yes | I am a human being |
| How did you hear about this opportunity | `question_20328382004` | no | LinkedIn — confirm with Matt, this is a guess, not a record |

Note: unlike Canonical, this form has no own-words/AI attestation question, so nothing here needs a rewrite before submission.

## Free-text answer staged for the form

**Anything else you'd like to share with our hiring team** (`question_20328380004`).

Two things the CV compresses. First, the security work is on a small fleet by choice of constraint, not by preference for small
systems: thirteen hosts is enough that controls have to be mechanised and too few to hide behind process, which is why the
controls ended up as declarative code with evidence attached. Second, the gap I would rather state than have found: no
Kubernetes, no hyperscaler, no owned ISO 27001 or SOC 2 cycle. What I have done is read standards and audit guidance, find the
control they are really asking for, and build it into the place where engineers already work — secrets, access, network policy,
builds and monitoring — with the evidence produced by the system rather than collected afterwards. The CISA KEV work is the
closest thing to the assurance mindset on its own: a public dataset, an exposure model, an effort-clustered patch order, and a
page that says when the data is sample.

## Before applying

1. Remote in Germany is eligible; the letter says so and the form answers the sponsorship question without ambiguity.
2. Expect a code screen discussing algorithms, data structures and optimisation — Go is the strongest ground, and the
   bountystash event log plus fibtransponder benchmarks are the two pieces of work to have ready to explain.
3. The published German band is €97,034 – €116,441 plus RSUs; the letter states no figure, so range discussion belongs in the
   first recruiter call.
4. If a screen happens, lead with controls-as-evidence and name the Kubernetes/hyperscaler gap before it is asked about.
5. Attach `lebenslauf.pdf`; submit through Greenhouse `6228511004`. Nothing was submitted.
