---
name: paste
description: "Share files, command outputs, and code across fleet hosts via pb (paste.frieren.lan)."
version: 0.1.0
author: Shaoyan Ji (shaoyanji), Hermes Agent
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: ['paste', 'pb', 'frieren', 'share', 'logs']
    related_skills: ['infra', 'checks']
---

# `paste` — Fleet Pastebin (`pb`) Runbook

Operational runbook and command reference for `pb`, the zero-configuration private fleet pastebin hosted on `frieren.lan` and served at `http://paste.frieren.lan`.

---

## 1. System Overview & Architecture

* **Host:** `frieren.lan` (`192.168.3.25`, Tailscale `100.97.61.65`).
* **Module Definition:** Declaratively declared in `modules/services/paste.nix`.
* **CLI Wrapper:** Installed to `~/.local/bin/pb` via Home Manager.
* **Storage Location:** `/var/lib/paste` on `frieren` (owned by `devji:users`, mode `0755`).
* **Web Endpoint:** `http://paste.frieren.lan/<name>` (served via Nginx port 80).
* **Network Scope:** LAN (`192.168.3.0/24`) and Tailscale mesh. No external public exposure.
* **Retention & Cleanup:** Pastes automatically expire and are purged after **30 days** via systemd-tmpfiles (`e /var/lib/paste - - - 30d`).
* **Security & Privacy:** Unauthenticated read access within LAN/mesh. Directory autoindex is disabled (`autoindex off`) so paste URLs cannot be enumerated.

---

## 2. CLI Usage (`pb`)

The `pb` command is installed across the fleet. It streams files or piped standard input over SSH directly to `frieren`.

### A. Pipe Command Output (Piped stdin)
```bash
# Upload journal logs
journalctl -u nginx -n 100 --no-pager | pb

# Upload system diagnostic or dmesg
dmesg -T | pb

# Upload command output
nix eval .#nixosConfigurations.frieren.config.networking.hostName | pb
```
*Output:* Prints the generated URL (e.g. `http://paste.frieren.lan/a1b2c3d4`) and copies it to the system clipboard (via `wl-copy` or `xclip` if available).

### B. Upload a File
```bash
pb build.log
pb /tmp/trace.json
```

### C. Upload with a Specific Custom Name
```bash
# Set a custom name (preserves file extension for proper browser rendering)
pb /tmp/summary.txt audit-2026-10-08.txt

# Or pipe stdin with a custom name
cat /etc/nginx/nginx.conf | pb - nginx-frieren.conf
```

### D. List Active Pastes
```bash
pb list
```
Displays all currently stored files in `/var/lib/paste` sorted by modification time.

### E. Delete a Paste
```bash
pb rm a1b2c3d4
pb rm audit-2026-10-08.txt
```

### F. Query URL for an Existing Name
```bash
pb url a1b2c3d4
# Outputs: http://paste.frieren.lan/a1b2c3d4
```

---

## 3. Remote Fleet Usage

The same `pb` utility works from any fleet machine (`netbook`, `poseidon`, `eisen`, `cassini`) that has SSH access to `frieren`.

### Configuration via Environment Variables

| Variable | Default Value | Description |
| :--- | :--- | :--- |
| `PASTE_SSH_TARGET` | `devji@192.168.3.25` | SSH target for uploads (can be set to `devji@frieren-ts` or `devji@100.97.61.65`) |
| `PASTE_BASE_URL` | `http://paste.frieren.lan` | Base URL printed by `pb` |

### Example: Running from Off-LAN or Remote Machine over Tailscale
```bash
export PASTE_SSH_TARGET="devji@100.97.61.65"
cat /var/log/syslog | pb
```

---

## 4. Web Viewing & Formats

* **Plain Text:** Files without extensions default to `Content-Type: text/plain; charset=utf-8`.
* **Markdown / Code:** Files named with `.md`, `.json`, `.py`, `.nix`, `.diff`, `.patch` preserve their extension and can be rendered or downloaded directly by browsers or `curl`.
* **Retrieving Pastes via CLI:**
  ```bash
  curl -s http://paste.frieren.lan/a1b2c3d4
  ```

---

## 5. Security & Hygiene Rules

1. **LAN / Mesh Only:** Never assume end-to-end encryption. Any machine on the local LAN or Tailscale can view a paste if they know or guess the URL.
2. **Never Paste Secrets:**
   * Do NOT paste `~/.config/sops/age/keys.txt` or age private keys.
   * Do NOT paste decrypted SOPS secret files or API keys.
   * Do NOT paste SSH private keys or session tokens.
3. **Large Binary Files:** Use `/Volumes/data` storage or NAS client mounts instead of `pb` for files > 100 MB.
