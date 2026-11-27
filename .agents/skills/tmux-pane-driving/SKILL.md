---
name: tmux-pane-driving
description: "Drive an idle tmux agent pane at a shell prompt."
version: 0.1.0
platforms: [linux]
metadata:
  hermes:
    tags: ['tmux', 'pane', 'drive', 'brief', 'devin', 'hermes']
---

# tmux-pane-driving — drive an idle pane at a shell prompt

Mechanical workflow for getting a task brief into an idle tmux agent pane (devin,
hermes, freebuff, nu, etc.) and confirming it landed. Complements
`subagent-orchestration` (roles, xs polling, nudging) with the low-level send
steps.

## Procedure

1. **Map before you drive.** Run:
   `tmux list-panes -a -F 's=#{session_name} w=#{window_index} p=#{pane_index} cmd=#{pane_current_command}'`
   Then `tmux capture-pane -t <target> -p -S -6` to confirm the pane is idle
   (at a prompt, not mid-redraw, not `Working…`). Pane numbering is per-host
   and per-session — do not assume pane0 = window 1 or pane3 = window 4.
2. **Clear the input first.** `tmux send-keys -t <target> Escape; tmux send-keys
   -t <target> C-u`. Verify empty with `tmux capture-pane -t <target> -p -S -4`.
   `tmux load-buffer` appends to existing input — skipping this double-pastes
   the brief over old text.
3. **Send via load-buffer + paste-buffer.** Write the task to a temp file,
   `tmux load-buffer -t <target> /tmp/...`, `tmux paste-buffer -t <target>`,
   then `tmux send-keys -t <target> Enter`.
4. **Verify it landed.** Capture the pane and confirm the input box shows the
   text (e.g. `[Pasted text #1 +N lines]`) before pressing Enter. After Enter,
   confirm `Thinking`/`Working…` appears, not a repeat of the prompt.
5. **If double-pasted anyway.** Clear with Escape + C-u and resend once clean.

## Pitfalls

- **`tmux load-buffer` without `-t <target>` fails** ("too few arguments").
  Always pass the target session/window.
- **A pane showing a spinner/modal/`Working…` is BUSY.** Send nothing. Read the
  tail first.
- **Never `Escape`/`Ctrl+C` to a working pane** — it aborts the turn and can
  drop the session. Only clear input on an idle pane.

## Related

- `subagent-orchestration` — pane roles, xs-ledger polling, nudging, recovery.
- `tmux-pane-steward` — keep panes busy, recover dead tmux server.
- `xs-turn-orchestration` — monitor xs turns, delegate to pane agents.
---

Truth: `scripts/task/pane-nudge.sh` — the driving mechanics; this page is when to use them.
