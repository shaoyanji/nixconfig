# ENVIRIA Energy Holding GmbH — Commercial Asset Manager Solar PV (all genders)

Personio job **2635638**, Frankfurt am Main, hybrid. German packet. Native Typst sources; the old
`Enviria_*.txt` / `Enviria_*.pdf` files are removed.
Status: compiled and checked, **nothing submitted**.

| Field | Value |
| :--- | :--- |
| Role ID | `enviria` |
| Employer | ENVIRIA Energy Holding GmbH |
| Role | Commercial Asset Manager Solar PV (all genders) |
| Location | Frankfurt am Main — hybrid; Voll- oder Teilzeit ab 30 h |
| Language | **de** |
| Apply URL | https://enviria.jobs.personio.de/job/2635638?language=de |
| Fit | **5** |

## Personio form fields

The supplied Lever URL (`jobs.lever.co/enviria/3b6bb897-…`) returns 404; the live posting is Personio 2635638.

| Field | Value |
| :--- | :--- |
| Vorname | Matt |
| Nachname | Ji |
| E-Mail * | matt@bountystash.com |
| Telefon | +49 1733281570 |
| Verfügbar ab * | 01.12.2026 |
| Gehaltsvorstellung * | 85.000–95.000 EUR brutto p.a. (field value from the earlier staging; the letter does not name a figure) |
| Wie hast Du von uns erfahren? * | ENVIRIA Website (`custom_option_77322`) |
| LinkedIn | https://linkedin.com/in/mattji |
| Lebenslauf | `lebenslauf.pdf` |
| Anschreiben | `anschreiben.pdf` |
| Arbeitszeugnisse / Sonstiges | not attached |
| Datenschutz | read and accepted |
| Citizenship / work permit | US citizen, unbefristete Niederlassungserlaubnis, no sponsorship |

## Fit map

| Requirement | Evidence | Verdict |
| :--- | :--- | :--- |
| Commercial asset management, operating phase | Asset manager, USD 100M+ solar portfolio, 10 MW PV | **core match** |
| Financial modelling, bank-grade | Yield and valuation models that satisfied bank audits | **core match** |
| Energy market operations | PPA trading models, gas storage/swing risk for EWE Trading, weather-derivative hedging | strong |
| Contracts, O&M and due diligence | Due diligence on O&M projects, a dozen USD 4–5M deals with banks and brokers | strong |
| Reporting, invoice audit | Bank and investor reporting, deviation analysis | strong |
| Data quality, plant performance | Meter/inverter/weather reconciliation, explicit error budget | strong |
| German market specifics (EEG, Direktvermarktung, MaStR) | **no contract ownership in the German market** | **gap, named in the letter** |
| German C1, English native | — | fulfilled |
| Work authorisation | Niederlassungserlaubnis, no sponsorship | fulfilled |

## The argument the letter makes

A solar park earns in the twenty years after construction, not during it — and across those twenty years contracts,
data quality and commercial control decide whether the modelled return holds. That is the operating phase Matt ran
for four years, so the packet stays in that register instead of selling software.

The one gap is stated outright: **no contract ownership in the German market** — EEG, Direktvermarktung and MaStR
come from study and observation, not from carrying the contract. Portfolios were US-based. Framed as the reason to
apply rather than something to discover in an interview.

## Checks

| Check | Result |
| :--- | :--- |
| Old `Enviria_*` files | removed |
| `chmod u+w *.pdf` | applied |
| `typst compile lebenslauf.typ` | exit 0, no warnings |
| `typst compile anschreiben.typ` | exit 0, no warnings |
| `pdfinfo lebenslauf.pdf` | **2 pages** |
| `pdfinfo anschreiben.pdf` | **1 page** |
| Markers CV | `Niederlassungserlaubnis`, `100 Mio`, `EWE Trading`, `Bankenprüfung` |
| Markers letter | `Commercial Asset Manager`, `ENVIRIA`, `EEG`, `PPA` |
| `task checks:prose` | 242 prose files, exit 0 |
| sha256 CV | `fc8c7351b94734ba4a330949b4225012a636a8b05c6b3dc3862b571e208fd0a1` |
| sha256 letter | `0244b59f0cc97a73a673012f71dbc295c8bfbc60dc6b56e98abec8e94144ffa0` |
| DB read-back | verified after upsert |

## Next steps

1. Submit through Personio; salary and start date go in the form, not the letter.
2. Expect questions on EEG/Direktvermarktung — have a concrete answer about how the learning gap closes in the first
   three months.
3. Ask which share of the portfolio is under PPA versus merchant exposure, since that changes the risk work.
