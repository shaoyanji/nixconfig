# SVA System Vertrieb Alexander — DevOps Engineer – Container und Cloud (m/w/d), j456

**Status: packet built 2026-11-22, NOT submitted.** No form filled, no upload sent. Pipeline
record `sva-devops-engineer-container-und-cloud` at stage `prep`.

Third SVA packet in this repo: j734 (Linux consultancy, `submissions/sva-linux/`), j262
(infrastructure automation, `submissions/sva-automation/`), and this one. Same portal, same form
family, one hiring group — see the sequencing note at the end.

## Role

| Field | Value |
| :--- | :--- |
| Company | SVA System Vertrieb Alexander GmbH (HQ Borsigstraße 26, 65205 Wiesbaden) |
| Role | DevOps Engineer – Container und Cloud (m/w/d) |
| Kennung | **j456**; application form **f456** |
| Posting | https://www.sva.de/de/job-portal/DevOps-Engineer-Container-und-Cloud-mwd-de-j456.html |
| Form | https://www.sva.de/de/job-portal/DevOps-Engineer-Container-und-Cloud-mwd-de-f456.html |
| Locations | 29 sites, choice at application: **Freiburg** (Schnewlinstraße 12, 79098) ~25 km from home |
| Employment | full time, permanent; mobile work per assignment |
| Posted / valid | **2026-09-22, `validThrough` 2026-12-31** — roughly five weeks left; this is the one SVA req with a real expiry |
| Language | German C1+, English B2+ |
| Compensation | not published; this packet states **EUR 85,000 p.a.** |
| Pipeline record | `sva-devops-engineer-container-und-cloud`, stage `prep` |
| Folder | `submissions/sva-container/` |

## What the posting asks for

- Build the customer's **container platform** and integrate it into their cloud estate.
- Work mainly with **Kubernetes** — vanilla, or integrated (RKE, Red Hat OpenShift).
- Use **Infrastructure-as-Code** to automate the environments.
- **Security** as a first-class theme: hardening, **admission control**, observability, compliance
  with security standards.
- **Resilience**: chaos engineering and disaster recovery practice.
- Community and project contribution, evaluating ideas with colleagues.
- Profile: Kubernetes experience (vanilla or a distribution), **SRE practices** with common OSS
  tools, *ideally* **immutable OS** and container security, C1 German / B2 English, travel in
  Germany, and **willingness to undergo a security check under SÜG level 2**.

## The eligibility question that decides this one

**SÜG-Stufe 2 (SÜ2)** is a German security clearance, and the posting requires willingness to go
through it. A SÜ2 clearance presumes German citizenship in practice; § 9 SÜG allows allied
nationals only as an exception, decided case by case by the responsible ministry. The candidate is
a **US citizen with German permanent residence** — permanent residence is a residence title, not
citizenship, and does not settle the SÜ2 question.

So the letter states willingness and names the risk in the same sentence, and the sheet records it
as the first thing to clarify with SVA: if the role means actual SÜ2-cleared project work, this
application probably cannot proceed; if "Bereitschaft" only means consenting to the process, it
may. Nothing in the packet pretends the clearance is a formality.

## Files

| File | Notes |
| :--- | :--- |
| `packet/lebenslauf.pdf` | **2 pages** A4, German headings, sha256 `e90ba8dfda9a70871438f7afa63321f035cb51b7d4cec14d876b09b236de5850` |
| `packet/anschreiben.pdf` | **1 page** A4, German, sha256 `3be9609d968fccf3df158e9329fbdd9933c6fb57d62a7a9788c1e9619c26c8f4` |
| `packet/selection.json` | 13/32 highlights, 4/10 projects |
| `lebenslauf.pdf`, `anschreiben.pdf`, `selection.json` | read-only copies for upload |
| `letter.json` | German letter source |
| `job-description.txt` | German posting text from the page's schema.org `JobPosting` plus header (29 sites, dates) |
| `submission-sheet.md` | this sheet |

Built with:

```bash
NIX_CONFIG='builders =' bash scripts/task/appflow-packet.sh \
  --id sva-devops-engineer-container-und-cloud \
  --language de --resume "$HOME/.config/appflow/lebenslauf.json" \
  --jd submissions/sva-container/job-description.txt \
  --letter submissions/sva-container/letter.json \
  --out submissions/sva-container/packet
```

`--language de` overrides the record's stale `en`; `NIX_CONFIG='builders ='` keeps the build local.
`typeset` reported 2 pages against a budget of 2 and 1 against 1.

## The form (f456), field by field

Server-rendered PHP, read from the markup — names are `bewerbung_form[...]`, required flags are
`aria-required="true"`.

| Portal label | Input name | Required | Value |
| :--- | :--- | :--- | :--- |
| Anredetitel | `titel` | no | **Herr** |
| VORNAME | `vorname` | **yes** | **Matt** |
| NACHNAME | `nachname` | **yes** | **Ji** |
| STRASSE | `strasse` | no | **Am Burgerhof 4** |
| PLZ | `plz` | no | **79261** |
| ORT | `ort` | no | **Gutach im Breisgau** |
| LAND | `country` | no | **Deutschland** |
| GEBURTSDATUM | `geburtsdatum` | no | **empty** — voluntary |
| TELEFON | `telefon` (+49 selector) | no | **1733281570** |
| E-MAIL | `mail` | **yes** | **matt@bountystash.com** |
| Geschlecht | `gender` | no | **männlich** |
| SCHULABSCHLUSS | `schulabschluss` | no | **Hochschulabschluss** |
| BERUFSAUSBILDUNG (BEZEICHNUNG) | `berufsausbildung_o_sb` | no | degree as in the CV |
| BERUFSERFAHRUNG | `erfahrung_pref_inJ` | no | **mehr als 5 Jahre** |
| FRÜHESTER EINTRITT (TT.MM.JJJJ) | `eintrittsdatum` | **yes** | **01.12.2026** |
| GEHALTSWUNSCH P.A. (NUR ZAHL) | `gehaltswunsch` | no | **85000** |
| WIE HABEN SIE UNS GEFUNDEN? | `wie_gefunden` | **yes** | job-board/search option, not "Empfehlung" |

Two schema differences from the sibling forms worth knowing: **f456 has no DEUTSCHKENNTNISSE
select** (f734 and f262 both did, and both made it required), and it exposes an extra
`cv_lebenslauf` upload alongside `lebenslauf`. Language proficiency therefore has to be argued in
the letter here, not clicked in a dropdown.

**Anlagen:** `anschreiben` (labelled `*`), `cv_lebenslauf`, `lebenslauf`, `foto`, `anlage1`,
`anlage2`, `anlage8`, `anlage9`, `anlage10`; Word/PDF/JPG/PNG/GIF, **15 MB** per file, no
password-protected documents. Mandatory Datenschutz checkbox (`agbs_check`) plus a CSRF token
(`bewerbung_form_tkn`), so the form must be submitted from the page. As with the other two SVA
applications, the **Zeugnisse the posting asks for do not exist in this repo** and have to come
from the operator.

## Projection audit

Scorer terms, strongest first: **system** (27.576), **cloud** (24.079), **kubernetes** (20.582),
**cloud-systemlandschaft** (14.603), **cloudumgebung** (14.603), **container** (10.163).

- **Highlights: 13 of 32** — the best of the three SVA packets, because the JD's cloud and system
  vocabulary matches the estate work.
- **Projects: 4 of 10** — `nixconfig`, `matt.bountystash.com`, `Masterarbeit`, `Postgraduales
  Studium`. `nixconfig` is the load-bearing one; `bountystash` (Go service) is dropped again.
- **Headings German**, tagged `/H1`.

## Alignment and honest gaps

Real, inspectable here:

- **Immutable OS, already the operating model** — NixOS builds a system from a declaration,
  generations are reproducible, rollback is a pointer to the previous generation. The posting lists
  immutable OS as "bestenfalls" desirable; here it is the baseline.
- **Declarative guests alongside declarative hosts** — `hosts/microvms/` declares a base, a
  Friere canary and a test VM, each built from the same codebase as its host, with its own kernel
  and network config rather than a hand-built image. That is the container-platform instinct in a
  applied to virtual machines instead of containers.
- **Security by construction** — SOPS/age per host, SSH certificate authority with short-lived
  certificates, default-deny nftables, patching ordered by CISA KEV and exposure.
- **Observability that is trusted** — sentinel ledger every fifteen minutes (job status,
  generation age, disk, PSI), gatus paging on any non-ok state, a green socket never accepted as
  proof.
- **Recovery rehearsed, not assumed** — the mail archive's restore is executed, not documented.

Gaps, all named in the letter:

1. **Kubernetes never operated in production** — not vanilla, not RKE, not OpenShift. The posting's
   first profile line.
2. **No Docker, no systemd-nspawn** in the tool history; container work is the declarative microVM
   guest and the containerised build environment, not running container fleets.
3. **No admission control, no chaos-engineering practice, no BSI hardening** — named as new ground.
4. **SÜG level 2 clearance is doubtful for a US citizen** — see above.
5. **Zeugnisse missing.**

## Sequencing across the three SVA applications

j734, j262 and j456 are all SVA, all Freiburg-capable, all with the same 100-person DevOps group.
Sending three applications to one team in the same week reads as a scattergun. The sheets are
built so the operator can pick: j734 if Linux administration and customer ops is the goal, j262 if
automation and IaC consulting is, j456 if container platforms and cloud integration is — and j456
is the one with a hard expiry (2026-12-31).

## Submit-time checklist

1. Open `f456` from the posting's "Jetzt bewerben!" button, dismiss the cookie overlay first.
2. Fill the fields above; no birth date, no photo.
3. Upload `anschreiben.pdf` into the required slot and `lebenslauf.pdf` into LEBENSLAUF (or
   `cv_lebenslauf`, whichever the form insists on); add certificates when supplied.
4. Salary `85000`, entry `01.12.2026`, "Wie gefunden" from the job-board options.
5. Clarify the SÜ2 question with SVA before investing in the process — it is the one requirement
   that can end the application regardless of technical fit.
6. Tick the Datenschutz agreement, press **Senden**, keep the confirmation, move the record to
   `applied`.

## Next action

Review the PDFs; resolve the clearance question first. Nothing has been sent.
