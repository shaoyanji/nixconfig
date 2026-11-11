// lib/matt/cv.typ — the CV, compiled by typst from the same JSON the page uses.
// cv.json is written by lib/matt-site.nix: profile, work, education, projects
// (with a formatted period), stack, plus the locale's `labels` and `lang`.
//
// One template renders both languages. The data carries translated prose and a
// closed set of labels; a second template would let a heading or a page number
// drift between an English and a German CV that claim to be the same document.
#let d = json("cv.json")
#let p = d.profile
#let labels = d.at("labels", default: (:))
#let lang = d.at("lang", default: "en")

#set document(title: p.name + " — " + labels.at("cv", default: "CV"), author: p.name)
#set page(
  paper: "a4",
  margin: (x: 17mm, top: 14mm, bottom: 15mm),
  footer: context align(center, text(size: 7.6pt, fill: rgb("#666666"))[
    #p.name · #p.handle · #labels.at("page", default: "page") #counter(page).display() #labels.at("of", default: "of") #counter(page).final().first()
  ]),
)
#set text(font: "New Computer Modern", size: 9.4pt, lang: lang)
#set par(leading: 0.58em, justify: false)
#show link: it => text(fill: rgb("#1c5f4d"))[#it]

#let muted = rgb("#555555")
#let accent = rgb("#1c5f4d")

#let head(title) = block(above: 11pt, below: 4pt)[
  #text(size: 7.9pt, weight: "bold", tracking: 0.14em, fill: accent, upper(title))
  #v(-3pt)
  #line(length: 100%, stroke: 0.4pt + rgb("#bbbbbb"))
]

// header -------------------------------------------------------------------
#grid(columns: (1fr, auto), column-gutter: 12pt)[
  #text(size: 21pt, weight: "bold")[#p.name]
  #v(1pt)
  #text(size: 10.5pt)[#p.title]
][
  #align(right)[
    #text(size: 8.3pt, fill: muted)[
      #p.handle \
      #p.location \
      #link("https://matt.bountystash.com")[matt.bountystash.com] \
      #link("https://github.com/shaoyanji")[github.com/shaoyanji] · #link("https://linkedin.com/in/mattji")[linkedin.com/in/mattji]
    ]
  ]
]

#v(5pt)
#line(length: 100%, stroke: 0.9pt + black)
#v(4pt)
#text(size: 9.2pt)[#p.bio]

// experience ---------------------------------------------------------------
#head(labels.at("experience", default: "Experience"))
#for w in d.work {
  block(above: 5pt, below: 1pt)[
    #grid(columns: (1fr, auto), column-gutter: 8pt)[
      #strong[#w.title] #h(3pt) #text(fill: muted)[#w.role]
    ][
      #text(size: 8.1pt, fill: muted)[#w.period]
    ]
    #if w.at("description", default: "") != "" [
      #text(size: 8.9pt)[#w.description]
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
#head(labels.at("projects", default: "Selected projects"))
#for e in d.projects.slice(0, calc.min(6, d.projects.len())) [
  #par(leading: 0.5em)[
    #strong[#e.name] #text(size: 8pt, fill: muted)[— #e.period] \
    #text(size: 8.8pt)[#e.summary]
  ]
]

// education ----------------------------------------------------------------
#head(labels.at("education", default: "Education"))
#for e in d.education [
  #grid(columns: (1fr, auto), column-gutter: 8pt)[
    #strong[#e.degree], #e.school
  ][
    #text(size: 8.1pt, fill: muted)[#e.period]
  ]
]

// tools --------------------------------------------------------------------
#head(labels.at("tools", default: "Tools"))
#for s in d.stack [
  #par(leading: 0.5em)[
    #strong[#s.category]: #s.items.join(", ")
  ]
]

// languages and authorisation ---------------------------------------------
#head(labels.at("languages", default: "Languages and authorisation"))
#par[#p.languages]
#par[#p.workAuth]
