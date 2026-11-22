// BlockTech — Senior Site Reliability Engineer, Trading Infrastructure. English letter.
#set page(paper: "a4", margin: (x: 2.3cm, y: 1.9cm))
#set text(font: "DejaVu Sans", size: 9.9pt, fill: rgb("#191919"), lang: "en")
#set par(justify: true, leading: 0.62em)
#let muted = rgb("#5c6b7a")

#align(right)[
  #text(weight: "bold", size: 10.6pt)[Matt Ji]
  #linebreak()
  #text(size: 9.2pt)[Am Burgerhof 4 · 79261 Gutach im Breisgau · Germany]
  #linebreak()
  #text(size: 9.2pt)[matt\@bountystash.com]
]

#v(0.45cm)
#text(size: 8.8pt, fill: muted)[22 November 2026]
#v(0.4cm)
BlockTech\\
Trading Systems Hiring Team\\
Amsterdam, Netherlands

#v(0.55cm)
#text(weight: "bold", size: 10.3pt)[Application: Senior Site Reliability Engineer — Trading Infrastructure]
#v(0.45cm)

Dear BlockTech Trading Systems Hiring Team,

I am applying for the SRE role on your trading infrastructure. Two things make this the most interesting
posting I have read this month: the system has to be right around the clock, and the thing it is right
about is a price. I have spent my career on both halves of that sentence.

On the trading side, I built an algorithm for options trading and hedging on weather derivatives, ran it as
an internal risk manager, and modelled the volatility that fed it. Weather is a market with settlement at
the end, positions that must be hedged, and no ability to wait for a clean signal — closer to your problem
than a generic infrastructure role would suggest.

On the machine side, I run thirteen Linux hosts from bare metal. Provisioning is PXE and iVentoy, not a
hypervisor wizard; the state of each host is declared in one repository; every change passes a gate in CI
and on the host, and a failed check leaves the previous generation running. I watch a ledger rather than a
dashboard — job status, generation age, disk pressure and PSI every fifteen minutes, a page on any state
other than ok — and I diagnose with journald, cgroups and tcpdump when something is off. Go, Python, Bash
and Nix are how a repeated manual step becomes something the machine does once.

What I do not have, I would rather name now. I have not worked in a colocation cage next to an exchange, so
my feel for microsecond latency is conceptual rather than earned; my tuning experience is cgroups, PSI and
scheduler-adjacent limits, not kernel patching or busy-polling. I do not write Rust. My 24/7 experience is a
thirteen-host fleet with real pages, not a market-making stack with exchange sessions. If the role needs
someone to walk into the cage on day one and shave a hundred microseconds, that is not me yet.

What I would bring is the part that is harder to hire: a temperament that treats every change as reversible,
telemetry as the primary artefact, and an incident as something to write down so the next one is shorter —
plus a genuine understanding of what the numbers on your screens are for.

On logistics: Amsterdam is a relocation for me, from Freiburg, and I would rather discuss that openly than
pretend a commute. I am a US citizen with German permanent residence and need no sponsorship for the
Netherlands beyond the usual formalities.

Yours sincerely,
#v(0.5cm)
Matt Ji
