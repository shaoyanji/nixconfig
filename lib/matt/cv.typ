// lib/matt/cv.typ — the CV, compiled by typst from the same JSON the page uses.
// cv.json is written by lib/matt-site.nix: profile, work, education, projects
// (with a formatted period), stack, plus the locale's `labels` and `lang`.
//
// One template renders both languages. The data carries translated prose and a
// closed set of labels; a second template would let a heading or a page number
// drift between an English and a German CV that claim to be the same document.
//
// The layout is one column on purpose: an applicant tracking system reads the
// text stream, so the name, the contact block, every heading and every entry sit
// in document order. No `grid` in the body (a right-aligned date is a column
// jump), no letter-spacing, no link anchors, and no name in the footer — a parser
// that drops footers or link text must still find the whole document. Why:
// docs/cv-ats-compliance.md.
#let d = json("cv.json")
#let p = d.profile
#let labels = d.at("labels", default: (:))
#let lang = d.at("lang", default: "en")

#set document(title: p.name + " — " + labels.at("cv", default: "CV"), author: p.name)
#set page(
  paper: "a4",
  margin: (x: 17mm, top: 14mm, bottom: 15mm),
  // Page numbers only, and only once there is a second page: a footer repeating
  // the name is content a parser may skip, a page number is not content.
  footer: context align(center, text(size: 7.6pt, fill: rgb("#666666"))[
    #if counter(page).final().first() > 1 [
      #counter(page).display() / #counter(page).final().first()
    ]
  ]),
)
#set text(font: "New Computer Modern", size: 9.4pt, lang: lang)
#set par(leading: 0.58em, justify: false)

#let muted = rgb("#555555")
#let accent = rgb("#1c5f4d")

// A heading is bold text in the document's own language, not an uppercased,
// tracking-spaced label: `Experience` is the string a parser matches, and 0.14em
// of letter-spacing is what some extracts turn into `E X P E R I E N C E`.
#let head(title) = block(above: 9.5pt, below: 3pt)[
  #text(size: 9.7pt, weight: "bold", fill: accent)[#title]
  #v(1pt)
  #line(length: 100%, stroke: 0.4pt + rgb("#bbbbbb"))
]

// header -------------------------------------------------------------------
// Top to bottom, one column: name, role, contact, rule, summary. The contact
// URLs are plain text, because a parser that strips a link anchor leaves the
// anchor's text or nothing at all, depending on who built it.
#text(size: 20pt, weight: "bold")[#p.name]
#v(1.5pt)
#text(size: 10.5pt)[#p.title]
#v(3pt)
#text(size: 8.4pt, fill: muted)[
  #p.handle · #p.location \
  matt.bountystash.com · github.com/shaoyanji · linkedin.com/in/mattji
]

#v(4pt)
#line(length: 100%, stroke: 0.9pt + black)
#v(4pt)
#text(size: 9.2pt)[#p.bio]

// experience ---------------------------------------------------------------
#head(labels.at("experience", default: "Experience"))
#for w in d.work {
  block(above: 5pt, below: 1pt)[
    // Title, role and period on one line: the date follows the entry it belongs
    // to in reading order instead of being parked in a second column.
    #par[#strong[#w.title] — #text(fill: muted)[#w.role] #text(size: 8.1pt, fill: muted)[· #w.period]]
    #if w.at("description", default: "") != "" [
      #par[#text(size: 8.9pt)[#w.description]]
    ]
    // Only a tailored CV carries bullets: the full one names the role and the
    // prose behind it, and an empty list renders nothing rather than a gap.
    #if w.at("highlights", default: ()).len() > 0 {
      set list(marker: [–], indent: 0.9em, body-indent: 0.9em, spacing: 0.2em)
      for h in w.highlights {
        list.item[#text(size: 8.6pt)[#h]]
      }
    }
  ]
}

// projects -----------------------------------------------------------------
#head(labels.at("projects", default: "Projects"))
#for e in d.projects.slice(0, calc.min(6, d.projects.len())) [
  #par(leading: 0.5em)[
    #strong[#e.name] #text(size: 8pt, fill: muted)[— #e.period] \
    #text(size: 8.8pt)[#e.summary]
  ]
]

// education ----------------------------------------------------------------
#head(labels.at("education", default: "Education"))
#for e in d.education [
  #par[#strong[#e.degree], #e.school #text(size: 8.1pt, fill: muted)[· #e.period]]
]

// skills -------------------------------------------------------------------
#head(labels.at("skills", default: "Skills"))
#for s in d.stack [
  #par(leading: 0.5em)[
    #strong[#s.category]: #s.items.join(", ")
  ]
]

// languages and authorisation ---------------------------------------------
#head(labels.at("languages", default: "Languages"))
#par[#p.languages]
#par[#p.workAuth]

// typeset report ------------------------------------------------------------
// Read back by the build (lib/typeset.nix): how many pages this made, and how far
// down its last page the content reached. A one-line final page is a layout defect
// the build refuses instead of a file a person has to notice.
#context [
  #metadata((
    pages: counter(page).final().first(),
    last: int(calc.round(here().position().y / 1mm)),
  )) <typeset>
]
