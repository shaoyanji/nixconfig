# HANDOFF.md — Fleet Architecture & Declarative Codebase Handoff

> **Scope:** Multi-Host Declarative Fleet Configuration (`shaoyanji/nixconfig`)  
> **Target Fleet:** `frieren` (NAS / Media Mainframe), `poseidon` (Workstation), `eisen` (Living Room Kiosk), `stark` (AIO Kiosk), `fern`, `scratch`, `guckloch`, `delphi`, `garnixMachine`  
> **Updated:** 2026-10-13 21:15 CEST  
> **Status:** Production Active (NixOS 26.11)

---

## ⚠ Disambiguation of Handoff Documents

To maintain clean separation of concerns across the fleet, two distinct handoff documents exist:

| Document | Location | Authority & Scope | Read/Write Lifecycle |
| :--- | :--- | :--- | :--- |
| **Fleet Architecture Handoff** | `/Volumes/data/projects/nixconfig/HANDOFF.md` *(This file)* | **Declarative Source of Truth.** Tracks git commits, flake inputs, NixOS modules, cross-host configuration, shared profiles, and architectural migrations across the entire fleet. | Edited by human operators and autonomous engineering agents during feature development. Tracked in git (`origin/main`). |
| **Node Runtime Handoff** | `/home/devji/HANDOFF.md` | **Live Host Operational State.** Tracks local machine runtime findings on `frieren` (e.g., active drive sector errors, glibc collation version mismatches, transient service logs, and daily systemd audit findings). | Updated daily by autonomous background services (`agy-nightly-handoff.service`, `agy-nightly-system.service`). Lives on local host filesystem. |

---

## Current Architecture Initiatives & Status

### 1. [x] EXP-102: Ephemeral MicroVM Deployment Sandbox & Model B Service Migration
* **Status:** `PROTOTYPED, VERIFIED & COMMITTED` ([`b11b5e9`](https://github.com/shaoyanji/nixconfig/commit/b11b5e9))
* **Architecture:**
  - `hosts/microvms/frieren-canary.nix`: Lightweight Canary MicroVM running under `cloud-hypervisor` via KVM.
  - Zero-duplication `/nix/store` shared read-only via `virtiofs` with ephemeral writable overlay (`/nix/.rw-store`).
  - Hard resource limits (2 vCPUs, 2048 MB RAM) protecting host stability without daemon polling.
  - Fixed host ed25519 keys (`/var/lib/microvms/frieren-canary/ssh-host-keys`) mounted via virtiofs paired with `/var/lib/microvms/.known_hosts`—0 prompts, 0 collision churn across teardowns.
  - Local bridge networking (`microbr` on `192.168.83.1/24`) with host NAT through `enp1s0`.
  - Hypervisor Nginx dynamically routes `/canary/` and `canary.frieren.lan` over LAN and Tailnet (`100.97.61.65`). Verified 504 on teardown and instant 200 OK recovery on boot.
* **Workflows:** `task vm:canary:build`, `task vm:canary:run`, `task vm:canary:test`.
* **Next Migration Steps (Model B Rollout):**
  - Migrate standalone background services (Kiwix offline library, Gatus monitoring backend, Paperless document queue) into dedicated, bounded MicroVMs.

### 2. [x] EXP-101: Grammar-Constrained JSON Schema Tool Dispatcher for System 2
* **Status:** `INTEGRATED & VERIFIED`
* **Architecture:** Constrains Ollama Nemotron-3 deliberation to a typed JSON schema (`query_system2_schema()`), cutting output tokens by 85% and routing operational primitives through a sandboxed Python allowlist dispatcher (`modules/services/systemone/ensemble.py`).

### 3. [x] EXP-100: Declarative 3-Tier Fleet Governor (`services.fleetGovernor`)
* **Status:** `ACTIVE IN SYSTEMD`
* **Architecture:** Replaced ad-hoc standalone daemon timers with a consolidated 3-tier governor:
  - **S0 (Deterministic Rules):** < 500ms execution, SQLite WAL maintenance, Btrfs capacity checks.
  - **S1 (System 1 Reflex Classifier):** Julia-1 (144M) sub-millisecond triage across 10 service telemetry feeds.
  - **S2 (System 2 Deep Deliberation):** Ollama Nemotron-3-Ultra structured JSON schema reasoning for complex, unresolvable anomalies.

### 4. Ongoing Fleet Maintenance Items
* **DNS Failover:** Secondary resolver hardware node pending declaration in `profiles.dnsFailover.resolvers`.
* **SOPS Secrets Management:** 32 recipient keys synchronized across all 6 SOPS files (`task checks:sops:drift` clean).
* **Nightly Auto-Upgrade Window:** 03:00 - 05:30 nightly backup window strictly observed; all commits pushed to `origin/main`.
