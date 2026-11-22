// Pure Storage — Senior Systems & Storage Engineer. English letter, one page.
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
Pure Storage

#v(0.42cm)
#text(weight: "bold", size: 10.1pt)[Application: Senior Systems & Storage Engineer]
#v(0.32cm)

Dear Pure Storage team,

I am applying for the Senior Systems & Storage Engineer role. Storage is the subsystem where a wrong assumption costs you a night, so my
practice is built around measuring it instead of reasoning about it from a diagram.

The fleet I run keeps a deliberate taxonomy across local disk, a NAS and object tiers: each tier has a stated purpose, a backup path and a
retention rule, restores are rehearsed rather than believed, and alerts fire on disk pressure and on failed jobs. A backup that has never
been restored is a rumour, so the restore test is on the schedule rather than saved for the week before an audit.

Performance work I start from the pressure signals. PSI tells me whether tasks are actually stalling on IO, memory or CPU, and that
distinction is the difference between buying capacity and fixing the thing that is slow; cgroup limits per service slice make the noisy
neighbour visible before it becomes the incident. I read the numbers before changing a tunable, and when a benchmark contradicts me I
narrow the claim rather than the measurement — a collision detector of mine was falsified by its own benchmark and the claim was rewritten
instead of defended.

Underneath all of it the fleet is declared once: thirteen NixOS hosts from one flake, host as feature list, service as module with an
explicit unit and written failure behaviour, kernel track pinned per host where the hardware requires it. Inputs are pinned, builds are
hermetic, secrets are sealed with sops behind a certificate authority, and a release is a pointer to the previous generation. The gate CI
runs is the gate the machine passes, and a canary proves a configuration before the fleet receives it.

What I have not done, stated plainly: I have not administered an enterprise array — no FlashArray, no SAN fabric, no multipath, no NVMe-oF
— and I have not carried a vendor escalation path at 24/7. My scale is thirteen hosts and a PostgreSQL archive, not petabytes behind a
controller pair. I would be learning the array side from your team, and I would rather say that in a letter than have it discovered in a
interview.

What I bring that is harder to hire is the habit of proving a storage claim before making it: measure the stall, restore the backup, narrow
the benchmark, then write the result down where the next person finds it.

Kind regards,
#v(0.4cm)
Matt Ji
