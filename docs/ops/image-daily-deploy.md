# image-daily deploy path — frieren

The image pipeline ships to exactly one host: frieren's `image-daily-slot-1..4`
systemd timers (`hosts/frieren/infra-stack.nix`). The slot wrappers bake
`daily=<store>/scripts/task/image-daily.sh` into the store at build time, so a
script change is only live after a nixos-rebuild — a push to main alone changes
nothing the timers run. Manual `task images:*` calls read the checkout directly
and are not the thing being deployed.

## plan

```bash
task infra:deploy:host:frieren   # gate -> plan -> apply -> validate in one
# or plan only, substitutes without switching:
task infra:plan:host:frieren
```

The plan is what tells you the slot units get new store paths — look for the
`unit-image-daily-slot-*.service` scripts in the diff. A change confined to
`scripts/task/image-daily-*.sh` rebuilds those units and nothing else.

## apply

`infra:deploy` applies the same plan it printed; on frieren the switch is
`nixos-rebuild` on the host itself. One rebuild at a time — never retry-loop.

## validate

```bash
bash ~/Documents/nixconfig/scripts/task/image-daily.sh gate      # structure gate
systemctl list-timers 'image-daily-slot-*'                       # timers armed
journalctl -u image-daily-slot-1.service -n 50 --no-pager        # after a slot fires
task images:today                                              # ledger view
```

Proof a slot is healthy: the ledger gains `attempt` rows and at least one
`keep`; `verdict: unjudged` rows repeating mean the judge route, not the
deploy, is what failed — `task images:gate` (the script's `gate` subcommand)
separates the two. `checks:images:publish:test` pins the gate against
`470c9034^` (the 0-of-43 tree) so it cannot silently stop failing.

## rollback

```bash
task infra:rollback:host:frieren
```

Rollback restores the previous generation's slot wrappers — the previous
store-baked `image-daily.sh` — which is the correct undo for a script regression.
The ledger and `/Volumes/data/pics/generated` are data, not configuration: a
rollback never deletes plates or un-keeps verdicts. If the regression already
burned allowance, the loss is the day's spend, not the tree — the circuit
breaker (`unjudged_streak >= 2` in `run_lane` and the plates loop) caps it at
two generations per lane.
