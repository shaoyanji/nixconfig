# energy & meteo systems GmbH — Systemadministrator:in (Wind- und Solarprognosen)

Advert is the get-in-it copy of BA `13644-311398-S`: Oldenburg, Home-Office möglich, unbefristet.
The full text is already in `job-description.txt`; this sheet adds the fit map, the salary band and
the portal answers.

| | |
| :--- | :--- |
| Role ID | `energy-meteo-sysadmin` |
| BA reference | 13644-311398-S |
| get-in-it posting | p311398 |
| Employer | energy & meteo systems GmbH, Oldenburg (Oldb) |
| Work model | Home-Office möglich, flexible hours, every overtime hour recorded |
| Contract | unbefristet, 30 days holiday not stated — ask |
| Core of the job | 1st/2nd level support, hardware lifecycle, Linux admin, monitoring, software rollouts, IT security |

## Candidate facts used

| Fact | Value |
| :--- | :--- |
| Name | Matt Ji |
| Address | Am Burgerhof 4, 79261 Gutach im Breisgau |
| E-mail / phone | matt@bountystash.com / +49 173 3281570 |
| Languages | German C1, English native |
| Right to work | US citizen with German permanent residence, no sponsorship needed |
| Distance | ~700 km to Oldenburg, so remote with presence days |
| Salary | target **65.000 – 72.000**, letter states **68.000** |
| Start | immediate or by agreement |

## Why the domain is real, not claimed

The canonical CV already carries it: **O3 Energy, Asset Manager 2016 – 2020**, hedging and weather
derivative models, a portfolio of about 100 million USD, plus **M.Sc. Renewable Energy Management,
Albert-Ludwigs-Universität Freiburg**. Wind, Solar and Erneuerbare appear 8, 7 and 5 times in the
German corpus without any packet-local addition. This is the one posting in the set where the energy
history is the strongest card rather than a footnote.

## Fit map

| Requirement (JD) | Evidence | Verdict |
| :--- | :--- | :--- |
| IT support, 1st and 2nd level, single point of contact for colleagues | Single-operator support for thirteen hosts and a mail archive; no enterprise helpdesk, no ticket queue | partial |
| Hardware lifecycle, including admin and monitoring of the IT systems | Thirteen hosts installed, patched, replaced; monitoring via ledger and alerting | strong |
| Linux systems | NixOS fleet, systemd, cgroups/PSI, nftables, DNS and MTU diagnosis | strong |
| Python or another scripting language | Python and Go tooling in daily use | strong |
| IT security when installing hardware and software | SOPS/age secrets, SSH CA with short-lived certificates, default-deny firewall | strong |
| Installing software, security patches, updates and testing them | Declared updates through one source, changes gated in CI and on the host | strong |
| Software rollouts to client systems, mobile device management | Never done: no client fleet, no MDM, no Windows administration | **gap** |
| Evaluating and introducing new software and open-source tools | Nix, MicroVMs, gatus-style alerting, self-built tooling | strong |
| Careful IT documentation | One page per intervention with cause, command and way back | strong |
| Renewable-energy context | O3 Energy asset management, weather derivatives, M.Sc. Renewable Energy Management | strong |

## Portal schema — get-in-it and the direct route

Two ways in, and they take different data:

1. **get-in-it** (`get-in-it.de/jobsuche/p311398`) — the aggregator advert; "Jetzt bewerben" hands off
   to the employer, and the BA reference `13644-311398-S` is what survives if the posting is pulled.
2. **energy & meteo systems directly** (`energy-meteo.com/karriere`) — a small company, so a mail to
   the address on the careers page with CV and letter attached works as well as a form, and often
   better.

| # | Field | Answer |
| :-- | :--- | :--- |
| 1 | Referenz | 13644-311398-S / p311398 |
| 2 | Anrede / Vorname | Herr, Matt |
| 3 | Nachname | Ji |
| 4 | E-Mail | matt@bountystash.com |
| 5 | Telefon | +49 173 3281570 |
| 6 | Anschrift | Am Burgerhof 4, 79261 Gutach im Breisgau |
| 7 | Lebenslauf | `lebenslauf.pdf` (2 Seiten) |
| 8 | Anschreiben | `anschreiben.pdf` (1 Seite) |
| 9 | Gehaltsvorstellung | 68.000 EUR brutto (Band 65.000 – 72.000) |
| 10 | Frühester Eintritt | sofort oder nach Vereinbarung |
| 11 | Arbeitsmodell | Home-Office aus Gutach, Präsenztage nach Absprache |
| 12 | Deutschkenntnisse | C1 |
| 13 | Arbeitserlaubnis | unbefristetes Niederlassungsrecht, kein Sponsoring |
| 14 | Datenschutz-Einwilligung | ja |

## Remote and Oldenburg terms

The advert says Home-Office is possible and hours are flexible, but the job is written as an
on-site support role: printers, laptops, phones and colleagues at the Oldenburg site. At 700 km the
honest position is remote-first with a real presence commitment during onboarding, and the letter
says exactly that rather than implying relocation. Ask for the expected presence days in the first
call — if the answer is "most days", this posting is not workable from Gutach.

## Salary

Band requested: 65.000 – 72.000 EUR. The letter states 68.000, in the middle. The role is support
and administration rather than platform engineering, so the band is the realistic one; the energy
domain and the Linux depth are the two arguments for the upper half.

## Checks

| Check | Result |
| :--- | :--- |
| `pdfinfo lebenslauf.pdf` | **2 pages** (budget 2) |
| `pdfinfo anschreiben.pdf` | **1 page** (budget 1) |
| `task checks:prose` | 194 prose files, exit 0 |
| selection | 10/37 highlights, 0/0 projects |
| sha256 CV | `1b093513f7b63df1995fa1de5fb708f927dd94ff81919f1fb7bf7b42c97c74cd` |
| sha256 letter | `d990b8fecf56e84ada370322c62daf85ce7c5a0e2d08ca7e1f6c17ae84fa3e67` |

## Next actions

1. Ask for presence days before submitting; the answer decides whether this is viable at all.
2. Submit via the direct route if the company site has a mail address — small team, direct works.
3. Expect a question about why a platform engineer applies for 1st/2nd level: the letter answers it,
   keep that answer consistent in the call.
