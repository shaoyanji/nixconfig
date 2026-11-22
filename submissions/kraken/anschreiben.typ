#set document(title: "Application — Kraken, Infrastructure / DevOps Engineer", author: "Matt Ji")
#set page(paper: "a4", margin: (top: 2cm, bottom: 2cm, left: 2.2cm, right: 2.2cm))
#set text(font: ("Libertinus Serif", "DejaVu Sans"), size: 10pt, fill: rgb("#111827"), lang: "en")
#set par(leading: 0.58em, justify: true, spacing: 1.1em)

#text(size: 9pt, fill: rgb("#374151"))[
  #text(weight: "bold", size: 10pt, fill: rgb("#111827"))[Matt Ji] \
  Am Burgerhof 4, 79261 Gutach im Breisgau, Germany \
  matt\@bountystash.com • +49 1733281570 • github.com/shaoyanji
]

#v(14pt)

#text(size: 9pt)[
  Kraken \
  Infrastructure team
]

#v(14pt)
#align(right)[#text(size: 8.5pt, fill: rgb("#4b5563"))[22 November 2026]]

#v(6pt)
#text(weight: "bold")[Application — Infrastructure / DevOps Engineer]

#v(4pt)
Dear Kraken team,

#v(2pt)
Uptime is not a property of a design document; it is what happens at four in the morning when a disk fills, a certificate expires, or a service comes back on an older generation. I ran thirteen bare-metal Linux hosts alone for five years, with no cloud to fall back on and nobody to escalate to. That arrangement forces the habits a 24/7 estate needs: access as a short-lived certificate from our own CA, secrets encrypted per host with sops and age, every service behind a WireGuard mesh with no public listener, and a rollback that is a task rather than a procedure.

#v(2pt)
The telemetry loop is the part I care most about. A probe that fires and never arrives is worse than no probe, because it buys a false belief that someone is watching, so alerts go through a bridge in Go that only reports success once delivery is confirmed. A ledger records job status, generation age, disk and PSI pressure every fifteen minutes, which is how a slow service gets a cause instead of a story. Restores are tested rather than counted, and every procedure lives in a runbook because there was no second person to remember it.

#v(2pt)
What I have not done, plainly: no Kubernetes and no cloud infrastructure — my estate is hardware I bought and racked. No company-scale on-call rotation, since the rotation was one person. No crypto or exchange operations, and no formal incident command training. The failure modes I know are bare-metal ones: boot, storage, certificates, network boundaries, and the slow drift that turns a healthy fleet into a fragile one.

#v(2pt)
I am based in Germany with permanent residence and a US passport, so no sponsorship is involved. Native English, German C1. The repository is public and unglamorous: github.com/shaoyanji/nixconfig

#v(4pt)
Yours sincerely,

#v(18pt)
Matt Ji
