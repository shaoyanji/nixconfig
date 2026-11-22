#set document(title: "Application — VirtusLab, Linux Hacker & Nix Wizard", author: "Matt Ji")
#set page(paper: "a4", margin: (top: 2cm, bottom: 2cm, left: 2.2cm, right: 2.2cm))
#set text(font: ("Libertinus Serif", "DejaVu Sans"), size: 10pt, fill: rgb("#111827"), lang: "en")
#set par(leading: 0.58em, justify: true, spacing: 1.1em)

#text(size: 9pt, fill: rgb("#374151"))[
  #text(weight: "bold", size: 10pt, fill: rgb("#111827"))[Matt Ji] \
  Am Burgerhof 4, 79261 Gutach im Breisgau, Germany \
  matt\@bountystash.com • +49 1733281570 • github.com/shaoyanji/nixconfig
]

#v(14pt)

#text(size: 9pt)[
  VirtusLab \
  Tooling Space \
  Poland
]

#v(14pt)
#align(right)[#text(size: 8.5pt, fill: rgb("#4b5563"))[22 November 2026]]

#v(6pt)
#text(weight: "bold")[Application — Linux Hacker & Nix Wizard (Senior / Expert)]

#v(4pt)
Dear VirtusLab team,

#v(2pt)
The job title is unusual enough that I will answer it with a repository. For five years my fleet has been one Nix flake: one module per service, a feature list per host, pinned inputs, and a gate that evaluates modules and assertions before anything is deployed. A host registers once and the option surface it composes is a cost the gate pays for. Rollback is a generation, not a rebuild. That design was not inherited from a template; it was forced by having no team, no configuration management server, and thirteen machines that had to survive three hardware generations.

#v(2pt)
Where the role asks for Linux, my experience is as an operator rather than a contributor: systemd units and their failure modes, cgroups and namespaces for isolation, PSI and disk pressure as the signal that something is wrong before a user notices, boot and initrd on real hardware, nftables and a WireGuard mesh with no public listener. The tooling around it is Python and Go, including an alerting bridge that only reports success once delivery is confirmed. Documentation is generated from the same graph that drives the task menu, because documentation that drifts is worse than none.

#v(2pt)
Where I fall short is the other half of the posting. I have not worked on kernel internals — memory management, IPC, syscalls — beyond reading them when something broke. I have not written eBPF programs, and I have not used perf or valgrind as working instruments. My C experience is instrumenting lab equipment, not writing Rust or C bindings. Python is my tooling language, not a performance-engineering specialism. If the role is genuinely half kernel work, that half would start from a low base.

#v(2pt)
I am based in Germany, work remotely without difficulty, and am open to a B2B arrangement. Native English, German C1, US citizen with permanent German residence. The repository is public and unglamorous: github.com/shaoyanji/nixconfig

#v(4pt)
Yours sincerely,

#v(18pt)
Matt Ji
