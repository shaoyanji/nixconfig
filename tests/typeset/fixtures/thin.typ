// One short page: the floor only applies once there is a second page, so a CV
// that stops high on a single page is not a spillover.
#set page(paper: "a4", margin: (top: 14mm, bottom: 15mm, x: 17mm))
Kurz: eine Seite, wenig Inhalt.
#context [
  #metadata((
    pages: counter(page).final().first(),
    last: int(calc.round(here().position().y / 1mm)),
  )) <typeset>
]
