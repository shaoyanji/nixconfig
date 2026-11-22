// Flox — Member of Technical Staff, Core Systems. English letter, one page.
#set page(paper: "a4", margin: (x: 2.3cm, y: 1.8cm))
#set text(font: "DejaVu Sans", size: 9.6pt, fill: rgb("#191919"), lang: "en")
#set par(justify: true, leading: 0.6em)
#let muted = rgb("#5c6b7a")

#align(right)[
  #text(weight: "bold", size: 10.4pt)[Matt Ji]
  #linebreak()
  #text(size: 9pt)[Am Burgerhof 4 · 79261 Gutach im Breisgau, Germany]
  #linebreak()
  #text(size: 9pt)[matt\@bountystash.com · +49 1733281570]
]

#v(0.32cm)
#text(size: 8.6pt, fill: muted)[22 November 2026]
#v(0.32cm)
Flox

#v(0.42cm)
#text(weight: "bold", size: 10.1pt)[Application: Member of Technical Staff, Core Systems]
#v(0.32cm)

Dear Flox team,

Flox is the closest thing I have seen to my own infrastructure practice turned into a product: a flake is the unit of truth, the build is
hermetic, and the CLI is the interface. My fleet is one flake with every input pinned, hosts composed from feature lists and modules rather
than edited by hand, and builds run in the sandbox with the network closed. A rebuild is a function of the repository, not of the machine
that ran it — which is the same claim Flox makes to its users, and the one I would want to work on.

The developer-environment half is where I do my best work. `nix develop` gives me, CI and an agent the same shell, so a toolchain skew cannot
masquerade as a bug. The tooling half is the other side of it: bountystash is a single Go binary carrying a CLI, a TUI, a REST surface and
PostgreSQL behind one command, and my fleet's operator surface is a task plane with typed arguments, dry-run plans, JSON output and one exit
code per outcome. Tools should explain themselves — a failure that names the broken input, and no state hidden between runs.

On systems programming: tokenloom is a Rust cargo workspace behind a pinned dev shell, with a piece table holding the document, a
re-tokeniser that touches only the changed span, a Hilbert-indexed bridge to image data, an acceptance test that holds the invariant, and a
5 ms gate that keeps a keystroke honest. Before that, a C++ instrument driver at Fraunhofer and a Go fuzzer for adversarial geometry. Rust is
my newest of those, real but not a decade of it.

What I have not done, so a first call does not have to find it: I have not spent five years as a technical lead inside a product engineering
organisation, and I have not built a team-wide AI-assisted development practice — I use agents as the operating layer of my own fleet and
would start from shared, reproducible checks rather than from doctrine. No TypeScript or Angular, AWS without the Terraform-and-platform
depth, and no foreign-architecture cross-compilation: my cross-platform work is one declaration evaluated for Linux and Darwin, with
per-system inputs in the lock file.

Two practical points. I am a US citizen with German permanent residence, so no sponsorship is needed, though I would want to confirm that a
Germany-based arrangement fits a US-remote payroll. And I would rather show you the repository than describe it:
https://github.com/shaoyanji/nixconfig

Best regards,
#v(0.4cm)
Matt Ji
