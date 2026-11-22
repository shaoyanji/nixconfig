# NavVis — Senior Linux Platform Engineer (F/M/D)

**Status: SUBMITTED 2026-11-21** (DB `navvis-senior-linux-platform`, stage `applied`, OTP mail 311060 on file). This pass did not
apply again; it rebuilt the packet as native Typst sources so the documents are editable and reproducible instead of existing only
as Nix-generated PDFs.

| Field | Value |
| :--- | :--- |
| Role ID | `navvis-senior-linux-platform` |
| Employer | NavVis GmbH, Munich (300+ people, 60 nationalities) |
| Role | Senior Linux Platform Engineer (F/M/D) — System Software, Mapping and Perception |
| Location | Munich, at least three days per week on site; hybrid otherwise |
| Language | **en** |
| Apply URL | https://job-boards.eu.greenhouse.io/navvis/jobs/4943654101 |
| Greenhouse API | https://boards-api.greenhouse.io/v1/boards/navvis/jobs/4943654101?questions=true |
| Posting updated | 2026-10-16 (API `updated_at`) |
| Salary staged on the form | **EUR 100,000 gross**, full-time equivalent; NavVis publishes no band |
| Fit | 2 |

## What was submitted, and what this rebuild is

| Artefact | Submitted 2026-11-21 | Native rebuild |
| :--- | :--- | :--- |
| CV | 2 pages, 656 words, `d2678627aa0dc612e4d66c036cc99c99e0a4fb68e7bcc3d36378162f8b214321` | 2 pages, 901 words, `fccd3933e32107a5853459522e4baa54a1306d33a7eff986446315eece7aeee3` |
| Letter | 1 page, 294 words, `6a4b14f4501f56c9d052a613b8a6362e3a80e1a02dd60a086c9b1e6e88527bba` | 1 page, 339 words, `0c80f72d7f65d4d2105c1d3204052494a490e93fdfc8378374a9472d2be3895f` |

The submitted bytes remain recoverable from git history, which is why nothing was preserved as a duplicate copy. Both native
documents compile at **0 warnings** with typst; no `**` in either source; the CV's page 1 ends inside Selected Work and page 2
opens on the CUDA node card, so no heading is orphaned.

**Divergence, stated rather than hidden.** The Nix-built CV carried a skills block claiming Kubernetes, AWS, Azure and Google
Cloud. Nothing in the repository supports production experience in any of them, and this session has removed exactly that claim
from other packets, so the native rebuild does not reproduce it: it lists Nix/NixOS, systemd, Python, Go, C++, Bash, sops and git
instead. Everything else follows the submitted story — NixOS fleet as a declared feature list, sops and the fleet SSH CA, a
reproducible image with one-command rollback, the per-host CI gate, the fifteen-minute sentinel, the CUDA driver boundary and the
microVM sandbox. The letter keeps its gap paragraph verbatim in substance and adds one sentence on the Munich relocation.

## What the role is

Own the Linux platform of NavVis's mobile mapping devices (VLX, MLX, CLX): OS lifecycle, system services, patches and
modifications to system libraries, graphics and media integration. Build, adapt, package and release **Debian and Ubuntu images**
on **amd64 and ARM**, with OS updates, migrations, build and release pipelines, dual boot and OTA at production scale. Integrate
drivers with the application, collaborate on the HAL, support the **ROS**-based mapping stack (**C++ and Python**), patch system
libraries for device-specific needs (Mesa/OpenGL, libc), own camera and media userspace from **V4L2** to LiDAR, and keep quality
measurable with CI, hardware-in-the-loop tests, stress tests and benchmarks. Explicitly not a firmware or bootloader role; the
Embedded Software team owns those. Five-plus years shipping Linux device software, ideally ARM; Yocto/Buildroot an added benefit.

## Fit map

| Requirement | Evidence | Verdict |
| :--- | :--- | :--- |
| Linux OS lifecycle and image building | A fleet where each host is a declared feature list and the image is rebuilt reproducibly; generations roll back with one command | **strong**, but Nix rather than Debian/Ubuntu images |
| systemd, services, packaging | Services as systemd units with explicit failure behaviour; packaging model is Nix, not dpkg | strong on services; packaging is the wrong toolchain |
| CI, HIL-style gating, benchmarks | One gate identical for CI and machines; canary guest before production; a benchmark that falsified its own claim | **strong** |
| Kernel and userspace boundary | Kernel modules and parameters pinned per host, initrd debugging, `strace` across the boundary, out-of-tree NVIDIA and evdi modules | strong |
| Graphics and driver integration | Driver and userspace pinned together on a CUDA node, Mesa-level breakage diagnosed and patched around, latency measured | **strong** |
| Python for tooling and automation | Pipelines, tooling and tests across the fleet | **strong** |
| Production C++ | C++ for the Fraunhofer lab-equipment application; no production C++ since | partial |
| Debian or Ubuntu image ownership | **none**; no dpkg, debhelper or Ubuntu image work | **gap (role centre)** |
| ARM device fleet | **none**; x86 hosts and microVMs | **gap** |
| ROS / robotics middleware | **none** | **gap** |
| V4L2, camera, LiDAR, sensor protocols | **none**; the sensor-adjacent work is GPU and driver pinning | **gap** |
| Yocto or Buildroot | **none** (bonus only) | gap |
| Munich, three days on site | Based near Freiburg; relocation question, stated in the letter | **constraint** |

Fit **2**, as recorded when this was applied: the OS lifecycle, service management, reproducible builds and CI gating transfer
cleanly, but the role's centre is Debian/Ubuntu image ownership for ARM devices with V4L2 and ROS integration, and none of that is
present.

## Greenhouse form — as answered

14 questions, ids read from the boards API.

| Field | Id | Answer given or staged |
| :--- | :--- | :--- |
| First Name | `first_name` | Matt |
| Last Name | `last_name` | Ji |
| Email | `email` | matt@bountystash.com |
| Phone | `phone` | +49 1733281570 |
| Resume/CV | `resume` | the submitted 2-page CV (original bytes in git history) |
| Cover Letter | `cover_letter` | the submitted 1-page letter |
| LinkedIn profile | `question_9427438101` | https://linkedin.com/in/mattji |
| Legally authorized to work | `question_9427439101` | Yes — US citizen with German permanent residence |
| Require immigration sponsorship | `question_9427440101` | No |
| Salary expectation (gross annual, 100%) | `question_9427441101` | EUR 100,000 |
| Where are you currently located | `question_9427442101` | Gutach im Breisgau, Germany |
| Preferred start date | `question_9427443101` | Immediately, by arrangement |
| How did you hear about this job | `question_9427444101` | NavVis careers page (Greenhouse) |
| Privacy notice confirmation | `question_9427445101` | Confirmed |

## Standing state

1. Do not resubmit: the application is with NavVis and the recruiter reply is outstanding.
2. If a screen happens, send the native CV and letter so both parties hold the same documents, and lead with the Munich
   relocation answer.
3. The honest position on the gaps is already in the letter; keep it there rather than letting an interview discover it.
