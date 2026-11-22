#set document(title: "Obsidian Systems — Functional Software Engineer", author: "Matt Ji")
#set page(paper: "a4", margin: (top: 2cm, bottom: 2cm, left: 2.2cm, right: 2.2cm))
#set text(font: ("Libertinus Serif", "DejaVu Sans"), size: 10pt, fill: rgb("#111827"), lang: "en")
#set par(leading: 0.58em, justify: true, spacing: 1.1em)

#text(size: 9pt, fill: rgb("#374151"))[
  #text(weight: "bold", size: 10pt, fill: rgb("#111827"))[Matt Ji] \
  Am Burgerhof 4, 79261 Gutach im Breisgau, Germany \
  matt\@bountystash.com • +49 1733281570 • github.com/shaoyanji
]

#v(14pt)

#text(size: 9pt)[
  Obsidian Systems \
  Engineering — Functional Software Engineer \
  Remote, USA East Coast
]

#v(14pt)
#align(right)[#text(size: 8.5pt, fill: rgb("#4b5563"))[22 November 2026]]

#v(6pt)
#text(weight: "bold")[Functional Software Engineer — application]

#v(4pt)
Dear Obsidian Systems team,

#v(2pt)
The role names Haskell, Scala, OCaml, F\# and Clojure first among its preferences. None of them is in my production record, and I would rather put that in the opening paragraph than let it be discovered in a review. What I do have is five years of building systems whose declarative half is functional in the way that matters: a Nix flake is a function from pinned inputs to a machine, modules compose, options carry types, evaluation is lazy, and the expression CI evaluates is the expression the machine builds.

#v(2pt)
Thirteen hosts are declared that way. A host is a value, not a sequence of shell steps: rebuilding it is the commit plus one command, a broken definition fails the module gate before it reaches hardware, secrets are encrypted per host and certificates come from the fleet's own certificate authority. The same habit is in bountystash, a Go service that turns a request into an immutable, content-addressed document. State there is an append-only log, so a job replays a month later and two engineers can agree on what was asked. Immutability was not a style choice; it is what makes the answer reproducible.

#v(2pt)
Correctness where money moves is familiar ground. At O3 Energy I built yield and valuation models for a solar portfolio above \$100M that passed bank audits. Later, as a consultant, I built options and hedging models on weather derivatives and risk-managed gas storage and swing trading for EWE Trading, a German energy trader. That is financial infrastructure in a different market than Canton, and I will not pretend the two are the same; what carries over is the standard, because a wrong number reaches a counterparty and the model has to be tested before it is trusted.

#v(2pt)
I also write the measurement before the claim. fibtransponder was meant to be a stream detector; the corpus benchmark killed the first design, so what ships is the smaller claim — a state machine whose work per step stays bounded, with the corpus that falsified the rest in the repository. That is the closest thing in my record to property-based testing, and I say closest because it is not the same technique.

#v(2pt)
What is missing, plainly: Haskell or any other language on your list, Daml and Canton, blockchain systems, and property-based testing in a typed language. I learn by needing a tool — the risk engine is driven by a Nushell and Awk pipeline because that was the cheap way to do it — but a functional language at the depth your clients need is months of work, not weeks, and I would be joining as a beginner in it. I am a US citizen with German permanent residence, remote from CET with a US-East overlap, available 2026-12-01, and the range I gave in the application, USD 150–180k, still stands.

#v(2pt)
If that gap is too wide, tell me plainly and I will stop. If it is closeable, I would like the conversation. The repository shows the work unedited: github.com/shaoyanji/nixconfig

#v(4pt)
Yours sincerely,

#v(18pt)
Matt Ji
