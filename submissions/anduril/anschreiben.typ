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
Anduril Industries\\
Electromagnetic Warfare

#v(0.55cm)
#text(weight: "bold", size: 10.1pt)[Application: Senior Embedded NixOS Engineer]
#v(0.45cm)

Dear Anduril team,

most NixOS experience is server-room shaped. Yours is the version that has to survive contact with a board, a radio
front end and a field — so the question I would ask of me is whether the way I build survives contact with yours. I
think it does, and the repository is the argument: https://github.com/shaoyanji/nixconfig.

One flake describes thirteen hosts. Each host is a feature list concatenated in order rather than a machine someone
patched; each service is a module; every input is pinned in a lock file, so a rebuild months later produces the same
derivation and not merely something that compiles today. Deployment is a rebuild and a generation switch, never an
edit on the host — the store path is the identity of what is running. That is the property a software supply chain
needs at its root: the thing you flashed is the thing you can name, and the name is reproducible.

The EW team's problem — NixOS bring-up on hardware that is still changing — is where my experience is real but
narrower than yours. I cross-compile and image for aarch64 and x86_64 targets inside one flake (Raspberry Pi-class
boards and thin clients, not custom boards), build images the same way I build hosts — one pipeline, one lock file —
and debug at the boundary where a build meets the hardware: device trees, initrd, serial consoles, the boot log as
the first truth. What I have not done: FPGA work, custom driver or kernel-module development, and bring-up on
hardware that did not exist before the schematic — if the core of the role is the last one, I would rather say it
now than in week three.

The supply-chain side I match more closely: binary caches and remote builders with cache misses treated as events
worth explaining, an inventory-driven CI matrix that gates one host per process under a memory guard, and a fleet
sentinel that records job status, generation age, disk and PSI every fifteen minutes — because on a build fleet the
first symptom is usually capacity and the second is silence.

On the practical matters: I am a US citizen by birth (Colorado School of Mines, B.Sc.), resident in Germany with
unrestricted US work authorization, and eligible and willing to undergo the clearance process. Costa Mesa is a
relocation I would take seriously, not a checkbox. English is native, German C1.

#v(0.5cm)
Matt Ji
