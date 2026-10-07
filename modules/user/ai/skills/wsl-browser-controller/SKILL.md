---
name: wsl-browser-controller
description: >-
  Inspect and control active Windows browsers (Google Chrome, Microsoft Edge) directly from WSL2 using Windows UI Automation.
  Enumerate open tabs, inspect active tab, switch tabs, open URLs, and close tabs without requiring browser flags or remote debugging ports.
---

# WSL Browser Controller Skill

Drive and inspect active Windows host browsers (**Google Chrome**, **Microsoft Edge**) directly from inside **WSL2** using native Windows UI Automation over the WSL interop boundary.

Unlike CDP-based tools that require starting Chrome with special debug flags (`--remote-debugging-port`), `wsl-browser-controller` inspects and controls the user's **actual, live browser windows and tabs** on Windows.

## Features

- **Tab Enumeration**: List all open tabs across Chrome and Edge windows with index, titles, memory footprint, and audio activity indicators.
- **Active Tab Detection**: Instantly report which tab is currently selected/focused.
- **Tab Switching & Focusing**: Bring the browser window to the foreground and activate any tab by index or title substring.
- **Tab Closing**: Close specific tabs cleanly.
- **URL Launching**: Open new URLs in the default Windows host browser directly from WSL.
- **Agent-Ready JSON Mode**: Emit structured JSON (`--json`) for automated tool calling and agent policies.

## CLI Usage

The skill provides the `wsl-browser.sh` utility under `scripts/`:

```bash
# List all open tabs in a formatted table
wsl-browser.sh list

# List all open tabs as structured JSON
wsl-browser.sh list --json

# Get the currently active tab
wsl-browser.sh active

# Focus a tab by 1-based index or title keyword
wsl-browser.sh focus 3
wsl-browser.sh focus "YouTube"

# Open a URL in the host Windows browser
wsl-browser.sh open "https://github.com"

# Close a tab by index or keyword
wsl-browser.sh close 15
wsl-browser.sh close "Stirling"
```

## How It Works

WSL2 communicates across the Windows interop boundary (`powershell.exe`) with the Windows `UIAutomationClient` framework:
1. Queries running browser processes (`chrome.exe`, `msedge.exe`) with active main window handles.
2. Traverses the browser's native UI tree to find `TabStrip` / `TabContainerView` control panes.
3. Reads `SelectionItemPattern` on each tab item to determine selection status.
4. Invokes `.Select()` on the target `AutomationElement` and calls `SetForegroundWindow` via Win32 API to seamlessly bring the tab into focus.

## JSON Schema Output

`wsl-browser list --json` outputs:

```json
[
  {
    "index": 1,
    "title": "Inbox (26) - user@example.com - Gmail - Memory usage - 674 MB",
    "browser": "chrome",
    "processId": 3400,
    "isSelected": false
  },
  {
    "index": 19,
    "title": "(30) Video Title - YouTube - Audio playing - Memory usage - 469 MB",
    "browser": "chrome",
    "processId": 3400,
    "isSelected": true
  }
]
```
