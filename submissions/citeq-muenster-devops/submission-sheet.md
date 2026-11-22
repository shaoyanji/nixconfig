# citeq — IT-Dienstleister der Stadt Münster — DevOps Engineer (m/w/d)

**Deadline 29.11.2026.** Interamt ID `1510832`, Ausschreibungsnummer `22-029/26`, unbefristet,
nächstmöglicher Eintritt, Scheibenstraße 109, Münster. Team "Web-Entwicklung und -Betrieb".

| | |
| :--- | :--- |
| Role ID | `citeq-muenster-devops` |
| Interamt ID | 1510832 |
| Ausschreibungsnummer | 22-029/26 |
| Employer | citeq, zentraler IT-Dienstleister für Stadt Münster und Kommunen im Münsterland |
| Pay | TVöD/TV IKT **E 9a – E 11**, Beamt*innen A 11 LBesO A NRW |
| Hours | Vollzeit, teilbar; Home-Office und Gleitzeit ausgeschrieben |
| Fachliche Ansprechperson | Tobias Burgmann, 0251/492-1868, Burgmann(at)citeq.de |
| Recruiting | Oliver Musiolik, 0251/492-1054 |

## Candidate facts used

| Fact | Value |
| :--- | :--- |
| Name | Matt Ji |
| Address | Am Burgerhof 4, 79261 Gutach im Breisgau |
| E-mail / phone | matt@bountystash.com / +49 173 3281570 |
| Languages | German C1, English native |
| Right to work | US citizen with German permanent residence, no sponsorship needed |
| Distance | ~600 km to Münster, so remote with presence days |
| Salary | TVöD band applies; letter asks for **E 11**, no euro figure |
| Start | nächstmöglicher Zeitpunkt |

## TVöD VKA E 9a – E 11 expectations

From the advert itself: **3.877,94 – 6.326,77 EUR monthly** gross, plus a **85 % Christmas bonus**
and a performance component (LoB). That is roughly **49.800 – 81.300 EUR a year** including the
bonus, and the band is wide because the same advert covers three grades.

| Stufe basis | Monthly | Annual, incl. 85 % bonus |
| :--- | :--- | :--- |
| E 9a entry | 3.877,94 | ≈ 49.800 |
| E 11 top | 6.326,77 | ≈ 81.300 |

Practical reading: an E 11 appointment with several years of relevant experience typically lands in
the middle steps, not the top, so the realistic expectation is around **60.000 – 70.000 EUR**. The
letter therefore asks for the grade, not a number — in the public sector the grade is the salary,
and naming a figure signals that the tariff has not been read.

## Fit map

| Requirement (JD) | Evidence | Verdict |
| :--- | :--- | :--- |
| Ansible configuration management, kept running and developed further | No Ansible. Nix declarations with derived options and rollback by pointer do the same job | **gap** in tool, strong in concept |
| Prometheus, Grafana, Graylog monitoring | No such stack. Sentinel ledger every 15 minutes, alerting on any non-ok state, journald logs, PSI/cgroups | **gap** in tool, partial in method |
| Optimise GitLab CI pipelines, automate release, deployment and tests | Gates that run in CI and on the host; no GitLab pipeline built | partial |
| Develop and maintain central Docker images | No image maintenance; containers only as a pinned build environment | **gap** |
| Security of web applications | SOPS/age secrets, SSH CA with short-lived certificates, nftables default-deny; no web-app hardening or pentest work | partial |
| Linux web server infrastructure and IT security, multi-year (desirable) | NixOS fleet, systemd, cgroups/PSI, DNS and MTU diagnosis; no nginx/PHP/TYPO3 operations | partial |
| Analytical, independent problem solving | Single-operator fleet, incidents end in a check or a gate | strong |
| Communication across interfaces | Documents in German for a German-speaking operation, presents the gap rather than hiding it | strong |

## Interamt application mapping

Interamt runs its own application flow: register with the portal, then "Jetzt online bewerben" on
the advert. Documents are uploaded, and the cover letter field is the one that carries the argument.

| # | Field | Answer |
| :-- | :--- | :--- |
| 1 | Stellen-ID / Az. | 1510832 / 22-029/26 |
| 2 | Anrede / Vorname | Herr, Matt |
| 3 | Nachname | Ji |
| 4 | E-Mail | matt@bountystash.com |
| 5 | Telefon | +49 173 3281570 |
| 6 | Anschrift | Am Burgerhof 4, 79261 Gutach im Breisgau |
| 7 | Anschreiben | `anschreiben.pdf` (1 Seite) |
| 8 | Lebenslauf | `lebenslauf.pdf` (2 Seiten) |
| 9 | Qualifikation | M.Sc. Erneuerbare-Energien-Management, B.Sc. Erdöltechnik |
| 10 | Berufserfahrung | 2010 – heute, zuletzt selbstständige Plattformarbeit |
| 11 | Gehaltswunsch / Eingruppierung | E 11 angestrebt, TVöD VKA |
| 12 | Frühester Eintritt | nächstmöglicher Zeitpunkt |
| 13 | Arbeitsmodell | Home-Office aus Gutach, Präsenztage nach Absprache |
| 14 | Schwerbehinderung | keine Angabe |
| 15 | Einverständnis Datenverarbeitung | ja |

## What the letter says

It opens on the municipal difference — users who cannot switch providers — then names Nix as the
configuration management it actually runs, the ledger and alerting as the monitoring it actually
runs, and admits in the fourth paragraph that GitLab pipelines, Docker images and TYPO3 web servers
are absent. It closes with E 11 rather than a euro figure, and with the 600 km reality.

## Checks

| Check | Result |
| :--- | :--- |
| `pdfinfo lebenslauf.pdf` | **2 pages** (budget 2) |
| `pdfinfo anschreiben.pdf` | **1 page** (budget 1) |
| `task checks:prose` | 196 prose files, exit 0 |
| selection | 11/37 highlights, 0/0 projects |
| sha256 CV | `59f5550ee29d75db44c8e58b8caf3876847a17e234fafeadc54a2d106d90fbbb` |
| sha256 letter | `c481c651959fdcfe4b7786dddab557801d3963b1c62cdefbbf01420983ed6c19` |

## Next actions

1. Submit before **29.11.2026** through Interamt; the portal needs an account, so register first.
2. Book the offered workplace visit with Tobias Burgmann if it can happen before the deadline — it
   is also the fastest way to learn how real the home-office share is at 600 km.
3. If invited, expect a question about the Ansible and Grafana gap: the answer is that the concept
   transferred twice already and the tool is a week of work.
