# Flower — Asset Manager, Energy Assets Germany

Remote, based in Germany. Teamtailor **8532038**, reports to the Head of Asset Management in Stockholm. English packet;
the posting asks for the CV in English. Native Typst sources; the legacy `Flower_*.pdf/.txt`, `Matt_Ji_Resume_Flower.pdf`
and `selection.json` are removed.
Status: compiled and checked, **nothing submitted**. **[applied per apps DB `flower` — this sheet's status predates submission]**

| Field | Value |
| :--- | :--- |
| Role ID | `flower` |
| Employer | Flower (BESS portfolio operator, Stockholm-managed, 30+ nationalities) |
| Role | Asset Manager, Energy Assets Germany |
| Location | Remote, based in Germany |
| Language | **en** (corporate language; CV requested in English) |
| Apply URL | https://flower.teamtailor.com/jobs/8532038-asset-manager-energy-assets-germany |
| Compensation | no band published; no figure in the letter |
| Fit | 4 (DB entry 5) |

## What the role owns

Availability as the core KPI for a German battery storage portfolio; O&M and SLA enforcement including penalty and bonus
clauses; the cost base and budget; EEG and BImSchG compliance; and the counterparties — landowners, municipalities, grid
operators, authorities. Technical and commercial at once, with a Stockholm team and German market reality.

## Fit map

| Requirement | Evidence | Verdict |
| :--- | :--- | :--- |
| Asset management of a renewable portfolio | Headed management of a portfolio above USD 100M, 10 MW of PV operated | **strong** |
| Availability as a managed number | Availability and cost were the two measures reported to investors | **strong** |
| O&M and SLA enforcement | Scoped contracts, tested guarantees, applied penalty clauses | **strong** |
| Cost base and budget ownership | Owned the budget, explained variance line by line | **strong** |
| Financial yield modelling | Yield, degradation and valuation models that survived bank review | **strong** |
| Due diligence | Technical and contractual O&M review for project managers | **strong** |
| German market counterparties | Grid operators, municipalities, authorities, landowners, banks, in German | **strong** |
| German C1, English native | Both, with German as the working language for authorities | **strong** |
| BESS hardware and revenue stack | **none** — solar PV; no ancillary services or capacity-market work | **gap, named** |
| Bazefield or comparable SCADA | **none**; own telemetry stack instead | gap |
| Owning BImSchG permitting files | **not claimed**; regulatory context known through ten years of work | gap |
| Existing German energy network | O3 Energy, Smart Energy 360, Fraunhofer ISE — named, not generalised | plus, not required |

Fit **4**: the commercial core of this role — availability, O&M enforcement, cost, yield models, German counterparties —
is the candidate's actual career, not an adjacent skill. It is not a 5 because the asset class is new: no BESS hardware,
no degradation behaviour, no revenue stack, no Bazefield. The DB keeps the instructed **5**.

## What the letter does differently

It opens with ownership rather than enthusiasm: ten years on the commercial side, and downtime as a line in a budget
someone had to explain. The middle paragraph is the one that matters for this role — *holding service providers to what
they signed* — with the detail that makes it credible: scoping, testing against guarantees, applying the penalty clause.

The gap paragraph is deliberately unhedged, because a role that owns availability for a battery fleet is not a place to
discover a surprise in month three: solar not storage, no ancillary services or capacity markets, no BImSchG file owned,
no Bazefield. Then the part that transfers without translation: grid operators, municipalities, authorities, landowners
and banks as recurring calls, in German, with the follow-up owned.

It closes with two questions that only someone from this world would ask: how availability is defined per asset today —
contractual or measured — and where the penalty clauses have actually bitten.

## The Teamtailor form, as it renders

| Control | Value |
| :--- | :--- |
| First / last name | Matt / Ji |
| Email **required** | matt\@bountystash.com |
| Phone | **1733281570** — the country selector already supplies +49; typing the leading zero produces +49 0173… and is rejected on submit |
| Upload CV | `lebenslauf.pdf` (2 pages, English) |
| Additional files | optional; add `anschreiben.pdf` only if you want the PDF, otherwise leave empty rather than duplicating the letter |
| Cover letter | paste the letter text |
| Consent **required** | privacy checkbox must be ticked or submit fails |

There is no location field and no LinkedIn field on this form; address and contact reach Flower through the CV header,
which is why the CV carries them. "Apply with LinkedIn" imports the profile as-is, which is not this tailored CV.

## Checks

| Check | Result |
| :--- | :--- |
| Legacy `Flower_*.pdf/.txt`, `Matt_Ji_Resume_Flower.pdf`, `selection.json` | removed |
| `chmod u+w *.pdf` | applied |
| `typst compile lebenslauf.typ` | exit 0, **0 warnings** |
| `typst compile anschreiben.typ` | exit 0, **0 warnings** |
| `pdfinfo lebenslauf.pdf` | **2 pages** |
| `pdfinfo anschreiben.pdf` | **1 page** |
| Markers CV | `availability`, `O&M`, `EEG`, `BESS` (gap), `USD 100M`, `German` |
| Markers letter | `Flower`, `availability`, `O&M`, `BESS`, `EEG`, `Stockholm` |
| Stray asterisks / salary / foreign-company leak | 0 / 0 / 0 |
| `task checks:prose` | 255 prose files, exit 0 |
| sha256 CV | `71eb8c55bf74b70a5dc0ca0fac61557c5ab15546a0e4886021bb564463631ccf` |
| sha256 letter | `c405fdd9ffe163a4de822689be2003e757904b7f58c4e5d98e8237f5079c1798` |
| DB read-back | verified after upsert |

## Before you submit

1. German will be tested in the first sentence you speak. Have three ready: how availability was calculated for the
   portfolio, one penalty clause you actually enforced, and what you did about a recurring fault.
2. Do not let the first call imply battery experience. The letter has already named it; repeating the caveat costs nothing,
   being caught by it costs the process.
3. Upload the English CV, not a German Lebenslauf, even though the form is German-facing.
