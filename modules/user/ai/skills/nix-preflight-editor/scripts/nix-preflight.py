#!/usr/bin/env python3
"""
nix-preflight: Precision editor companion and preflight syntax validator for Nix files.

Ensures zero-regression editing of Nix expressions by:
1. Validating syntax with `nix-instantiate --parse` before and after edits.
2. Inspecting context at 2-3 anchor points (line numbers or regex/substrings) with exact indentation.
3. Linting multiline indented strings (''...'') for premature termination traps (e.g. Python '' or bash '').
"""

import sys
import os
import re
import subprocess
import argparse

def run_parse(file_path):
    if not os.path.isfile(file_path):
        print(f"ERROR: File not found: {file_path}", file=sys.stderr)
        return False, f"File not found: {file_path}"
    
    cmd = ["nix-instantiate", "--parse", file_path]
    res = subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True)
    if res.returncode == 0:
        return True, "Syntax valid (AST parsed cleanly)."
    else:
        return False, res.stderr.strip()

def check_syntax_cmd(file_path):
    ok, msg = run_parse(file_path)
    if ok:
        print(f"✓ [PARSE OK] {file_path}: {msg}")
        return 0
    else:
        print(f"✗ [PARSE ERROR] {file_path}:", file=sys.stderr)
        print(msg, file=sys.stderr)
        return 1

def inspect_lines_cmd(file_path, anchors):
    if not os.path.isfile(file_path):
        print(f"ERROR: File not found: {file_path}", file=sys.stderr)
        return 1

    with open(file_path, "r", encoding="utf-8", errors="replace") as f:
        lines = f.readlines()

    total_lines = len(lines)
    print(f"=== File: {file_path} (Total lines: {total_lines}) ===")

    for i, anchor in enumerate(anchors, 1):
        target_idx = None
        # Check if anchor is an integer line number
        if anchor.isdigit():
            target_idx = int(anchor) - 1
            print(f"\n--- Anchor {i}: Line {anchor} ---")
        else:
            # Substring / regex search
            print(f"\n--- Anchor {i}: Search query '{anchor}' ---")
            matches = [idx for idx, l in enumerate(lines) if anchor in l]
            if not matches:
                print(f"  [No matches found for query '{anchor}']")
                continue
            for m_idx in matches:
                start = max(0, m_idx - 3)
                end = min(total_lines, m_idx + 4)
                print(f"  Match at Line {m_idx + 1}:")
                for cur in range(start, end):
                    prefix = ">>>" if cur == m_idx else "   "
                    line_text = lines[cur].rstrip("\r\n")
                    print(f"  {prefix} {cur + 1:4d}: {line_text}")
            continue

        if target_idx is not None:
            if target_idx < 0 or target_idx >= total_lines:
                print(f"  [Line {anchor} out of range (1..{total_lines})]")
                continue
            start = max(0, target_idx - 3)
            end = min(total_lines, target_idx + 4)
            for cur in range(start, end):
                prefix = ">>>" if cur == target_idx else "   "
                line_text = lines[cur].rstrip("\r\n")
                print(f"  {prefix} {cur + 1:4d}: {line_text}")

    return 0

def lint_multiline_cmd(file_path):
    """
    Scans for premature termination of Nix multiline strings (''...'').
    In Nix, any two consecutive single quotes '' inside an indented string
    close the string (unless followed by another single quote, e.g. ''' or ''$).
    """
    if not os.path.isfile(file_path):
        print(f"ERROR: File not found: {file_path}", file=sys.stderr)
        return 1

    with open(file_path, "r", encoding="utf-8", errors="replace") as f:
        lines = f.readlines()

    in_multiline = False
    issues = []

    for idx, raw_line in enumerate(lines, 1):
        line = raw_line.rstrip("\r\n")
        pos = 0
        while pos < len(line):
            # Look for ''
            found = line.find("''", pos)
            if found == -1:
                break
            
            # Check context
            if not in_multiline:
                # Entering a multiline string
                in_multiline = True
                pos = found + 2
            else:
                # Inside multiline string: is it an escape sequence?
                # ''$ escapes $
                # ''' produces ''
                # ''\ escapes newline/special
                if found + 2 < len(line) and line[found + 2] in ('$', "'", '\\'):
                    # Safe escape sequence
                    pos = found + 3
                else:
                    # Closing multiline string or accidental delimiter!
                    # Let's inspect what follows or if it appears to be inside a python/bash script
                    rest = line[found + 2:].strip()
                    # Check if there's code on the same line that suggests premature termination
                    # e.g. '' == '' or python empty string
                    if re.search(r'["\'a-zA-Z0-9_]', rest) and not rest.startswith(";"):
                        # Possible trap
                        issues.append((idx, found + 1, line.strip()))
                    # Toggled off multiline
                    in_multiline = False
                    pos = found + 2

    if issues:
        print(f"⚠ [SUSPICIOUS MULTILINE DELIMITER] in {file_path}:")
        for line_num, col, snippet in issues:
            print(f"  Line {line_num}:{col} -> Possible premature multiline termination: {snippet}")
        print("  Hint: In Nix ''...'' strings, use standard double quotes (\"\") for Python strings to avoid closing the Nix string.")
        return 2
    else:
        print(f"✓ [MULTILINE LINT OK] No premature string delimiter traps found in {file_path}")
        return 0

def verify_cmd(file_path):
    print(f"=== Preflight / Postflight Verification: {file_path} ===")
    m_code = lint_multiline_cmd(file_path)
    s_code = check_syntax_cmd(file_path)
    if s_code == 0 and m_code == 0:
        print(f"✓ [ALL CHECKS PASSED] {file_path} is syntactically sound and ready.")
        return 0
    elif s_code == 0 and m_code == 2:
        print(f"⚠ [WARNING] Syntax parsed, but suspicious multiline patterns were flagged.", file=sys.stderr)
        return 0
    else:
        print(f"✗ [VERIFICATION FAILED] Please fix errors before committing.", file=sys.stderr)
        return 1

def main():
    parser = argparse.ArgumentParser(description="Nix preflight editor validation & line inspection helper.")
    subparsers = parser.add_subparsers(dest="command", required=True)

    p_check = subparsers.add_parser("check-syntax", help="Run nix-instantiate --parse on a file")
    p_check.add_argument("file", help="Path to .nix file")

    p_inspect = subparsers.add_parser("inspect", help="Inspect lines at 1-3 anchor points")
    p_inspect.add_argument("file", help="Path to .nix file")
    p_inspect.add_argument("anchors", nargs="+", help="Line numbers or search queries (up to 3 recommended)")

    p_lint = subparsers.add_parser("lint-multiline", help="Scan for multiline string '' traps")
    p_lint.add_argument("file", help="Path to .nix file")

    p_verify = subparsers.add_parser("verify", help="Run full syntax check and multiline linting")
    p_verify.add_argument("file", help="Path to .nix file")

    args = parser.parse_args()

    if args.command == "check-syntax":
        sys.exit(check_syntax_cmd(args.file))
    elif args.command == "inspect":
        sys.exit(inspect_lines_cmd(args.file, args.anchors))
    elif args.command == "lint-multiline":
        sys.exit(lint_multiline_cmd(args.file))
    elif args.command == "verify":
        sys.exit(verify_cmd(args.file))

if __name__ == "__main__":
    main()
