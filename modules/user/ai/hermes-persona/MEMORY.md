# MEMORY.md — Persistent Boot Memory

Wrapper binary for jev: `askjev` (shell wrapper at `~/.local/bin/askjev`, wraps `jev-decide classify --provider typesafe`). Real call returns `jev_called: true`, `transport: typesafe`. User-preferred openrouter model: `inception/mercury-decide:free` (not applied by askjev wrapper — call `jev-decide` directly for openrouter).

Tips for making official skills with wrappers:
1. The wrapper (`askjev`) loads keys from `~/.config/hermes/hermes.env`, exports `OPENROUTER_API_KEY` + `TYPESAFE_API_KEY`, builds a temp criteria JSON, then calls `jev-decide classify --provider typesafe --text "$QUESTION" --criteria`.
2. To make an official skill with a wrapper: define `SKILL.md` with trigger/description; add a `scripts/` wrapper that validates inputs (check `--help` before invoking), loads env, builds evidence files (not strings), and calls the underlying binary with `--dry-run` first.
3. Never invent invocation shapes — read the wrapper source (`cat /path/to/wrapper`) and the underlying binary's `--help` before writing the skill.
4. Log results back: `jev_called`, `transport`, `probability`, `margin`, model used, and whether the user overrode.
