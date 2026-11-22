#set document(title: "Application — Canonical, Lead Linux Kernel Engineer", author: "Matt Ji")
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
  Canonical \
  Kernel team — Ubuntu \
  Home based — Worldwide
]

#v(14pt)
#align(right)[#text(size: 8.5pt, fill: rgb("#4b5563"))[22 November 2026]]

#v(6pt)
#text(weight: "bold")[Application — Lead Linux Kernel Engineer, Ubuntu]

#v(4pt)
Dear Canonical kernel team,

#v(2pt)
I have not written a kernel patch. For a Lead Kernel Engineer role that is the defining qualification, so I will not spend this letter implying that five years of running Linux adds up to it. What I can offer is the operating half of the discipline, and a clear account of which half is missing.

#v(2pt)
On my fleet the kernel was configuration, not a black box: options declared in NixOS modules and reviewed in git, modules loaded by policy rather than by accident, cgroups and namespaces bounding services, and boot, initrd and recovery treated as things that must work without a console. Updates were fleet work — rebuild from pinned inputs, verify the evaluated state, roll out, keep the previous generation bootable — which is the same shape as reproducible kernel builds and CVE response, done at a much smaller scale. When something broke at the boundary between kernel and userspace, I was the person reading the messages, the OOM events and the pressure figures, because there was nobody else.

#v(2pt)
What that does not give me: patch development or review, upstream triage, driver or subsystem work, eBPF, and no experience negotiating with silicon or cloud partners. I have also never led a team of engineers or held a maintainer role, and a Lead position is as much about judgement across other people's patches as about writing them. Those are not gaps a first year closes; they are the job.

#v(2pt)
I am applying because the reproducible-build and CVE-response side of kernel engineering is real work I have done, and because a team that owns Ubuntu's kernel is worth one honest letter even when the answer is no. I am based in Germany with permanent residence, a US citizen with native English and German C1, so worldwide remote needs no sponsorship. The repository is public: github.com/shaoyanji/nixconfig

#v(4pt)
Yours sincerely,

#v(18pt)
Matt Ji
