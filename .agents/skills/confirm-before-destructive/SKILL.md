---
name: confirm-before-destructive
description: The shared confirmation policy for destructive actions — confirm before delete, overwrite, send, deploy, push, stop, or restart. Reference this skill from every skill that has a destructive step.
---

# confirm-before-destructive

**Runs on:** every host, every agent.
**Use when:** any step would delete, overwrite, send, deploy, push, stop, or restart something — or when you are unsure whether a step is destructive.
**Pick me over:** nothing — this is a policy, not a tool. It applies on top of every other skill.

## The rule

**Confirm before delete / overwrite / send / deploy / push / stop / restart.**

State the destructive step at the point where it happens, not delegated to a Taskfile or a script. Do not rely on the user having read a policy elsewhere.

## How to confirm

1. Say exactly what will happen (what gets deleted / overwritten / sent / deployed / pushed / stopped / restarted), and what it affects.
2. Say what is irreversible (e.g. "this deletes the file, no undo", "this pushes to origin, rewriting history").
3. Wait for an explicit yes. A vague "go ahead" for a different step is not a yes for this one.
4. If the user already approved this exact step in this conversation, do not re-ask. If the step changed (different file, different target, different scope), ask again.

## What counts as destructive

- **Delete:** `rm`, `data:clean:*`, `pb rm`, `git clean`, dropping a database/table.
- **Overwrite:** writing to an existing file without a backup, `git push --force`, restoring a backup over live data.
- **Send:** sending a message/email, submitting a form, calling a billed API (see below).
- **Deploy / push:** `git push`, deploying to production, `infra:deploy`, `site:deploy`, `bountystash:deploy:prod`.
- **Stop / restart:** `systemctl stop/restart` on a service carrying live traffic, rebooting a host, `serv00:server:stop`.

## Billed / spend actions

Confirm before any action that spends money or prepaid credit: `parallel-cli` `research` / `monitor create` (prepaid credit), any paid API call, any purchase. State the cost (or that the cost is unknown) before proceeding.

## What does NOT need confirmation

- Reading, listing, searching, checking status.
- Writing a new file that does not overwrite an existing one.
- A dry-run / `--dry-run` / report-only mode (use it first when available).

## Anti-patterns (do not do these)

- `--yolo`, `--dangerously-skip-permissions`, or any flag that bypasses the confirmation prompt. Never set them by default, never bake them into examples.
- "The user said go ahead" for a *different* step. Approval covers the exact step named.
- Hiding a destructive step inside a larger command ("and then it cleans up"). Name every destructive step separately.
