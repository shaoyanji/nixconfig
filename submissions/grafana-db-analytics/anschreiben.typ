// Grafana Labs — Senior Full Stack Engineer, Databases - Analytics. English letter, one page.
#set page(paper: "a4", margin: (x: 2.3cm, y: 1.9cm))
#set text(font: "DejaVu Sans", size: 9.6pt, fill: rgb("#191919"), lang: "en")
#set par(justify: true, leading: 0.62em)
#let muted = rgb("#5c6b7a")

#align(right)[
  #text(weight: "bold", size: 10.4pt)[Matt Ji]
  #linebreak()
  #text(size: 9pt)[Am Burgerhof 4 · 79261 Gutach im Breisgau, Germany]
  #linebreak()
  #text(size: 9pt)[matt\@bountystash.com · +49 1733281570]
]

#v(0.4cm)
#text(size: 8.6pt, fill: muted)[22 November 2026]
#v(0.4cm)
Grafana Labs\\
Databases — Analytics, Context Layer Team

#v(0.5cm)
#text(weight: "bold", size: 10.1pt)[Application: Senior Full Stack Engineer, Databases - Analytics]
#v(0.4cm)

Dear Grafana Databases - Analytics team,

your posting's principle — the context system retrieves, agents decide, data teams maintain the intelligence — is the
architecture I have been running for the last year on a smaller estate. A fleet of agents works against a compiled inventory
and an epistemics table that declares which source settles which claim; they query structured surfaces rather than
maintaining brittle context files, and every answer carries its provenance. Retrieval is a Postgres archive with hot tables
and a full-text index behind an API, a knowledge-graph projection that answers "what touches what" over Cypher, and a Go
coordination service where concurrent agents claim work, publish ordered turns, and retry without duplicating.

The multi-tenant SaaS foundations you name are the same problems at homelab scale: tenant isolation enforced by construction
(capped microVM guests, read-only mounts, no egress), issued rather than standing access (a fleet CA with short-lived
credentials), an audit ledger written every fifteen minutes that pages on bad state and on silence, and usage argued from
measured queue depth instead of guessed capacity. I also operate an LLM-serving stack daily — chat, speech-to-text and
text-to-speech on one GPU — and the agent workflows built on it include a pipeline that fills ATS forms and passes email
verification under a human-approval boundary: practical GenAI, not a demo.

The honest gaps, because a staff-level screen will find them anyway: AWS, GCP and Azure I have not run in production — my
cloud is rented metal and my infrastructure-as-code is Nix. TypeScript is a working language for tooling and dashboards, not
a primary one, and multi-team scope is argued from a single-operator estate rather than a company. What I would not need to
learn is the domain: governed retrieval, provenance and confidence signals, and agent-facing contracts are what I already
operate and reason about in writing, in the async style a remote-first team runs on.

A question I would bring to a first conversation: when two sources disagree on the same entity — say a stale CRM record
versus a live service registry — does the context layer surface both with confidence, or resolve one and risk silently
poisoning the agent's decision? That boundary is where retrieval systems quietly become wrong, and it is the problem I find
most interesting here.

I am a US citizen with permanent German residence, so remote-from-Germany needs no sponsorship. German is C1, English
native.

Kind regards,
#v(0.45cm)
Matt Ji
