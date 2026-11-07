# AGENTS.md — clanker

The fleet's `AGENTS.md` still binds. This section is what is different on this
box.

## What this box is

An Instabox VM: 4 vCPU, 8 GiB, 20 GiB on `/data`. We own `~/.nix-profile` and
nothing else — boot, kernel and accounts are the image's. It runs bounded work
(Go builds, Nix builds, a tool being tried before it earns a place on a fleet
host). A job auto-suspends 30 minutes after the last API call and dies at 120
minutes, so work that has to outlive that window belongs somewhere else.

## Reaching the fleet

This VM is **not on the tailnet**. MagicDNS and every
`*.cloudforest-kardashev.ts.net` name fail to resolve here, and a timeout is not
the fleet being down — it is this box being outside it. The public door is
`delphi.bountystash.com`: use it. When a task assumes the tailnet, report the
assumption rather than substituting a host that happens to answer.

The agent-turn log is public and read-only at
`https://delphi.bountystash.com/turns/` — `curl -sN …/turns/api/stream` for the
wire, `agent-browser open` for the page. Reading it is free. Publishing a turn
needs the xs token, which this VM must not hold: hand the summary back to the
caller, or post it from a host that already owns the token.

## What "done" means here

A build that succeeds here is a suggestion. It is real when a cache has it
(`task dev:nixbuild:plan`, or CI's cachix push) or a host has switched to it.
Verify on the artifact — the store path, the running unit, the HTTP response —
never on this VM's exit code alone. Fleet-wide evals and `nix flake check` stay
off this box for the same reason they are off a small host: the memory is the
image's, not ours, and a killed eval proves nothing.
