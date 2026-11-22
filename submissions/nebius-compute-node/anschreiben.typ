// Nebius — Senior SRE, Compute Node Team. English letter, one page.
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
Nebius

#v(0.42cm)
#text(weight: "bold", size: 10.1pt)[Application: Senior Site Reliability Engineer, Compute Node Team]
#v(0.32cm)

Dear Nebius Compute Node team,

the Compute Node team works where a guest meets the host: Linux, the hypervisor, and the scheduler deciding what gets memory and CPU next. My work
sits at that line on a smaller fleet. Each host pins its own kernel track and kernel parameters, each service is a systemd unit with defined failure
behaviour, and the whole generation rolls back in one command. When a host misbehaves, the question is which layer lied — user space, the unit, the
kernel parameter, or the declaration that produced it — and each has its own evidence.

The guests are microVMs: microvm.nix driving cloud-hypervisor on KVM, vsock for control, a tap on the host bridge with NAT in front of it, the guest
firewall off because the boundary lives on the host that owns the bridge. The store arrives read-only over virtiofs with a writable overlay, `/var`
has its own volume so identity survives a restart, and the ssh host key comes from a persistent share. Where `/dev/kvm` is absent the definition says
so and the runner falls back to TCG, rather than failing at boot in a way nobody can explain.

One of those guests is my canary. It boots its own kernel and root, imports no host chain and so carries none of the host's service tier: a
configuration or a runbook runs against a real systemd and ssh machine, and then the guest is thrown away. A host whose modules fail evaluation never
reaches an installer at all.

Observability is written, not consumed. A sentinel puts job status, generation age, disk and pressure stall information for IO, memory and CPU into a
ledger every fifteen minutes; `node_exporter` feeds the dashboards, gatus pages on a service that stops answering, and the same threshold pages on
silence, because a monitor that died quietly looks exactly like a healthy node. Incidents start with a hypothesis and a measurement — pressure stalls,
OOM kills, a unit restarting in a loop — not with a restart and hope.

What I have not done, so a first call does not have to find it: no QEMU or cloud-hypervisor internals and no live migration at scale, no NUMA or
cgroup v2 tuning beyond what systemd gives, no perf, eBPF, ftrace or kdump in production, no GPU, NVLink, InfiniBand or BMC/IPMI hardware lifecycle.
My kernel work is configuration and operations rather than hypervisor development.

Practical points. I am a US citizen with an unbefristete Niederlassungserlaubnis, so no sponsorship is needed, and I am applying to Remote Europe or
Germany rather than Amsterdam. My target is EUR 130,000–160,000. The repository is the honest version of this: https://github.com/shaoyanji/nixconfig

Best regards,
#v(0.4cm)
Matt Ji
