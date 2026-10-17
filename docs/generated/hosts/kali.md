# kali

> **Generated — do not edit.** Built from `inventory.toml` by `lib/docs.nix`
> (`nix build .#docs`). Refresh the checked-in copy with `task docs:sync`.


| field | value |
| --- | --- |
| role | Mobile Offensive Security Starter Pack |
| status | active — In active production as a mobile offensive security and penetration testing toolkit. |
| kind / arch | home / aarch64-linux |
| flake output | true |
| managed | false |
| in CI | false |
| hardware | Raspberry Pi 4 / OnePlus 6 NetHunter Pro (Chroot) |
| cpu | ARM64 (Cortex-A53 / Snapdragon 845) |
| gpu | Adreno / VideoCore |
| ram | 2 to 4 GB |
| storage | Tight mobile flash storage (/home/kali) |
| persona | Offensive Security & Pen-Testing Operative (tier: specialized-cli) |
| persona hint | You are a tactical mobile penetration tester and network discovery operative. Heavy desktop tools are omitted in favor of fast, async CLI tools. |

## Module chain

`globalModulesHome`

## Traits

- traits:
  - offensive-security
  - pen-testing
  - mobile-arm64
  - nethunter-pro

## Key services

- services:
  - Nushell + Starship
  - Recon: nmap, rustscan, arp-scan
  - Web Testing: gobuster, ffuf, sqlmap, nikto
  - Wireless: aircrack-ng, wifite2, bettercap

## Allowed tasks

- tasks:
  - Network port scanning & enumeration (nmap, rustscan)
  - Web application fuzzing & testing (gobuster, ffuf, sqlmap)
  - Wireless security auditing (aircrack-ng, bettercap)
  - Security telemetry logging

## Constraints

- constraint:
  - Mobile storage is tight; avoid installing heavy desktop tools (Ghidra, Burp, Metasploit).
  - All tools must build cleanly on aarch64-linux.
