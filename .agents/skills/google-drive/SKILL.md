---
name: google-drive
description: Use when setting up or troubleshooting Google Drive access via rclone on frieren. Covers OAuth flow, tailscale funnel, verification code, and token refresh.
version: 0.1.0
author: Shaoyan Ji
platforms: [linux]
---

# Google Drive Skill

## Setup

1. Create Google Cloud project with OAuth credentials (client_id, client_secret)
2. Configure rclone: `rclone config create gdrive drive client_id <id> client_secret <secret>`
3. Authorize via tailscale funnel: `tailscale funnel 53682`
4. Visit `https://<host>.ts.net/auth?state=<state>` and authorize
5. Paste verification code back

## Workflow

1. Start rclone auth: `rclone authorize drive > /tmp/rclone-auth.txt 2>&1 &`
2. Check status: `ss -tlnp | grep 53682`
3. Access via tailscale: `https://frieren.cloudforest-kardashev.ts.net/auth?state=<state>`
4. Verify: `rclone lsd gdrive:`

## Token Refresh

If token expires, re-auth with `rclone config reconnect gdrive:` and repeat the OAuth flow.

## Troubleshooting

- Port 53682 already in use: kill existing rclone process
- Auth state mismatch: use the current state from the running server
- Token expired: re-auth with new verification code
- tailscale funnel not working: check `tailscale funnel status --json`
