// Flox — Member of Technical Staff, Nix Packaging. English letter, one page.
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
#text(weight: "bold", size: 10.1pt)[Application: Member of Technical Staff, Nix Packaging]
#v(0.32cm)

Dear Flox team,

keeping a large open-source package set current, patched and reproducibly built — with a distributed build system that watches upstream,
builds and tests across many environments and publishes the result — is the shape of my own release path, one order of magnitude smaller. A
flake pins every input; a per-host module evaluation runs before anything is built, so a moved hash or a stale patch fails as a red check
instead of a half-upgraded machine; remote builders compile, a shared binary cache serves, and a generation rolls back with one command when
the build was reproducible and the result was still wrong.

Packaging judgment is the phrase in your posting that decided this application, because it is the distinction my gates are built around. A
change that looks right passes a syntax check: the attribute evaluates, the version string moved, the diff is small. A change that is right
survives an evaluation of the entire host it belongs to, and a sentinel that notices when the service stops reporting afterwards. Automation,
agents included, can produce the first kind all day — I use agents as the operating layer of my own fleet — and the second kind is what an
engineer is for. When a benchmark of mine contradicted its own claim, the claim changed rather than the measurement, and that habit is the
same one a package bump needs.

On the mechanics: I work with flakes and pins rather than channels, overlays instead of forks, and the module system as a contract — options
with types and assertions deciding what is legal before evaluation. Repeated shapes live in `lib/` functions so a pattern change is one edit.
The same module set evaluates for NixOS and for nix-darwin from one tree, which is where my cross-platform habit comes from.

What I have not done, so a first call does not have to find it: I have not committed to nixpkgs upstream or maintained a package in the
official set, I have no RPM, deb or apk packaging, and no registry work in npm, Cargo or PyPI beyond consuming those ecosystems. I have not
owned a large C/C++ build system either. My packaging depth is my own software and its dependencies, plus the build farm and cache
operations around it.

I am in Gutach im Breisgau, remote in CET, available from 01.12.2026, and I would rather show you the repository than describe it:
https://github.com/shaoyanji/nixconfig

Best regards,
#v(0.4cm)
Matt Ji
