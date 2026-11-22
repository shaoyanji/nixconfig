// Flox — Member of Technical Staff, Infrastructure & Operations. English letter, one page.
#set page(paper: "a4", margin: (x: 2.3cm, y: 1.9cm))
#set text(font: "DejaVu Sans", size: 9.6pt, fill: rgb("#191919"), lang: "en")
#set par(justify: true, leading: 0.62em)
#let muted = rgb("#5c6b7a")

#align(right)[
  #text(weight: "bold", size: 10.4pt)[Matt Ji]
  #linebreak()
  #text(size: 9pt)[Am Burgerhof 4 · 79261 Gutach im Breisgau, Germany]
  #linebreak()
  #text(size: 9pt)[matt\@bountystash.com · github.com/shaoyanji]
]

#v(0.4cm)
#text(size: 8.6pt, fill: muted)[22 November 2026]
#v(0.4cm)
Flox\\
Engineering

#v(0.55cm)
#text(weight: "bold", size: 10.1pt)[Application: Member of Technical Staff, Infrastructure & Operations]
#v(0.45cm)

Dear Flox team,

most companies ask you to learn Nix for their infrastructure. You are the infrastructure, so the interesting question is
whether the way I already work survives contact with yours. I think it does, and the repository is the argument:
https://github.com/shaoyanji/nixconfig.

One flake describes thirteen hosts. Each host is a feature list concatenated in order rather than a machine someone
patched; each service is a module; every input is pinned in a lock file, so a rebuild months later produces the same
derivation and not merely something that compiles today. Deployment is a rebuild and a generation switch, never an edit
on the host — the store path is the identity of what is running. Rollback keeps a parent pointer, so returning to a
known-good system takes one command on the day it matters, which is the only day it is tested.

Around that sit the parts that decide whether a Nix platform is pleasant or miserable: a shared binary cache and remote
builders, with cache misses treated as events worth explaining rather than as weather. An inventory-driven CI matrix
that gates one host per process under a memory guard, running the same module check the machine runs, so a green build
cannot mean something different from a healthy host. And a sentinel that records job status, generation age, disk
pressure and PSI every fifteen minutes, because on a build fleet the first symptom is usually capacity and the second
is silence.

What I have not done: I have not worked on Nixpkgs itself, I have not operated a public cache at Flox's scale, and my
infrastructure is bare metal rather than AWS. Those are real differences, and the reason I am applying is that they are
the parts of this job I would be learning from people who have already solved them — not something I would pretend to
have solved at thirteen machines.

On the pragmatic side, I would rather ship a boring mechanism that a colleague can debug at 02:00 than a clever one
that needs me. That shows up in the repo as a preference for one obvious way to do a thing, help text and validation on
every task, and documentation generated from the same source as the configuration, so it does not drift. Before this I
spent a decade running the numbers on energy assets, which is where the cost discipline comes from: a cache that saves
a rebuild is worth more than a build that feels fast.

I am a US citizen with German permanent residence, so there is no sponsorship question, German is C1 and English is
native, and remote with on-call suits me. I would genuinely enjoy talking about where the cache boundaries are drawn and
what breaks first when a customer's build graph is stranger than the platform expected.

Yours sincerely,
#v(0.5cm)
Matt Ji
