// Catapult Sports — Senior DevOps Engineer, English cover letter.
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
Catapult Sports\
Engineering Hiring Team\
Cologne, Germany

#v(0.55cm)
#text(weight: "bold", size: 10.3pt)[Application: Senior DevOps Engineer]
#v(0.45cm)

Dear Catapult Sports Engineering Hiring Team,

I am applying for the Senior DevOps Engineer role in Cologne. What drew me in is the shape of the problem:
a platform that must stay reliable while carrying media, computer-vision models and analytics for teams
where a one-percent difference is the whole point. I have spent five years building that discipline on a
smaller stage — infrastructure declared once, checked before it lands, reversible in one move.

My fleet is thirteen Linux hosts described by a repository. Each machine converges to that description;
nobody logs in to fix a host by hand. A change passes the same gate in CI and on the host, so a failing
check leaves the previous generation running and rollback is a pointer move. I do the bare metal myself,
from PXE and iVentoy provisioning through first configuration to rebuild, and I treat the network as part
of the system: WireGuard, nftables default-deny, an internal DNS zone, MTU faults found with tcpdump.
Observability is a ledger before it is a dashboard — job status, generation age, disk pressure and PSI
every fifteen minutes, paging on any state other than ok. Go, Python and Bash are how a repeated manual
step becomes something the machine does once and never forgets.

Where I fall short, I want to be precise. I have not run Kubernetes in production; containers have been
pinned build environments, not a cluster I upgraded and debugged. I have not used Terraform or Ansible —
my infrastructure as code is NixOS modules and flake wiring, declarative GitOps in all but the tool name.
I have not built GitLab CI pipelines, though I have lived inside the gate design that makes a pipeline
trustworthy, and I have not operated GPU clusters, only run models on my own hardware under cgroup limits.
What I bring is depth in the layer all of that sits on, and the habit of proving a system does what its
owner believes it does.

On logistics: I live near Freiburg, about four and a half hours from Cologne by train. I would take the
role on a hybrid basis with regular presence in the office, and I am open to discussing relocation if the
team needs more. I am a US citizen with German permanent residence and need no sponsorship. Your advert
says you would rather talk to people who do not tick every box than miss the right one; I am asking for
that conversation, and I will bring the cluster layer up to the standard of the rest.

Yours sincerely,
#v(0.5cm)
Matt Ji
