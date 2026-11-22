# NVIDIA — Systems / Infrastructure Engineer

Linux systems internals · GPU driver and kernel module configuration · measured performance tuning · declarative cluster deployment.

## This folder held a different requisition

`submissions/nvidia/` contained a complete packet for **Kitmaker's "Senior Software Engineer, Nix Packaging and Release Automation"**
(Workday `JR2029346`, US-CA-Remote, posted 2026-11-19). That is not this role. Following the same rule as `purestorage`, the contents were
**replaced** and the superseded artefacts are recorded here before being retired:

| Retired artefact | sha256 (first 16) | What it was |
| :--- | :--- | :--- |
| `Matt_Ji_Resume_Nvidia.pdf` | `98d1286531a96277…` | CV for JR2029346, 16/36 highlights, packaging-led |
| `Nvidia_Anschreiben.pdf` | `79e58944ed94e1d3…` | cover note for JR2029346, addressed to "Dear Kitmaker team" |
| `Nvidia_Cover_Note.txt` | same text | plain-text duplicate of the above |
| `Nvidia_Submission_Sheet.txt` | — | Workday recon for JR2029346: form structure, 275,000 USD staged, US-residency gate, NixOS Discourse warm channel |
| `selection.json` | `4649619e4ade9539…` | JD selector output for JR2029346 |

Both packets exist in git history if the Kitmaker application moves again. The DB row `nvidia-senior-nix-packaging-release-automation` is
annotated accordingly and stays `prep`; nothing was ever submitted for it.

**No job description exists on file for Systems / Infrastructure Engineer.** `job-description.txt` states the four pillars the dossier is built
against and says plainly that it is not a captured posting — inventing requirements would be worse than admitting the gap. Supply the live
requisition and the dossier can be tuned in one pass.

## Files

| File | Pages | Words | Warnings | sha256 (first 16) |
| :--- | :--- | :--- | :--- | :--- |
| `lebenslauf.pdf` | 2 | 1384 | 0 | `7d290c1945d3a641` |
| `anschreiben.pdf` | 1 | 497 | 0 | `409b51f30a54e5ed` |

Plus both `.typ` sources, `job-description.txt` and this sheet.

## The four pillars, with the evidence that backs each

| Pillar | Evidence in the repository | In the documents as |
| :--- | :--- | :--- |
| GPU driver and kernel module configuration | Three profiles: `profiles/nvidia.nix` (proprietary, modesetting, PRIME offload), `hosts/poseidon/nvidia.nix` (open modules, both bus IDs), `hosts/ares`/`kellerbench` (Kepler on `legacy_580` with kernel pinned to 6.12 LTS); `nvidia_drm.modeset=1`/`fbdev=1`; four modules loaded by name; `pcie_aspm=off` and amdgpu on eisen | claimed in full — this is the centre of the packet |
| Low-latency performance tuning | Governor changed and measured (2.46 W / 41 °C at 800 MHz against 2.93 W / 42 °C for the daemon); `schedutil` where `powersave` floored an APU; zram 1.8 GiB at 3.76:1; swappiness 100/180, `vfs_cache_pressure`, `dirty_background_ratio` per host class; a "1.895 s win" reverted because it only moved the wait | claimed in full, numbers included |
| Linux systems internals | `kernelModules`/`initrd.kernelModules` per host, `boot.kernel.sysctl` on five hosts, cgroups, PSI, systemd unit and socket semantics, journald | claimed in full |
| Declarative cluster deployment | One flake, thirteen hosts, feature lists, per-host evaluation gate in CI and on the machine, canary KVM guest, rollback by pointer | claimed in full |

## Gaps, in both documents

No kernel development or upstream patches. No GPU cluster ownership. No hugepages, `isolcpus` or real-time kernel; no `io_uring`. No eBPF,
bpftrace or ftrace — diagnosis is `strace`, `tcpdump`, `journald`, PSI. No CUDA/cuDNN/TensorRT packaging. Each of those words appears in the CV
only inside the paragraph declining it; the scan confirms it.

## Fit and route

**3 of 5.** The GPU driver work, the kernel-parameter discipline and the measured tuning are real and unusually specific for a personal fleet;
the missing pieces are kernel-level contribution, cluster scale and the tracing toolchain.

**Location, unresolved:** NVIDIA's remote systems requisitions have been US-remote, and this folder's predecessor was explicitly US-CA-Remote. A
US citizen resident in Germany is not automatically payable on a US-remote arrangement. The letter raises it in the last paragraph; the sheet
treats it as a pre-submit blocker.

**Compensation:** no band published for this requisition, so no figure appears in the letter. (The retired Kitmaker packet staged 275,000 USD
against 232,500–442,000; that belongs to that row, not this one.)

## Checks

| Gate | Result |
| :--- | :--- |
| `typst compile` both sources | 0 warnings each |
| Page budget | CV 2 pages, letter 1 page |
| `**` in sources | 0 |
| Unsupported claims (eBPF/bpftrace/ftrace/io_uring/isolcpus/hugepage/DCGM/CUDA/TensorRT) | 0 outside the gap paragraph |
| Salary in letter | 0 mentions |
| `task checks:prose` | exit 0 |
| Superseded Kitmaker artefacts | all five removed, hashes recorded above |
