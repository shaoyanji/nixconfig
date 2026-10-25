# Services in a microVM

delphi · aarch64-linux · NixOS

`ssh slides@delphi.bountystash.com` · `ssh -p 2222 slides@delphi.cloudforest-kardashev.ts.net`

The public name is port 22: the host's sshd authenticates a fleet key, then hops
into this guest. The tailnet name is the guest directly, on 2222.

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
- Stirling PDF (`:8082`), proxied at `/microvm/stirling/` — tailnet only, because
  it holds documents a public vhost has no business answering for.
- Three state volumes; Stirling's is in use, the other two wait for their service:

| volume | mount | size |
| :--- | :--- | :--- |
| `hermes` | `/var/lib/hermes` | 1 GiB |
| `stirling` | `/var/lib/stirling-pdf` | 4 GiB |

---

## Persistence without imperative work

- Each volume is an ext4 image on the host, labelled, mounted by the guest.
- A service's `StateDirectory` lands on it and keeps its uid, because the
  filesystem belongs to the guest.
- Restart the guest: state is still there. Delete the image: state is gone.

---

## Service Placement (Lane Decisions)

- DeepSeek Harness (`dsh-web`) is pinned to the **Native Host Lane**: running an active
  interactive coding agent inside QEMU TCG software emulation on OCI A1 incurs massive
  interpreted CPU overhead on the 2 OCPU budget. Native bare-metal execution protects latency.
- Stirling PDF is pinned to the **MicroVM Guest Lane**: passive JVM document processing
  with isolated temp directories and no continuous CPU footprint.
- Raise the guest's RAM as the service set grows; the ceiling for this host is
  8 GiB, and it must stay under what the hypervisor needs to serve.
- Keep the deck: `slides` is the cheapest way to explain a change to a person
  who only has a terminal.
