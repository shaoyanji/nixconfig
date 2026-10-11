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
