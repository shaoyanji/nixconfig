---
name: simplex-admin
description: >-
  Declarative administration, WebSocket JSON-RPC automation, and inter-agent coordination
  for SimpleX Chat across the NixOS fleet. Use to manage daemon lifecycle, inspect group state,
  issue invitations, and route encrypted messages between autonomous host agents and human users.
version: 0.1.0
platforms: [linux]
---

# SimpleX admin skill

Declarative fleet administration and inter-agent communication protocol powered by **SimpleX Chat**.

SimpleX Chat is an asynchronous, privacy-preserving messaging protocol that uses unilateral message queues (SMP protocol) without user identifiers, phone numbers, or central servers. In this fleet it is the zero-trust bus between autonomous host agents (`frieren`/Hermes, `guckloch`/Antigravity, future node agents) and human users (`devji`).

## Architecture & fleet topology

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

## Declarative NixOS setup

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

### 2. Hermes user service daemon

The option is `programs.hermes-user` in `modules/user/ai/hermes-user.nix`; the
values frieren sets (gateway, simplex daemon, env file) are in
`hosts/frieren/configuration.nix`. Read the option, not a copy of it — a pasted
block is a block that drifts, and `checks:policies#services-live-in-modules`
rejects one.

---

## Hermes agent integration & environment configuration

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

## WebSocket JSON-RPC protocol

When `simplex-chat -p <port>` is running, clients communicate over a WebSocket connection using JSON frames:

### Request frame
```json
{
  "corrId": "req-1",
  "cmd": "/members #Fleet"
}
```

### Response frame
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

### Key daemon commands
* `/groups`: List known groups.
* `/members #<group>`: Inspect members and connection states.
* `#<group> <message>`: Send a message to a group.
* `@<contact> <message>`: Send a direct message to a contact.
* `/create link #<group> member`: Generate an invite link for an agent or user to join.
* `/connect <invitation_link>`: Accept a direct or group invitation.
* `/chats`: List recent conversations and unread status.

---

## Inter-Agent communication (`simplex-rpc.py`)

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

### Headless CLI mode (without daemon port)
On nodes running the standalone client without an open WebSocket port, use the `-e` flag:
```bash
simplex-chat -e "#Fleet guckloch ready for pair-programming."
```

---

## Adding future host agents

To onboard a new host agent (e.g. `nas`, `serv00`, `air`):
1. **Include Package**: Add `simplex-chat` and `python3.withPackages [ websockets ]` to the host's configuration.
2. **Initialize Profile**: Run `simplex-chat -e "/profile <hostname>"` once to create the local DB (`~/.simplex`).
3. **Generate Group Invite**: On `frieren`, run `simplex-rpc.py "/create link #Fleet member"` to get an SMP invite link.
4. **Join Group**: On the new host, run `simplex-chat -e "/c <invite_link>"`.
5. **Update Hermes Allowlist**: Add the new hostname or memberId to `SIMPLEX_ALLOWED_USERS` in `~/.hermes/.env` on `frieren`.

---

## Self-hosted private SMP server (`smp-server`)

To eliminate reliance on public relays (`smp5.simplex.im`, etc.), the fleet runs a dedicated private SMP message broker on `frieren` via `modules/services/simplex-smp-server.nix`.

### 1. Declarative NixOS Service

`modules/services/simplex-smp-server.nix` is the option surface (`ip`,
`tailscaleIp`, `port`, `openFirewall`); `hosts/frieren/configuration.nix` is the
caller that sets them. Read the option rather than copying a block that drifts.

### 2. Trust is the fingerprint, and the URI carries both addresses

SimpleX pins an ED25519 public key inside the URI
(`smp://<ED25519_FINGERPRINT>@<HOST>:<PORT>`), so no CA and no reverse proxy sits
in front of `smp-server`: `smp-server init` writes the self-signed CA, the server
certificate and the base64 fingerprint under `/etc/opt/simplex/`, and a client
compares the TLS handshake against that fingerprint directly. Comma-separated
hosts give one URI for both networks, and `hosts/frieren/firewall-scope.nix`
permits `5223` on `enp1s0`, `wlp2s0` and `tailscale0`:

```bash
cat /etc/opt/simplex/fingerprint
simplex-chat --server "smp://<FINGERPRINT>@<lan-ip>:5223,<tailnet-ip>:5223"
```

The same URI is what a mobile client adds under Settings → Network & Servers →
SMP Servers. The addresses are the module's options; do not copy them from here.

