# eisen — Laya Final Verification Handoff

Close-out checklist for the Laya decision-model deployment (`hosts/eisen/decision-models.nix`),
the last piece of the offline **qwen + laya tandem**. Everything below is a *final check* —
the wiring itself is committed (`29383b4`) and was already proven working on 2026-10-09
when eisen was last up.

**Canonical docs**: [`.agents/deploy/hosts/eisen.md`](../../.agents/deploy/hosts/eisen.md) ·
**Impl**: [`hosts/eisen/decision-models.nix`](./decision-models.nix) ·
**Related**: [`hosts/eisen/HANDOFF.md`](./HANDOFF.md) (LLM + Laya architecture)

> Prerequisite: **eisen must be powered on and reachable** (`ssh -o BatchMode=yes eisen true`).
> It was off at the time this handoff was written, so the runtime checks below could not be
> re-run — treat them as the acceptance gate, not as already-passed.

---

## What to prove

| # | Claim | Why it matters |
| :- | :--- | :--- |
| 1 | Deployed generation carries the Laya config | closes the `outPath` vs `/run/current-system` hash question |
| 2 | `laya-serve` and friends are active | the service survived the last switch |
| 3 | `/v1/systemone` answers correctly on loopback | the model actually loads and decided right |
| 4 | Both exposures answer | tailnet `:8443` and nginx `laya.lan:80` |
| 5 | Qwen on `:443`/`:80` is unregressed | the two do not collide |
| 6 | The bootstrap guard is idempotent | a re-run is a no-op, not a reinstall |

---

## Step 0 — reach the host

```bash
ssh -o BatchMode=yes eisen true && echo REACHABLE
```

## Step 1 — deployed generation really contains Laya (settles the hash question)

The earlier mismatch (`nix eval outPath` ≠ `/run/current-system`) is the clean-vs-dirty
source-tree artifact, **not** config drift — the later commit `3f84739` changed the flake
source tree after the last eisen build. Prove it by content, not by hash:

```bash
ssh eisen 'readlink -f /run/current-system'
ssh eisen 'systemctl cat laya-serve | sed -n "1p;/ExecStart=/p"'
ssh eisen 'grep -rl laya.lan /run/current-system/etc/nginx 2>/dev/null'
ssh eisen 'nixos-rebuild list-generations | tail -3'
```

**Pass**: a `laya-serve.service` unit is present in the running system, an nginx file under
`/run/current-system/etc/nginx` mentions `laya.lan`, and the current generation is the one
from the Laya rebuild. Report the hash difference as *source-tree artifact* in the handoff.

## Step 2 — units active

```bash
ssh eisen 'systemctl is-active laya-serve eisen-laya-bootstrap tailscale-serve-laya tailscale-serve-node nginx llama-swap'
ssh eisen 'systemctl --failed --no-legend'
```

**Pass**: all six report `active`; the **only** failed unit is the pre-existing
`home-manager-devji.service` (user-scope sops-nix, `0 successful groups required, got 0`).
That failure is why `nixos-rebuild switch` exits **4** — the system generation still applies.

## Step 3 — loopback decision call (correctness, not just liveness)

```bash
ssh eisen 'curl -s http://127.0.0.1:8090/v1/systemone -H "Content-Type: application/json" -d "{
  \"state\": {\"document\": \"I was charged twice this month. Please refund the duplicate or I will cancel.\"},
  \"questions\": {
    \"department\": {\"type\": \"choice\", \"instructions\": \"Which department should handle this?\",
                   \"criteria\": {\"billing\": \"invoices, payments, refunds\", \"technical\": \"bugs and errors\"}},
    \"urgency\": {\"type\": \"score\", \"instructions\": \"How urgent is this?\",
                \"criteria\": [\"not urgent\", \"soon\", \"critical deadline or blocking issue\"]},
    \"churn_risk\": {\"type\": \"noul\", \"instructions\": \"Does the user threaten to cancel or leave?\"}
  }}" | jq .'
```

**Pass** (2026-10-09 baseline): HTTP 200 in ~0.43 s warm, `department: billing` (0.975),
`urgency: 1.70` (0.75 on "critical"), `churn_risk: 0.78`. A `usage` block and
`routing.model` must be present.

**Watch for** the benign load warning: `laya: this checkpoint ships invalid temperatures …
Treat confidence from the affected entries as uncalibrated.`

## Step 4 — both exposures

```bash
# tailnet (no MagicDNS — pin the address)
curl -s --resolve eisen.cloudforest-kardashev.ts.net:8443:100.119.172.99 \
  https://eisen.cloudforest-kardashev.ts.net:8443/v1/systemone -o /dev/null -w '%{http_code}\n'

# LAN vhost
curl -s --resolve laya.lan:80:100.119.172.99 http://laya.lan/v1/systemone -o /dev/null -w '%{http_code}\n'

# risky-free path: bind :8443 host still present?
ssh eisen 'tailscale serve status'   # expect :443 -> 8080 and :8443 -> 8090
```

**Pass**: both `200`; `tailscale serve status` shows `:8443 → http://127.0.0.1:8090`
alongside `:443 → 8080`.

> Reminder: `.lan` names do **not** resolve through a host's default resolver (fleet-wide,
> pre-existing, affects `eisen.lan` identically). `--resolve` or the tailnet name is required.

## Step 5 — Qwen unregressed

```bash
curl -s --resolve eisen.cloudforest-kardashev.ts.net:443:100.119.172.99 \
  https://eisen.cloudforest-kardashev.ts.net/v1/models -o /dev/null -w '%{http_code}\n'
```

**Pass**: `200`. Laya's `:8443` listener must not have displaced Qwen's `:443`.

## Step 6 — bootstrap idempotency

```bash
ssh eisen 'systemctl restart eisen-laya-bootstrap && systemctl show eisen-laya-bootstrap -p ActiveState -p NRestarts -p ExecMainStatus'
ssh eisen 'journalctl -u eisen-laya-bootstrap -n 5 --no-pager'
```

**Pass**: `ActiveState=active`, `ExecMainStatus=0`, log line
`laya venv already bootstrapped (/mnt/storage/decision/.laya-ready)` — and `laya-serve`
uptime is undisturbed.

---

## Known state (not failures)

- **Rebuilds exit 4** on eisen — user-scope `sops-nix` cannot decrypt (pre-existing since
  2026-09-29). Read `readlink -f /run/current-system` + `systemctl --failed`, not the exit code.
- **`.lan` names don't resolve via the default resolver** — pre-existing, fleet-wide.
- **`outPath` ≠ `/run/current-system`** — expected: the flake source tree is itself an input,
  so later commits (docs, `modules.toml`) shift the hash with no Nix change.
- **Kolibri-1 remains blocked** — `unknown model architecture: 'kolibri1'`; unrelated to Laya.

## Rollback

```bash
# on eisen, if Laya misbehaves
sudo systemctl stop laya-serve tailscale-serve-laya
ssh eisen 'sudo rm -f /mnt/storage/decision/.laya-ready && sudo systemctl restart eisen-laya-bootstrap'  # forced rebuild
# full revert of the host change:
git revert 29383b4   # then task infra:deploy:host:eisen
```

## Acceptance summary

All six checks pass → Laya is verified end-to-end on the running host and this handoff is closed.
Any non-`200` / inactive unit / missing `laya.lan` in `/run/current-system` → capture
`journalctl -u laya-serve -n 80 --no-pager` and reopen.
