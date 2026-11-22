// Flower — Asset Manager, Energy Assets Germany. Standalone English source.
#set page(paper: "a4", margin: (x: 1.5cm, y: 1.2cm))
#set text(font: "DejaVu Sans", size: 9.2pt, fill: rgb("#191919"), lang: "en")
#set par(justify: true, leading: 0.55em)
#set list(marker: text(fill: rgb("#6b3f1d"))[•], indent: 0.85em, spacing: 0.32em)
#let accent = rgb("#6b3f1d")
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
    #text(size: 9.8pt)[Renewable Asset Management · O&M Contracts · Yield Modelling]
  ],
  [
    #align(right)[
      #text(size: 8.4pt)[Am Burgerhof 4 · 79261 Gutach im Breisgau, Germany]
      #linebreak()
      #text(size: 8.4pt)[matt\@bountystash.com · +49 1733281570]
      #linebreak()
      #text(size: 8.4pt)[German C1 · English native]
    ]
  ])
#v(-4pt)
#line(length: 100%, stroke: 0.9pt + accent)

#section("Profile")
Ten years on the commercial side of renewable assets in Germany, ending as the person who owned the numbers: heading
asset management of a solar portfolio above USD 100M, building the yield and valuation models behind it, and running
O&M due diligence for project managers. The portfolio was judged on two things, and they are the two things this role
puts at the centre — availability and cost. Downtime was never an abstraction; it was a line in a budget that had to be
explained to an investor. The work I did most often was holding service providers to what they signed: scoping O&M
contracts, testing performance against guarantees, and being the counterparty who notices when a penalty clause should
actually be applied. I have also sat on the other side of that table carrying the P&L, which is why I read a service
contract as a risk document rather than an administrative one.

#section("Areas")
#grid(columns: (1fr, 1fr), column-gutter: 14pt, row-gutter: 2pt,
  [*Availability* — measured per asset, reconciled against contract],
  [*O&M contracts* — scope, guarantees, penalty and bonus clauses],
  [*Cost base* — budget ownership, cost per MWh, variance explained],
  [*Yield models* — energy yield, degradation assumptions, bank review],
  [*Due diligence* — technical and contractual review of assets],
  [*Stakeholders* — grid operators, municipalities, authorities, landowners],
  [*Regulation* — EEG and BImSchG context, reporting obligations],
  [*Monitoring* — telemetry, fault triage, reporting automation])

#section("Experience")

#job("Asset Manager", "O3 Energy", "Aug 2016 – Jun 2020")
- Headed asset management of a solar portfolio above USD 100M, including operation of 10 MW of PV plants, with availability and cost as the two measures reported to investors.
- Ran O&M contracts as commercial instruments: scoped the service, set the performance guarantees, tracked delivery against them, and applied penalty clauses where a provider fell short.
- Owned the cost base and the budget, and explained variance line by line rather than in aggregate.
- Built the yield and valuation models that underwrote the portfolio, including degradation assumptions that had to survive bank review.
- Ran due diligence on O&M projects on behalf of project managers, so the technical risk was priced before it was signed.
- Dealt with grid operators, municipalities, authorities, landowners and banks as recurring counterparties, in German.
- Turned fault data into decisions: recurring failures became a contract or maintenance argument, not a monthly surprise.

#job("Founder", "Bountystash", "Jun 2020 – Aug 2025")
- Built and ran the monitoring and reporting layer for own infrastructure: telemetry every fifteen minutes, alerting on any state short of ok, and on silence itself.
- Automated reporting from the source system, so a figure in a report and a figure in the ledger could not disagree.
- Wrote the tooling in Python and Go, with the same discipline an asset report needs: one number, one origin, reproducible.

#job("Director of Sustainability", "Smart Energy 360", "Aug 2015 – Aug 2016")
- Advised commercial clients on energy strategy, risk and project economics, with data models as the basis of every recommendation.
- Carried a project pipeline above USD 100M.

#job("Research Assistant", "Fraunhofer ISE", "Mar 2012 – Sep 2012")
- Measurement and analysis on solar components: the technical reading of an asset started here, and it is still how I approach a fault — understand the physics before accepting the explanation.

#job("Associate Technical Professional", "Halliburton", "Jun 2010 – Sep 2011")
- Field diagnosis of equipment and process failures under time pressure.

#section("Selected Work")
#grid(columns: (1fr, 1fr), column-gutter: 10pt, row-gutter: 5pt,
  [
    #text(weight: "bold")[Solar portfolio asset management] #text(size: 8pt, fill: muted)[— O3 Energy]
    #linebreak()
    Portfolio above USD 100M, 10 MW of PV under direct operation, availability and cost reported to investors, O&M
    providers held to guarantee and penalty terms.
  ],
  [
    #text(weight: "bold")[O&M due diligence] #text(size: 8pt, fill: muted)[— project managers]
    #linebreak()
    Technical and contractual review of O&M arrangements before signature, with the risk priced rather than
    acknowledged.
  ],
  [
    #text(weight: "bold")[Yield and valuation models] #text(size: 8pt, fill: muted)[— finance]
    #linebreak()
    Energy yield, degradation and cash-flow models that withstood bank review, with a documented assumption behind every
    figure.
  ],
  [
    #text(weight: "bold")[Monitoring and alerting] #text(size: 8pt, fill: muted)[— operations]
    #linebreak()
    Fifteen-minute telemetry with alerts on bad state and on silence, built because a fault nobody noticed is the
    expensive kind.
  ],
  [
    #text(weight: "bold")[Three-feed reconciliation] #text(size: 8pt, fill: muted)[— data quality]
    #linebreak()
    Measurement sources merged into one auditable series, with missing readings treated as an explicit error budget.
  ],
  [
    #text(weight: "bold")[Regulatory reporting in German] #text(size: 8pt, fill: muted)[— compliance]
    #linebreak()
    Reports and correspondence for authorities, banks and grid operators, written in German and defensible on review.
  ])

#section("Education")
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[M.Sc. Renewable Energy Management] #text(fill: muted)[— Albert-Ludwigs-Universität Freiburg]],
  [#text(size: 8pt, fill: muted)[2011 – 2014 · grade 1.8]])
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[B.Sc. Petroleum Engineering] #text(fill: muted)[— Colorado School of Mines, McBride Honors Program]],
  [#text(size: 8pt, fill: muted)[2006 – 2010 · 3.2 GPA]])

#v(5pt)
#text(size: 7.8pt, fill: muted)[German C1, working language for authorities and service providers · English native · US citizen with German permanent residence, no sponsorship needed · remote from Germany]
