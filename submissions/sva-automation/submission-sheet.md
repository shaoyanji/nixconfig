# SVA System Vertrieb Alexander — DevOps Engineer / Consultant – Infrastructure Automation (m/w/d), j262

**Status: packet built 2026-11-22, NOT submitted.** No form filled, no upload sent. Pipeline
record `sva-devops-consultant-infrastructure-automation` at stage `prep`.

Second SVA packet in this repo: the sibling Linux consultancy role (j734) lives in
`submissions/sva-linux/`. Both use the same portal and the same form, so only the emphasis differs
— this one sells **declarative automation and cloud build**, not Linux administration.

## Role

| Field | Value |
| :--- | :--- |
| Company | SVA System Vertrieb Alexander GmbH (HQ Borsigstraße 26, 65205 Wiesbaden) |
| Role | DevOps Engineer / Consultant – Infrastructure Automation (m/w/d) |
| Kennung | **j262**; the application form is served as **f262** |
| Posting | https://www.sva.de/de/job-portal/DevOps-Engineer-Consultant-Infrastructure-Automation-mwd-de-j262.html |
| Application form | https://www.sva.de/de/job-portal/DevOps-Engineer-Consultant-Infrastructure-Automation-mwd-de-f262.html |
| Locations | **29 sites**, choice at application: **Freiburg** (Schnewlinstraße 12, 79098) is ~25 km from home; Karlsruhe, Leinfelden-Echterdingen, Ulm, Meersburg are the other BW options |
| Employment | full time, permanent; mobile work per assignment |
| Posted / valid | 2026-11-06, `validThrough` 2027-01-06; no deadline while the posting is visible |
| Language | German **C1 or above**, English B2 or above (stated in the posting, repeated in English) |
| Compensation | not published; the form asks for a figure — this packet states **EUR 85,000 p.a.** |
| Pipeline record | `sva-devops-consultant-infrastructure-automation`, stage `prep` |
| Folder | `submissions/sva-automation/` |

## What the posting asks for, versus j734

| Aspect | j262 (this one) | j734 (Linux consultancy) |
| :--- | :--- | :--- |
| Focus | Implement **cloud solutions**, automate IT infrastructure | Operate and tune **Linux infrastructures** |
| Experience bar | **at least 3 years** operating IT infrastructure | "mehrjährige" experience |
| Named tools | **Ansible, SaltStack, Terraform, HashiCorp Vault** "besonders geschätzt" | distro expertise (RHEL, SUSE, Ubuntu, Debian) |
| Desirable | CI/CD and dev environments, system management, containers, secret management | cloud, containers, secret management |
| Both | documentation, presales support, workshops/training, post-project support, travel in Germany | same |

The tool list is the crux: this posting names the three automation tools that the candidate has
never operated, and Vault. The packet does not pretend otherwise — it argues the declarative
model from Nix, then states the tool gap in the open.

## Files

| File | Notes |
| :--- | :--- |
| `packet/lebenslauf.pdf` | **2 pages** A4, German headings, sha256 `a42ade6267206ff6a24ce0008097a9c6f3c6fcaa16d48feb027c5af08beba1a9` |
| `packet/anschreiben.pdf` | **1 page** A4, German, 412 words, sha256 `ac038fdc46e3459286fa1f5ee82cf07d6f7c520eb70227264d7293e278495f80` |
| `packet/selection.json` | 10/32 highlights, 4/10 projects |
| `lebenslauf.pdf`, `anschreiben.pdf`, `selection.json` | read-only copies for upload |
| `letter.json` | German letter source |
| `job-description.txt` | German posting text from the page's schema.org `JobPosting`, plus header (29 sites, dates) |
| `submission-sheet.md` | this sheet |

Built with:

```bash
NIX_CONFIG='builders =' bash scripts/task/appflow-packet.sh \
  --id sva-devops-consultant-infrastructure-automation \
  --language de \
  --resume "$HOME/.config/appflow/lebenslauf.json" \
  --jd submissions/sva-automation/job-description.txt \
  --letter submissions/sva-automation/letter.json \
  --out submissions/sva-automation/packet
```

`--language de` is required because the record is filed `en`; without it the German CV renders
English headings. `typeset` reported `lebenslauf.pdf: 2 page(s), budget 2` and
`anschreiben.pdf: 1 page(s), budget 1`.

## The form, field by field (f262)

Same server-rendered PHP form as f734, read from the markup — input names are
`bewerbung_form[...]`. Required flags here are `aria-required="true"`.

| Portal label | Input name | Required | Value |
| :--- | :--- | :--- | :--- |
| Anredetitel | `titel` | no | **Herr** |
| VORNAME | `vorname` | **yes** | **Matt** |
| NACHNAME | `nachname` | **yes** | **Ji** |
| STRASSE | `strasse` | no | **Am Burgerhof 4** |
| PLZ | `plz` | no | **79261** |
| ORT | `ort` | no | **Gutach im Breisgau** |
| LAND | `country` | no | **Deutschland** |
| GEBURTSDATUM (TT.MM.JJJJ) | `geburtsdatum` | no | **empty** — voluntary, and not needed for a German IT application |
| TELEFON | `telefon` + `+49` selector | no | **1733281570** |
| E-MAIL | `mail` | **yes** | **matt@bountystash.com** |
| Geschlecht | `gender` | no | **männlich** |
| SCHULABSCHLUSS | `schulabschluss` | no | **Hochschulabschluss** |
| BERUFSAUSBILDUNG (BEZEICHNUNG) | `berufsausbildung_o_sb` | no | degree as it appears in the CV |
| BERUFSERFAHRUNG | `erfahrung_pref_inJ` | no | **mehr als 5 Jahre** (the posting asks for 3+) |
| DEUTSCHKENNTNISSE | `berufsausbildung_m_sb` | **yes** | **C1** |
| FRÜHESTER EINTRITT (TT.MM.JJJJ) | `eintrittsdatum` | **yes** | **01.12.2026** |
| GEHALTSWUNSCH P.A. (NUR ZAHL) | `gehaltswunsch` | no | **85000** — digits only, matching the letter |
| WIE HABEN SIE UNS GEFUNDEN? | `wie_gefunden` | **yes** | the job-board/search option; the list loads client-side, so pick that wording, not "Empfehlung" |

**Anlagen** — Word (doc, docx), PDF, JPG, PNG, GIF, **max 15 MB** per file, no password- or
write-protected documents:

| Slot | Input name | Required | Upload |
| :--- | :--- | :--- | :--- |
| ANSCHREIBEN / KOMPLETTE UNTERLAGEN | `anschreiben` | **yes** | **`anschreiben.pdf`** |
| LEBENSLAUF | `lebenslauf` | no | **`lebenslauf.pdf`** |
| FOTO | `foto` | no | **none** |
| LETZTES ARBEITGEBERZEUGNIS | `anlage1` | no | **missing** — SVA asks for Zeugnisse; the repo has none, the operator has to supply them |
| WEITERE ANLAGE 2–4 | `anlage2`, `anlage8`, `anlage9`, `anlage10` | no | reserved for those certificates |

Two more controls: the mandatory Datenschutz agreement (`agbs_check`) — *"DIE
»DATENSCHUTZERKLÄRUNG« DER SVA HABE ICH ZUR KENNTNIS GENOMMEN…"* — and a CSRF token
(`bewerbung_form_tkn`), so the form has to be submitted from the page, not replayed. There is no
required file input at the markup level, but the posting's own text lists **Anschreiben,
Lebenslauf, Zeugnisse, Gehaltsvorstellung, Eintrittsdatum** as the material it expects, and the
first one is named `*` in the form, so treat it as required.

## Location, language, sponsorship

- **Freiburg is 25 km from Gutach im Breisgau**, and SVA lets the applicant choose the site; that
  removes relocation and weekly-commute questions entirely.
- **German C1 is the stated bar** and Deutschkenntnisse is a required select. C1 is exactly what
  the candidate has; a German-language interview is fair game.
- **Travel** inside Germany is required, explicitly limited in support/operations.
- **No sponsorship needed** — US citizen with German permanent residence; the form asks no permit
  question.

## Projection audit

Scorer terms, strongest first: **system** (30.748), **cloud** (22.506), **cloud-lösungen** (14.603),
**cloud-plattformen** (14.603), **hashicorp** (14.603), **system-management** (14.603).

- **Highlights: 10 of 32**, spread across the five roles.
- **Projects: 4 of 10** — `nixconfig` (the one that matters), `fibtransponder`, `Masterarbeit:
  Wetter und Volatilität`, `Postgraduales Studium`. `bountystash` is dropped again, so the Go
  service only appears in the letter.
- **Headings German** (`Berufserfahrung`, `Projekte`, `Kenntnisse`, `Sprachen`), tagged `/H1`.
- Note the scorer ranked `hashicorp` highly — the word appears in the JD and in the skills line via
  "HashiCorp"? It does not: the CV has no Vault line, so this term is JD-side only. The gap is real
  and unpapered.

## Alignment and honest gaps

Real, inspectable in this repo:

- **Declarative infrastructure, actually declared** — thirteen NixOS hosts from one flake,
  feature-list registration, derived option surface, one module gate in CI and on the machines.
  Idempotence, desired state and drift are the operating conditions here, not slideware.
- **Configuration management and version control** — pinned inputs, hermetic builds, changes only
  through the gate; git history is the audit trail.
- **Telemetry as proof** — sentinel writes job status, generation age, disk and PSI every fifteen
  minutes; gatus pages on any non-ok state; the ledger, not a green socket, decides completion.
- **Cloud projects in substance** — the estate runs on a cloud-hosted builder and tailnet, with
  SOPS/age secrets, an SSH certificate authority and KEV-ordered patching.
- **Customer work** — advised energy-trading clients, in-house risk manager for a large German
  energy trader, O&M due diligence, workshops and documentation written to be used without him.

Gaps:

1. **Ansible, SaltStack, Terraform: not operated.** The model transfers, the tooling does not.
2. **HashiCorp Vault: not used** — SOPS plus age per host, and short-lived SSH certificates instead.
3. **Virtualisation/hypervisor operation is thin** — no VMware/Proxmox/Nutanix work in the corpus.
4. **Red Hat and SUSE not administered**, and no certifications (RHCE, SUSE CLA).
5. **No IT-presales history** — the presales experience is energy trading and due diligence.
6. **Zeugnisse absent** from the repo, and the form wants them.

## Submit-time checklist

1. Open `f262` from the posting's "Jetzt bewerben!" button (dismiss the cookie overlay first).
2. Fill the fields as above; leave birth date and photo empty.
3. Upload `anschreiben.pdf` into the required slot, `lebenslauf.pdf` into LEBENSLAUF; add
   certificates once supplied.
4. Salary `85000`, entry `01.12.2026`, Deutschkenntnisse `C1`, "Wie gefunden" from the job-board
   options.
5. Tick the Datenschutz agreement and press **Senden**; keep the confirmation.
6. Move the record to `applied` with the receipt date.

## Next action

Review the two PDFs and decide whether to send j262, j734 or both — they are the same team, and two
applications from one candidate to the same 100-person DevOps group should be sequenced
deliberately rather than fired together.
