---
name: simplex-admin
description: >-
  Declarative administration, WebSocket JSON-RPC automation, and inter-agent coordination
  for SimpleX Chat across the NixOS fleet. Use to manage daemon lifecycle, inspect group state,
  issue invitations, and route encrypted messages between autonomous host agents and human users.
---

# SimpleX Admin Skill

Declarative fleet administration and inter-agent communication protocol powered by **SimpleX Chat**.

SimpleX Chat is an asynchronous, privacy-preserving messaging protocol that uses unilateral message queues (SMP protocol) without user identifiers, phone numbers, or central servers. In the homelab fleet, it serves as the zero-trust communication bus connecting autonomous host agents (`frieren`/Hermes, `guckloch`/Antigravity, future node agents) and human users (`devji`).

## Architecture & Fleet Topology

```text
               ┌────────────────────────────────────────────────────────┐
               │                  SimpleX SMP Relays                   │
               └──────────▲──────────────────▲───────────────────▲──────┘
                          │                  │                   │
                  (Unilateral SMP)   (Unilateral SMP)    (Unilateral SMP)
                          │                  │                   │
                          ▼                  ▼                   ▼
                  ┌───────────────┐  ┌───────────────┐   ┌──────────────┐
                  │ devji (Human) │  │  guckloch     │   │   frieren    │
                  │ SimpleX App   │  │ (Antigravity) │   │ (Hermes Bot) │
                  └───────┬───────┘  └───────┬───────┘   └───────┬──────┘
                          │                  │                   │
                          └──────────► #Fleet ◄──────────────────┘
                                 (Multiplayer Group)
                                         ▲
                                         │
                         frieren Direct Channel: devji (Home)
```

1. **Fleet Group (`#Fleet`)**:
   - A collaborative multiplayer space containing human operator (`devji`) and all active fleet host agents.
   - Allows agents to post status reports, alert on long-running task completions, request operator intervention, or ping peer agents.
2. **Home Channel (`SIMPLEX_HOME_CHANNEL`)**:
   - 1:1 direct connection between Hermes and `devji`.
   - Used for confidential operational summaries, scheduled notifications, and direct instructions where public group context is unnecessary.
3. **Daemon Lifecycle**:
   - `simplex-chat -p 5225`: Local WebSocket JSON-RPC server listening on `127.0.0.1:5225`.
   - Declaratively supervised by Home-Manager via `programs.hermes-user.simplex.daemon = true;` (`simplex-chat.service`).

---

## Declarative NixOS Setup

All dependencies and daemon configurations are defined declaratively in `nixconfig`.

### 1. Host Package & Python Environment
In host tool definitions (e.g. `hosts/frieren/tools.nix`, `hosts/guckloch/configuration.nix`):
```nix
environment.systemPackages = with pkgs; [
  simplex-chat
  (python3.withPackages (ps: with ps; [
    websockets
    requests
    aiohttp
  ]))
];
```

### 2. Hermes User Service Daemon
In `hosts/frieren/configuration.nix`:
```nix
home-manager.users.devji.programs.hermes-user = {
  enable = true;
  gateway.enable = true;
  simplex.daemon = true;  # Generates systemd user service simplex-chat on :5225
  envFile = "/run/secrets/rendered/hermes.env";
};
```

---

## Hermes Agent Integration & Environment Configuration

Reference: [Hermes SimpleX Guide](https://hermes-agent.nousresearch.com/docs/user-guide/messaging/simplex)

Hermes communicates with the SimpleX Chat daemon via WebSocket JSON-RPC. Platform settings are configured via environment variables in `~/.hermes/.env` on the host running Hermes (`frieren`):

| Variable | Required | Description |
| :--- | :--- | :--- |
| `SIMPLEX_WS_URL` | **Yes** | WebSocket URL of the simplex-chat daemon (default: `ws://127.0.0.1:5225`) |
| `SIMPLEX_ALLOWED_USERS` | Recommended | Comma-separated allowlist of numeric `contactId`s. Display names are **not accepted** — any contact can change theirs. |
| `SIMPLEX_ALLOW_ALL_USERS` | Optional | Set `true` to allow every contact (use carefully; default: `false`) |
| `SIMPLEX_AUTO_ACCEPT` | Optional | Auto-accept incoming contact requests (default: `true`) |
| `SIMPLEX_GROUP_ALLOWED` | Optional | Comma-separated group IDs the bot participates in, or `*` for any group. Omit to ignore group messages entirely |
| `SIMPLEX_HOME_CHANNEL` | Optional | Default numeric contact/group ID for cron job delivery and operational alerts |
| `SIMPLEX_HOME_CHANNEL_NAME` | Optional | Human label for the home channel (e.g. `devji`) |
| `HERMES_SIMPLEX_TEXT_BATCH_DELAY` | Optional | Quiet-period seconds (default: `0.8`) used to concatenate rapid-fire inbound text messages into one event |

> [!IMPORTANT]
> SimpleX Chat contacts are identified internally by numeric integer `contactId`s (e.g. `3`), while groups have integer `groupId`s (e.g. `1`). Never use display names in `SIMPLEX_ALLOWED_USERS` or `SIMPLEX_HOME_CHANNEL` as display names are untrusted and mutable by the peer.

---

## WebSocket JSON-RPC Protocol

When `simplex-chat -p <port>` is running, clients communicate over a WebSocket connection using JSON frames:

### Request Frame
```json
{
  "corrId": "req-1",
  "cmd": "/members #Fleet"
}
```

### Response Frame
```json
{
  "corrId": "req-1",
  "resp": {
    "type": "groupMembers",
    "group": { "groupInfo": { "localDisplayName": "Fleet", "groupId": 1 } },
    "members": [ ... ]
  }
}
```

### Key Daemon Commands
* `/groups`: List known groups.
* `/members #<group>`: Inspect members and connection states.
* `#<group> <message>`: Send a message to a group.
* `@<contact> <message>`: Send a direct message to a contact.
* `/create link #<group> member`: Generate an invite link for an agent or user to join.
* `/connect <invitation_link>`: Accept a direct or group invitation.
* `/chats`: List recent conversations and unread status.

---

## Inter-Agent Communication (`simplex-rpc.py`)

A bundled helper script is provided at `scripts/simplex-rpc.py`:

```bash
# Query group membership
python3 scripts/simplex-rpc.py --members "#Fleet"

# Send a message to the group
python3 scripts/simplex-rpc.py --send-group "#Fleet" "guckloch build task completed."

# Send a direct message to a contact
python3 scripts/simplex-rpc.py --send-contact "@frieren" "ping: offloading nixos-rebuild"

# Run arbitrary command
python3 scripts/simplex-rpc.py "/groups"
```

### Headless CLI Mode (Without Daemon Port)
On nodes running the standalone client without an open WebSocket port, use the `-e` flag:
```bash
simplex-chat -e "#Fleet guckloch ready for pair-programming."
```

---

## Adding Future Host Agents

To onboard a new host agent (e.g. `nas`, `serv00`, `air`):
1. **Include Package**: Add `simplex-chat` and `python3.withPackages [ websockets ]` to the host's configuration.
2. **Initialize Profile**: Run `simplex-chat -e "/profile <hostname>"` once to create the local DB (`~/.simplex`).
3. **Generate Group Invite**: On `frieren`, run `simplex-rpc.py "/create link #Fleet member"` to get an SMP invite link.
4. **Join Group**: On the new host, run `simplex-chat -e "/c <invite_link>"`.
5. **Update Hermes Allowlist**: Add the new hostname or memberId to `SIMPLEX_ALLOWED_USERS` in `~/.hermes/.env` on `frieren`.

---

## Self-Hosted Private SMP Server (`smp-server`)

To eliminate reliance on public relays (`smp5.simplex.im`, etc.), the fleet runs a dedicated private SMP message broker on `frieren` via `modules/services/simplex-smp-server.nix`.

### 1. Declarative NixOS Service
In `hosts/frieren/configuration.nix`:
```nix
imports = [
  # ...
  ../../modules/services/simplex-smp-server.nix
];

services.simplex-smp-server = {
  enable = true;
  ip = "192.168.3.25";          # Local LAN address
  tailscaleIp = "100.97.61.65"; # Tailnet address
  port = 5223;                  # Standard SMP TLS port
  openFirewall = true;
};
```

### 2. Native TLS & Fingerprint Pinning (Why Reverse Proxy Is Not Needed)
Unlike web browsers that depend on Web PKI (Let's Encrypt / CA hierarchies), SimpleX Chat verifies relay security using **cryptographic public key pinning embedded directly into the URI**:
```text
smp://<ED25519_FINGERPRINT>@<HOST>:<PORT>
```
* `smp-server init` generates a self-signed ED25519 CA and server certificate in `/etc/opt/simplex/`.
* The server's base64 public key fingerprint is stored in `/etc/opt/simplex/fingerprint`.
* Connecting clients compare the server's TLS handshake directly against this fingerprint.
* **No Caddy/Nginx certificate copying required**: Because the cryptographic trust root is the fingerprint itself, external Let's Encrypt certificates are redundant for SMP protocol traffic and introduce unnecessary failure modes.

### 3. LAN & Tailnet Dual-Addressing
SimpleX Chat supports comma-separated hosts in its server URIs:
```text
smp://<FINGERPRINT>@192.168.3.25:5223,100.97.61.65:5223
```
* **At Home (LAN)**: Clients and fleet agents connect directly to `192.168.3.25:5223` at wire speed with sub-millisecond latency.
* **On the Move (Tailnet)**: Mobile clients and roaming laptops route through Tailscale to `100.97.61.65:5223`.
* **Firewall Scoping**: In `hosts/frieren/firewall-scope.nix`, port `5223` is explicitly permitted on `enp1s0` (wired LAN), `wlp2s0` (wifi LAN), and `tailscale0` (Tailnet).

### 4. Configuring Clients to Use the Private Relay
* **Inspect Server Address**:
  ```bash
  cat /etc/opt/simplex/fingerprint
  # Server URI format:
  # smp://<FINGERPRINT>@192.168.3.25:5223,100.97.61.65:5223
  ```
* **CLI Client / Daemon**:
  Launch with `--server`:
  ```bash
  simplex-chat --server "smp://<FINGERPRINT>@192.168.3.25:5223,100.97.61.65:5223"
  ```
  Or set default in interactive chat:
  ```text
  /set server smp://<FINGERPRINT>@192.168.3.25:5223,100.97.61.65:5223
  ```
* **Mobile SimpleX App**:
  1. Open SimpleX App -> Settings -> Network & Servers -> SMP Servers.
  2. Tap `Add server` and paste the `smp://` URI.
  3. Set as primary server for new invitations and group queues.

