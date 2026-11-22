// Grafana Labs — Senior Software Engineer, Security Assurance. Standalone English source.
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
    #text(size: 9.8pt)[Security assurance automation · Controls as code · Go & Python · Linux]
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
Security assurance is a software problem before it is a documentation problem: either the control is mechanised and its evidence
falls out of the system running, or it is a spreadsheet already stale when someone reads it. I spent five years building the
first version for a thirteen-host fleet — secrets encrypted per host with sops and age, so one compromised machine yields nothing
against another; a certificate authority issuing 90-day SSH certificates renewed by timer instead of standing keys; default-deny networking
with grants declared beside the systems they govern, so an access review is a diff with history; and builds from pinned inputs
with no network at build time, making provenance a property of the artefact.

Evidence comes from the same place. A fifteen-minute ledger records job state, generation age, disk and pressure, and pages both
on a bad state and on silence — the second alert matters more, because a monitor that dies quietly is indistinguishable from a
system with nothing to report. On the vulnerability side I built the CISA KEV catalogue into a time series and into effort
clusters with exposure per cluster, so patching follows reach and effort rather than the order a catalogue happens to list, and
I have audited bug bounty programmes and threat-modelled systems before they shipped.

What I have not done: run an ISO 27001 or SOC 2 audit cycle as the responsible engineer, or worked in Kubernetes, AWS, GCP or
Azure with Terraform, Helm or Jsonnet. My controls are Linux, certificates, secrets and declarative configuration at depth; the
cloud-native estate is the half I would have to learn quickly.

#section("Areas")
#grid(columns: (1fr, 1fr), column-gutter: 14pt, row-gutter: 2pt,
  [*Controls as code* — grants, secrets and network policy in one reviewable tree],
  [*Evidence* — checks that record their own results, not screenshots of same],
  [*Supply chain* — pinned inputs, hermetic builds, content-addressed artefacts],
  [*Vulnerability work* — CISA KEV analysis, effort clusters, bug bounty audits],
  [*Automation* — Python and Go behind one validated, dry-run task surface],
  [*Observability* — ledger every fifteen minutes, paging on state and on silence],
  [*Stakeholders* — documentation written for the auditor and the on-call reader])

#section("Experience")

#job("Founder", "Bountystash", "Jun 2020 – Aug 2025")
- Encrypted secrets per host with sops and age, each machine holding only its own decryption key, so the blast radius of one host is that host.
- Ran identity as a mechanism: a fleet certificate authority minting 90-day user certificates that a timer renews, so no standing key exists to be found later in a backup.
- Declared access and network policy in the same repository as the systems, default-deny between hosts, so every permission change is a reviewed diff with a history.
- Built from pinned inputs with no network at build time and content-addressed outputs, making the artefact the provenance record rather than a separate attestation.
- Built the evidence loop: job status, generation age, disk and PSI every fifteen minutes, with paging on any state short of ok and on silence.
- Turned vulnerability data into decisions: CISA KEV drawn as a time series and grouped into effort clusters with exposure per cluster, giving a patch order that follows reach and cost.
- Audited bug bounty programmes and threat-modelled client systems, then wrote the findings as engineering work with an owner rather than as a risk register entry.
- Automated recurring operations in Python and Go behind one task surface — named arguments, validation, dry-run plans, JSON output — and wrote CLI tools against REST APIs.
- Documented the security model for two different readers: the engineer changing a grant and the auditor asking what it means.

#job("Asset Manager", "O3 Energy", "Aug 2016 – Jun 2020")
- Owned data quality and yield models for a solar portfolio above USD 100M, reconciling three measurement feeds into one auditable series.
- Administered software and IT for the company and its subsidiaries, including user access, rollout and the documentation that made it repeatable.
- Reported variance line by line, with every assumption documented next to its number — the habit that audit work runs on.

#job("Director of Sustainability", "Smart Energy 360", "Aug 2015 – Aug 2016")
- Advised commercial clients on energy strategy, risk and cybersecurity software, translating both directions between technical and commercial readers.

#job("Research Assistant", "Fraunhofer ISE", "Mar 2012 – Sep 2012")
- Wrote the C++ application driving a heliostat interferometer and its Python analysis, and verified the geometry independently
  in Mathematica rather than trusting the first implementation.

#job("Associate Technical Professional", "Halliburton", "Jun 2010 – Sep 2011")
- Field diagnosis of equipment and process failures under time pressure, with a crew and a schedule depending on the answer.

#section("Selected Work")
#grid(columns: (1fr, 1fr), column-gutter: 10pt, row-gutter: 5pt,
  [
    #text(weight: "bold")[controls as code] #text(size: 8pt, fill: muted)[— assurance]
    #linebreak()
    Secrets, access and network policy declared beside the systems they govern, so the configuration is the control and the diff is its evidence.
  ],
  [
    #text(weight: "bold")[fleet-sentinel] #text(size: 8pt, fill: muted)[— security observability]
    #linebreak()
    A fifteen-minute ledger of job state, generation age, disk and PSI, paging on bad state and on silence.
  ],
  [
    #text(weight: "bold")[KEV exposure model] #text(size: 8pt, fill: muted)[— vulnerability prioritisation]
    #linebreak()
    The CISA catalogue as a time series and as effort clusters with exposure, producing a patch order rather than a list.
  ],
  [
    #text(weight: "bold")[vulnerability operations concept] #text(size: 8pt, fill: muted)[— programme design]
    #linebreak()
    An exposure table, a 90-day method and a service model, built on sample data and labelled as such.
  ],
  [
    #text(weight: "bold")[task control plane] #text(size: 8pt, fill: muted)[— automation]
    #linebreak()
    Recurring operations behind one surface with validation and dry runs, so a routine change is a command rather than a ticket.
  ],
  [
    #text(weight: "bold")[nixconfig] #text(size: 8pt, fill: muted)[— platform]
    #linebreak()
    Thirteen hosts, one repository, pinned inputs, one gate per host. https://github.com/shaoyanji/nixconfig
  ])

#section("Education")
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[M.Sc. Renewable Energy Management] #text(fill: muted)[— Albert-Ludwigs-Universität Freiburg]],
  [#text(size: 8pt, fill: muted)[2011 – 2014 · grade 1.8]])
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[B.Sc. Petroleum Engineering] #text(fill: muted)[— Colorado School of Mines, McBride Honors Program]],
  [#text(size: 8pt, fill: muted)[2006 – 2010 · 3.2 GPA]])

#v(5pt)
#text(size: 7.8pt, fill: muted)[German C1 · English native · US citizen with German permanent residence, eligible to work in Germany with no sponsorship · Germany, fully remote · available 01.12.2026]
