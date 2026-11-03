---
name: codespace
description: "Pick me when the work runs in a GitHub Codespace: the `gh cs ssh` flags that bite, how a file crosses without `cp`, and how a commit leaves a clone that cannot push."
version: 0.1.0
platforms: [linux]
metadata:
  hermes:
    tags: ['codespace', 'gh', 'ssh', 'remote', 'ephemeral']
    related_skills: ['tmux', 'confirm-before-destructive', 'paste']
---

# codespace — GitHub Codespaces as a mode, not a one-off

| | |
| :--- | :--- |
| Surface | `task codespace:*` (`taskfiles/codespace.yml`) |
| Implementation | `scripts/task/codespace.sh` |
| Selector | `CS=<name>` picks one explicitly; with `CS` unset the single `Available` codespace is used, and two `Available` is an error rather than a guess |
| Checkout | `/workspaces/<repo>`, discovered — `CSDIR=` overrides it |
| State vocabulary | `Available` accepts ssh · `ShuttingDown` · `Shutdown` (never "Stopped") |

A codespace is a remote disk with a language toolchain on it, not a host in the
fleet: it is not in `inventory.toml`, nothing in this repo configures it, and it
can be deleted without a trace. So the only durable truth is what has been
pushed out of it, and the mode is worth having when the repo under work already
ships a devcontainer that builds itself.

## The four traps, each one a failed attempt

| Trap | What actually happens | Do instead |
| :--- | :--- | :--- |
| `gh cs ssh -c $C -q …` | `unknown shorthand flag: 'q'` — the word after the flags is parsed as a gh flag, not a command | command after `--`; there is no quiet mode |
| `gh cs cp -c $C <src> <dst>` | failed in both directions (exit 1) on a codespace whose ssh worked | `codespace:put` / `codespace:get` — base64 over the ssh channel |
| `git push` inside the codespace | the clone had no credential helper, so the push failed | `codespace:push` — bundle out, push from the clone that holds the auth |
| `gh cs list` filtered for `Stopped` | the state is `Shutdown`; a poll for the other string never terminates | poll `Shutdown`, which is what `codespace:stop` does |
| `gh cs start` | no such subcommand — `gh codespace` has code, cp, create, delete, edit, jupyter, list, logs, ports, rebuild, ssh, stop, view | the first `codespace:exec` boots it (auto-start); the explicit form is `POST /user/codespaces/<name>/start` |

`codespace:push` compares the codespace's repository against `remote.origin.url`
before it does anything, because pushing a codespace branch into whichever
checkout you happen to be standing in is the expensive mistake. It is
fast-forward only: a divergent branch fails instead of forcing.

## The loop

```bash
task codespace:list                                  # state, name, repository
task codespace:exec -- "uname -a && go version"      # the command follows --
task codespace:put -- ./local.go /tmp/local.go       # when the repo is not the vehicle
task codespace:exec -- "cd /workspaces/<repo> && go test ./..."
task codespace:status                                # safe to stop, or not?
task codespace:push                                  # from the host with the gh auth
task codespace:stop                                  # waits for Shutdown
```

`codespace:exec` re-joins its words with single spaces, so a quote-sensitive
command gets mangled: write it to a file, `codespace:put` it, and run it by
path. The one-liners in this page survive that; anything with `$'…'` or nested
quotes does not.

The first command after a stop pays the boot (tens of seconds); later ones are a
second or two. `exec` lands in `$HOME` unless the command changes directory, so
a test run names the checkout explicitly or relies on `CSDIR`, which the tasks
that touch git already use.

## What it costs

A cold `go test ./...` in a codespace is minutes, not seconds — the compile is
from scratch and a package that exercises a real database can take 3-4 minutes
on its own. That is the price of the toolchain, not of the transport: an edit
round-trip over `gh cs ssh` is a second or two. Plan the session around one test
run, not around re-running a suite after every file.

## Stopping and deleting are different

`codespace:stop` is reversible — the disk survives, and it is how billing
stops. `codespace:delete` destroys the disk, so it needs `CONFIRM=1` and
`codespace:status` is the check to run first. GitHub also deletes a codespace on
its own after a retention window (30 days of inactivity by default), so an
unpushed commit on that disk is not stored anywhere.

## The history-rewrite hazard

An old codespace clone is dangerous rather than merely stale after an upstream
rewrite: it still contains the objects that were purged and would put them back
on its next push. `codespace:sync` fetches every remote-tracking ref with
`--prune`, then resets onto `origin/<branch>`, refusing a dirty tree unless
`FORCE=1`.

That fetch is also what makes the `ahead` count trustworthy. `codespace:status`
compares against `origin/<branch>` as the clone last saw it, so after work lands
elsewhere an unrefreshed clone reports those commits as local-only and calls the
stop UNSAFE. When someone else may have pushed, `codespace:sync` before
`codespace:status`.

**`sync` needs credentials it does not have**, which is why it must fail loudly:
the clone inside a codespace has no credential helper, so `git fetch` over https
dies on the missing username. It now exits 1, resets nothing, and names the
credential-free path — bundle the commits on the host, `codespace:put` the bundle,
then `git fetch /tmp/sync.bundle <branch> && git reset --hard FETCH_HEAD` and move
`refs/remotes/origin/<branch>` so `status` stops calling the clone ahead.

That body is `scripts/task/codespace-sync-body.sh`, not a heredoc, so the failure
is testable without a codespace: `task checks:codespace:sync` runs it against local
repositories (unreachable origin, dirty tree, FORCE, fast-forward, missing branch).
It converts a regression that once reported success on an unauthenticated fetch
into five named assertions.

Truth: `taskfiles/codespace.yml` — the executable contract; `scripts/task/codespace.sh`
is the implementation, and this page is the procedure and the measured traps.
