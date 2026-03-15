# OpenClaw on thinsandy

- System gateway is canonical.
- Durable home backing store: `/srv/data/openclaw`.
- Stable path inside system boundary: `/var/lib/openclaw/home`.
- User-level `~/.openclaw` is intentionally not the source of truth.
