# Services in a microVM

delphi · aarch64-linux · NixOS

`ssh -p 2222 slides@delphi.bountystash.com`

---

## What you are looking at

- A guest, not a container: it boots its own kernel and root.
- One host, one bridge (`brlan`, 192.168.83.0/24), one guest address (192.168.83.11).
- This deck is a store path mounted read-only over virtiofs. Editing it means
  editing the repo, not the guest.

---

## Why a guest for services

- Sandboxing: a ported service cannot reach the LAN, the tailnet, or the host's
  secrets — only the NAT out of `192.168.83.1`.
- Teardown: `systemctl stop microvm@sandbox` stops everything at once.
- Boot cost: a TCG guest here takes minutes, so fleet-critical monitors stay on
  the hypervisor and only applications move in.

---

## What lives in the guest today

- Two stub HTTP services (`:8080`, `:8081`), proxied at
  `/microvm/one/` and `/microvm/two/` on both hostnames.
- Three empty state volumes, waiting for the services they are named after:

| volume | mount | size |
| :--- | :--- | :--- |
| `hermes` | `/var/lib/hermes` | 1 GiB |
| `stirling` | `/var/lib/stirling` | 2 GiB |
| `dsh` | `/var/lib/deepseek-harness` | 1 GiB |

---

## Persistence without imperative work

- Each volume is an ext4 image on the host, labelled, mounted by the guest.
- A service's `StateDirectory` lands on it and keeps its uid, because the
  filesystem belongs to the guest.
- Restart the guest: state is still there. Delete the image: state is gone.

---

## Next

- Port Stirling PDF, then the DeepSeek harness, then hermes — one service per
  switch, each behind its own `/microvm/<name>/` proxy.
- Raise the guest's RAM as the service set grows; the ceiling for this host is
  8 GiB, and it must stay under what the hypervisor needs to serve.
- Keep the deck: `slides` is the cheapest way to explain a change to a person
  who only has a terminal.
