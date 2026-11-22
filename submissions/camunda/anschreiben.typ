// Camunda — Senior Site Reliability Engineer. English letter, one page.
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
Camunda\\
Site Reliability Engineering

#v(0.55cm)
#text(weight: "bold", size: 10.1pt)[Application: Senior Site Reliability Engineer]
#v(0.45cm)

Dear Site Reliability team,

Camunda sells governed autonomy: agents propose, people decide, and the audit trail proves which was which. I run
infrastructure on the same rule, and it is the reason I want this role rather than any other SRE seat. A machine may
propose; a check must dispose.

In practice that means AI drafts configuration, scripts and documentation for me every day, and every artefact is
read and checked against the running system before it can reach a production path — because the failure mode is not a
bad model, it is a person who accepted an answer because it looked confident. Nothing generated is trusted on
plausibility, nothing touching credentials goes near a model, and I sign what ships. Your must-have list states that
principle almost word for word, which is rare enough that it changed which job I applied for.

The reliability side is the same discipline pointed at machines. Thirteen Linux hosts declared in one repository:
every change through a gate that runs identically in CI and on the host, so a failing check leaves the previous
generation serving; every release a generation with a parent, so rollback is a pointer rather than a repair at 03:00.
Telemetry every fifteen minutes over job status, generation age, disk pressure and PSI — one condition per check,
thresholds that mean something, and silence treated as blindness instead of calm. Alerts that do not cry wolf, in
other words, because an alert nobody trusts is worse than no alert.

Automation is where I have had the most practice and the least glamour. Recurring operations live behind one entry
surface with named arguments, help text and JSON output, validated so a wrong argument fails before it touches a host
— runbooks that are executable rather than prose someone reads at the wrong moment. Faults are explained from
packets and syscalls, `tcpdump` for MTU and fragmentation, `strace` for syscall behaviour, cgroups and PSI to tell I/O
starvation from memory shortage, before anything is restarted.

What I have not done, plainly: I have not operated Kubernetes in production, I have not written Terraform, and I have
not run Prometheus or Grafana. My platform is bare metal and thirteen machines, my orchestration is Nix, and my
observability is hand-built. The concepts transfer — declarative state, gated change, rollback, alerting on symptoms
— but the tooling would be new, and on a multi-cloud Kubernetes estate that is a real ramp.

On compensation, I have seen the posted range and understand it is location-based: the US band does not transfer to a
Germany-based contract through Remote.com, so I would rather discuss the local band than anchor on a number that does
not apply to me. I am a US citizen with German permanent residence, so there is no sponsorship question, German is C1
and English is native, and remote-first with async writing suits how I already work. I would welcome the chance to
talk about what "observability that matters" means to this team today.

Yours sincerely,
#v(0.5cm)
Matt Ji
