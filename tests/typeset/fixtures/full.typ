// Two pages where the second carries a real section (73 mm): a light page, not a
// spillover, and it passes.
#set page(paper: "a4", margin: (top: 14mm, bottom: 15mm, x: 17mm))
#set text(size: 9.4pt)
#lorem(450)
#pagebreak()
#lorem(250)
#context [
  #metadata((
    pages: counter(page).final().first(),
    last: int(calc.round(here().position().y / 1mm)),
  )) <typeset>
]
