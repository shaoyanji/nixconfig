// Luminovo — Senior/Staff Platform Engineer. English letter, one page.
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
Luminovo\\
Team Core

#v(0.55cm)
#text(weight: "bold", size: 10.1pt)[Application: Senior/Staff Platform Engineer]
#v(0.45cm)

Dear Luminerds,

Team Core's job — make every other team faster, and make the path to production short and hard to get wrong — is the work
I have been doing alone, for myself, for five years. One repository declares thirteen Linux hosts: each host is a feature
list, each service a module, and CI runs the same per-host check the machines run, so a broken definition fails before it
deploys rather than after. Rebuilds come from a shared binary cache and remote builders, every change records its parent,
and rolling back is one command. A sentinel writes job status, generation age, disk and PSI every fifteen minutes and
pages when a service goes quiet. That is the shape of platform work: the tooling exists so the person deploying does not
have to be careful in the right way.

The honest part first, because it is the centre of your posting: *I have not written Rust in production.* My systems code
is Go and Python, with C and C++ earlier in my career, so ownership and the compiler's refusal to let you be sloppy are
familiar ideas without being a language I have shipped in. If Team Core needs the in-house Rust depth on day one, I am not
the hire, and I would rather write that here than have it surface in week one. If the role can pair a platform engineer
with the team while that depth grows, the rest of this letter is why it might work.

What I can own immediately is the CI and developer-experience half. A gate that is identical in CI and on the target
machine turns "it passed" into a statement about a real system. A build that is content-addressed turns a rebuild months
later into the same artefact instead of something that merely compiles today. A task surface with named arguments,
validation and dry-run plans turns support requests into commands. I have run that at thirteen hosts; the arguments scale
to a hundred engineers, and the failure modes — cache misses, builder capacity, a gate that is slow enough that people
route around it — are the ones I have already argued about with numbers.

On agents, your posting asks for someone who helps engineers use them productively. I do not run them as autocomplete.
This repository is built to be read and driven by them: a task plane as executable truth, generated references instead of
prose to grep, a rule that an answer comes from the source compiled for that claim, isolated worktrees, and a check that
decides whether output counts. Making a hundred engineers' agents effective against one codebase is a CI, documentation
and permissions problem with a new surface, and my opinions about it come from doing it daily rather than reading about
it.

I am in Gutach im Breisgau, comfortably inside your two-hour CET window, and set up for remote-first work. English native,
German C1, no sponsorship needed.

One question I would ask early: how long does the slowest pipeline stage take on a median change, and what is the p95? The
gap between those two numbers usually says where the next month of platform work should go.

Yours sincerely,
#v(0.5cm)
Matt Ji
