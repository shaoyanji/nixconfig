# MongoDB — Site Reliability Engineer (Senior or Staff), Storage Layer Services

**Greenhouse `6984814`.** Status: packet prepared, **nothing submitted**. The team is
re-architecting the storage layer under Atlas and hiring its founding SREs; the posting was
updated 2026-11-17 and is live.

| Field | Value |
| :--- | :--- |
| Role ID | `mongodb-sre-storage-layer` |
| Greenhouse job id | `6984814` (`gh_jid`) |
| Internal req | `2263171786` (footer of the description) |
| Employer | MongoDB (Atlas, Storage Layer Services) |
| Level | Senior or Staff |
| Location | Cork or Dublin, Ireland — **or remotely in Ireland** |
| Language | `en` |
| Board | `mongodb` |
| Apply URL | https://www.mongodb.com/careers/job/?gh_jid=6984814 |

## Location and authorisation — the decisive constraint

"Remotely in Ireland" is not "remote in the EU". The candidate is in Gutach im Breisgau, Germany,
so this role means relocation or an Irish employment contract he cannot currently take from home.
The letter says that plainly and answers the sponsorship question the same way.

- German permanent residence (*Niederlassungserlaubnis*) does not transfer to Ireland.
- As a US citizen he needs an Irish employment permit: **employer-supported relocation**.
- Greenhouse asks "Will you now or in the future require employment sponsorship?" as a **required**
  field (`question_57683854`); the honest answer is **Yes**, and the sheet keeps it consistent with
  the letter rather than softening the form.

## Candidate facts used

| Fact | Value |
| :--- | :--- |
| Name | Matt Ji |
| Address | Am Burgerhof 4, 79261 Gutach im Breisgau, Germany |
| E-mail / phone | matt@bountystash.com / +49 173 3281570 |
| Languages | English native, German C1 |
| Residence | German permanent residence; Ireland requires a permit |
| On-call | Accepted; no 24/7 rotation held in a company of this size (said in the letter) |
| Salary | no figure in the letter — MongoDB bands by location; ask for the Dublin/Cork band first |

## Fit map

| Requirement (description) | Evidence | Verdict |
| :--- | :--- | :--- |
| Define SLOs with the teams building the services | Health is a recording: sentinel ledger every 15 minutes (job status, generation age, disk, PSI), paging on any non-ok state. Formal SLOs with error budgets are new | partial — measurement real, formal SLOs new |
| Shape capacity plans | Capacity kept as a budget with a check (disk, memory, closure size), so growth is visible before a full disk | partial — right method, small scale |
| Reliability, durability, operational safety of a storage layer | Immutable generations, pinned inputs, a rollback that is a pointer; no stateful multi-tenant storage operated | **gap** at Atlas scale |
| 6+ years software development and operating distributed systems | Ten years of systems work; the fleet is thirteen hosts, not a distributed storage service | partial |
| Python, Go or similar | Go and Python tooling behind one task interface; Go services with append-only event logs | strong |
| Experience using and extending Kubernetes | Containers only as pinned build environments; no production cluster | **gap** |
| AWS, GCP or Azure platform expertise | Small AWS Lambda project plus Oracle Cloud hosts; no multi-cloud platform ownership | partial |
| Linux internals and networking (TCP/IP, DNS, TLS, routing) | systemd, cgroups, PSI, nftables default-deny, DNS and MTU faults read from tcpdump, in-house SSH CA | strong |
| Prefer automation over manual process | Anything done by hand twice became a check; the taskfile is the operator surface | strong |
| 24/7 on-call rotation | On-call accepted; never carried a rotation in a 24/7 organisation | partial |
| Optimise from the application to the kernel | Works below the application (cgroups, PSI, nftables, MTU); no kernel or filesystem development | partial |
| Customer-focused mindset | Four years of client-facing asset management and risk work before infrastructure | strong |

## Greenhouse schema (read from the boards API, 2026-11-22)

Question ids below are the live ones for this requisition, not copied from the sibling MongoDB
packet.

| Field | Answer | Question id |
| :--- | :--- | :--- |
| First Name * | Matt | `first_name` |
| Last Name * | Ji | `last_name` |
| Email * | matt@bountystash.com | `email` |
| Phone * | +49 1733281570 | `phone` |
| Resume/CV * | `lebenslauf.pdf` (2 pages) | `resume` |
| Cover Letter | `anschreiben.pdf` (1 page) | `cover_letter` |
| Preferred Name * | Matt | `question_57683845` |
| Website | https://www.bountystash.com | `question_57683846` |
| LinkedIn Profile | https://linkedin.com/in/mattji | `question_57683847` |
| Github | https://github.com/shaoyanji | `question_57683848` |
| StackExchange | (none) | `question_57683849` |
| Culture & careers content | optional — leave unchecked | `question_57683850` |
| How did you learn about this job? | board option, free text "MongoDB careers (Greenhouse)" | `question_57683851`, `question_57683852` |
| Job alerts | optional | `question_57683853` |
| **Require employment sponsorship?** * | **Yes** — Irish employment permit; German PR does not transfer | `question_57683854` |
| Worked at MongoDB before? * | No | `question_57683855` |
| Current MongoDB employee? | No | `question_68101873` |

## What the CV says, measured on the built PDF

The projection kept 13 of 36 highlights and 4 of 10 projects. Measured on the finished text:
**Linux ×2, systemd ×2, cgroups ×2, PSI ×2, Go ×3, Python ×2, capacity ×1**, and **Kubernetes,
SRE, SLO, durability, multi-tenant and on-call zero times**. The CV opens on Linux operations,
measurement and declaration; the letter has to carry the reliability argument and the gaps.

## What the letter says

It opens on the team's own framing — SREs defining SLOs and capacity plans rather than receiving
them — then describes the fleet: declaration, gate, generation rollback, the sentinel ledger with
paging, journald, and capacity as a budget. The third paragraph is Linux below the application.
The fourth names every gap before the first call: no multi-tenant distributed storage, no production
Kubernetes, no AWS/GCP/Azure platform ownership, no 24/7 rotation, SLOs with error budgets new. The
fifth concedes the location and answers sponsorship with a yes and a relocation commitment.

## Checks

| Check | Result |
| :--- | :--- |
| `pdfinfo lebenslauf.pdf` | **2 pages** (budget 2) |
| `pdfinfo anschreiben.pdf` | **1 page** (budget 1) |
| `task checks:prose` | 202 prose files, exit 0 |
| selection | 13/36 highlights, 4/10 projects |
| sha256 CV | `5f92cdda357bf853db5789254bb007d34e2792f95eaa72d29c5af39d7bf9c6f7` |
| sha256 letter | `84f34d15842b3d3551f0c16112655a57a61e475563177c1c2448faae654dfd24` |

## Next actions

1. Decide the relocation question before submitting: this is the only remote-EU option in the
   sweep, but the remote is Ireland, so a submission is a commitment to move.
2. Ask the recruiter for the Dublin/Cork band before naming a salary; the letter deliberately
   carries no figure.
3. If invited, expect the Kubernetes question first — the answer is the container-as-build-environment
   work, the module boundary and the CA, not a cluster story.
