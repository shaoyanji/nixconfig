// MongoDB — SRE (Senior or Staff), Storage Layer Services. English letter, one page.
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
MongoDB #linebreak() Storage Layer Services

#v(0.42cm)
#text(weight: "bold", size: 10.1pt)[Application: Site Reliability Engineer (Senior or Staff), Storage Layer Services]
#v(0.32cm)

Dear Hiring Team,

your description says the storage layer is being re-architected under Atlas, and that the SREs sit with the engineers who build it —
defining SLOs and capacity plans rather than receiving them. That arrangement is what I have been building toward on a smaller stage: I
run the infrastructure I wrote, and I can defend every number in it.

For five years I have operated a thirteen-host NixOS fleet from one declaration. The wanted state lives in the repository, each machine
pulls it, and nothing is hand-edited on the target. A release is one step — build, gate, activate — and the way back is a pointer to the
previous generation, not a restore run. Health is a recording, not a dashboard: a sentinel writes job status, generation age, disk
pressure and PSI into a ledger every fifteen minutes and pages on any state that is not ok, because an open port is not evidence. Logs
and events meet in journald and an event store, and I trace faults by host, unit and time window.

Below the application I work with systemd units and per-slice memory limits, cgroups, nftables default-deny, and DNS or MTU faults read
from tcpdump. Capacity is kept as a budget with a check, so growth is visible before a full disk makes it urgent. The tooling around all
of this is Go and Python behind one task interface, which is how I keep toil from becoming a second job.

What I have not done, so that the first call does not have to discover it: I have not operated a multi-tenant distributed storage
system, and durability and consistency trade-offs at Atlas scale are a step up from single-tenant hosts with immutable generations. I
have not run Kubernetes in production — containers have been pinned build environments here, not a cluster I schedule on, and that is
the largest gap against the requirements. My cloud experience is a small AWS Lambda project and Oracle Cloud hosts, not AWS, GCP or
Azure platform ownership, and I have not carried a 24/7 on-call rotation in an organisation of this size. Formal SLOs with error
budgets are new; measuring availability and paging on it is not.

On location, plainly: I am in Germany, this role is Dublin, Cork or remote in Ireland, and I would relocate for it. As a US citizen with
German permanent residence I would need an Irish employment permit, so the answer to the sponsorship question is yes.

I would welcome thirty minutes to talk about the storage layer and where an operator of small, fully declared fleets fits into it.

Kind regards,
#v(0.4cm)
Matt Ji
