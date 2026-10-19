# NUSHELL.md — shell layer, secrets, LLM and decision models

Status: **current** (2026-10-19). Audited and probed on `frieren`, nushell `0.115.1`.
Scope: `modules/shell/nushell.nix`, `modules/config/secrets.nu`, `modules/config/nu/*.nu`,
and the `nu_scripts` extras the config sources. This page is the single home for
"does the nushell layer work here" — do not restate it in AGENTS.md or a skill.

---

## 1. How the shell is assembled

| Stage | File | Contents |
| :--- | :--- | :--- |
| env | `modules/config/secrets.nu` (sourced from `extraEnv`) | PATH prepend, secrets loader |
| config | `modules/config/nu/config.nu` | UI, history, completion settings |
| modules | `modules/config/nu/{llm,decision,utils,mataroa,finance,de,jobby,todoist}.nu` | user commands |
| extras | `pkgs.nu_scripts` modules | `extract`, `clip`, `nufetch`, `wc`, `get_weather`, nix completions |
| plugins | `nushellPlugins.{query,gstat,formats,polars}` | registered via `plugin.msgpackz` |

---

## 2. RULE: `nu -c` and `nu script.nu` do **not** load your config

Measured on 0.115.1 (this is the trap that made the shell look broken):

```bash
nu -c 'print $env.config.show_banner'                          # true   (built-in default)
nu --config ~/.config/nushell/config.nu -c 'print $env.config.show_banner'  # false  (yours)
nu -c 'help commands | where name == nugroq | length'          # 0
nu --config ~/.config/nushell/config.nu -c 'help commands | where name == nugroq | length'  # 1
```

`nu -c` and `nu file.nu` evaluate only `default_env.nu` — the debug log
(`--log-level debug`) shows no read of `~/.config/nushell/{env,config}.nu`. So a
scripted `nu` has: no secrets, no `llm`/`decide`, no aliases, `edit_mode=emacs`,
`show_banner=true`. Plugins still load (they come from `plugin.msgpackz`).

**Every agent invocation must be explicit:**

```bash
nu --config ~/.config/nushell/config.nu --env-config ~/.config/nushell/env.nu -c '…'
```

For a single-need probe, sourcing just what you need is cheaper:

```bash
nu --no-config-file -n -c 'source ~/Documents/nixconfig/modules/config/nu/decision.nu; decide models'
```

---

## 3. Secrets loader (`modules/config/secrets.nu`)

Design: decrypt once via sops → JSON cache in `$XDG_RUNTIME_DIR/nushell-secrets.json`
(0600) → `load-env` on every shell start.

Fixed 2026-10-19:

- **Skip check was keyed on `GEMINI_API_KEY`.** A session that exported any single
  key made the loader return early, so the cache was never read and every other key
  stayed missing. Now keyed on an explicit `NU_SECRETS_LOADED=1` marker; a second
  call costs **182 µs**.
- **Cache was created 0644** by `save`, then `chmod`ed — a world-readable window.
  Now `install -m 600` creates it first, `save -f` truncates in place.

Verified: 34 keys load; `GROQ`, `TODOIST`, `COHERE`, `OPENROUTER`, `TYPESAFE`,
`NVIDIA`, `GEMINI` all present; pre-setting `GEMINI_API_KEY` no longer blocks the rest.
`sops`/age keys are not needed for **eval** — only for this loader.

Pitfall: the loader is `export-env` + `def --env`, so it takes effect when the file
is **sourced** (the real `env.nu` path). It is inert as `--env-config` in `-c` mode;
use `source …/secrets.nu` in an `env.nu` instead.

---

## 4. LLM layer (`modules/config/nu/llm.nu`)

Commands: `llm` (fallback chain), `nugroq`, `nunvidia`, `nugemini`, `nuhere`,
`nurouter` (OpenRouter), `nuaihubmix`, `nuopencode`, `nullama`, `llm models`.

Live-verified 2026-10-19 (keys from the loader only): groq `ok`, nvidia `ok`,
gemini `ok`; `llm` with a bad Groq key printed
`groq: API error: Invalid API Key` / `opencode: API Error: Upstream request failed: Model is unavailable.`
to stderr and still answered via the next provider.

Fixed:

- **`ensure-api-key` used `$env | get`** → `column_not_found` thrown before the
  message; every caller died with a generic error. Now `get -o` + empty-string check.
- **NVIDIA default model was retired** (`minimaxai/minimax-m2.7` → HTTP 410). Default
  is now `nvidia/nemotron-3-nano-omni-30b-a3b-reasoning`; the list only holds models
  this account can reach.
- **`chat-request` only understood `{error}`** and died on RFC 7807 (`{status,title,detail}`,
  what NVIDIA returns) and on `content: null` from reasoning models. It now reports
  all three shapes and treats an empty completion as a failure so the chain advances.
- **`catch { print -e $in }`** printed the whole error record (msg, debug, raw,
  rendered). Now `catch { |err| … $err.msg }`.
- `nuopencode` / `nuaihubmix` duplicated raw `choices.0` parsing; both now share
  `chat-request`.
- `nugemini` reads `candidates.0.content.parts` defensively and reports
  `finishReason` instead of a column error.

Rules: never log keys; stderr is reserved for provider failures (so `llm … | save`
stays clean); one provider per attempt, no retry loop inside a command.

---

## 5. Decision models (`modules/config/nu/decision.nu`)

Wire shape is System One: `POST /v1/systemone` with `state` + `questions`
(`choice` / `noul` / `score`), one forward pass, no generated text.

```
decide models                                  # provider + readiness (key set? CLI present?)
decide "pick the backup tier" --options [ssd hdd tape]     # auto: Jev → local
decide yes "the upstream is degraded" --state {msg:"502"}  # calibrated probability
decide score "rate severity" --criteria [ok degraded down] # ordered scale
decide jev … | decide local …                  # force provider
```

Live-verified: `decide jev` → `jev-1.13.0` (choice 0.52/0.46/0.02, yes 0.69, score
with legend); with no key, `typesafe: TYPESAFE_API_KEY is not set` then a local answer;
`decide models` → `typesafe…set`, `local…ok` on hosts with `systemone-decision`.

Caveats an agent must respect:

- **The local CLI is a lexical scorer** (hash embeddings + softmax), not the 421M
  checkpoint. Its confidence is low signal — offline fallback only.
- **Never let a decision gate a destructive action alone.** See
  `.agents/skills/decision-picker/SKILL.md` and `confirm-before-destructive`.
- `decide local` needs `systemone-decision` (installed on `frieren` and `eisen` only).
- A silent fallback is not allowed: the provider error goes to stderr first.

---

## 6. `nu_scripts` extras — what works here, what does not

Probed 2026-10-19 on `frieren` with the live config (`--config`, `--env-config`).

| Extra | Verdict | Evidence / reason |
| :--- | :--- | :--- |
| `extract` (tar.gz) | **works** | 180 ms, 8 lines from `tar xvzf` |
| `extract` (zip) | **works, interactive on overwrite** | 186 ms clean; re-extract prompts `replace …?` because `unzip` runs without `-o` |
| `extract` (rar / macOS pkg) | **broken** | `unrar` and `pkgutil` are not installed (`unzip`, `7za`, `xz`, `tar` are) |
| `nufetch` | **works** | 1.19 s; `nix path-info --recursive` per profile, cheaper than feared |
| `wc` (pipe) | **works** | `… | wc` parses into `lines/words/bytes` |
| `wc` (file args) | **broken upstream** | `^wc $rest` passes a list → `cannot_pass_list_to_external` |
| `clip` | **not usable from an SSH/agent shell** | `notify-send` and `xclip` missing (`wl-copy` present). With `WAYLAND_DISPLAY=wayland-1` inherited over SSH it **hung a pipeline** and had to be killed; even where copying succeeds, the `notify-send` step fails |
| `get_weather` | **broken** | hard-coded shared OWM token, retired `forecast/daily` endpoint → `Error getting location` (304 ms) |
| nix completions | **no effect** | `export extern "nix"` inside a **sourced** file is not registered — `help nix` → not found, `nix` absent from `help commands` |
| plugin: polars | **works** | 1.4 s (`into-df → sum → collect`) |
| plugin: gstat | **works** | 0.45 s in the repo |
| plugin: query | **works, `db` only** | `query db` 95 ms; this build exposes no `query json|web|xml` |
| plugin: formats | **works, no `from ini`** | `from url` 75 ms; ini is not among the commands |

The live generation sources `nu_scripts` **2026-07-19**; the repo now pins
**2026-10-02**. The failures above reproduce on both versions (they are upstream
behaviour, not a stale-store problem).

### Recommended changes (not yet applied)

1. **Drop `wc.nu`** or replace it with a local `wc` that splats (`^wc ...$rest`) —
   nu already has `lines | length` for the pipe case.
2. **Drop `get-weather.nu`** (dead token, retired endpoint). If weather is wanted,
   `http get https://wttr.in/?format=j1` needs no key.
3. **Drop `system/mod.nu` on headless hosts**, or keep it and stop calling `clip`;
   add `libnotify` if it stays (its `notify-send` step fails even when copying works).
4. **Change the completions entry to `use …/nix-completions.nu`** (not `source`), or
   drop it — Carapace does not cover `nix`, so `use` is worth keeping.
5. Keep `ultimate_extractor.nu`, `nufetch`, and all four plugins.

---

## 7. Binaries the layer expects

`modules/shell/nushell.nix` now declares `skim`, `mdq`, `zbar`, `poppler-utils`
(used by `utils.nu`), but **nothing takes effect until a switch**. On `frieren`
today: `sk`, `mdq`, `zbarimg`, `pdfinfo`, `todoist`, `typst`, `pdfcpu` are all
missing; `glow`, `himalaya`, `mpv`, `ddgr`, `htmlq`, `sqlite3`, `wl-copy`, `7za`,
`unzip` are present. For an immediate one-off:

```bash
nix shell nixpkgs#skim nixpkgs#mdq nixpkgs#zbar nixpkgs#poppler-utils -c nu --config … -c '<cmd>'
```

---

## 8. Verification recipe (cheap → expensive)

```bash
# 1. parse every nu file (positive control first — the grep pattern matters)
nu --ide-check 100 /tmp/bad.nu | grep -c 'severity":"Error'        # >0
for f in modules/config/nu/*.nu modules/config/secrets.nu; do
  nu --ide-check 100 "$f" | grep -c 'severity":"Error'; done        # 0 each

# 2. does the *built* config source the file? (~5 s, one host)
nix eval --raw .#nixosConfigurations.frieren.config.home-manager.users.devji.programs.nushell.extraConfig \
  | grep -E 'source /nix/store/.*(decision|llm)\.nu'

# 3. live, with the shipped store copies and loader keys only
nu --no-config-file -n -c 'source <secrets.nu>; source <decision.nu>; decide models'

# 4. Nix gate after touching nushell.nix
task checks:host HOST=frieren MODE=eval        # 2241 assertions, rc=0, ~8 s warm
```

`nu --ide-check` prints `{"type":"diagnostic","severity":"Error",…}` lines — a grep
for `"type":"error"` matches nothing and silently "passes". Use the control above.

---

## 9. Open items

- Apply the switch so `skim`/`mdq`/`zbar`/`poppler-utils` reach PATH (and the newer
  `nu_scripts` pin takes effect).
- Prune or replace the four failing extras (section 6).
- `nu -c` config semantics bite every agent script; consider a `nu-run` wrapper in
  `modules/scripts/` that always passes `--config`/`--env-config`.
