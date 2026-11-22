// Grafana Labs — Senior Full Stack Engineer, Database Observability. English letter, one page.
#set page(paper: "a4", margin: (x: 2.3cm, y: 1.9cm))
#set text(font: "DejaVu Sans", size: 9.6pt, fill: rgb("#191919"), lang: "en")
#set par(justify: true, leading: 0.62em)
#let muted = rgb("#5c6b7a")

#align(right)[
  #text(weight: "bold", size: 10.4pt)[Matt Ji]
  #linebreak()
  #text(size: 9pt)[Am Burgerhof 4 · 79261 Gutach im Breisgau, Germany]
  #linebreak()
  #text(size: 9pt)[matt\@bountystash.com · +49 1733281570]
]

#v(0.4cm)
#text(size: 8.6pt, fill: muted)[22 November 2026]
#v(0.4cm)
Grafana Labs #linebreak() Database Observability, Grafana Cloud

#v(0.5cm)
#text(weight: "bold", size: 10.1pt)[Application: Senior Full Stack Engineer, Database Observability]
#v(0.4cm)

Dear Grafana Labs team,

the hardest part of observability is not collecting data, it is writing the one sentence that turns a pile of it into a
decision. A database that is slow is the same question I have spent five years answering one layer up: job state, generation
age, disk and pressure every fifteen minutes, paging when something is wrong and when a service has stopped reporting at all,
because a monitor that dies quietly looks exactly like a system with nothing to report.

Your squad's product is that sentence for database telemetry — which queries are slow, why, and what to do next — and the work I
would bring to it is a bias toward explaining rather than displaying. On my own fleet the dashboard leads with "what changed",
not "is it up", and every incident I handled ended as a gate, a check or a runbook entry so the same page never arrived twice.

I build the interface half in JavaScript rather than React. tokenloom's workbench is a browser client speaking a binary
WebSocket protocol to a service: a token rope, a diff lane, a warning feed and a constraint panel rebuilt from snapshot-plus-delta
frames, around two milliseconds end to end on a ten-thousand-token document. That is the same problem a query explorer poses —
frames arriving out of order, a view that must stay honest under load, an operator who needs the cause and not just the number.
The server side is Go and Python with Postgres underneath: an event-log binary serving HTTP endpoints, a turn-log API and an
archive API with pagination and idempotent writes.

I will be precise about what is missing, because it is the centre of this role. I have not shipped production React or
TypeScript; my JavaScript is real and in use, but your component model and typing discipline would be new to me. I have not used
Prometheus, Loki, Tempo or Grafana in anger, and database performance monitoring as a product is new work — my database
experience is operating one and reasoning about its query plans, not helping thousands of customers understand theirs. If the
squad needs someone productive on the frontend in week one, I am not that person. If it needs someone who can own a telemetry
feature end to end, argue about what it should say, and write the Go and SQL behind it, that is the work I have actually done.

I am fully remote in Germany and need no sponsorship.

One question I would bring to a first call: when a customer's database slows down and the dashboard already shows them five
plausible causes, how do you decide which one the product names first? Getting that ranking right is most of the value, and it is
the kind of decision I like working on.

Kind regards,
#v(0.45cm)
Matt Ji
