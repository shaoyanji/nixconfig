// Canonical — Kernel Build Automation Engineer, Ubuntu Linux. English letter, one page.
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
Canonical #linebreak() Kernel Team

#v(0.5cm)
#text(weight: "bold", size: 10.1pt)[Application: Kernel Build Automation Engineer, Ubuntu Linux]
#v(0.4cm)

Dear Canonical team,

a distribution is a build system that happens to ship a kernel, so a kernel build that people can trust is really a claim about
its build system. I have spent five years making that claim hold for thirteen Linux hosts, and the design I arrived at is
unfashionably simple: the kernel is a declared input, not a thing installed once.

Concretely, one repository states which track each machine runs, how its configuration is produced, which module packages and
parameters come with it, and where sources are pinned. The default is the current stable; the exceptions are machines whose
legacy NVIDIA modules need 6.12 LTS, a netbook whose newest kernel could not mount its root filesystem, and a documented
fallback chain for the day a track leaves the package set. Each exception carries its reason in the same file as the setting,
because a build system that cannot explain a deviation is one nobody will trust to reproduce it. No network at build time, hashed
outputs, and a configuration change that arrives as a reviewable diff.

Delivery is where build systems usually lose their way. My version: a canary guest boots the new kernel before any machine that
matters does, rollback is a pointer rather than a rebuild, and the same gate that runs on a laptop runs in CI and on the host it
is about to change. Getting from a working prototype to a deployed image needs the machine on the other end to be cheap to
reproduce, and that is what I optimise for.

The automation around this is Python and Go behind a single task surface — named arguments, validation, dry-run plans and JSON
output — so a recurring request becomes a command and a wrong argument fails before it touches anything. I have also written CLI
tools against REST APIs, because the fastest way to make an internal process stick is to make it one line in somebody's shell.

I will be precise about the gap. I have not patched the mainline kernel, authored or maintained kbuild makefiles, sent a series
upstream, or assembled a Yocto or buildroot image, and my C is instrument software from Fraunhofer plus small changes in my own
services rather than kernel C. What I bring is the part that transfers: reading a build or boot failure back to the layer that
caused it, treating configuration as data that deserves review, and refusing to let an exception live without its reason. Your
posting says kernel internals experience is welcome but not required, and that a grasp of the build system beyond typing `make`
is; that is the line I work on.

I am home based in Germany, which is EMEA, and I have German permanent residence, so travel and the twice-yearly sprints are
simple.

One question I would ask in a first call: when a customer wants one configuration option changed, how many people and how many
hours stand between that request and a tested image? That number is the whole design problem, and it is the one I would want to
spend the first year moving.

Kind regards,
#v(0.45cm)
Matt Ji
