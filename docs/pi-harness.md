# Pi harness — research dump

Gathered 2026-10-21 for a possible fleet integration. Facts are marked with how they
were checked; anything unverified is listed under **Open questions**, not asserted.
Design rationale lives in `AGENTS.nix` (`pi-eisen-ondemand`); this page is the
source material so nobody has to re-fetch it.

## 1. Version reality check

| Claim | Checked how | Result |
| :--- | :--- | :--- |
| "Pi 2.0 exists" | `registry.npmjs.org/@earendil-works/pi-coding-agent` | **60 versions published, no `2.x`**; dist-tags are `latest: 1.3.0`, `legacy-node20: 0.74.2` |
| Newest release | `api.github.com/repos/earendil-works/pi/releases` | `v1.3.0` (2026-10-15) — below it `v1.2.0` (10-12), `v1.1.0` (10-07), `v1.0.4` (10-05) |
| Newest tags | `api.github.com/repos/earendil-works/pi/tags` | `v1.3.0 … v1.0.0`, nothing above |
| Changelog | `packages/coding-agent/CHANGELOG.md` | `[Unreleased]` above `[1.3.0]` |

So **there is no 2.0**. The "MCP coding mode" that carries the hype is `codemode`,
which ships in 1.x (the changelog's 1.x notes and `docs/codemode.md` describe it in
full). Anything read about a "2.0" is either a rumour or a different product.

## 2. What codemode actually is

The model writes **JavaScript**, not JSON tool calls. The script runs in a QuickJS
sandbox with no Node APIs, filesystem, network or timers, and reaches the outside
world only through `tools.*` and `models`:

- every callable tool is `tools.<name>(args)`; MCP tools are namespaced, so
  `mcp__dev-radius__search` becomes `tools.mcp__dev_radius__search`;
- only the script's output reaches the model, so a script can fan out in parallel
  (`Promise.allSettled`) and filter large results before the model pays for them;
- `bash` resolves to `{ output, truncated, full_output_path, exit_code, wall_time_seconds }`
  with up to 1 MiB of output (first/last 512 KiB kept) rather than the 2 000-line /
  50 KB the model would see;
- `searchTools(query)` (BM25, default 8), `describeTool`, `describeNamespace` and
  `ALL_TOOLS` let the model discover deferred tools — including MCP servers that
  connect later, which is why the codemode description stays stable while servers
  come and go;
- the declared tool surface shares a 3 000-estimated-token budget
  (`codemode.inlineBudget`);
- `codemode.mode = "only"` hides the other tools from the model entirely, so every
  call goes through a script.

Limit to know before designing around it: `max_output_tokens` defaults to 10 000,
`timeout_ms` is unset by default, and a script fails past 16 MiB of text/base64
output. Unawaited promises are discarded; calls made before a failure are not undone.

## 3. Install and runtime

- `nix run github:earendil-works/pi/stable` (tag-pinnable); the repo supports
  `nix build .` from a checkout and pins model-catalog data offline.
- Node **≥ 22.19.0** (`engines` in the npm manifest, and the README).
- Reference install is `curl -fsSL https://pi.dev/install.sh | sh` — unpinned, so
  not what a Nix-first fleet should use.
- Modes: interactive TUI, `--print`/JSON, RPC, and a TypeScript SDK. `pi-chat`
  (Slack/chat automation) is a separate repo built on the RPC surface.
- **No built-in permission system**: it runs with the launching user's filesystem,
  process, network and credential access. Upstream suggests a micro-VM (Gondolin
  extension), plain Docker, or OpenShell.

## 4. Configuration surfaces

The agent directory defaults to `~/.pi/agent` and is relocatable with
`PI_CODING_AGENT_DIR` (or the SDK's `agentDir`). Project config is `.pi/`, loaded
only after project trust.

| Path | Responsibility |
| :--- | :--- |
| `<agent-dir>/models.json` | OpenAI-compatible endpoints, models, `modelOverrides` |
| `<agent-dir>/settings.json` | preferences, defaults, resource paths, packages |
| `<agent-dir>/mcp.json` | MCP servers available in every project |
| `<agent-dir>/auth.json` | saved API keys / OAuth |
| `<agent-dir>/AGENTS.md`, `SYSTEM.md`, `APPEND_SYSTEM.md` | instructions, system-prompt replacement/appendix |
| `<agent-dir>/skills/`, `extensions/`, `prompts/`, `themes/` | resources |

A custom endpoint is five fields:

```json
{
  "providers": {
    "eisen": {
      "baseUrl": "http://eisen.lan/v1",
      "api": "openai-completions",
      "apiKey": "local",
      "models": [{ "id": "qwen" }]
    }
  }
}
```

`apiKey` may be a literal, `$ENV`/`${ENV}` or a `!command`; commands run **at request
time and are not cached**, which rules out putting a two-minute model load behind one.

Credentials resolve in order: `--api-key`, `auth.json`, `models.json` `apiKey`,
provider env vars. Model metadata worth setting for a local MoE: `inputLimits`,
`promptCache`, `samplingParams` / `samplingParamsByThinkingLevel` (openai-* APIs
only), and `reasoning`/thinking levels.

**Classifier models** (Jev-compatible typed decisions) are reachable through
codemode rather than `/model`: `models.getAvailableOfType("classifier")`, backed by
`typesafe/jev-latest`, Cloudflare Clef, OpenAI GPT-6 Luna, or llama.cpp router
models. That is the interesting overlap with this fleet's Laya/`/v1/systemone`.

## 5. What a lean eisen integration looks like

Eisen's existing service is the constraint, not Pi:

- llama-swap on `:8080`, one slot, one model at a time (`qwen` = Qwen3.6-35B-A3B,
  DFlash2 speculative decode, ~5.75 of 8 GiB VRAM);
- cold load 2–3 min (21 GiB GGUF), `/v1/models` does **not** load weights;
- the gaming guard stops llama-swap while a Steam game runs and restarts it after;
- `task infra:wol:eisen` already exists for the cold-host path.

Three layers, no new daemon:

1. **Data** — generate `models.json` from the eisen LLM module's own facts (model id,
   LAN URL, tailnet URL) into a store path, and point `PI_CODING_AGENT_DIR` at it, so
   the endpoint can never drift from the server it names.
2. **Control** — one `pi-eisen` shim: probe `/v1/models` (1 s) → else
   `task infra:wol:eisen` + poll → `max_tokens: 1` completion to force the load →
   `exec pi`. Per session, never per request.
3. **Lifecycle** — none. llama-swap idles the model out; a gaming desktop must never
   be auto-slept by an agent harness.

## 6. Scenarios

| Scenario | Behaviour |
| :--- | :--- |
| LAN, host up, model unloaded | shim prewarms once (2–3 min), then normal latency |
| Off-LAN | same shim against the tailnet `serve` URL |
| Steam game running | guard refuses; shim reports it and offers a cloud model instead of hanging |
| Unattended / agy / CI / scheduled | **never eisen** — the guard is non-deterministic and a 21 GiB reload must not gate a schedule |
| Two sessions | one llama-swap slot: keep runs sequential, expect queueing |
| Sunshine streaming | do not share; the GPU is already owned |

## 7. Deliberate non-goals

- Pi's own `/llama` router on eisen — duplicates the declarative llama-swap.
- `curl | sh` install — use the flake, pin the tag.
- Any design where a wake happens inside `models.json` `!command` — uncached, per
  request, and it would block inside auth.

## 8. Open questions

- Whether Pi's request timeout defaults tolerate a 2–3 min first token; if not, the
  shim's prewarm is mandatory rather than an optimisation (verify with
  `--print` against a cold model and time the first token).
- Whether `<agent-dir>` can be a read-only store path in practice — `sessions` and
  `auth.json` want to write; likely `PI_CODING_AGENT_DIR` for config plus a
  writable `sessionDir`, unverified.
- Whether codemode's classifier surface can front Laya (`/v1/systemone`) as an
  OpenAI-compatible classifier, or needs a provider extension.
- Containerization: Gondolin (micro-VM) vs the repo's existing MicroVM canary — no
  decision made.
