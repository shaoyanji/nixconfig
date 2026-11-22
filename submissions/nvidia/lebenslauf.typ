// NVIDIA — Systems / Infrastructure Engineer.
// Native English source replacing the ad-hoc PDF. Kernel modules, GPU drivers, measured tuning, declared fleets.
#set page(paper: "a4", margin: (x: 1.5cm, y: 1.15cm))
#set text(font: "DejaVu Sans", size: 9.2pt, fill: rgb("#191919"), lang: "en")
#set par(justify: true, leading: 0.55em)
#set list(marker: text(fill: rgb("#1f3a26"))[•], indent: 0.85em, spacing: 0.3em)
#let accent = rgb("#1f3a26")
#let muted = rgb("#5c6b7a")
#let section(t) = block(above: 8pt, below: 2pt)[
  #text(size: 9.8pt, weight: "bold", fill: accent, tracking: 0.07em)[#upper(t)]
  #v(-3pt)
  #line(length: 100%, stroke: 0.5pt + rgb("#c3ced8"))
]
#let job(title, org, when, where) = block(above: 4pt, below: 1pt)[
  #grid(columns: (1fr, auto),
    [#text(weight: "bold")[#title] #text(fill: muted)[— #org]],
    [#text(size: 8pt, fill: muted)[#when]])
  #v(-2pt)
  #text(size: 8pt, fill: muted)[#where]
]

#grid(columns: (1fr, auto),
  [
    #text(size: 19pt, weight: "bold", fill: accent)[Matt Ji]
    #v(-2pt)
    #text(size: 9.8pt)[Systems engineer · Linux internals, GPU enablement, declared fleets]
  ],
  [
    #align(right)[
      #text(size: 8.4pt)[Am Burgerhof 4 · 79261 Gutach im Breisgau, Germany]
      #linebreak()
      #text(size: 8.4pt)[matt\@bountystash.com · +49 1733281570]
      #linebreak()
      #text(size: 8.4pt)[github.com/shaoyanji · linkedin.com/in/mattji]
    ]
  ])
#v(-4pt)
#line(length: 100%, stroke: 0.9pt + accent)

#section("Profile")
I work at the layer where a machine's behaviour is actually decided: which kernel modules load, which parameters they take, what the scheduler
governor is set to, how memory pressure is handled before the OOM killer takes an interest. My habit is to declare that layer rather than
adjust it, and to keep the measurement next to the change, because a tuning claim without a number is a preference.

GPU enablement is the most concrete part of it. I maintain three distinct driver profiles in one repository: the proprietary modules with
modesetting and PRIME offload as the default, the open kernel modules on a hybrid laptop where the NVIDIA and AMD bus IDs have to be declared
explicitly, and a Kepler card held on the legacy driver branch with the kernel pinned to 6.12 LTS because every upstream bump breaks
out-of-tree rebuilds. The parameters that make each of them work are declared, not discovered: `nvidia_drm.modeset=1` and `fbdev=1` for a
compositor that needs a KMS node, `nvidia`, `nvidia_uvm`, `nvidia_modeset` and `nvidia_drm` loaded by name, DRM lease groups set so a Wayland
session can take the card, and `pcie_aspm=off` on the AMD machine where link power management cost more than it saved.

Performance work is measured, and the measurement has occasionally contradicted the change. Removing a CPU frequency daemon and fixing the
governor measured 2.46 W and 41 °C at an 800 MHz idle against 2.93 W and 42 °C for the daemon it replaced; a different APU sat on its 1400 MHz
floor under `powersave` and needed `schedutil` instead. A zram profile carries 1.8 GiB of compressed swap at a measured 3.76:1, and
`vm.swappiness`, `vfs_cache_pressure` and `dirty_background_ratio` are set per class of machine rather than copied. One "optimisation" I
reverted after measuring: masking a boot unit looked like a 1.895 s win and had only moved the wait somewhere else.

Inference on a GPU host is tuned the same way: layers offloaded to the card, flash attention on, metrics exposed, and an idle-stop that frees the
GPU after fifteen minutes without a request — plus contention handling when a human wants the same card. Pressure stall information is what I
watch while doing it, because it says which resource is queueing rather than which one is busy.

What I have not done: I have not written kernel code or submitted patches upstream, and I have not owned a GPU cluster. No hugepages, no
`isolcpus`, no real-time kernel, no `io_uring`. I have not used eBPF, bpftrace or ftrace for tracing — my diagnosis is `strace`, `tcpdump`,
`journald` and PSI. And I have not packaged CUDA, cuDNN or TensorRT.

#section("Areas")
#grid(columns: (1fr, 1fr), column-gutter: 14pt, row-gutter: 2pt,
  [*Kernel configuration* — modules by name, boot and runtime parameters, per-host sysctl],
  [*GPU drivers* — proprietary, open modules, legacy branches pinned to a kernel],
  [*Display and KMS* — modeset and fbdev parameters, PRIME bus IDs, DRM lease groups],
  [*Memory tuning* — zram with compression ratio measured, swappiness, cache pressure, dirty ratios],
  [*CPU and power* — governor choice by measurement, EPP, idle power and thermals],
  [*Observability* — PSI by resource, job state and generation age, page on bad state and silence],
  [*Declarative deployment* — hosts from evaluation, canary guest, rollback by pointer],
  [*Diagnosis* — strace, tcpdump, journald, MTU faults by path, benchmarks that can refute])

#section("Experience")

#block(breakable: false)[
#job("Founder and engineer", "Bountystash", "Jun 2020 – Aug 2025", "Freiburg, DE")
- Maintained three GPU driver configurations in one tree: proprietary modules with modesetting and PRIME offload, open kernel modules with both bus IDs declared on a hybrid machine, and a Kepler card on the legacy branch with the kernel pinned to 6.12 LTS to stop out-of-tree rebuilds breaking on every bump.
- Declared the parameters instead of discovering them: `nvidia_drm.modeset=1` and `fbdev=1`, the four `nvidia*` modules loaded by name, DRM lease groups for a Wayland session, `pcie_aspm=off` where link power management cost more than it saved.
- Measured every tuning change and kept the number: a fixed governor at 2.46 W / 41 °C against 2.93 W / 42 °C for the daemon it replaced, `schedutil` on an APU that stayed at its 1400 MHz floor under `powersave`.
- Ran compression-backed swap deliberately: 1.8 GiB of zram at a measured 3.76:1, with `vm.swappiness`, `vfs_cache_pressure` and `dirty_background_ratio` set per machine class — 100/50/3 on a low-memory host, 180 with watermark boosting off on another — instead of one profile copied everywhere.
- Reverted an optimisation that measured well and explained nothing: a masked boot unit that looked like a 1.895 s win had only moved the wait to a different unit.
- Tuned GPU inference rather than guessing at it: layers offloaded to the card, flash attention, `--metrics` exposed, and an idle-stop freeing the GPU after 900 s without a request, with a guard that yields the card when a human sits down.
- Declared a thirteen-host fleet in one flake — pinned inputs, feature-list hosts, options with types and assertions — so a machine is produced by evaluation, gated by the same module check in CI and on the host, and rolled back by pointer.
- Deployed through a canary: a KVM guest built from the host's own modules proves a configuration before the fleet receives it.
- Ran the evidence loop on the same machines: job state, generation age, disk and PSI pressure to a ledger every fifteen minutes, paging on any state short of ok and on silence.
]

#block(breakable: false)[
#job("Independent projects", "Self-directed", "2023 – present", "Remote")
- fibtransponder: a state machine streaming a bitstream with bounded work per step, because an unbounded step is a latency bug waiting for the wrong input; a corpus benchmark refuted the first detector design and the claim narrowed.
- tokenloom: a Rust workspace with a piece table, a ripple re-tokeniser that touches only the changed span, and a 5 ms gate that keeps a keystroke honest.
- Diagnosed a path-specific MTU fault to the boundary that dropped the packet rather than raising an application timeout, and wrote the path down so the next diagnosis starts where the evidence ends.
]

#block(breakable: false)[
#job("Asset Manager", "O3 Energy", "Aug 2016 – Jun 2020", "Dallas, TX")
- Owned data quality and yield models for a solar portfolio above USD 100M, reconciling three measurement feeds into one auditable series.
- Administered software and IT for the company and its subsidiaries; managed an international team.
]

#block(breakable: false)[
#job("Director of Sustainability", "Smart Energy 360", "Aug 2015 – Aug 2016", "Dallas, TX")
- Advised commercial clients on energy strategy, cybersecurity software and risk, translating between technical and commercial readers.
]

#block(breakable: false)[
#job("Research Assistant", "Fraunhofer ISE", "Mar 2012 – Sep 2012", "Freiburg, DE")
- Wrote the C++ application driving a heliostat interferometer and the Python analysis beside it, then verified the geometry independently rather than trusting the first implementation.
]

#block(breakable: false)[
#job("Associate Technical Professional", "Halliburton", "Jun 2010 – Sep 2011", "Williston, ND, US")
- Troubleshot equipment and process failures on site in twelve-hour shifts, with a crew and a schedule depending on the answer.
]

#section("Selected Work")
#grid(columns: (1fr, 1fr), column-gutter: 10pt, row-gutter: 5pt,
  [
    #text(weight: "bold")[GPU driver profiles] #text(size: 8pt, fill: muted)[— enablement]
    #linebreak()
    Proprietary, open modules on a hybrid laptop with both bus IDs, and a legacy branch pinned to 6.12 LTS. KMS and DRM lease parameters declared.
  ],
  [
    #text(weight: "bold")[power and frequency] #text(size: 8pt, fill: muted)[— tuning]
    #linebreak()
    Governor chosen by measurement: 2.46 W at 800 MHz idle against 2.93 W for the daemon it replaced; schedutil where powersave floored.
  ],
  [
    #text(weight: "bold")[memory profile] #text(size: 8pt, fill: muted)[— pressure]
    #linebreak()
    zram at 1.8 GiB / 3.76:1 measured, swappiness and cache pressure set per machine class, dirty ratios tuned for bursty writes.
  ],
  [
    #text(weight: "bold")[nixconfig] #text(size: 8pt, fill: muted)[— declared fleet]
    #linebreak()
    Thirteen hosts from pinned inputs, one evaluation gate per host, rollback by pointer. https://github.com/shaoyanji/nixconfig
  ],
  [
    #text(weight: "bold")[inference host] #text(size: 8pt, fill: muted)[— GPU workload]
    #linebreak()
    GPU layers offloaded, flash attention, metrics exposed, idle-stop after 900 s, card yielded to a human on demand.
  ],
  [
    #text(weight: "bold")[fleet-sentinel] #text(size: 8pt, fill: muted)[— evidence]
    #linebreak()
    Job state, generation age, disk and PSI every fifteen minutes; pages on bad state and on silence.
  ])

#section("Education")
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[M.Sc. Renewable Energy Management] #text(fill: muted)[— Albert-Ludwigs-Universität Freiburg]],
  [#text(size: 8pt, fill: muted)[2011 – 2014 · grade 1.8]])
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[B.Sc. Petroleum Engineering] #text(fill: muted)[— Colorado School of Mines, McBride Honors Program]],
  [#text(size: 8pt, fill: muted)[2006 – 2010 · 3.2 GPA]])

#v(4pt)
#text(size: 7.8pt, fill: muted)[German C1 · English native · US citizen with permanent US work authorization and German permanent residence · based in Gutach im Breisgau · available 01.12.2026]
