// Grafana Labs — Senior Software Engineer, Security Assurance. English letter, one page.
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
Grafana Labs #linebreak() Security Assurance / GRC Engineering

#v(0.5cm)
#text(weight: "bold", size: 10.1pt)[Application: Senior Software Engineer, Security Assurance]
#v(0.4cm)

Dear Grafana Labs team,

a security programme is only as good as the evidence it can produce on a Tuesday afternoon, months after the control was
designed. That belief is why I built my last five years of infrastructure so that the control and the proof are the same
artefact: secrets encrypted per host with sops and age, each machine holding only its own key; identity issued by a certificate
authority as certificates that expire and renew on a timer rather than standing keys; network and access policy declared in the same
repository as the systems they govern, default-deny between hosts, so a permission change is a reviewed diff and the review is
the audit trail.

Your posting describes guardrails and paved roads rather than gates, and that is the distinction I care about too. A rule that
lives in a wiki is a rule people route around; a default that is already correct requires no conversation, and a dry run tells
someone what would change before it changes. Mine also carries its own alarm: the last loop I built writes job state, generation
age, disk and pressure every fifteen minutes and pages both on a bad state and on silence, because a control that has quietly
stopped reporting looks exactly like a system with nothing to report. On the vulnerability side I turned the CISA KEV catalogue
into a time series and into effort clusters with exposure per cluster, so patching follows reach and effort instead of the order
a list happens to be written in.

I write this in Go and Python, mostly behind one task surface with named arguments, validation and JSON output, plus CLI tools
against REST APIs — the shape of work your team describes when it says it builds the tool it needs.

I will be equally plain about the gap. I have not taken an organisation through ISO 27001 or SOC 2 as the responsible engineer,
worked in Kubernetes, or run workloads in AWS, GCP or Azure; my infrastructure is declared Linux on rented metal, and my
cloud-native knowledge is the shape of the problem rather than the provider's console. What I bring is the habit the posting
values more than rote framework knowledge: read the standard, find the control it is really asking for, and implement that as
code with evidence attached. Auditors and engineers need the same facts in different grammar, and making one artefact serve both
is most of the job as I understand it.

I am based in Germany, work remotely by default, and need no sponsorship.

One question I would bring to a first call: if an auditor asked today which engineers could read customer data in March, how long
would the answer take to produce from the system rather than from someone's memory? Closing that gap is the work I want.

Kind regards,
#v(0.45cm)
Matt Ji
