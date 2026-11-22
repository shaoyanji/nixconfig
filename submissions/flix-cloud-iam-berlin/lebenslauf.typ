// Flix — Cloud Engineer (Identity and Access Management). Standalone English source.
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
    #text(size: 9.8pt)[Identity and Access · Secrets · Automation · Linux]
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
Access is the part of infrastructure where the policy and the mechanism have to be the same thing, or the mechanism wins. I
spent five years building it that way for a thirteen-host fleet: identity issued rather than stored, through a fleet
certificate authority that mints short-lived SSH credentials so a permission exists for a purpose and expires; secrets
encrypted per host with sops and age, decrypted only at activation with that host's key; network access default-deny between
hosts; and every grant written in the same repository as the system it applies to, so a review of access is a review of a diff
rather than an audit of a spreadsheet.

The automation underneath is Python and Go over a validated task surface: named arguments, dry-run plans, machine-readable
output, so a recurring request becomes a command and a wrong argument fails before it touches anything. Third-party
integrations I have built include OAuth consent and token refresh flows against Google's APIs, and the glue that keeps an
expiring token from becoming a Monday morning outage. Telemetry is a closed loop — job status, generation age, disk and PSI
every fifteen minutes, paging on bad state and on silence.

What I have not run: Microsoft Entra ID or any SSO platform administration, SAML federation, AWS, Terraform, or Microsoft 365
tenant work. My identity work is Linux, SSH and secrets at depth rather than an IdP console.

#section("Areas")
#grid(columns: (1fr, 1fr), column-gutter: 14pt, row-gutter: 2pt,
  [*Identity* — short-lived credentials from a private CA, no standing keys],
  [*Secrets* — sops and age per host, decrypted at activation only],
  [*Access control* — default-deny networks, declared grants, reviewable diffs],
  [*Automation* — Python and Go behind a validated, dry-run task surface],
  [*Integrations* — OAuth consent and refresh flows against third-party APIs],
  [*Linux* — systemd, cgroups, PSI, nftables, `strace`, `tcpdump`],
  [*Telemetry* — fifteen-minute ledger, paging on state and on silence],
  [*Stakeholders* — documentation and runbooks written for the person on call])

#section("Experience")

#job("Founder", "Bountystash", "Jun 2020 – Aug 2025")
- Ran access as a mechanism: a fleet certificate authority issuing short-lived SSH credentials, so nothing standing on disk outlives the session that needed it.
- Encrypted secrets per host with sops and age, each machine holding only its own decryption key, so one compromised host yields nothing usable against another.
- Wrote access grants into the same repository as the systems they applied to, and default-deny between hosts, so a permission change is a reviewable diff rather than a ticket.
- Built OAuth integrations against third-party APIs, including consent flow, token storage and refresh, with the failure path handled rather than assumed.
- Automated recurring operations in Python and Go behind one task surface with validation, dry-run plans and JSON output, so routine requests need no ticket.
- Documented the access model for the person on call: what a credential is for, how it expires, and what to do when it does not work.
- Built the telemetry loop: job status, generation age, disk and PSI every fifteen minutes, paging on any state short of ok and on silence.
- Kept infrastructure declared and rebuildable: thirteen hosts from one repository, pinned inputs, rollback as a pointer.
- Diagnosed at the system layer when an access problem was not an access problem: `strace` for what a process asked the kernel for, `tcpdump` for an MTU that broke only on one path.

#job("Asset Manager", "O3 Energy", "Aug 2016 – Jun 2020")
- Owned data quality and yield models for a solar portfolio above USD 100M, reconciling three measurement feeds into one auditable series.
- Administered software and IT for the company and its subsidiaries, including user access and rollout documentation.
- Reported variance line by line, with every assumption documented next to its number.

#job("Director of Sustainability", "Smart Energy 360", "Aug 2015 – Aug 2016")
- Advised commercial clients on energy strategy, risk and cybersecurity software, with data models behind every recommendation.

#job("Research Assistant", "Fraunhofer ISE", "Mar 2012 – Sep 2012")
- Wrote the C++ application driving a heliostat interferometer and its Python analysis with 3D geometry.

#job("Associate Technical Professional", "Halliburton", "Jun 2010 – Sep 2011")
- Field diagnosis of equipment and process failures under time pressure.

#section("Selected Work")
#grid(columns: (1fr, 1fr), column-gutter: 10pt, row-gutter: 5pt,
  [
    #text(weight: "bold")[zero standing secrets] #text(size: 8pt, fill: muted)[— identity]
    #linebreak()
    A fleet certificate authority issuing short-lived SSH credentials and per-host encrypted secrets, with default-deny rules
    between hosts.
  ],
  [
    #text(weight: "bold")[access as a diff] #text(size: 8pt, fill: muted)[— governance]
    #linebreak()
    Grants declared in the same repository as the systems they apply to, so an access review is a code review with history.
  ],
  [
    #text(weight: "bold")[OAuth integration] #text(size: 8pt, fill: muted)[— third-party APIs]
    #linebreak()
    Consent flow, token storage and refresh against Google's APIs, with the expiry path handled before it became an outage.
  ],
  [
    #text(weight: "bold")[task control plane] #text(size: 8pt, fill: muted)[— automation]
    #linebreak()
    Recurring operations behind one surface with validation and dry-run plans, so routine work is a command rather than a
    ticket.
  ],
  [
    #text(weight: "bold")[fleet-sentinel] #text(size: 8pt, fill: muted)[— telemetry]
    #linebreak()
    Job state, generation age, disk and PSI every fifteen minutes, paging on bad state and on silence.
  ],
  [
    #text(weight: "bold")[nixconfig] #text(size: 8pt, fill: muted)[— platform]
    #linebreak()
    Thirteen hosts, pinned inputs, one per-host gate, rollback as a pointer. https://github.com/shaoyanji/nixconfig
  ])

#section("Education")
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[M.Sc. Renewable Energy Management] #text(fill: muted)[— Albert-Ludwigs-Universität Freiburg]],
  [#text(size: 8pt, fill: muted)[2011 – 2014 · grade 1.8]])
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[B.Sc. Petroleum Engineering] #text(fill: muted)[— Colorado School of Mines, McBride Honors Program]],
  [#text(size: 8pt, fill: muted)[2006 – 2010 · 3.2 GPA]])

#v(5pt)
#text(size: 7.8pt, fill: muted)[German C1 · English native · US citizen with German permanent residence, no sponsorship needed · Gutach im Breisgau, Berlin hybrid commutable by arrangement]
