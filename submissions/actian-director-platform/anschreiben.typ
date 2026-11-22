// Actian — Director of Platform Engineering. English cover letter.
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
Actian\\
Engineering Leadership\\
Remote

#v(0.55cm)
#text(weight: "bold", size: 10.3pt)[Application: Director of Platform Engineering — Data Intelligence Platform]
#v(0.45cm)

Dear Actian Engineering Leadership,

You are hiring someone to build a platform organisation around a data graph: metadata, lineage, quality and
business context in one structure that enterprise customers can trust. I want to be direct about which half
of that I have done. I have built the graph, alone, and I have never built the organisation.

The graph is the part I can show. My fleet's repository compiles into 1,772 edges over 38 hosts, 330
modules, 250 tags, 79 documents and 63 skills, and the question "what touches this module" is a Cypher
query rather than a search. Alongside it sits an epistemics table that records which source settles which
claim — a module's configuration outranks a doc, a compiled inventory outranks a hand-kept list — so
authority is resolved rather than argued. That is the same problem your platform solves for customers:
not storing metadata, but making it trustworthy enough to act on.

The delivery layer follows the same principle. Every change passes a gate that runs in CI and on the host;
a failure leaves the previous generation running and rollback is a pointer move. Documentation has a line
budget and a vocabulary gate, so it fails like code when it drifts. Agents operate inside the same
discipline: a compiled skill index, a turn ledger for coordination, and checks they must pass rather than
summaries they must write. Human oversight, auditability and guardrails are not a policy I would add to
AI-driven operations; they are the structure I already run.

Where I fall short is the job title. I have not recruited, structured or managed a platform team, and the
organisation-building, hiring bar and 12-month delivery plan in your advert assume someone who has. I have
also not run Kubernetes in production, Terraform/Terragrunt, or Argo CD; my infrastructure as code is NixOS
modules and flake wiring, and my cloud experience is Oracle hosts plus one Lambda project. If the role is
strictly a director with an existing leadership record, I am not that candidate, and I would rather say so
than waste your first two interviews.

If there is room for a founding platform engineer who owns the architecture and the verification layer while
the leadership structure is built around them, that is a conversation I would take seriously. The graph,
the gates and the evidence discipline are already in my hands; the team is what I would be learning.

Yours sincerely,
#v(0.5cm)
Matt Ji
