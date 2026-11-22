// IONOS SE — Staff Network Reliability Engineer. Standalone English source.
#set page(paper: "a4", margin: (x: 1.5cm, y: 1.2cm))
#set text(font: "DejaVu Sans", size: 9.2pt, fill: rgb("#191919"), lang: "en")
#set par(justify: true, leading: 0.55em)
#set list(marker: text(fill: rgb("#1f3d2b"))[•], indent: 0.85em, spacing: 0.32em)
#let accent = rgb("#1f3d2b")
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
    #text(size: 9.8pt)[Networked Linux · Telemetry · Judgment Over Automation]
  ],
  [
    #align(right)[
      #text(size: 8.4pt)[Am Burgerhof 4 · 79261 Gutach im Breisgau, Germany]
      #linebreak()
      #text(size: 8.4pt)[matt\@bountystash.com · github.com/shaoyanji]
    ]
  ])
#v(-4pt)
#line(length: 100%, stroke: 0.9pt + accent)

#section("Profile")
I run small networks with production discipline: host and inter-site connectivity designed once, declared in a
repository, firewalled default-deny, and watched by a fifteen-minute telemetry loop that reports anything short
of ok. My experience is at fleet scale, not data-centre scale — I have not designed BGP or EVPN fabrics, and I
have not operated carrier-grade switching. What I have is the part that transfers to a network reliability role:
a suspicion of anything unverified, a habit of proving state before changing it, and automated changes that pass
a gate or do not land. I use AI tooling daily and treat its output as a draft to be checked, never as an
authority. Based in Baden-Württemberg, German C1, US citizen with German permanent residence.

#section("Areas")
#grid(columns: (1fr, 1fr), column-gutter: 14pt, row-gutter: 2pt,
  [*Linux networking* — nftables, WireGuard, DNS zones, TLS/PKI, MTU analysis],
  [*Telemetry* — fifteen-minute ledger, alert routing, silence as a fault],
  [*Failure analysis* — tcpdump, strace, cgroups/PSI, cause before action],
  [*Declarative systems* — pinned inputs, rebuild as a path, rollback per generation],
  [*Automation* — Go, Python, Bash behind one task surface others can drive],
  [*Verification gates* — a change lands only if the check passes, whoever wrote it],
  [*AI in operations* — generated drafts, human verification, no blind trust],
  [*Documentation* — runbooks, incident notes, decisions with reasons])

#section("Experience")

#job("Founder", "Bountystash", "Jun 2020 – Aug 2025")
- Designed and ran host and inter-site connectivity for thirteen Linux hosts: nftables default-deny with explicit allowances, WireGuard tunnels, an own DNS zone, and a TLS certificate authority.
- Diagnosed network faults with tcpdump and MTU analysis rather than by restarting interfaces, and wrote each cause into the runbook afterwards.
- Built a telemetry loop recording job status, generation age, disk pressure and PSI every fifteen minutes, reporting any state short of ok and treating blindness as a failure.
- Gated every change with a check that runs identically in CI and on the machine; a failing check leaves the previous generation serving, so a bad change has a known way back.
- Ran thirteen Linux hosts declaratively for five years, with no hand edits on a target host and a documented rebuild path for each.
- Hardened hosts with SOPS/age-encrypted secrets per host and an SSH certificate authority issuing short-lived credentials.
- Isolated workloads in microVMs as declared guests and memory-capped systemd slices, so one failure stayed one failure.
- Automated recurring operations in Go, Python and Bash behind one task surface with named arguments and help text.
- Used AI assistance for drafting configuration, scripts and documentation, and verified every generated artifact against the running system before it went anywhere near production.

#job("Asset Manager", "O3 Energy", "Aug 2016 – Jun 2020")
- Owned data quality and yield models for a solar portfolio above USD 100M: measurements, telemetry reconciliation, deviation analysis.
- Replaced guesswork on missing sensor data with systematic reconciliation, and reported deviations in a form that passed audits.
- Ran software rollouts and updates across client systems and documented each one.
- Looked after software and IT administration for the company and its subsidiaries: workstations, network, Wi-Fi, applications.

#job("Director of Sustainability", "Smart Energy 360", "Aug 2015 – Aug 2016")
- Advised clients on energy strategy and risk management, with data models as the basis of each recommendation.
- Translated technical constraints into recommendations a non-technical board could act on.
- Carried a project pipeline above USD 100M.

#job("Research Assistant", "Fraunhofer ISE", "Mar 2012 – Sep 2012")
- Measured heliostat inaccuracies by interferometry and wrote the C++ application that spoke to the instrument.
- Wrote Python tooling for measurement analysis and 3D geometry, and evaluated the resulting series statistically.
- Worked inside fixed measurement campaigns where a result had to be reproducible, not merely plausible.

#job("Associate Technical Professional", "Halliburton", "Jun 2010 – Sep 2011")
- Fixed equipment and process problems in the field, under time pressure and without a second attempt.
- Led the crew's safety training and worked to procedures that tolerate no deviation.

#section("Selected Work")
#grid(columns: (1fr, 1fr), column-gutter: 10pt, row-gutter: 5pt,
  [
    #text(weight: "bold")[nixconfig] #text(size: 8pt, fill: muted)[— declaration as contract]
    #linebreak()
    One flake describes thirteen hosts, services, firewall rules, secrets, telemetry and a task surface; CI and
    the host run the same gate, so what is tested is what is deployed.
  ],
  [
    #text(weight: "bold")[fleet-sentinel] #text(size: 8pt, fill: muted)[— telemetry loop]
    #linebreak()
    A ledger checks job status, generation age, disk pressure and PSI, reports anything short of ok, and keeps
    what was measured when — the difference between an outage and a guess.
  ],
  [
    #text(weight: "bold")[task control plane] #text(size: 8pt, fill: muted)[— internal tooling]
    #linebreak()
    Every fleet operation behind one command surface with named arguments and help text, so a colleague can run
    it without reading the implementation.
  ],
  [
    #text(weight: "bold")[kev-time] #text(size: 8pt, fill: muted)[— data pipeline]
    #linebreak()
    CISA's exploited-vulnerability catalogue fetched, normalised and published as a time series, with exposure
    clustered by remediation effort.
  ],
  [
    #text(weight: "bold")[bountystash] #text(size: 8pt, fill: muted)[— Go service]
    #linebreak()
    An immutable, content-addressed specification of a request: append-only events and a terminal interface from
    one binary, stored in PostgreSQL.
  ],
  [
    #text(weight: "bold")[netboot provisioning] #text(size: 8pt, fill: muted)[— bare metal]
    #linebreak()
    PXE and iVentoy serving installers and first configuration, so a machine joins the declared fleet instead of
    being assembled by hand.
  ])

#section("Education")
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[M.Sc. Renewable Energy Management] #text(fill: muted)[— Albert-Ludwigs-Universität Freiburg]],
  [#text(size: 8pt, fill: muted)[2011 – 2014 · grade 1.8]])
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[B.Sc. Petroleum Engineering] #text(fill: muted)[— Colorado School of Mines, McBride Honors Program]],
  [#text(size: 8pt, fill: muted)[2006 – 2010 · 3.2 GPA]])

#v(5pt)
#text(size: 7.8pt, fill: muted)[German C1 · English native · US citizen with German permanent residence, no sponsorship needed · Baden-Württemberg, Karlsruhe reachable in about 1.5 hours]
