---
name: jev-ultrafast
description: >-
  Ultra-low-latency web browsing and DOM navigation agent powered by TypeSafe Jev (50-100ms per step).
  Indexes page DOM controls into a structured action space and predicts next actions in a single network round-trip.
  Drives Windows Chrome.exe directly across the WSL2 boundary without requiring Chromium in Nix.
  Use when the user requests ultrafast browser automation, rapid form filling, or quick web goal navigation.
---

# Jev Ultrafast Browser Skill

Low-latency, vision-free browser automation combining **Browser Use** design patterns with **TypeSafe Jev System One** structured prediction.

Unlike traditional screenshot-based vision agents that take several seconds per step, Jev transforms the visible page DOM into an indexed table of interactive controls and makes a single speculative API call to determine the operation and target element in ~50–100ms.

## Native Windows `chrome.exe` Integration

On WSL2 / `guckloch`, this skill automatically drives the host's native Windows Google Chrome (`C:\Program Files\Google\Chrome\Application\chrome.exe` or `msedge.exe`):
- **Zero Linux Chromium required**: No large browser binaries or shared library dependencies needed in the Nix store.
- **Native Host Browser**: Launches and automates the Windows Chrome installation directly across the WSL boundary.
- **Headless or Headed**: Supports both background headless execution and live visible window automation (`--headed`) on Windows desktop.

## Architecture

```text
                      One TypeSafe System One Request
                     ┌───────────────────────────────┐
Page → Action Table  │ Operation (CLICK, TYPE, ...)  │
                     │ Target Element Head           │
                     └───────────────┬───────────────┘
                                     │
                        Deterministic Execution
                                     │
                 CLICK [e2] ─────────┴────────→ Windows chrome.exe
             TYPE_TEXT [e1] ──────────────────→ LLM text helper → Windows chrome.exe
```

1. **DOM Observation**: Elements are stamped with ephemeral IDs (`data-jev-action-id`), and only visible, interactive nodes within the viewport are indexed.
2. **Speculative Decision**: The System One endpoint (`https://api.typesafe.ai/v1/systemone`) evaluates operation selection (`CLICK`, `TYPE_TEXT`, `SELECT`, `SCROLL_UP`, `SCROLL_DOWN`, `WAIT`, `DONE`, `BLOCKED`) and candidate target heads simultaneously.
3. **Execution**: Playwright triggers native browser events on the exact matching DOM node in Windows Chrome.

## Environment & Prerequisites

The skill automatically sources API keys in the following priority order:
1. Active environment variables (`process.env`)
2. `~/.config/hermes/hermes.env`
3. Local `.env`

Required key:
* `TYPESAFE_API_KEY` (or `TYPESAFEAI_API_KEY`): Access token for TypeSafe AI API.

Optional text generation keys (for `TYPE_TEXT` values):
* `DEEPSEEK_API_KEY`, `OPENROUTER_API_KEY`, or `GEMINI_API_KEY`.

## CLI Usage

Run a browser automation goal directly from the WSL terminal:

```bash
node ~/.agents/skills/jev-ultrafast/scripts/jev-runner.mjs \
  --url "https://news.ycombinator.com" \
  --goal "Click on the 'newest' link" \
  --headless
```

To run with a visible browser window on Windows desktop:
```bash
node ~/.agents/skills/jev-ultrafast/scripts/jev-runner.mjs \
  --url "https://news.ycombinator.com" \
  --goal "Click on the 'newest' link" \
  --headed
```

### Options

| Flag | Description | Default |
| :--- | :--- | :--- |
| `--url <URL>` | Target website address | *Required* |
| `--goal <text>` | Natural language objective | *Required* |
| `--max-steps <N>` | Maximum iterations before terminating | `25` |
| `--headed` | Run with visible Chrome window on Windows desktop | `false` (headless) |
| `--delay <ms>` | Inter-step pacing delay | `100` |

## Programmatic API

```javascript
import { launchBrowser, observePage, buildActionSpace, executeAction } from './scripts/browser_primitives.js';
import { predictJevAction } from './scripts/jev_client.js';

const browser = await launchBrowser({ headless: true });
const page = await browser.newPage();
await page.goto('https://example.com');

const pageState = await observePage(page);
const actionSpace = buildActionSpace(pageState.actions);

const decision = await predictJevAction({
  pageState,
  actionSpace,
  goal: "Click Learn More"
});

console.log(`Action: ${decision.operation} (confidence: ${decision.confidence})`);
await executeAction(page, decision);
await browser.close();
```

## Verification & Smoke Testing

To verify the skill installation and end-to-end operation driving Windows `chrome.exe` from `guckloch`:

```bash
npm --prefix ~/.agents/skills/jev-ultrafast test
```
