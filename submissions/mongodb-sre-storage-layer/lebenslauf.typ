// MongoDB — Site Reliability Engineer (Senior or Staff), Storage Layer Services, req 6984814.
// Native English source replacing the Nix-projected PDF. Operations evidence first, gaps named.
#set page(paper: "a4", margin: (x: 1.5cm, y: 1.15cm))
#set text(font: "DejaVu Sans", size: 9.2pt, fill: rgb("#191919"), lang: "en")
#set par(justify: true, leading: 0.55em)
#set list(marker: text(fill: rgb("#2f3350"))[•], indent: 0.85em, spacing: 0.3em)
#let accent = rgb("#2f3350")
#let muted = rgb("#5c6b7a")
#let section(t) = block(above: 8pt, below: 2pt)[
  #text(size: 9.8pt, weight: "bold", fill: accent, tracking: 0.07em)[#upper(t)]
  #v(-3pt)
  #line(length: 100%, stroke: 0.5pt + rgb("#c3ced8"))
]
#let job(title, org, when, where) = block(above: 4pt, below: 1pt)[
  #grid(columns: (1fr, auto),
    [#text(weight: "bold")[#title] #text(fill: muted)[— #org]],
    [#text(size: 8pt, fill: muted)[#when]])
  #v(-2pt)
  #text(size: 8pt, fill: muted)[#where]
]

#grid(columns: (1fr, auto),
  [
    #text(size: 19pt, weight: "bold", fill: accent)[Matt Ji]
    #v(-2pt)
    #text(size: 9.8pt)[Site reliability engineer · Linux and storage-adjacent operations · Go]
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
Operations, to me, means measure, change, verify — with the way back designed in before anything moves. I run the infrastructure I
wrote: a thirteen-host NixOS fleet declared once, where the wanted state lives in the repository, each machine pulls it, nothing is
hand-edited on the target, a release is one step (build, gate, activate), and the way back is a pointer to the previous generation
rather than a restore procedure.

Health is a recording, not a dashboard. A sentinel writes job status, generation age, disk pressure and PSI into a ledger every fifteen
minutes and pages on any state that is not ok, because an open port is not evidence that work finished. Logs and events meet in journald
and an append-only event store, so a fault is traced by host, unit and time window instead of by guesswork.

Below the application I work at the layers a storage service actually lives in: systemd units with per-slice memory limits, cgroups and
PSI read as signals rather than decoration, nftables default-deny, and DNS or MTU faults diagnosed with tcpdump. Capacity is kept as a
budget with a check, so growth is visible before a full disk makes it urgent. The tooling is Go and Python behind one task interface,
which is how toil does not become a second job.

What I have not done, so the first call does not have to discover it: I have not operated a multi-tenant distributed storage system, and
durability and consistency trade-offs at Atlas scale are a step up from single-tenant hosts with immutable generations. I have not run
Kubernetes in production — containers here are pinned build environments, not a cluster I schedule on. My cloud experience is a small
AWS Lambda project and Oracle Cloud hosts, not platform ownership on AWS, GCP or Azure, and I have not carried a 24/7 rotation in an
organisation of that size. Formal SLOs with error budgets are new to me; measuring availability and paging on it is not.

#section("Areas")
#grid(columns: (1fr, 1fr), column-gutter: 14pt, row-gutter: 2pt,
  [*Reliability* — ledger every fifteen minutes, paging on state and on silence],
  [*Capacity* — disk, memory and closure size as a budget with a check],
  [*Linux* — systemd, cgroups and PSI, nftables default-deny, tcpdump],
  [*Storage hygiene* — immutable generations, pinned inputs, rollback by pointer],
  [*Automation* — Go and Python behind one validated task surface],
  [*Databases* — PostgreSQL with migrations, a rehearsed restore, statement timeouts],
  [*Security* — sops per host, short-lived certificates from an own CA],
  [*Incident work* — mitigate, then root cause, ending in a gate or a runbook])

#section("Experience")

#block(breakable: false)[
#job("Founder", "Bountystash", "Jun 2020 – Aug 2025", "Freiburg, DE")
- Operated a thirteen-host NixOS fleet from one declaration: state in the repository, pulled by each machine, never hand-edited on the target, with pinned inputs and immutable generations.
- Treated a release as one step — build, gate, activate — and rollback as a pointer to the previous generation rather than a restore run that has to work under pressure.
- Measured service health instead of decorating it: a sentinel writes job status, generation age, disk pressure and PSI to a ledger every fifteen minutes and pages on any state that is not ok, and on silence.
- Kept capacity as a budget with a check — disk, memory and closure size — so growth is visible before a full disk turns it into an incident.
- Administered Linux below the application: systemd units with per-slice memory limits, cgroups, nftables default-deny, and DNS or MTU faults diagnosed from tcpdump rather than escalated.
- Ran PostgreSQL for the application database and the mail archive: versioned migrations, a restore path walked rather than assumed, statement timeouts and connection limits set deliberately.
- Built Go and Python services behind one task interface: an append-only event log, a task surface with typed arguments, dry runs and JSON output, so a repeated operation is a command with a check rather than a runbook someone remembers.
- Hardened access: sops-encrypted secrets per host with an age key cut from the host's SSH key, machines authenticating through an own certificate authority instead of shared user keys.
- Took vulnerability work from advisory to action: the CISA KEV catalogue matched against what the fleet runs, ordered by exposure and effort.
]

#block(breakable: false)[
#job("Asset Manager", "O3 Energy", "Aug 2016 – Jun 2020", "Dallas, TX")
- Built the financial models and operated ten megawatts of solar PV, reconciling three measurement feeds into one auditable series.
- Documented and maintained software and IT administration for the company and its subsidiaries, including rollout, access and the documentation that made it repeatable.
- Defined and ran due diligence for O&M projects on behalf of project leads, which is where customer-facing judgement came from.
- Led an international team and built an incentive structure tied to a real-time financial model.
]

#block(breakable: false)[
#job("Director of Sustainability", "Smart Energy 360", "Aug 2015 – Aug 2016", "Dallas, TX")
- Owned customer service and client relationships, and developed sales and marketing strategy for sustainability services.
]

#block(breakable: false)[
#job("Research Assistant", "Fraunhofer ISE", "Mar 2012 – Sep 2012", "Freiburg, DE")
- Wrote the C++ application driving a heliostat interferometer and the Python analysis beside it, then verified the geometry independently in Mathematica.
]

#block(breakable: false)[
#job("Associate Technical Professional", "Halliburton", "Jun 2010 – Sep 2011", "Williston, ND, US")
- Diagnosed equipment and process failures in the field under time pressure, with a crew and a schedule depending on the answer.
]

#section("Selected Work")
#grid(columns: (1fr, 1fr), column-gutter: 10pt, row-gutter: 5pt,
  [
    #text(weight: "bold")[nixconfig] #text(size: 8pt, fill: muted)[— declared fleet]
    #linebreak()
    Thirteen hosts from one flake: pinned inputs, hermetic builds, generations, sops secrets, SSH CA, one gate per host. https://github.com/shaoyanji/nixconfig
  ],
  [
    #text(weight: "bold")[fleet-sentinel] #text(size: 8pt, fill: muted)[— reliability]
    #linebreak()
    Job state, generation age, disk and PSI every fifteen minutes, paging on bad state and on silence.
  ],
  [
    #text(weight: "bold")[mail archive] #text(size: 8pt, fill: muted)[— PostgreSQL]
    #linebreak()
    Mail ingested and classified, migrations and a rehearsed restore, served over a tailnet API with a verdict workflow.
  ],
  [
    #text(weight: "bold")[task control plane] #text(size: 8pt, fill: muted)[— automation]
    #linebreak()
    One validated surface with typed arguments, dry-run plans and JSON output, called by people and by agents.
  ],
  [
    #text(weight: "bold")[vulnerability operations] #text(size: 8pt, fill: muted)[— security]
    #linebreak()
    An exposure table, effort clusters and a 90-day method, driven by KEV data and ordered by what is actually exploited.
  ],
  [
    #text(weight: "bold")[matt.bountystash.com] #text(size: 8pt, fill: muted)[— build discipline]
    #linebreak()
    Two languages from one template, a CV generated from JSON, share cards built at build time.
  ])

#section("Education")
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[M.Sc. Renewable Energy Management] #text(fill: muted)[— Albert-Ludwigs-Universität Freiburg]],
  [#text(size: 8pt, fill: muted)[2011 – 2014 · grade 1.8]])
#text(size: 8.4pt)[Thesis: intermittent renewables and weather patterns analysed with artificial neural networks — a time-cross-correlation method for wind velocity data.]
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[B.Sc. Petroleum Engineering] #text(fill: muted)[— Colorado School of Mines, McBride Honors Program]],
  [#text(size: 8pt, fill: muted)[2006 – 2010 · 3.2 GPA]])

#v(4pt)
#text(size: 7.8pt, fill: muted)[English native · German C1 · US citizen with German permanent residence, would need an Irish employment permit · open to relocating to Dublin or Cork · available 01.12.2026]
