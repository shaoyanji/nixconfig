# SINC GmbH — DevOps Engineer (m/w/d)

**BA advert `12288-4996757754-S`.** Wiesbaden, Vollzeit, unbefristet, Beginn ab sofort. Hybrid mit
bis zu 60 Prozent Home Office und flexiblen Arbeitszeiten. SINC builds GovTech systems for public
institutions; the role is the internal IT interface between software development and IT operations.

| | |
| :--- | :--- |
| Role ID | `sinc-devops` |
| BA reference | 12288-4996757754-S |
| SINC job ID | 63891414 (`jobs.sinc.de/jobs/63891414`) |
| XING mirror | `xing.com/jobs/wiesbaden-devops-engineer-158462184` — now answers **410 Gone** |
| Employer | SINC GmbH, IT-Dienstleister, Wiesbaden |
| Contract | Vollzeit, unbefristet, ab sofort |
| Location | Wiesbaden, hybrid (60 % Home Office, flexible Arbeitszeiten) |
| Salary (advertised estimate) | XING estimate 60.500 – 83.000 EUR |
| Salary (ask) | **80.000 – 88.000 EUR**, letter states the range |

## Candidate facts used

| Fact | Value |
| :--- | :--- |
| Name | Matt Ji |
| Address | Am Burgerhof 4, 79261 Gutach im Breisgau |
| E-mail / phone | matt@bountystash.com / +49 173 3281570 |
| Languages | German C1, English native |
| Right to work | US citizen with German permanent residence, no sponsorship needed |
| Distance | ~300 km to Wiesbaden; remote-first with presence days |
| Start | sofort oder nach Vereinbarung |

## Source note — read this before quoting requirements

The BA page is a stub that links to "Externe Seite"; the XING mirror is gone (410), and
`jobs.sinc.de` timed out from here on 2026-11-22. The description in `job-description.txt` is the
advert's own text as indexed by the search engine, plus the hybrid/Home-Office terms from the
jobleads listing of the same advert. **No requirement list (must-have skills) was retrievable**, so
the fit map below works from the tasks that were published and marks what it cannot verify.

## Fit map

| Requirement (advert) | Evidence | Verdict |
| :--- | :--- | :--- |
| Internal interface between development and operations | Single operator of a thirteen-host fleet: the same repository is the app, the platform and the runbook | strong in miniature |
| Provide platforms, analyse operational requirements, keep processes stable | Feature-list hosts, one gate in CI and on the host, ledger for job status and generation age | strong |
| Operate, optimise and extend dev, test and integration environments | Environments are generated from one declaration; a rebuild reproduces the previous state exactly | strong |
| Develop and stabilise internal platform and infrastructure services | NixOS, systemd units with per-slice memory limits, nftables default-deny, SSH CA with short-lived certificates | strong |
| Configuration management | Declaration with pinned inputs and derived option surface; no Ansible used | **gap** in tool, strong in concept |
| GitOps pipelines, automated releases | Desired state pulled from the repository; a release is build → gate → activate, with rollback as a pointer. No Argo CD, Flux or Helm | partial — same model, different tool |
| Container platform (Kubernetes, OpenShift) | Containers only as pinned build environments, never a production platform | **gap** |
| CI pipelines (GitLab, Jenkins) | Gates run in CI and on the host, but no pipeline configuration was authored | partial |
| Public-sector delivery, ITIL change and incident process | No ITIL process work; public procurement is new | **gap**, stated in the letter |
| German at working level | German C1, documents written in German for German operations | strong |

## Portal mapping — BA advert → SINC career route

The BA advert carries no application form of its own; it forwards to the employer. SINC runs its own
careers site with a document upload, and XING is the dead mirror. So the two identifiers that matter
are the BA reference and SINC job ID 63891414.

| # | Field | Answer |
| :-- | :--- | :--- |
| 1 | Referenz | 12288-4996757754-S / 63891414 |
| 2 | Stelle | DevOps Engineer (m/w/d), Wiesbaden |
| 3 | Anrede / Vorname | Herr, Matt |
| 4 | Nachname | Ji |
| 5 | E-Mail | matt@bountystash.com |
| 6 | Telefon | +49 173 3281570 |
| 7 | Anschrift | Am Burgerhof 4, 79261 Gutach im Breisgau |
| 8 | Lebenslauf | `lebenslauf.pdf` (2 Seiten) |
| 9 | Anschreiben | `anschreiben.pdf` (1 Seite) |
| 10 | Gehaltsvorstellung | 80.000 – 88.000 EUR brutto |
| 11 | Frühester Eintritt | sofort oder nach Vereinbarung |
| 12 | Arbeitsmodell | remote-first, Präsenztage und Einarbeitung in Wiesbaden |
| 13 | Arbeitserlaubnis | Niederlassungsrecht, kein Sponsoring |
| 14 | Deutschkenntnisse | C1 |
| 15 | Datenschutz-Einwilligung | ja |

## Salary

The only number in the advert is XING's estimate, 60.500 – 83.000 EUR, which is a market guess rather
than a band SINC published. The ask is 80.000 – 88.000, stated as a range in the letter: it sits at
the top of the estimate and above it, which is defensible for a DevOps engineer who owns platform
and release work, and low enough not to price the application out before a conversation. If SINC
counters with the estimate's middle, the negotiation is about scope (on-call, release ownership),
not about the number.

## What the letter says

It opens on GovTech as the reason reliability must be provable — an outage is an open case file, not
a lost conversion. The second paragraph is Linux operations down to cgroups, PSI, nftables and
tcpdump. The third is configuration management and the GitOps shape it actually runs: desired state
in the repository, machine pulls it, release is build → gate → activate, rollback is a pointer. The
fourth names Ansible, Argo CD, Flux, Helm, Kubernetes, OpenShift, GitLab/Jenkins and ITIL as absent.
The fifth is the 300 km and the 60 % Home Office, with the salary range and no sponsorship needed.

## Checks

| Check | Result |
| :--- | :--- |
| `pdfinfo lebenslauf.pdf` | **2 pages** (budget 2) |
| `pdfinfo anschreiben.pdf` | **1 page** (budget 1) |
| `task checks:prose` | 200 prose files, exit 0 |
| selection | 11/38 highlights, 3/10 projects |
| sha256 CV | `3d1896a75b7a131c3214aa4c6b17e90c48691675064f2e5357bc3696b226eaab` |
| sha256 letter | `38a3c65ef2bc66557ba0ca42767696cf3d8b83e34e4adf8e7fd156c092afbcc4` |

## Next actions

1. Open `jobs.sinc.de/jobs/63891414` when the site answers, read the actual requirement list, and
   revise paragraph four if it names a tool the corpus could honestly claim.
2. Submit through the SINC career route quoting 63891414 and the BA reference; the BA page only
   forwards.
3. Ask in the first call how the 60 % Home Office is scheduled — a quarterly presence rhythm is a
   different commute from a weekly one at 300 km.
