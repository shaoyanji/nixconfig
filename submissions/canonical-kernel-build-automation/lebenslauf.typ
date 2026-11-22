// Canonical — Kernel Build Automation Engineer, Ubuntu Linux. Standalone English source.
#set page(paper: "a4", margin: (x: 1.5cm, y: 1.2cm))
#set text(font: "DejaVu Sans", size: 9.2pt, fill: rgb("#191919"), lang: "en")
#set par(justify: true, leading: 0.55em)
#set list(marker: text(fill: rgb("#2f3350"))[•], indent: 0.85em, spacing: 0.32em)
#let accent = rgb("#2f3350")
#let muted = rgb("#5c6b7a")
#let section(t) = block(above: 8pt, below: 2pt)[
  #text(size: 9.8pt, weight: "bold", fill: accent, tracking: 0.07em)[#upper(t)]
  #v(-3pt)
  #line(length: 100%, stroke: 0.5pt + rgb("#c3ced8"))
]
#let job(title, org, when) = block(above: 4pt, below: 1pt)[
  #grid(columns: (1fr, auto),
    [#text(weight: "bold")[#title] #text(fill: muted)[— #org]],
    [#text(size: 8pt, fill: muted)[#when]])
]

#grid(columns: (1fr, auto),
  [
    #text(size: 19pt, weight: "bold", fill: accent)[Matt Ji]
    #v(-2pt)
    #text(size: 9.8pt)[Kernel build automation · Declarative configuration · Python · Linux]
  ],
  [
    #align(right)[
      #text(size: 8.4pt)[Am Burgerhof 4 · 79261 Gutach im Breisgau, Germany]
      #linebreak()
      #text(size: 8.4pt)[matt\@bountystash.com · +49 1733281570]
      #linebreak()
      #text(size: 8.4pt)[github.com/shaoyanji · linkedin.com/in/mattji]
    ]
  ])
#v(-4pt)
#line(length: 100%, stroke: 0.9pt + accent)

#section("Profile")
A distribution is a build system that happens to ship a kernel, and the kernel is where its promises are kept or broken. I have
spent five years on the practical side of that sentence: thirteen Linux hosts where the kernel is a declared input rather than
something installed once — the track chosen per machine, the configuration generated from the same repository that declares the
machine, modules and parameters pinned alongside it, and the whole system the output of a build that either reproduces exactly
or fails loudly. When one machine's newest kernel could not mount its root filesystem, the fix was a pinned LTS with the reason
written next to it, not a repair performed by hand on the box.

The automation around that is Python and Go behind a validated task surface: named arguments, dry-run plans, machine-readable
output, and a gate that runs identically on a laptop, in CI and on the host it is about to change. Rollout is the part I take
seriously — a canary guest boots the new kernel before any machine that matters does.

What I have not done: patched the mainline kernel, written or maintained kbuild makefiles, sent a series upstream, or assembled
a Yocto or buildroot image. My kernel work is configuration, pinning, out-of-tree modules and the build graph around them,
argued from evidence rather than from familiarity with the makefiles.

#section("Areas")
#grid(columns: (1fr, 1fr), column-gutter: 14pt, row-gutter: 2pt,
  [*Kernel configuration* — per-host track, generated config, pinned modules],
  [*Reproducible builds* — pinned sources, no network at build time, hashed outputs],
  [*Automation* — Python and Go behind one validated, dry-run task surface],
  [*CLI and APIs* — tools over REST services, JSON out, usable in a script],
  [*Git* — public repositories, reviewable diffs, history read as evidence],
  [*Gates* — the same check on a laptop, in CI and on the target host],
  [*Linux systems* — systemd, initrd, journald, cgroups, nftables, `strace`],
  [*Delivery* — canary guest first, rollback as a pointer, schedule kept])

#section("Experience")

#job("Founder", "Bountystash", "Jun 2020 – Aug 2025")
- Treat the kernel as a pinned input: latest stable by default, 6.12 LTS on the hosts whose legacy NVIDIA modules require it, a documented fallback chain when a track leaves the package set, and a written reason beside every exception.
- Declare every host in one repository: pinned sources, no network at build time, hashed outputs, so the same commit produces the same kernel and a configuration change is a reviewable diff.
- Handle out-of-tree modules as first-class: NVIDIA legacy drivers across two generations, evdi for a dock, module packages and parameters set per machine.
- Boot a canary guest on the new kernel before any host that matters does, so a module that fails to load fails where nobody is waiting for it.
- Wrote the automation in Python and Go behind one task surface — named arguments, validation, dry-run plans, JSON output — so a wrong argument fails before it touches a machine.
- Built CLI tools that talk to REST APIs (an archive service, a paste service), so a recurring request is one command rather than a ticket.
- Diagnosed build and boot failures at the layer that caused them: initrd contents, a missing module, journald for what the kernel said before it gave up, `strace` for what a process asked for.
- Kept one gate for CI and for the machines, so a build that passes on a laptop means something on the host.

#job("Asset Manager", "O3 Energy", "Aug 2016 – Jun 2020")
- Owned data quality and yield models for a solar portfolio above USD 100M, reconciling three measurement feeds into one auditable series.
- Administered software and IT for the company and its subsidiaries, including rollout and the documentation that made it repeatable.
- Reported variance line by line, with every assumption documented next to its number.

#job("Director of Sustainability", "Smart Energy 360", "Aug 2015 – Aug 2016")
- Advised commercial clients on energy strategy, risk and cybersecurity software, with data models behind every recommendation.

#job("Research Assistant", "Fraunhofer ISE", "Mar 2012 – Sep 2012")
- Wrote the C++ application driving a heliostat interferometer, and the Python analysis with 3D geometry that went with it.
- Verified geometry matrices independently in Mathematica rather than trusting the first implementation.

#job("Associate Technical Professional", "Halliburton", "Jun 2010 – Sep 2011")
- Field diagnosis of equipment and process failures under time pressure, with a crew and a schedule depending on the answer.

#pagebreak()
#section("Selected Work")
#grid(columns: (1fr, 1fr), column-gutter: 10pt, row-gutter: 5pt,
  [
    #text(weight: "bold")[declared kernel] #text(size: 8pt, fill: muted)[— build configuration]
    #linebreak()
    Per-host kernel track, generated configuration and pinned module packages, with every deviation from the default carrying its
    reason in the same file.
  ],
  [
    #text(weight: "bold")[canary before rollout] #text(size: 8pt, fill: muted)[— delivery]
    #linebreak()
    A guest that boots the new kernel before production does, so a bad module is found by the canary rather than by a user.
  ],
  [
    #text(weight: "bold")[task control plane] #text(size: 8pt, fill: muted)[— automation]
    #linebreak()
    Recurring operations behind one surface with validation, dry runs and JSON output, written in Python and Go.
  ],
  [
    #text(weight: "bold")[bountystash] #text(size: 8pt, fill: muted)[— Go service]
    #linebreak()
    One binary serving an append-only event log, a terminal UI and HTTP endpoints, with a specification that is content-addressed.
  ],
  [
    #text(weight: "bold")[nixconfig] #text(size: 8pt, fill: muted)[— platform]
    #linebreak()
    Thirteen hosts, one repository, pinned inputs, one gate per host, rollback as a pointer. https://github.com/shaoyanji/nixconfig
  ],
  [
    #text(weight: "bold")[fibtransponder] #text(size: 8pt, fill: muted)[— research]
    #linebreak()
    A benchmark falsified the first detector design, so the claim was narrowed rather than defended. https://github.com/shaoyanji/fibtransponder
  ])

#section("Education")
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[M.Sc. Renewable Energy Management] #text(fill: muted)[— Albert-Ludwigs-Universität Freiburg]],
  [#text(size: 8pt, fill: muted)[2011 – 2014 · grade 1.8]])
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[B.Sc. Petroleum Engineering] #text(fill: muted)[— Colorado School of Mines, McBride Honors Program]],
  [#text(size: 8pt, fill: muted)[2006 – 2010 · 3.2 GPA]])

#v(5pt)
#text(size: 7.8pt, fill: muted)[German C1 · English native · US citizen with German permanent residence, no sponsorship needed · home based in Germany, EMEA time zone · available 01.12.2026]
