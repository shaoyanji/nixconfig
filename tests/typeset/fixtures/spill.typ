// One page of material, then two lines on a second page: the shape that shipped
// once. Held to one page it is over budget; allowed two, its last page carries
// 16 mm, under the floor.
#set page(paper: "a4", margin: (top: 14mm, bottom: 15mm, x: 17mm))
#set text(size: 9.4pt)
#lorem(450)
#pagebreak()
US-Staatsbürgerschaft mit deutscher Niederlassungserlaubnis; kein Sponsoring.
#context [
  #metadata((
    pages: counter(page).final().first(),
    last: int(calc.round(here().position().y / 1mm)),
  )) <typeset>
]
