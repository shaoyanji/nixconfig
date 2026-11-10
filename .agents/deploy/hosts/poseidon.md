# poseidon runbook

## Tailscale must not take the LAN path

`desktop-client.nix` sets `--accept-routes=true`, so frieren's advertised
`192.168.3.0/24` route lands in table 52 (ip rule 5270) and direct LAN
destinations go over the tailnet instead. Measured 2026-10-23: table 52 carried
`192.168.3.0/24 dev tailscale0`, frieren to poseidon on port 22 timed out, and
tailnet SSH worked. A policy rule preferring table main for the prefix fixed it
instantly. eisen (Steam Link) and fern (LAN SSH) carry the same override.

Dock Ethernet: `.agents/deploy/dock-ethernet.md`.
