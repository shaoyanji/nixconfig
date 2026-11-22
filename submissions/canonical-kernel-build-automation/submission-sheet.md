# Canonical — Kernel Build Automation Engineer, Ubuntu Linux

Home based — EMEA. Greenhouse req **7334725**. English packet. Native Typst sources; the directory held only
`job-description.txt` until this packet.
Status: compiled and checked, **nothing submitted**.

| Field | Value |
| :--- | :--- |
| Role ID | `canonical-kernel-build-automation` |
| Employer | Canonical (publisher of Ubuntu) |
| Role | Kernel Build Automation Engineer - Ubuntu Linux |
| Location | Home based — EMEA |
| Employment | Permanent, full time; 2–4 in-person sprints a year of 1–2 weeks |
| Language | **en** |
| Apply URL | https://job-boards.greenhouse.io/canonical/jobs/7334725 |
| Greenhouse API | https://boards-api.greenhouse.io/v1/boards/canonical/jobs/7334725?questions=true |
| Posting updated | 2026-08-05 (API `updated_at`), read 2026-11-22 |
| Compensation | not published; no figure in the letter |
| Fit | 3 (DB entry 4, carried from the scout row) |

## Measured output

| Artefact | Pages | Words | sha256 |
| :--- | :--- | :--- | :--- |
| `lebenslauf.pdf` | **2** | 968 | `1e1d17d14103156f3855e88efab30cb485abe3a0a7a5b7ba69dbb01e2176b306` |
| `anschreiben.pdf` | **1** | 552 | `234ad319d2719f779ede1b711660b5f07e5642a9c389368deaf1934a0e15f459` |

Both compiled with typst at **0 warnings**; word counts measured with `pdftotext | wc -w` on the rendered PDFs. No `**` in
either source. Page 2 opens on `SELECTED WORK`, so no heading is orphaned at a page foot.

## What the role is

Lead a new effort to take the configuration and build of the Ubuntu kernel to a higher level of simplicity and automation, so
customers can receive kernels tailored to their systems. The posting asks for an industry veteran who owns the implementation
from concept to delivery, works with other engineering teams inside Canonical, goes into `kbuild`, `kconfig` and `make` when the
obvious answer does not work, and drives proposals upstream. Required: significant Python, kernel patching and configuration
experience, strong `kconfig` and git, a background with Yocto or buildroot, English. Nice to have: JavaScript or Go, CLI tools
over REST APIs, CI/CD and process automation, packaging with Ubuntu/Debian/Snap experience. Kernel internals are welcome but
explicitly not required; a real grasp of the build system is.

## Fit map

| Requirement | Evidence | Verdict |
| :--- | :--- | :--- |
| Kernel configuration in practice | Per-host track selection: latest stable by default, 6.12 LTS where legacy NVIDIA modules require it, LTS pinned on the netbook because the newest kernel could not mount root, documented fallback chain when a track leaves the package set | **strong** |
| Build as a reproducible artefact | Pinned sources, no network at build time, hashed outputs; a configuration change is a reviewable diff, not a hand-edited file on a host | **strong** |
| Automation of a build and delivery pipeline | Python and Go behind one validated task surface: named arguments, dry runs, JSON output; one gate for laptop, CI and host | **strong** |
| Python | Pipelines, selector and packet tooling, tests over canonical data | **strong** |
| Git | Public repositories, reviewable diffs, history read as evidence | **strong** |
| CLI tools with REST APIs | bountystash (event log, TUI and HTTP endpoints from one binary), archive and paste clients | **strong** |
| CI/CD and process automation | Per-host module gates run identically in CI and on the machines; rollout through a canary guest | **strong** |
| Linux systems depth | systemd, initrd contents, journald, cgroups, PSI, nftables, `strace`, `tcpdump` | **strong** |
| Out-of-tree modules | NVIDIA legacy drivers across two generations, evdi for a dock, module packages and parameters per machine | strong |
| kbuild / makefile authorship | **none**; Nix drives the build, the makefiles are not mine | **gap** |
| Kernel patching | **none**; no series authored, no upstream submission | **gap** |
| Yocto or buildroot | **none** | **gap, named in the posting** |
| Debian / Snap packaging | **none**; Nix packaging only, apt/dpkg as a consumer | **gap (nice to have)** |
| C | C++ instrument software at Fraunhofer ISE, small C changes in own services | partial — not kernel C |
| Go or JavaScript | Go in production services | meets (Go) |
| Delivery leadership | Owned an international team at O3 Energy; sets the fleet's gates, canary and rollback discipline | partial — no kernel team |
| Location and legal | Germany (EMEA), US citizen with German permanent residence, no sponsorship | **strong** |

Fit **3**: the build-as-artefact, configuration-and-pinning and automation layers are genuinely the work this role automates,
and the candidate already runs a fleet where a kernel change is reviewed, built and canaried. It is not higher because the
posting's named background is kernel patching, `kbuild` and Yocto/buildroot, and none of those three is present; the truthful
claim is that the transferable part is the build graph and the discipline around it, not the makefiles.

## The argument the letter makes

It opens on the framing that decides the role: a distribution is a build system that happens to ship a kernel, so trust in the
kernel build is trust in the build system.

The second paragraph is the concrete design — one repository stating track, configuration, module packages and pinned sources,
with the default and the three documented exceptions, each carrying its reason beside the setting. That is the "beyond typing
`make`" claim answered with something auditable rather than asserted.

The third paragraph is delivery: canary guest first, rollback as a pointer, one gate for laptop, CI and host.

The fourth is Python, Go, task surface and CLI tools over REST APIs — the posting's own nice-to-haves.

The fifth states the gap plainly: no mainline patches, no `kbuild` authorship, no Yocto/buildroot, C is instrument software. It
then names what transfers and quotes the posting's own allowance that internals are welcome but not required.

It closes with the question that measures the whole design: how many people and hours stand between a customer's one-option
change and a tested image.

## Greenhouse form — staged answers

26 questions, labels and ids read from the boards API on 2026-11-22.

| Field | Id | Required | Staged answer |
| :--- | :--- | :--- | :--- |
| First Name | `first_name` | yes | Matt |
| Last Name | `last_name` | yes | Ji |
| Preferred First Name | `preferred_name` | no | leave empty |
| Email | `email` | yes | matt@bountystash.com |
| Phone | `phone` | no | +49 1733281570 |
| Resume/CV | `resume` | yes | `lebenslauf.pdf` |
| Cover Letter | `cover_letter` | no | `anschreiben.pdf` (this posting does expose the field) |
| LinkedIn | `question_60922172` | no | https://linkedin.com/in/mattji |
| Website | `question_60922173` | no | https://www.bountystash.com |
| Own words only, no AI or generated content | `question_60922174` | yes | **Hold.** This packet was drafted with AI assistance. Matt must review and rewrite the free-text answers in his own words before selecting Yes; a false Yes is a disqualification on Canonical's own terms. |
| Mathematics at high school | `question_60922175` | yes | **Cannot recall — PROVISIONAL** |
| Native language at high school | `question_60922176` | yes | **Cannot recall — PROVISIONAL** |
| Rationale for the two selections | `question_60922177` | yes | No class rank, SAT or ACT score on file, so "cannot recall" rather than an undocumented band. Verifiable record: 3.2/4.0 GPA in Petroleum Engineering at Colorado School of Mines (2010, calculus-bearing curriculum) and M.Sc. Renewable Energy Management at Freiburg (1.8/5.0 German scale, 1.0 best) with a neural-network thesis. Replace both selections and this rationale if Matt supplies a rank or a test score. |
| Bachelor's degree result | `question_60922178` | yes | `3.2/4.0 GPA (US 4.0 scale) — Bachelor of Science, Petroleum Engineering, Colorado School of Mines, 2010`. Master's, if wanted in the same box: `1.8/5.0 (German scale, 1.0 best) — M.Sc. Renewable Energy Management, University of Freiburg, 2014`. No honours classification. |
| Comfortable on own Ubuntu computer | `question_60922179` | yes | Yes — Linux is the daily driver (NixOS); Ubuntu and Debian are used and debugged as systems, not claimed as a maintained platform. |
| Build automation and/or packaging | `question_60922180` | no | **Free text, see below** |
| Kernel mainline or other OSS contribution links | `question_60922182` | no | **Free text, see below** — links only, with the absence of kernel commits stated |
| 2–4 in-person sprints a year, 1–2 weeks, international travel | `question_60922183` | yes | Yes |
| Website (duplicate field) | `question_60922184` | no | https://www.bountystash.com |
| LinkedIn (duplicate field) | `question_60922185` | no | https://linkedin.com/in/mattji |
| Recruitment privacy notice | `question_60922186` | yes | Read, then acknowledge |
| Country you currently work in | `question_60922187` | yes | Germany |
| Companies worked for in the past ten years | `question_60922188` | yes | **2** — O3 Energy (2016–2020) and Bountystash (2020–2025, own company; EWE and Landvest were contracting under it) |
| Gender | `question_60922189` | yes | Prefer not to say |
| Nationality | `question_65030206[]` | yes | American |
| Race or ethnicity | `question_65030245` | yes | Prefer not to say |

## Free-text answers staged for the form

**Build automation and packaging** (`question_60922180`).

One Nix flake declares thirteen Linux hosts: kernel track per machine, generated configuration, module packages and parameters,
secrets, services and the network. Builds are hermetic — pinned sources, no network at build time, hashed outputs — so the same
commit produces the same kernel and the same system, and a configuration change is a reviewable diff rather than an edit on a
host. Three deviations from the default track are documented beside their reason: 6.12 LTS where legacy NVIDIA modules require
it, an LTS pin on a machine whose newest kernel could not mount root, and a fallback chain for the day a track leaves the
package set. Delivery is gated: one module check runs identically on a laptop, in CI and on the target host, a canary guest
boots the new kernel before production does, and rollback is a pointer. The automation around it is Python and Go behind a task
surface with named arguments, validation, dry runs and JSON output, plus CLI tools over REST APIs. Packaging is Nix —
content-addressed, explicit dependencies, no build-time network. The gap: no Debian source packages, `debhelper`, PPAs, SRUs or
Snapcraft work; apt and dpkg from the consumer and debugger side.

**Kernel and open-source contributions** (`question_60922182`).

https://github.com/shaoyanji/nixconfig · https://github.com/shaoyanji/bountystash ·
https://github.com/shaoyanji/fibtransponder . Public, documented, but not kernel commits: no patch has been sent to mainline and
none is claimed. The kernel work is at the distribution layer — track selection and pinning, configuration, out-of-tree module
packages, initrd and boot parameters. fibtransponder is the honest example of method: a corpus benchmark falsified the first
detector design and the claim was narrowed rather than defended.

**Salary expectation.** Canonical publishes no band and this form has no salary field. Six-figure EUR expectation to be
established at the first call; do not invent a number on the form.

## Before applying

1. Berlin is irrelevant here — the role is home based in EMEA, so Germany is directly eligible; the letter says so.
2. The own-words attestation is the blocker: rewrite the two free-text answers in Matt's own voice, then select Yes.
3. Two high-school questions remain the only unsupported answers; supply a rank or test score to replace "cannot recall".
4. Link the two PDFs, confirm the parser reads name, email and phone, then submit through Greenhouse `7334725`.
5. If a screen happens, lead with the build-as-artefact argument and name the `kbuild`/Yocto gap before it is asked about.
