---
name: google-drive
description: "Google Drive on any host through rclone: one script runs the OAuth handshake (with an optional tailscale funnel for a browser elsewhere), or verifies the existing remote and its quota. Covers dead tokens and reconnect."
version: 0.2.0
author: Shaoyan Ji
platforms: [linux]
metadata:
  hermes:
    tags: [rclone, google-drive, oauth, tailscale-funnel]
    related_skills: [infra]
---

# google-drive

`scripts/drive-auth.sh` is the procedure; this page is what each step is for.

```bash
scripts/drive-auth.sh verify                        # quota + top-level dirs; fails on a dead token
scripts/drive-auth.sh auth                          # handshake; prints the URL to open
scripts/drive-auth.sh auth --funnel                 # same, but expose the callback on the tailnet
scripts/drive-auth.sh stop-funnel                   # tear down a funnel left behind
```

Client id and secret come from `GDRIVE_CLIENT_ID`/`GDRIVE_CLIENT_SECRET`, else
from the sops plane (`googleDrive/clientId`, `googleDrive/clientSecret` — the
same pair the calendar/vdirsyncer setup reads).

## Why a script and not five commands

The handshake is mechanical but stateful, and every hand-copied version gets one
of these wrong:

- `rclone authorize` prints a **loopback** URL (`http://127.0.0.1:53682/auth?state=…`).
  On a headless host that URL is useless to a browser on your laptop, and the
  `state` is bound to that process — copy the URL from an old terminal and you
  get a state mismatch.
- `--auth-no-open-browser` is mandatory headless; without it rclone waits on a
  browser that will never exist.
- The token only exists in the process's stdout after consent, so the script has
  to capture the process output and turn it into `rclone config create … token`.

With `--funnel`, the script exposes exactly the authorize port, rewrites the URL
to the tailnet name, and **tears the funnel down on exit** — including Ctrl-C.
Funnels are public ingress; one left on is an exposure, not a leftover.

## When the token dies

`verify` fails with rclone's own words (`invalid_grant`, `token expired`). Fix it
per remote, not by rewriting config:

```bash
rclone config reconnect gdrive:      # re-runs the handshake for an existing remote
scripts/drive-auth.sh verify         # proves it before anything mounts
```

`drive-auth.sh auth` deliberately refuses to touch an existing remote unless
`--force`, so a reconnect can never silently replace a working token.

## Troubleshooting

- **Port 53682 busy:** another `rclone authorize` is still alive. `pgrep -af "rclone authorize"`, then kill it — the port is fixed, and the state is per-process.
- **State mismatch:** you opened a URL from a previous run. Use the one the script just printed.
- **Funnel says nothing:** `tailscale funnel status`; HTTPS must be enabled for the tailnet before any funnel can serve.
- **`--funnel` refused on a fresh host:** `tailscale` not installed, or MagicDNS off (the public hostname cannot be built).

Truth: `modules/config/shells/common-packages.nix` (installs rclone) and `modules/sops.nix` (the client pair); this page is the procedure.
