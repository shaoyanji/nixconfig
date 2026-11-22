// trawa — Engineering Manager, Platform and Data Intelligence. English cover letter.
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
trawa\\
Engineering Hiring Team\\
Berlin, Germany

#v(0.55cm)
#text(weight: "bold", size: 10.3pt)[Application: Engineering Manager — Platform and Data Intelligence]
#v(0.45cm)

Dear trawa Engineering Hiring Team,

I am applying for the Engineering Manager role across Platform and Data Intelligence. Your premise — that
the data layer is what turns energy-market complexity into a customer's savings — is the premise I have
worked from on both sides of that layer: as an energy analyst who had to trust the numbers, and as the
engineer who built the pipeline that produced them.

The domain side is not a hobby. My MSc at Freiburg was in Renewable Energy Management; my thesis modelled
weather patterns and intermittency with neural networks on multi-decade series. I priced and hedged
weather derivatives as an internal risk manager, managed 10 MW of solar assets inside a portfolio above
USD 100 M, and built the financial models those decisions rested on. I know what a wrong timeseries does
to an invoice, and why billing-grade data needs a record rather than a belief.

The platform side is five years of running what I built: thirteen Linux hosts declared in one repository,
telemetry every fifteen minutes (job status, generation age, disk pressure, PSI) with a page on any state
other than ok, PostgreSQL services with append-only event logs, and pipelines in Go, Python and Nix that
reproduce the same result on any host. Observability, for me, has always been a data question first —
which is why your pairing of Data Intelligence with Platform reads as one system rather than two teams.

What I lack, I would rather say here. I have not managed engineers: I led frac crews at Halliburton and
held a director title, but no one has reported to me in a software organisation, with goals and reviews.
I have not run an AWS Terraform estate; my infrastructure as code is NixOS modules, and my cloud
experience is Oracle hosts plus one Lambda project. dbt and ClickHouse I know by reputation, not by
operating them. What I bring against that is a rare combination for this role: someone who can review the
data model and the platform underneath it with the same judgement, and who understands the market the data
describes.

On the office rhythm: your tech team asks for at least three days a week in Berlin, and I live near
Freiburg, roughly seven hours away. I would take the role with weekly presence and would discuss
relocation openly — I would rather commit to the rhythm you actually run than pretend to a commute that
does not work.

Yours sincerely,
#v(0.5cm)
Matt Ji
