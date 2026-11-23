# ATS compliance: the CV and the Lebenslauf

An employer's applicant tracking system reads a resume's text layer and files it
before a person opens the file. It reads in document order, matches section
headings against a fixed vocabulary, and drops anything it cannot place into an
unsorted pile. Both templates now answer that: one column top to bottom, standard
heading words, contact details in the body, visible URLs, no letter-spacing and
no letterhead footer.

The rules live in the templates themselves. This page is the reason they are
shaped that way, and the measurement that says the change kept the page budgets
(`lib/typeset.nix`).

## What an ATS needs

| It reads | So the document |
| :--- | :--- |
| text in one column, top to bottom | stacks the header; puts a date on the line it dates instead of in a right-hand column |
| the standard section words | says `Experience`, `Projects`, `Education`, `Skills`, `Languages` (and the German equivalents) in the record's language |
| contact details as body text | keeps name, email, town and URLs in the first block of the page |
| the keywords as text | writes every technology as text, never as an image, a table cell or a link label |

## Violations found, before the change

| # | Finding | Where | Effect on a parser |
| --- | :--- | :--- | :--- |
| 1 | Header split into two columns (`grid(columns: (1fr, auto))`): name and role left, contact right | `lib/matt/cv.typ` header | the contact block is a second column; an extractor that reads by column emits it after the summary, not after the name |
| 2 | Footer repeated the name, the email and a page counter on every page | `lib/matt/cv.typ` page footer | a parser that keeps footers reads the name twice and the email in the wrong place; one that drops them loses the identity |
| 3 | Headings were uppercased and carried `tracking: 0.14em` | `head()` in `lib/matt/cv.typ`, `section()` in `lebenslauf.typ` | extraction returned `EXPERIENCE` and, with spacing, `E X P E R I E N C E`; exact-match section detection then finds no section |
| 4 | Contact URLs were link anchors (`#link(...)[text]`) | `lib/matt/cv.typ` header | a parser that strips link annotations can drop the visible text with them, or leave the label without its address |
| 5 | Each role, degree and project put its period in a right-hand column | `lib/matt/cv.typ` experience and education loops; `entry()` in `lebenslauf.typ` | the date is a column jump: it is read after the prose it belongs to, or on its own |
| 6 | Three headings were house words, not section words: `Selected projects`, `Tools`, `Languages and authorisation` (German: `Ausgewählte Projekte`, `Werkzeuge`, `Sprachen und Arbeitserlaubnis`) | `cvLabels` in `lib/matt-site.nix`, and the `labels` override in `cv-energy.json` / `cv-energy.de.json` | a heading the parser cannot classify turns that section into unsorted text, which is where the technologies and the work permit go |

Nothing else applied: neither template had a table, an image, a text box, a body
in two columns, or a skill written as a graphic. The data is plain text already,
and the fonts (New Computer Modern, Libertinus Serif) ship with Typst.

## What changed

| File | Change |
| :--- | :--- |
| `lib/matt/cv.typ` | header stacked into one column, contact URLs as plain text; project URLs as links over their own visible address; headings in normal case with no tracking, and `sticky` so a heading cannot end a page alone; each entry's period at its right edge; footer reduced to the page number (`1/2`), and omitted on a one-page document |
| `modules/plugins/appflow/templates/lebenslauf.typ` | `entry()` uses one column instead of a two-column grid; `section()` sets the heading in its own case, not uppercased, is `sticky`, and the text does not hyphenate; the closing `Generated from the application database` line is gone, so the document ends on its last section instead of on a provenance line no parser can file |
| `lib/matt-site.nix` | `cvLabels` now carries the standard words: `Projects`, `Skills`, `Languages` / `Projekte`, `Kenntnisse`, `Sprachen`; the key `tools` became `skills` |
| `lib/matt/cv-energy.json`, `cv-energy.de.json` | the tailored CV overrides `projects` with `Projects` / `Projekte` instead of `Relevant projects` / `Relevante Projekte` |

The templates' own comments name this page, so a later edit that reintroduces a
grid column meets the reason it was removed.

## Measurement

Compiled with the pinned typst, from the six `cv.json` payloads the site build
produces, and from the resume corpora for the Lebenslauf. `last` is how far down
its last page the content reached, in millimetres.

| Document | Budget | Before | After |
| :--- | ---: | :--- | :--- |
| `cv.pdf` (full, English) | 2 | 2 pages, 53 mm | 2 pages, 80 mm |
| `cv-de.pdf` (full, German) | 2 | 2 pages, 72 mm | 2 pages, 88 mm |
| `cv-energy.pdf` (tailored) | 1 | 1 page, 270 mm | 1 page, 269 mm |
| `cv-energy-de.pdf` (tailored) | 1 | 1 page, 273 mm | 1 page, 273 mm |
| `cv-software.pdf` (tailored, English) | 1 | — | 1 page, 241 mm |
| `cv-software-de.pdf` (tailored, German) | 1 | — | 1 page, 236 mm |
| `lebenslauf.pdf`, full corpus, no selection | 1 in a packet | 3 pages, 52 mm | 3 pages, 52 mm |
| `lebenslauf.pdf`, selected from a job ad | 1 in a packet | 2 pages, 125 mm | 2 pages, 125 mm |

The floor is 40 mm of content on a final page once a document has a second page, so
no measurement above is near it. The Lebenslauf rows are unchanged because the
template edit is height-neutral: an inline date occupies the line the grid row
already used. Its packet budget is met by `select.py`, which narrows the corpus to
one page of material, not by the template.

The same numbers are what `lib/typeset.nix` reads back from each build's
`<typeset>` report, so a budget that stops fitting is a build error rather than a
page someone has to notice.

## A heading cannot end a page, and nothing hyphenates

Compiled from the whole corpus, page 2 of the Lebenslauf ended on `Kenntnisse`
with all six skill lines on page 3: `section()` kept a heading with its own rule,
but not with the block that followed it. `cv.typ` had carried `sticky: true` for
this since its heading fix; `section()` now does too, so a heading moves to the
page its content is on instead of sitting alone at the foot of the previous one.

`#set text(… hyphenate: false)` alongside it states what the justified paragraphs
had been relying on: no extracted line of either corpus ends in a hyphen, and a
German compound that reaches a line end is the one a parser stops matching
(`Schwachstellen-` / `programme`). The guard costs nothing — measured below.

A/B against the previous template, same inputs, same harness:

| Input | Before | After |
| :--- | :--- | :--- |
| Full corpus | 3 pages, 68 mm | 3 pages, 81 mm |
| Selection over a description, 5 highlights / 1 project | 2 pages, 60 mm | 2 pages, 60 mm |
| Selection over a description, 9 highlights / 4 projects | 2 pages, 152 mm | 2 pages, 152 mm |

The full-corpus row grows because the heading moved onto the page its content
already filled. No page count changes anywhere, so no budget in `lib/typeset.nix`
nor `packet.nix` moved.

## Checked after the change

- `typst compile` succeeds on `lib/matt/cv.typ` and on
  `modules/plugins/appflow/templates/lebenslauf.typ`, and each still writes its
  `<typeset>` report.
- `pdftotext` order: name, role, contact, summary, `Experience`, roles, `Projects`,
  `Education`, `Skills`, `Languages` — the name at line 1 of the extracted text and
  the headings at lines 12, 42, 69, 73 and 79.
- Built through `nix build .#sites.matt-site`, the five CVs the site ships extract
  their headings as standard words, and no heading ends a page: page 1 of the full
  CV closes on an entry, and page 2 opens on `Education`.
- A link annotation is allowed only over its own visible address: every project
  URL is printed as text, so a parser that drops the annotation still reads it.
- The footer no longer carries `page 1 of`: on a one-page document it carries
  nothing, and on the full CV it carries only the page number, `1/2` and `2/2`.

## The PDF's structure tree, not only its text layer

A readable text layer is not a document structure. Before this change both
templates drew their section headings as bold `text` inside a block, so the built
PDFs carried a structure tree whose only roles were `P` and `Strong`: a parser
that reads structure rather than geometry saw paragraphs and had to infer the
headings from font weight.

Both templates now emit real `heading` elements, at level 1 because each section
is a top-level division of the document (and PDF/UA-1 rejects a first heading at
any other level), with a `show heading` rule that keeps the previous rendering
minus one gap: a heading element ends its paragraph, so typst adds the paragraph
space after it that a plain block did not. Measured at 5.1pt per heading, that
gap pushed `cv-energy-de.pdf` onto a second page, so `cv.typ` cancels it with
`below: -2.1pt`; the Lebenslauf keeps it (208 → 219mm on the example corpus,
105 → 109mm on the full one) because no page count moves there. Page budgets are
unchanged at 2/2/1/1 with 64/68/272/276mm on the last page, against
64/68/270/274 before.

Each template compiles with `--pdf-standard ua-1`, so the files are tagged and
PDF/UA-1 conformant and the five section words reach the tree as `/H1`. The
build fails if that regresses: `cv-ats-check.sh` reads `pdfinfo` and refuses a PDF
whose `Tagged` flag is absent (proved with `--no-pdf-tags`), so dropping the flag
in a refactor is a defect rather than a silent downgrade.

`cv.typ` also states `hyphenate: false` explicitly, matching `lebenslauf.typ`:
it was relying on ragged setting being hyphenated rarely rather than never.

## The link gate: a CV the site ships is a CV the site links

The rules above shape the six PDFs; this gate keeps them reachable.
`lib/matt-site.nix` compiles `cv`, `cvDe`, `cvEnergy`, `cvEnergyDe`, `cvSoftware`
and `cvSoftwareDe` and lists
them once in `cvFiles`. The installs read that list and so does the gate, so a CV
added there without a page linking it fails the build instead of shipping as a
file nobody can find, and the six filenames are spelled in one place.

The gate runs twice inside the `matt-site` derivation, both times with `cvFiles`
as the required list: `bash scripts/task/site-links.sh --gap $out …` as a
pre-flight, so a CV the build ships with no page linking it (or a target that
resolves nowhere) names itself on one line and stops the build there, then the
full pass again as the last step. `scripts/task/site-links.sh` walks the
finished artifact,
resolves every root-relative and relative `href`/`src` the way Cloudflare Pages
serves it (a file, or `x` as `x.html`), and fails on three things: a link that
lands nowhere, a `*.pdf` no page links, and a named PDF the artifact does not
ship. A failure leaves `$out` uncreated, so no task and no deploy can publish
that site — the check is in the build rather than in a gate a deploy might skip.

```bash
nix build --builders "" --out-link /tmp/matt-site .#sites.matt-site -L   # the gate runs here
task site:links                                                         # both Nix sites, same script
bash scripts/task/site-links.sh /tmp/matt-site cv.pdf cv-de.pdf cv-energy.pdf cv-energy-de.pdf cv-software.pdf cv-software-de.pdf
```

A passing build prints `site-links: no gaps — every target resolves and all 6
built PDFs have a site link` from the pre-flight and then
`site-links: every internal link resolves, all 6 PDFs are linked, and all 16 PDF
anchors download`. An orphaned CV fails the build naming it:

```text
site-links: 81 internal links over 15 pages, 6 PDFs (5 required)
FAIL no page links stray.pdf
site-links: 1 unlinked PDF(s) of 6
```

Each failure below is one mutation of a passing artifact, run through the same
script, so the gate is known to fail for the reason it claims:

| Perturbation | Exit | It prints |
| :--- | ---: | :--- |
| a required name the artifact does not ship (`cv-ghost.pdf`) | 1 | `FAIL required PDF not shipped cv-ghost.pdf` |
| an extra PDF no page links (`stray.pdf`) | 1 | `FAIL no page links stray.pdf` — in the full pass and in `--gap` |
| ` download` deleted from the anchor in `index.html` | 1 | `FAIL index.html: cv.pdf has no download attribute` |
| `href="cv-energy.pdf"` pointed at a file that is not there | 1 | `FAIL index.html: cv-energy-gone.pdf -> /cv-energy-gone.pdf`, in both modes |
| `cv-de.pdf` deleted from the artifact | 1 | `FAIL de/index.html: ../cv-de.pdf -> /cv-de.pdf`, and the count drops to `5 PDFs (6 required)` |

The deployed artifact agrees with the gate rather than merely with the store:
all six URLs on `matt.bountystash.com` answer `200 application/pdf` with the
byte count and sha256 of the file this build produced.

`--check` is not a flag on this Nix (`2.35.3`): it errors before building, and
`--rebuild` only re-runs a derivation whose output is already in the store. To
verify a change to the gate, perturb the input and build plainly — the failing
derivation has no old output to re-check.

## The ATS parity gate: the PDF must still say what the record says

The link gate keeps the five PDFs reachable; this one keeps them the document
they claim to be. The template reads `cv.json`, and nothing proved the finished
PDF still said what that record says: a heading that becomes a house word, a role
the loop drops, a project URL that exists only as a link target or a word
hyphenated at a line end compiles cleanly, and the page-count check in `lib/typeset.nix` sees none of
them.

`bash scripts/task/cv-ats-check.sh --record work/cv.json $out/cv.pdf` runs inside
every `matt-cv-*` derivation. It reads the PDF back with `pdftotext` in reading
order — not `-layout`, which reintroduces the columns the template removed — and
compares it with the same JSON the template read: the name in the first three
lines, the contact in the body, the five headings as exact lines in one order
(`Experience`, `Projects`, `Education`, `Skills`, `Languages`; German
`Berufserfahrung`, `Projekte`, `Ausbildung`, `Kenntnisse`, `Sprachen`), every work
title and role, every degree, school, project and skill group the record carries,
and the record's own `labels` against that vocabulary. Then the lines: no line that
ends in a hyphen and continues lowercase. Link annotations are permitted because
the project address is also printed as text; a bare link label is not.

A failure names the property rather than the file:

```text
cv-ats-check: cv.pdf <- cv.json (en)
FAIL the record's 'projects' heading is 'Selected projects'; the ATS word is 'Projects'
FAIL heading 'Selected projects' is not a line of the extracted text — an ATS matches the word, not an uppercased or house-style variant
cv-ats-check: 2 defect(s)
```

The record is the payload this build generated, so the gate compares the PDF with
the data the CV was built from, not with the applications table: a site build is
a pure derivation and cannot read Postgres. `task career:export` is what carries
a row change into the JSON.

The same script runs in `modules/plugins/appflow/packet.nix`, against
`work/resume.json` and `work/application.json`, so the packet's `lebenslauf.pdf` —
the document a real application ships — is read back too. That record is a JSON
Resume rather than the site payload, so the dialect decides only where a fact is
spelled: `basics.name` instead of `profile.name`, `work[].name` / `position`
instead of `title` / `role`, and the language in `application.json`, because a
JSON Resume carries none. The properties are identical, with one consequence of
the template's shape: a JSON Resume prints only the sections it has data for, so
the headings are required only where the record has the section, while the site
payload always carries all five and its `labels` must already be the standard
words. After a job-ad selection `work/resume.json` is the selected record, so a
project `select.py` dropped is not a defect while a row the template dropped is
still one.

## Downstream: `task apps:build` compiles another template

`task apps:build` drives the workflow checkout, and that checkout keeps its own
Typst sources — `/srv/data/projects/antigravity-application-workflow/src/templates/`,
namely `rezi_template.typ` and `packet.typ`. It does not read either template this
page describes. The run that compiled 55 folders and passed `task apps:audit` (110
documents, 0 violations) still produced, from `dist/`:

| Document | Extracted headings | Link annotations |
| :--- | :--- | ---: |
| `Focused_Energy_ML_Engineer/Resume_Matt_Ji_Focused.pdf`, 2 pages | `SUMMARY`, `CORE COMPETENCIES` | 3 |
| `Aldi_Sued_Waldkirch/Lebenslauf.pdf`, 1 page | `PROFIL`, `STÄRKEN & KOMPETENZEN`, `BERUFLICHE ERFAHRUNG` | 2 |

`apps:audit` passed those documents before the port because it checks page count and
orphan lines, not the properties above. The checkout now answers the same rules the
site does: the standard word replaces a spec's own heading, its `section()` helper
emits a `heading` element in the document's own case instead of `upper()`, every
`#upper()` in the generated sources is gone, and hyphenation is off. Rebuilt: 55
folders, 110 documents, 0 audit violations; the two resumes above now extract
`Profile`, `Skills`, `Experience`, `Education`, `Projects` and `Profil`, `Kenntnisse`,
`Berufserfahrung`, `Ausbildung`. Those edits live in that repository, not here.

## Limits of this check

No commercial ATS was run; the evidence is the extracted text and the layout rules
above. `anschreiben.typ` sits in the same directory and is not
covered: it justifies without the no-hyphenation guard, which matters less for a
letter no parser hunts keywords in. The packet target was compiled from the corpus
and from a selection over a synthetic description, because the production selection
depends on the job ad it is built for.
