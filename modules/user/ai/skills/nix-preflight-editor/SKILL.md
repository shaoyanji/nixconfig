---
name: nix-preflight-editor
description: Precision editor and preflight syntax validator for Nix files. Verifies AST syntax with nix-instantiate --parse, inspects multi-anchor line context before edits, and guards against Nix multiline string delimiter ('') traps.
---

# Nix Preflight Editor

A specialized agent skill designed to guarantee **zero-regression editing** of Nix expressions and configuration modules.

## Why This Skill Exists
Editing `.nix` files without fast local validation can introduce subtle, costly breakages:
1. **The Nix Multiline String Trap:** In Nix indented strings (`''...''`), any consecutive single quotes (`''`) close the Nix string immediately. Python code embedded inside Nix expressions using standard Python `''` (e.g. `empty_str = ''`) or bash `''` prematurely closes the string, causing parse errors that break subsequent system builds.
2. **Indentation and Anchor Drift:** Replacing chunks without reading the surrounding 3-5 lines across multiple anchor points frequently causes mismatched braces, dangling attributes, or scope confusion.
3. **Expensive Rebuild Cycles:** Running a full `nixos-rebuild switch` to find a syntax typo wastes minutes of I/O and CPU. `nix-instantiate --parse` validates the exact file in < 10 milliseconds.

## CLI Companion Tool

The skill includes a dedicated helper tool located at:
`~/.agents/skills/nix-preflight-editor/scripts/nix-preflight.sh`

### Subcommands:
- **`check-syntax <file.nix>`**:
  Runs `nix-instantiate --parse <file.nix>` to verify that the file parses into a valid Nix AST in complete isolation.
- **`inspect <file.nix> <anchor1> [anchor2] [anchor3]`**:
  Extracts precise context around 1 to 3 anchor points (line numbers or substring search queries). Outputs 1-indexed line numbers and exact character content.
- **`lint-multiline <file.nix>`**:
  Scans indented strings (`''...''`) for premature `''` termination traps.
- **`verify <file.nix>`**:
  Runs both `lint-multiline` and `check-syntax` in sequence.

## Workflow Invariant for Agents

When preparing to edit any `.nix` file:

```
[1. PREFLIGHT]
nix-preflight.sh check-syntax <file.nix>
       ↓
[2. PRECISION INSPECTION]
nix-preflight.sh inspect <file.nix> "<target_symbol_or_line>" "<context_anchor_2>"
       ↓
[3. TARGETED EDIT]
Apply replace_file_content with exact character matching
       ↓
[4. POSTFLIGHT VERIFICATION]
nix-preflight.sh verify <file.nix>
```

### Safety Rules
1. **Always use double quotes `""` for Python strings** embedded in Nix indented strings (`''...''`).
2. **Always run `check-syntax` or `verify`** immediately after modifying a Nix file before running any git commit or rebuild command.
3. **If `check-syntax` fails**, revert or fix the exact file immediately using the reported line and column numbers.
