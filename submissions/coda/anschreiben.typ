// Coda — Senior Infrastructure Operations Engineer. English letter, one page.
#set page(paper: "a4", margin: (x: 2.3cm, y: 1.9cm))
#set text(font: "DejaVu Sans", size: 9.6pt, fill: rgb("#191919"), lang: "en")
#set par(justify: true, leading: 0.62em)
#let muted = rgb("#5c6b7a")

#align(right)[
  #text(weight: "bold", size: 10.4pt)[Matt Ji]
  #linebreak()
  #text(size: 9pt)[Am Burgerhof 4 · 79261 Gutach im Breisgau, Germany]
  #linebreak()
  #text(size: 9pt)[matt\@bountystash.com · github.com/shaoyanji]
]

#v(0.4cm)
#text(size: 8.6pt, fill: muted)[22 November 2026]
#v(0.4cm)
Coda\\
Infrastructure Operations

#v(0.55cm)
#text(weight: "bold", size: 10.1pt)[Application: Senior Infrastructure Operations Engineer]
#v(0.45cm)

Dear Infrastructure Operations team,

a payments business runs on two things that look like infrastructure and are really promises: the money moves exactly once,
and the shop is open at 03:00 on the busiest night of the year. Both are bought with unglamorous discipline — least
privilege that is actually enforced, changes that can be reversed by someone who did not make them, and alarms that mean
something when they fire.

That discipline is what I have spent five years building, at a smaller scale than yours. Thirteen Linux hosts described in
one repository, with no manual edits on a running machine. Access issued rather than stored: a fleet certificate authority
handing out short-lived SSH credentials, secrets encrypted per host, default-deny firewall rules, so a host holds nothing
reusable if it is lost. Every change passes a gate that runs the same check in CI and on the machine, and every deployment
is a generation with a parent, which makes rollback a pointer rather than a repair under pressure. A ledger checks job
status, generation age, disk pressure and PSI every fifteen minutes and pages on any state short of ok, timing out on
silence, because a node that stops reporting is the failure nobody is told about. I have held that pager myself, which is
where the runbooks and the automation came from: anything that failed twice became a check.

Cost is part of the same seat. Retention is a decision with a number attached rather than the residue of never deleting
anything, and capacity is measured on the same cadence as everything else, because on a commerce platform the bill is a
reliability signal that arrives monthly.

Where I am honestly short is the stack, and it is most of the job description. I have not operated AWS in production — no
EC2, ECS, Lambda, RDS, VPC, Route 53 or CloudFront, no AWS Organizations, IAM policy design, SCPs or CloudTrail — I have not
written Terraform, and I have not run Docker, ECS or Kubernetes. My infrastructure as code is a Nix flake and my
orchestration is systemd: same invariants, different tooling, and a hiring manager is right to weigh that. Datadog and
Grafana I have not used either; my monitoring is hand-built. Payment platforms and PCI DSS are new territory for me as
well, though the audit-heavy reporting I did on a USD 100M solar portfolio is where I learned to treat a control as
evidence rather than a checkbox.

One practical matter, raised early rather than at offer stage: I am a US citizen living in Germany with permanent
residence, so nothing needs sponsoring for a German contract. A Dutch contract does not inherit those rights — it needs a
sponsored permit, which for the Netherlands is the highly skilled migrant route with a salary threshold and a recognised
sponsor. I would want to confirm that route and the hybrid expectation in Amsterdam with you before either of us invests
in a longer process; I am willing to relocate, and the letter is not the place to discover a legal obstacle.

I would enjoy hearing which of Coda's problems is hardest right now: the multi-account boundary, the security review
queue, or the cost of running storefronts in seventy markets.

Yours sincerely,
#v(0.5cm)
Matt Ji
