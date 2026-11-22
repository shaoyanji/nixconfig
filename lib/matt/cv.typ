// lib/matt/cv.typ — the CV, compiled by typst from the same JSON the page uses.
// cv.json is written by lib/matt-site.nix: profile, work, education, projects
// (with a formatted period), stack, plus the locale's `labels` and `lang`.
//
// The layout is the appflow packet's centred résumé: name, title and contact
// centred over a hairline, bold section words over a full-width rule, one column
// with the date at the right edge of each entry, and a justified serif body.
// Two build constraints shape it: section words stay in normal case and alone on
// their extracted line (`cv-ats-check` matches the line), and no line may end in
// a hyphen, so a keyword survives extraction whole.
#let d = json("cv.json")
#let p = d.profile
#let labels = d.at("labels", default: (:))
#let lang = d.at("lang", default: "en")
#let compact = d.at("pages", default: 2) == 1
#let inlineDates = d.at("inlineDates", default: false)

#set document(title: p.name + " — " + labels.at("cv", default: "CV"), author: p.name)
#set page(
  paper: "a4",
  margin: (
    top: if compact { 1.05cm } else { 1.4cm },
    bottom: if compact { 0.8cm } else { 1.4cm },
    left: if compact { 1.3cm } else { 1.7cm },
    right: if compact { 1.3cm } else { 1.7cm },
  ),
  footer: context align(center, text(size: 7.5pt, fill: rgb("#6b7280"))[
    #if counter(page).final().first() > 1 [
      #counter(page).display() / #counter(page).final().first()
    ]
  ]),
)
// Libertinus ships with Typst, so the sandbox needs no font package.
#set text(
  font: ("Libertinus Serif", "New Computer Modern"),
  size: if compact { 8.5pt } else { 9.5pt },
  fill: rgb("#111827"),
  lang: lang,
  hyphenate: false,
)
#set par(leading: if compact { 0.45em } else { 0.5em }, justify: true)

#let muted = rgb("#4b5563")
#let headingInk = rgb("#1f2937")
#let hairline = rgb("#e5e7eb")

// header -------------------------------------------------------------------
#align(center)[
  #text(size: if compact { 15.5pt } else { 19pt }, weight: "bold")[#p.name]
  #v(1pt)
  #text(size: if compact { 8pt } else { 9pt }, fill: muted)[#p.title]
  #v(2pt)
  #text(size: if compact { 7.4pt } else { 8.5pt }, fill: rgb("#374151"))[
    #p.handle • #p.location.split(" · ").at(0) \
    #d.site • #d.links.at(0, default: "") \
    #d.links.slice(1).join(" • ")
  ]
]
#v(if compact { 1.5pt } else { 6pt })
#line(length: 100%, stroke: 0.5pt + rgb("#d1d5db"))
#v(if compact { 1.5pt } else { 6pt })
#text(size: if compact { 8pt } else { 9pt })[#p.bio]
#if not compact [
  #v(3pt)
  #text(size: 8.8pt, weight: "bold", fill: headingInk)[#p.target]
]

// headings -----------------------------------------------------------------
// Normal case, alone on the extracted line, then the rule: an uppercase or
// decorated section word is the one an ATS cannot classify.
#set heading(numbering: none)
#show heading: it => block(breakable: false, sticky: true, width: 100%)[
  #v(if compact { 1.5pt } else { 6pt })
  #text(size: if compact { 8.8pt } else { 10.5pt }, weight: "bold", fill: headingInk)[#it.body]
  #v(0.5pt)
  #line(length: 100%, stroke: 0.4pt + hairline)
  #v(if compact { 0.5pt } else { 2pt })
]
#let head(title) = heading(title, level: 1)

// entry: title and muted subtitle left, date right -------------------------
// The full CV keeps the subtitle on the title line, the appflow way. A compact
// CV gives the title, role and date a column each instead: the German titles
// wrapped when the role trailed them, and a wrapped header cost a page.
#let entry(title, subtitle, when, body, three-col: false, href: "", inline: false) = block(breakable: false, width: 100%)[
  #if inline [
    #let sub = if when != "" { [#subtitle, #when] } else { [#subtitle] }
    #text(weight: "bold")[#title]
    #if subtitle != "" [
      #text(size: if compact { 8.4pt } else { 9pt }, fill: muted)[ — ]
      #if href != "" [
        #link(href)[#text(size: if compact { 8.4pt } else { 9pt }, fill: muted)[#underline[#sub]]]
      ] else [
        #text(size: if compact { 8.4pt } else { 9pt }, fill: muted)[#sub]
      ]
    ] else if when != "" [
      #text(size: if compact { 7.5pt } else { 8.5pt }, fill: muted)[#when]
    ]
  ] else if three-col [
    #grid(
      columns: (1.45fr, 1fr, 50pt),
      column-gutter: 7pt,
      align: (left + horizon, left + horizon, right + horizon),
    )[
      #text(weight: "bold", size: 8.3pt)[#title]
    ][
      #text(size: 7.9pt, fill: muted)[#subtitle]
    ][
      #text(size: 7.3pt, fill: muted)[#when]
    ]
  ] else [
    #grid(
      columns: (1fr, auto),
      column-gutter: 8pt,
      align: (left + horizon, right + horizon),
    )[
      #text(weight: "bold")[#title]#if subtitle != "" [
        #text(size: if compact { 8.4pt } else { 9pt }, fill: muted)[ — ]
        #if href != "" [
          #link(href)[#text(size: if compact { 8.4pt } else { 9pt }, fill: muted)[#underline[#subtitle]]]
        ] else [
          #text(size: if compact { 8.4pt } else { 9pt }, fill: muted)[#subtitle]
        ]
      ]
    ][
      #text(size: if compact { 7.5pt } else { 8.5pt }, fill: muted)[#when]
    ]
  ]
  #if body != "" [
    #v(0.5pt)
    #text(size: if compact { 7.9pt } else { 9pt })[#body]
  ]
  #v(if compact { 0pt } else { 3pt })
]

// experience ---------------------------------------------------------------
#head(labels.at("experience", default: "Experience"))
#for w in d.work [
  #entry(w.title, w.role, w.period, w.at("description", default: ""), three-col: compact, inline: inlineDates)
  #if w.at("highlights", default: ()).len() > 0 {
    block(inset: (left: 8pt, top: 0pt, bottom: 0pt))[
      #set list(marker: [-], indent: 0.9em, body-indent: 0.9em, spacing: if compact { 0.2em } else { 0.15em })
      #for h in w.highlights {
        list.item[#text(size: if compact { 7.7pt } else { 8.8pt })[#h]]
      }
    ]
  }
]

// projects -----------------------------------------------------------------
// The repository or site address rides on the title line as the muted
// subtitle, so the URL is visible without adding a line the page budget cannot
// pay for. It is a real link over that visible text: stripping the annotation
// still leaves the address in the text layer, which is what a parser reads.
#head(labels.at("projects", default: "Projects"))
#for e in d.projects.slice(0, calc.min(6, d.projects.len())) [
  #let link = e.at("url", default: "").replace("https://", "").replace("http://", "")
  #let link = if link.ends-with("/") { link.slice(0, link.len() - 1) } else { link }
  #entry(e.name, link, e.period, e.summary, href: e.at("url", default: ""), inline: inlineDates)
]

// education ----------------------------------------------------------------
// The full CV gives page 2 a section: with Education on page 1, page 2 held
// only Skills and Languages. `weak` avoids a blank page when it already starts there.
#if not compact [
  #pagebreak(weak: true)
]
#head(labels.at("education", default: "Education"))
#for e in d.education [
  #entry(e.school, e.degree, e.period, "", inline: inlineDates)
]

// skills -------------------------------------------------------------------
// Whole and unbreakable: a heading at the foot of page 1 with its groups alone
// on page 2 is the failure this block is shaped to prevent.
#block(breakable: false)[
  #head(labels.at("skills", default: "Skills"))
  #for s in d.stack [
    #par[
      #text(weight: "bold", size: if compact { 8.1pt } else { 9.5pt })[#s.category]
      #text(size: if compact { 8pt } else { 9pt }, fill: muted)[ — #s.items.join(", ")]
    ]
  ]
]

// languages and authorisation ---------------------------------------------
#head(labels.at("languages", default: "Languages"))
#par[#text(size: if compact { 8pt } else { 9pt })[#p.languages]]
#par[#text(size: if compact { 7.7pt } else { 8.5pt }, fill: muted)[#p.workAuth]]

// typeset report -----------------------------------------------------------
#context [
  #metadata((
    pages: counter(page).final().first(),
    last: int(calc.round(here().position().y / 1mm)),
  )) <typeset>
]
