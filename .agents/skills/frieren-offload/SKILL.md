---
name: frieren-offload
description: "Offload heavy agy tasks from netbook to frieren."
version: 0.1.0
author: Shaoyan Ji (shaoyanji), Hermes Agent
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: ['frieren', 'offload', 'agy']
    related_skills: []
---

# Frieren Offload Runbook (Antigravity Remote Delegation)

Operational runbook and tooling for delegating heavy, memory-intensive, or long-running Antigravity (`agy`) agent workloads from host `netbook` to `frieren.lan`.

---

## 1. Context & Motivation

* **Local Host (`netbook`):**
  * Hardware: Intel Celeron N3060 (2 cores, 1.6–2.4 GHz), 1.8 GiB RAM.
  * Storage: 24 GB eMMC (~11 GB free).
  * Role: Ultra-lightweight, battery-efficient Wayland terminal client.
  * Limitations: Compiling large codebases, indexing massive archives (e.g. 50 GB Wikipedia ZIM dumps), running containerized builds, or long-running agent loops will exhaust memory or storage and throttle the machine.

* **Remote Host (`frieren.lan`):**
  * Hardware: Multi-core x86_64 workstation / server.
  * Storage: >860 GiB available on `/home/devji`.
  * Role: Always-on high-compute host.
  * Installed Tooling: `agy` (v1.2.9), `uv`, `nix`, `aria2c`, `tmux`.

**Key Benefit:** Decoupled execution. Once dispatched, the netbook lid can be closed or disconnected without interrupting the remote agent.

---

## 2. Network & Authentication

SSH connection details are pre-configured in `~/.ssh/config`:

```sshconfig
Host frieren.lan frieren
    HostName 192.168.3.25
    User devji

Host frieren-ts
    HostName 100.97.61.65
    User devji
```

* **Local LAN:** `frieren.lan` (`192.168.3.25`).
* **Tailscale Fallback:** `frieren-ts` (`100.97.61.65`).
* **Remote User:** `devji`.
* **Auth:** Passwordless Ed25519 key authentication.

Quick connectivity test:
```bash
ssh frieren.lan "hostname; whoami"
```

---

## 3. The `agy-offload` CLI Utility

A helper tool is available in `~/.local/bin/agy-offload` (source: `scripts/agy-offload`):

| Subcommand | Description | Example |
| :--- | :--- | :--- |
| `start` | Dispatch a task inside a detached `tmux` session on `frieren` | `agy-offload start wiki-task ~/wikipedia-offline HANDOFF.md` |
| `status` | List running `agy` processes and `tmux` sessions on `frieren` | `agy-offload status` |
| `logs` | Tail or view the remote `agy.log` | `agy-offload logs ~/wikipedia-offline -f` |
| `attach` | Interactively connect to the remote `tmux` session | `agy-offload attach wiki-task` |
| `kill` | Terminate a remote session | `agy-offload kill wiki-task` |
| `pull` | Rsync finished files from `frieren` back to `netbook` | `agy-offload pull ~/wikipedia-offline/output ./local-dir` |

---

## 4. End-to-End Offloading Workflow

### Step 1: Draft the `HANDOFF.md`
Create a markdown task specification containing:
1. **Background & Constraints:** Why the task is being offloaded and available resources.
2. **Clear Objectives:** Specific deliverables, files to generate, or services to configure.
3. **Execution Steps:** Concrete shell commands, tools to install via Nix, or APIs to use.
4. **Verification Criteria:** Exact test commands to verify completion.

### Step 2: Dispatch the Remote Agent
Run `agy-offload start`:
```bash
agy-offload start <session_name> <remote_workdir> <path_to_HANDOFF.md>
```
What this does under the hood:
1. Creates the target directory on `frieren.lan` via SSH.
2. Securely copies `HANDOFF.md` into the remote directory.
3. Creates an isolated executable runner (`run.sh`) that calls `agy --dangerously-skip-permissions -p "..."` and tees output to `agy.log`.
4. Launches the runner inside a persistent, detached `tmux` session named `<session_name>`.

### Step 3: Verify and Disconnect
Check that the agent is running:
```bash
agy-offload status
```
Inspect initial output:
```bash
agy-offload logs <remote_workdir>
```
At this point, **the netbook can safely be closed or suspended.**

### Step 4: Check Progress & Pull Artifacts
When reconnecting:
```bash
# Stream live logs
agy-offload logs <remote_workdir> -f

# If interactive input is needed, attach to the tmux session
agy-offload attach <session_name>

# Once complete, sync output back to the netbook
agy-offload pull <remote_workdir>/results/ ./local-results/
```

---

## 5. Low-Level Protocol (Manual Execution)

If `agy-offload` is unavailable, execute the steps manually:

```bash
# 1. Create directory and transfer handoff
ssh frieren.lan "mkdir -p ~/task-dir"
scp HANDOFF.md frieren.lan:~/task-dir/HANDOFF.md

# 2. Create the execution wrapper
ssh frieren.lan "cat << 'EOF' > ~/task-dir/run.sh
#!/usr/bin/env bash
cd ~/task-dir
echo '=== Starting agy at \$(date) ===' >> agy.log
agy --dangerously-skip-permissions -p 'Read HANDOFF.md and execute the plan.' 2>&1 | tee -a agy.log
echo '=== Completed at \$(date) ===' >> agy.log
EOF
chmod +x ~/task-dir/run.sh"

# 3. Launch inside detached tmux
ssh frieren.lan "tmux new-session -d -s task-session ~/task-dir/run.sh"

# 4. Monitor
ssh frieren.lan "tail -f ~/task-dir/agy.log"
```

---

## 6. Best Practices

* **Always use `--dangerously-skip-permissions`:** Remote detached sessions have no TTY for interactive confirmation prompts. Any unapproved tool call would otherwise block execution indefinitely.
* **Always run in `tmux`:** Running commands over raw SSH will terminate when the netbook closes or WiFi drops. `tmux` ensures persistence on `frieren`.
* **Separate Task Directories:** Always give each offloaded job its own distinct directory (e.g. `~/wikipedia-offline`, `~/kernel-build`) so multiple agent jobs do not clobber `HANDOFF.md` or `agy.log`.

---

## 7. Nightly Autonomous Execution (3:00 AM & 5:00 AM Systemd Services)

`frieren.lan` is configured with two persistent systemd user timers that automate overnight task and system management:

### A. 3:00 AM Task Runner (`HANDOFF.md`)
* **Timer:** `agy-nightly-handoff.timer` (`*-*-* 03:00:00`)
* **File:** `/home/devji/HANDOFF.md`
* **Workflow:**
  1. Checks if `/home/devji/HANDOFF.md` exists. If missing, exits immediately with code 0.
  2. Archives a copy to `/home/devji/.agents/handoffs/HANDOFF-<timestamp>.md`.
  3. Executes `agy --dangerously-skip-permissions -p "Please read HANDOFF.md in the current working directory and execute the plan."`.
  4. Deletes `/home/devji/HANDOFF.md` upon completion.
* **Usage:**
  ```bash
  scp HANDOFF.md frieren.lan:~/HANDOFF.md
  ```

### B. 5:00 AM System Maintenance Runner (`SYSTEM.md`)
* **Timer:** `agy-nightly-system.timer` (`*-*-* 05:00:00`)
* **File:** `/home/devji/SYSTEM.md`
* **Workflow:**
  1. Checks if `/home/devji/SYSTEM.md` exists. If missing, exits immediately with code 0.
  2. Archives a copy to `/home/devji/.agents/system/SYSTEM-<timestamp>.md`.
  3. Executes `agy --dangerously-skip-permissions -p "Please read SYSTEM.md in the current working directory and execute the plan."`.
  4. Deletes `/home/devji/SYSTEM.md` upon completion.
* **Usage:**
  ```bash
  scp SYSTEM.md frieren.lan:~/SYSTEM.md
  ```

### C. Monitoring & Verification
```bash
# Check scheduled timers
ssh frieren.lan "systemctl --user list-timers 'agy-nightly-*'"

# View logs for either service
ssh frieren.lan "journalctl --user -u agy-nightly-handoff.service -n 30 --no-pager"
ssh frieren.lan "journalctl --user -u agy-nightly-system.service -n 30 --no-pager"

# View archived copies
ssh frieren.lan "ls -la ~/.agents/handoffs/ ~/.agents/system/"
```
