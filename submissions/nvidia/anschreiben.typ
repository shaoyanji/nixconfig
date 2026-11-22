// NVIDIA — Systems / Infrastructure Engineer. English letter, one page.
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
NVIDIA

#v(0.42cm)
#text(weight: "bold", size: 10.1pt)[Application: Systems / Infrastructure Engineer]
#v(0.32cm)

Dear NVIDIA team,

the layer I work at is the one where a machine's behaviour is decided: which kernel modules load, which parameters they take, what the governor is
set to, how memory pressure is handled before the OOM killer becomes relevant. I keep three GPU driver profiles in a single repository — the
proprietary modules with modesetting and PRIME offload as the default, the open kernel modules on a hybrid laptop where the NVIDIA and AMD bus
IDs must be declared explicitly, and a Kepler card held on the legacy branch with the kernel pinned to 6.12 LTS because every upstream bump breaks
out-of-tree rebuilds.

The parameters that make those work are declared rather than discovered: `nvidia_drm.modeset=1` and `fbdev=1` for a compositor that needs a KMS
node, the four `nvidia*` modules loaded by name, DRM lease groups so a Wayland session can take the card, `pcie_aspm=off` where link power
management cost more than it saved. When a card or a display path misbehaves, I would rather read the module parameters and the kernel log than
reason from the desktop's symptoms.

On tuning, my rule is that the measurement travels with the change. Replacing a CPU frequency daemon with a fixed governor measured 2.46 W and
41 °C at an 800 MHz idle, against 2.93 W and 42 °C for the daemon; an APU that sat on its 1400 MHz floor under `powersave` needed `schedutil`
instead. A zram profile carries 1.8 GiB at a measured 3.76:1, with `vm.swappiness`, `vfs_cache_pressure` and `dirty_background_ratio` set per
machine class. I have also reverted an optimisation that measured well and explained nothing: masking a boot unit looked like a 1.895 s win and
had only moved the wait to another unit. GPU inference gets the same treatment — layers offloaded, flash attention, metrics exposed, an idle-stop
that frees the card after fifteen minutes, and pressure stall information as the thing I watch, because it says which resource is queueing.

Deployment is declarative end to end: one flake, pinned inputs, hosts composed from feature lists, a gate that runs the same evaluation in CI and
on the machine, a canary guest built from the host's own modules before a fleet rollout, and a generation that rolls back in one command.

Gaps rather than surprises: no kernel code or upstream patches, no GPU cluster ownership, no hugepages, `isolcpus` or real-time kernel, no
`io_uring`, no eBPF, bpftrace or ftrace (my diagnosis is `strace`, `tcpdump`, `journald` and PSI), and no CUDA, cuDNN or TensorRT packaging.

Two practical points: I am a US citizen with permanent US work authorization and also hold German permanent residence, so sponsorship is not the
question — but I live in Germany, and if this requisition means US residency I would rather settle that in the first conversation than at offer
stage. Repository: https://github.com/shaoyanji/nixconfig

Best regards,
#v(0.4cm)
Matt Ji
