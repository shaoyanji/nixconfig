# Bechtle AG (KubeOps) — Cloud Platform Engineer (w/m/d) (Remote)

**The role is live, the portal route is broken.** The advert was mirrored on the
Arbeitsagentur two days ago (`15086-44517367-1019-S`), but Bechtle's own URL

```
https://jobs.bechtle.com/job/Bisingen-Cloud-Platform-Engineer-%28wmd%29-%28Remote%29-72406/1367643158
```

302s to `jobs.bechtle.com/errorpage/?errortype=Exception` (HTTP 200 after redirect,
title only "Jobs bei Bechtle"). Adding `?locale=de_DE` changes nothing, and the site is
SuccessFactors RMK (`rmkcdn.successfactors.com`), so the requisition id `1367643158` is
simply not routable there any more. Apply through Bechtle's job search for
"Cloud Platform Engineer" and pick the Balingen entry; keep the BA mirror as proof of the
advert if the portal cannot find it.

| | |
| :--- | :--- |
| Role ID | `bechtle-cloud-platform-engineer-remote` |
| Employer | Bechtle AG, KubeOps (Bechtle Gruppe) |
| Office | Bisingen bei Hechingen / Bechtle Platz 1, 72336 Balingen |
| Model | 100% remote inside Germany for anyone living >60 km away; otherwise 90 office days a year |
| Recruiter | Christopher Waldraff, christopher.waldraff@bechtle.com |
| Vetting | **SÜ2** required |
| Language | very good German required, good English |

## Candidate facts used

| Fact | Value |
| :--- | :--- |
| Name | Matt Ji |
| Address | Am Burgerhof 4, 79261 Gutach im Breisgau |
| E-mail / phone | matt@bountystash.com / +49 173 3281570 |
| Distance | ~130 km to Bisingen, so the >60 km remote rule applies |
| Languages | German C1, English native |
| Right to work | US citizen with German permanent residence, no sponsorship needed |
| Salary | target **85.000 EUR**; letter states 85.000 |
| Start | immediate or by agreement |

## Fit map

| Requirement (JD) | Evidence | Verdict |
| :--- | :--- | :--- |
| Build and automate cloud-native platforms, integrate into existing environments | 13-host fleet declared as one flake, projections per host, integration through the same module gate | strong on method, small in scale |
| CI/CD, DevSecOps and automation | Every change passes a gate that runs in CI and on the host; no pipeline tooling beyond that | partial |
| Infrastructure as code, ideally Terraform | Nix as the IaC: declaration, reproducible generations, rollback by pointer. **No Terraform** | strong concept, wrong tool |
| Operate and develop a private cloud and platform services | Own hardware, secrets per host with SOPS/age, SSH CA with short-lived certificates, declarative MicroVMs | strong |
| Kubernetes, Docker or comparable container tech | Containers only as a pinned build environment; **no production Kubernetes** | **gap** |
| CI/CD tooling such as GitLab or GitHub | Git as the only change path, but no GitLab/GitHub pipeline history of note | partial |
| Solid Linux and DevOps concepts | NixOS daily, systemd units and cgroups, PSI-driven alerting, nftables, SSH CA | strong |
| Very good German for customer work | C1, letter and CV in German | strong |
| SÜ2 vetting | Willing; as a US citizen the process can run longer | partial |

## Portal form mapping

The SuccessFactors application form could **not** be read, because the job route is the
thing that is broken. What follows is the standard SuccessFactors profile shape that
Bechtle's career site uses, with the answers prepared; treat field names as the usual SF
keys and the labels as what the form asks, not as observed HTML.

| # | Field | Answer |
| :-- | :--- | :--- |
| 1 | `firstName` | Matt |
| 2 | `lastName` | Ji |
| 3 | `email` | matt@bountystash.com |
| 4 | `phone` | +49 173 3281570 |
| 5 | `country` / residence | Deutschland, Am Burgerhof 4, 79261 Gutach im Breisgau |
| 6 | CV upload | `lebenslauf.pdf` (2 pages) |
| 7 | Cover letter | `anschreiben.pdf` (1 page) |
| 8 | Salary expectation | 85.000 EUR brutto jährlich |
| 9 | Earliest start | sofort oder nach Vereinbarung |
| 10 | Remote / location | 100% remote aus Gutach im Breisgau, ca. 130 km zum Standort |
| 11 | SÜ2 readiness | ja, Bereitschaft zur Sicherheitsüberprüfung |
| 12 | Work permit | ja, unbefristetes Niederlassungsrecht, kein Sponsoring nötig |
| 13 | Languages | Deutsch C1, Englisch Muttersprache |
| 14 | How did you hear | Bechtle Karriereseite |
| 15 | Data protection consent | ja |

## Compensation note

XING estimates 72.000 – 78.500 EUR for this title at Bechtle. 85.000 is therefore at the
top of the plausible band, not inside it; the letter states 85.000 because that is the
target, and the recruiter call is where it gets tested. The role is unbefristet with a
company pension subsidy, which is worth counting.

## Tailoring notes

- The CV is built from a **packet-local corpus copy** (`lebenslauf.json` here). The canonical
  German corpus is an energy and risk CV, so four Bountystash bullets were added for the
  fleet work (declared hosts, gate-in-CI automation, ledger telemetry, Go/Python toil removal),
  plus `Infrastruktur als Code` and `Betrieb & Telemetrie` skill lines.
- `Kubernetes` was removed from the DevOps skill line again: the letter states it was never
  operated in production, and a CV that lists it invites the wrong first question.
- The keyword selector reads the advert body only, not the provenance header.

## Checks

| Check | Result |
| :--- | :--- |
| `pdfinfo lebenslauf.pdf` | `2` pages (budget 2) |
| `pdfinfo anschreiben.pdf` | `1` page (budget 1) |
| `task checks:prose` | `186 prose files, exit 0` |
| selection | `15/36 highlights, 0/0 projects` |
| sha256 CV | `ced0905fd024e3f84a200329425db3651e6fcac8b7a10ead440c38f9ae4ab5a1` |
| sha256 letter | `5ab72d53b60818fbc07f4952ec4b023adf0b4bc9ff3526b7965fd3a0ab2a09a5` |

## Next actions

1. Find the live Bechtle entry through the careers search (the direct link is dead), or write
   to Christopher Waldraff with the BA reference if the portal keeps erroring.
2. Submit the two PDFs, salary 85.000, SÜ2 consent.
3. If the form asks for a Kubernetes depth self-rating, answer honestly — the letter already
   sets the expectation.
