---
name: iventoy
description: "Manage PXE network boot, ISO image library, and bare-metal installs via iVentoy on frieren."
version: 0.1.0
author: Shaoyan Ji (shaoyanji), Hermes Agent
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: ['iventoy', 'pxe', 'iso', 'boot', 'dhcp', 'frieren']
    related_skills: ['infra', 'checks', 'data']
---

# `iventoy` — PXE Network Boot & Bare-Metal OS Provisioning Runbook

Operational runbook and administration guide for `iVentoy`, the bare-metal network boot server running on `frieren.lan` that serves the `/Volumes/data/isos` collection over the local network.

---

## 1. System Overview & Architecture

* **Host:** `frieren.lan` (`192.168.3.25`).
* **Service Definition:** `modules/services/iventoy.nix`.
* **Systemd Unit:** `iventoy.service` (runs as a systemd service managing `/srv/iventoy/iventoy.sh -R start`).
* **ISO Collection Root:** `/Volumes/data/isos` (symlinked to `/srv/iventoy/iso`).
* **Runtime Directory:** `/srv/iventoy` (persisted config in `data/iventoy.dat`, logs in `log/log.txt`).
* **Network Mode:** **ProxyNet (External DHCP)**:
  * The main router (`192.168.3.1`) remains the sole DHCP server leasing IP addresses.
  * iVentoy listens on UDP 67/69/4011 in ProxyDHCP mode, answering PXE requests with `next-server` and bootfile options without competing with the router's leases.
  * Fast streaming of ISO payloads occurs over HTTP on port `16000`.

---

## 2. Port & Firewall Layout

| Protocol | Port | Service | Purpose |
| :--- | :--- | :--- | :--- |
| **TCP** | `26000` | Web UI | iVentoy Web Management Interface (`http://frieren.lan:26000`) |
| **TCP** | `16000` | HTTP Streaming | High-speed PXE HTTP booting for kernels and initramfs |
| **UDP** | `67` | DHCP-Proxy | Listens for DHCP discover packets from PXE clients |
| **UDP** | `69` | TFTP | Initial bootstrap PXE NBP loader transfer |
| **UDP** | `4011` | ProxyDHCP | Responds to legacy BIOS and UEFI PXE requests |

---

## 3. Web Management UI & Configuration

Access the web interface from any machine on the LAN:
* **URL:** `http://frieren.lan:26000` or `http://192.168.3.25:26000`

### Initial / Persistent Configuration
Settings are saved to `/srv/iventoy/data/iventoy.dat`. The `-R` startup flag automatically restores them on boot:
1. **DHCP Server Mode:** Must be set to **`ProxyNet`** (indicates iVentoy runs on Linux while router DHCP runs externally).
2. **Server IP:** `192.168.3.25` on interface `enp1s0`.
3. **Status:** The green **Start** button must be active.

---

## 4. Managing ISO Images

All bootable images reside in `/Volumes/data/isos`:

### A. Directory Structure & Organization
```
/Volumes/data/isos/
├── appliances/      # Appliance installers & utilities
├── arch/            # Arch Linux ISOs
├── debian/          # Debian & Ubuntu installers
├── fedora/          # Fedora & Red Hat ISOs
├── nixos/           # NixOS minimal & graphical installer images
├── rescue/          # Clonezilla, SystemRescue, GParted
└── windows/         # Windows 10/11 installation media
```

### B. Adding a New ISO
1. Download or copy the ISO image directly into `/Volumes/data/isos/`:
   ```bash
   cd /Volumes/data/isos/nixos/
   curl -LO https://channels.nixos.org/nixos-26.11/latest-nixos-gnome-x86_64-linux.iso
   ```
2. Open the Web UI at `http://frieren.lan:26000` -> **Image Management** -> click **Refresh**.
3. The new ISO is immediately available in the network boot menu.

---

## 5. Booting Client Machines Over PXE

To install or recover any machine on the LAN (`scratch`, `stark`, `eisen`, `kellerbench`, etc.):

1. Connect the client device to the local Ethernet network (`192.168.3.0/24`).
2. Power on the client device and enter the boot menu (`F12`, `F11`, `F8`, or `Del` depending on firmware).
3. Select **Network Boot** / **PXE Boot** (UEFI IPv4 or Legacy PXE).
4. The client will acquire an IP from the router, receive boot options from `frieren`, load the iVentoy menu over TFTP/HTTP, and display the ISO selector.
5. Choose an ISO to boot into memory or begin installation.

---

## 6. Service Management & Health Checks

### Check Status & Listeners
```bash
# Check systemd service
systemctl status iventoy

# Verify active listeners
ss -tulpn | grep -E ':(16000|26000|67|69|4011)'

# Test web management UI
curl -sI http://127.0.0.1:26000/ | head -n 1
```

### Restarting the Daemon
```bash
sudo systemctl restart iventoy
```

### Reading Service Logs
```bash
sudo tail -n 50 /srv/iventoy/log/log.txt
```
