# STACKIT / Schwarz Digits — DevOps / Cloud Engineer (m/w/d), Kubernetes & IaC, GT4627

**Live.** The German route render 200 and carries `data-job-id="GT4627"`; `/en/jobsearch/...`
and `/de/jobsuche/...` both answer 404, so `job-description.txt` is the German text with a
provenance header. Apply through the RocketApply button on the same page.

| | |
| :--- | :--- |
| Role ID | `stackit-schwarz-digits-devops-cloud-engineer-kubernetes-iac` |
| Requisition | GT4627 |
| Employer | STACKIT / Schwarz Digits (Schwarz Gruppe) |
| Location | Am Campus 1, 74177 Bad Friedrichshall |
| Team scope | STACKIT Kubernetes as runtime for ServiceNow shared services: AI Search, ML, Document Intelligence |
| Recruiter | Lara Schlimgen, recruiting@mail.schwarz |
| Language | very good German, good English |

## Candidate facts used

| Fact | Value |
| :--- | :--- |
| Name | Matt Ji |
| Address | Am Burgerhof 4, 79261 Gutach im Breisgau |
| E-mail / phone | matt@bountystash.com / +49 173 3281570 |
| Languages | German C1, English native |
| Right to work | US citizen with German permanent residence, no sponsorship needed |
| Distance | ~190 km to Bad Friedrichshall |
| Salary stated | **85.000 EUR** |
| Start | immediate or by agreement |

## Fit map

| Requirement (JD) | Evidence | Verdict |
| :--- | :--- | :--- |
| Design and run highly available services on the STACKIT Kubernetes cluster | No enterprise cluster operations, no Helm releases, no cluster-level autoscaling | **gap** |
| CI/CD landscape (GitLab) and IaC with Terraform, Ansible, Helm | Gates that run in CI and on the host, declarative hosts, rollback by pointer. **No GitLab CI, no Terraform, no Ansible, no Helm** | partial — right discipline, other tools |
| Network integration between microservices, Java nodes and load balancers | Linux networking from the host side: nftables default-deny, WireGuard mesh, SSH CA, DNS and MTU diagnosis with tcpdump | partial |
| Sovereign cloud SLAs via autoscaling and observability | Ledger every 15 minutes (job status, generation age, disk, PSI), alerting on any non-ok state, a green socket is not proof | strong on observability, **gap** on SLA autoscaling |
| Cluster hardening: pod security, network policies, BSI C5, DORA | nftables, SOPS/age secrets, short-lived certificates. **No pod security, no C5 or DORA audit work** | **gap** |
| Translate requirements into standardised, scalable cloud architectures | Thirteen hosts as one declaration, options derived rather than copied, per-host projections | strong in miniature |
| DevOps culture, agile methods, high-security hosting | Single-operator ownership end to end, gates instead of promises, secrets per host | strong |
| Very good German, good English | German C1, English native | strong |

## Portal schema — RocketApply (SAP BTP)

The apply button posts to `hrplattformprod-rocketapply-prod-scos-rocketapply.cfapps.eu20.hana.ondemand.com/app/`
with the job id GT4627. The form is a single-page app behind a session, so the mapping below is the
standard RocketApply candidate shape rather than observed HTML; the job id and recruiter are verified.

| # | Field (standard RocketApply) | Answer |
| :-- | :--- | :--- |
| 1 | Job id (hidden) | GT4627 |
| 2 | Anrede / Vorname | Herr, Matt |
| 3 | Nachname | Ji |
| 4 | E-Mail | matt@bountystash.com |
| 5 | Telefon | +49 173 3281570 |
| 6 | Lebenslauf | `lebenslauf.pdf` (2 Seiten, deutsch) |
| 7 | Anschreiben | `anschreiben.pdf` (1 Seite, deutsch) |
| 8 | Gehaltsvorstellung | 85.000 EUR brutto |
| 9 | Frühester Eintritt | sofort oder nach Vereinbarung |
| 10 | Wohnort / remote | Gutach im Breisgau, ca. 190 km; Remote-Anteil zu klären |
| 11 | Sprachen | Deutsch C1, Englisch Muttersprache |
| 12 | Arbeitserlaubnis | unbefristetes Niederlassungsrecht, kein Sponsoring |
| 13 | Wie aufmerksam geworden | Schwarz Digits Jobsuche |
| 14 | Datenschutz-Einwilligung | ja |

## Compensation note

85.000 EUR is above the XING estimate for the sibling GT4121 Kubernetes role at this site
(56.000 – 76.000). The ask is defensible for platform work but expect it to be tested; the
Deutsch requirement and the ServiceNow enterprise context are the parts Matt actually meets.

## Tailoring notes

- CV from a **packet-local corpus copy** (`lebenslauf.json` here); the canonical German corpus is
  an energy and risk CV and carries no platform material. Five Bountystash bullets were added for
  declared hosts, gate discipline, MicroVM lifecycle, ledger telemetry and the SSH CA mesh.
- `Kubernetes` removed from the DevOps skill line: the letter states it was never operated, and the
  JD asks for enterprise cluster experience, so a skill entry would only invite the mismatch.
- The selector reads the advert body only, not the provenance header.

## Checks

| Check | Result |
| :--- | :--- |
| `pdfinfo lebenslauf.pdf` | **2 pages** (budget 2) |
| `pdfinfo anschreiben.pdf` | **1 page** (budget 1) |
| `task checks:prose` | 189 prose files, exit 0 |
| selection | 10/37 highlights, 0/0 projects |
| sha256 CV | `1b06ec5ff17fc7843b0dee252da81b5e64c0ecd85fd147138d734e9c7855fd6b` |
| sha256 letter | `9259051dc6cd1ef3984aea0bacea7def0045158a7c3033a8eb17b964dd5cc44e` |

## Next actions

1. Submit via RocketApply with GT4627, both PDFs attached.
2. Ask early about the remote share: 190 km rules out daily presence, and the posting is on-site.
3. In the interview, lead with gate discipline and observability, then name Terraform/Ansible as
   the tools to learn on the job rather than claiming them.
