// Coda — Senior Infrastructure Operations Engineer. Standalone English source.
#set page(paper: "a4", margin: (x: 1.5cm, y: 1.2cm))
#set text(font: "DejaVu Sans", size: 9.2pt, fill: rgb("#191919"), lang: "en")
#set par(justify: true, leading: 0.55em)
#set list(marker: text(fill: rgb("#2d4a2d"))[•], indent: 0.85em, spacing: 0.32em)
#let accent = rgb("#2d4a2d")
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
    #text(size: 9.8pt)[Infrastructure Operations · Access Control · Reliability]
  ],
  [
    #align(right)[
      #text(size: 8.4pt)[Am Burgerhof 4 · 79261 Gutach im Breisgau, Germany]
      #linebreak()
      #text(size: 8.4pt)[matt\@bountystash.com · github.com/shaoyanji]
      #linebreak()
      #text(size: 8.4pt)[US citizen · German permanent residence · English native, German C1]
    ]
  ])
#v(-4pt)
#line(length: 100%, stroke: 0.9pt + accent)

#section("Profile")
Five years running production Linux infrastructure the way an auditor would want it: everything declared in one
repository, changes only through a gate that runs the same check in CI and on the machine, and access issued rather than
stored — per-host secrets encrypted with age, short-lived SSH certificates from a fleet certificate authority, no
long-lived credential on disk. Deployments are generations with parents, so rollback is a pointer instead of a repair, and
a ledger reports job status, generation age, disk pressure and PSI every fifteen minutes, paging on any state short of
ok. Python and Bash for automation, Go for the services. I have not operated AWS in production — no EC2, ECS, Lambda, RDS,
VPC, Route 53 or CloudFront, no AWS Organizations or IAM policy design — I have not written Terraform, and I have not run
Docker or Kubernetes.

#section("Areas")
#grid(columns: (1fr, 1fr), column-gutter: 14pt, row-gutter: 2pt,
  [*Linux* — systemd, cgroups, PSI, nftables, `tcpdump`, `strace`],
  [*Access control* — per-host keys, SSH CA, short-lived credentials],
  [*Infrastructure as code* — pinned inputs, modules, generations, rollback],
  [*Network security* — default-deny rules, WireGuard mesh, own DNS zone],
  [*Reliability* — on-call discipline, alert on state, silence as fault],
  [*Automation* — Python, Bash and Go behind one validated surface],
  [*CI/CD* — one gate for CI and host, inventory-driven matrix],
  [*Cost and capacity* — retention as a decision, disk pressure measured])

#section("Experience")

#job("Founder", "Bountystash", "Jun 2020 – Aug 2025")
- Ran thirteen Linux hosts as one declaration: services, storage, firewall, secrets and telemetry as modules, with a written rebuild path per host and no manual edits on a running machine.
- Issued access instead of storing it: an SSH certificate authority with short-lived credentials, per-host age-encrypted secrets, and default-deny firewall rules so a stolen disk held nothing reusable.
- Gated every change with a check that runs identically in CI and on the target host, so a green build could not mean something different from a healthy machine.
- Deployed by generation with a parent pointer, making rollback a known system rather than a repair under pressure.
- Kept the platform observable: job status, generation age, disk pressure and PSI every fifteen minutes, paging on any state short of ok and timing out on silence itself.
- Held the on-call seat myself for five years, which is where the runbooks came from: recurring checks turned into tooling, and anything that failed twice turned into a gate.
- Separated I/O starvation from memory shortage with cgroups and PSI, and proved network faults with `tcpdump` rather than guessing at MTU.
- Kept retention and capacity honest: deletions decided rather than drifted, so storage pressure arrived as a known curve.

#job("Asset Manager", "O3 Energy", "Aug 2016 – Jun 2020")
- Owned data quality and yield models for a solar portfolio above USD 100M: measurement pipelines, reconciliation across three feeds, deviation analysis.
- Prepared reporting that satisfied bank auditors, including the reconciliation trail behind every number.
- Ran software rollouts across client systems and documented each one.

#job("Director of Sustainability", "Smart Energy 360", "Aug 2015 – Aug 2016")
- Advised clients on energy strategy and risk, with data models as the basis of every recommendation.
- Carried a project pipeline above USD 100M.

#job("Research Assistant", "Fraunhofer ISE", "Mar 2012 – Sep 2012")
- Wrote the C++ application driving a heliostat interferometer, implemented its analysis in Python with 3D geometry.
- Worked in measurement campaigns where a result had to be reproducible, not plausible.

#job("Associate Technical Professional", "Halliburton", "Jun 2010 – Sep 2011")
- Fixed equipment and process problems in the field, under time pressure and without a second attempt.

#section("Selected Work")
#grid(columns: (1fr, 1fr), column-gutter: 10pt, row-gutter: 5pt,
  [
    #text(weight: "bold")[zero standing secrets] #text(size: 8pt, fill: muted)[— access]
    #linebreak()
    A fleet certificate authority issuing short-lived SSH credentials, per-host age-encrypted secrets, and default-deny
    rules: a host holds nothing that outlives the session that needed it.
  ],
  [
    #text(weight: "bold")[nixconfig] #text(size: 8pt, fill: muted)[— infrastructure as code]
    #linebreak()
    Thirteen hosts, pinned inputs, one per-host gate under a memory guard, and rollback as a pointer to the previous
    generation.
  ],
  [
    #text(weight: "bold")[fleet-sentinel] #text(size: 8pt, fill: muted)[— monitoring and alerting]
    #linebreak()
    Job state, generation age, disk and PSI every fifteen minutes, paging on any state short of ok and on silence
    itself, with the history kept for the incident review.
  ],
  [
    #text(weight: "bold")[task control plane] #text(size: 8pt, fill: muted)[— self-service]
    #linebreak()
    Fleet operations behind one surface with named arguments and validation, so a developer acts without reading the
    implementation and a wrong argument fails first.
  ],
  [
    #text(weight: "bold")[network lockdown] #text(size: 8pt, fill: muted)[— network security]
    #linebreak()
    nftables default-deny, a WireGuard mesh, an own DNS zone and no inbound port that is not declared, with MTU and
    fragmentation problems proven by `tcpdump`.
  ],
  [
    #text(weight: "bold")[cost and capacity] #text(size: 8pt, fill: muted)[— operations]
    #linebreak()
    Retention and disk growth as explicit decisions with numbers attached, reviewed on the same fifteen-minute cadence
    as the rest of the platform.
  ])

#section("Education")
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[M.Sc. Renewable Energy Management] #text(fill: muted)[— Albert-Ludwigs-Universität Freiburg]],
  [#text(size: 8pt, fill: muted)[2011 – 2014 · grade 1.8]])
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[B.Sc. Petroleum Engineering] #text(fill: muted)[— Colorado School of Mines, McBride Honors Program]],
  [#text(size: 8pt, fill: muted)[2006 – 2010 · 3.2 GPA]])

#v(5pt)
#text(size: 7.8pt, fill: muted)[US citizen, no sponsorship needed for a US contract · German permanent residence · a Dutch contract needs a sponsored permit, discussed openly · English native, German C1]
