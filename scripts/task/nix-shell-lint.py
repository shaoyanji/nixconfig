#!/usr/bin/env python3
"""Lint the shell that lives inside Nix `''` strings.

Two checks over every `writeShellApplication`, `writeShellScriptBin` and
`writeShellScript` call site in the tracked `.nix` files:

  trap   `${...}` inside an indented string is Nix interpolation. When the body
         is shell rather than Nix — `${var:-default}`, `${sock##*/}` — Nix does
         not fail: it parses `var:-default` as a URI literal, so the script ships
         with `"var:-default"` where an expansion was meant. Hard failure, and
         the reason the gate exists.
  shell  The script, with each Nix interpolation replaced by a variable
         reference, is run through shellcheck. `writeShellApplication` already
         does this at build time; the other two helpers do not, which is what
         leaves those scripts uncovered.

Text-level on purpose: the trap is authored in the source text, and reaching
the 60-odd derivations would mean evaluating every host that includes them.
"""
from __future__ import annotations

import argparse
import re
import subprocess
import sys

CALL = re.compile(r"\b(writeShellApplication|writeShellScriptBin|writeShellScript)\s+\"([^\"]*)\"")
TEXT_KEY = re.compile(r"\btext\s*=\s*")
# Shell parameter-expansion syntax in an interpolation body. Nix has no reason
# to put any of these in a `${...}` inside a script string.
SHELL_BODY = re.compile(r":[-+=?]|##|%%|^[#!@*?$]|^[0-9]+$|^[A-Za-z_][A-Za-z0-9_]*%")
IGNORE_PRAGMA = "nix-shell-lint: ignore"


class Unterminated(Exception):
    pass


def skip_dquote(text: str, i: int) -> int:
    """Index just past the `"`-string opening at i."""
    i += 1
    while i < len(text):
        if text[i] == "\\":
            i += 2
            continue
        if text[i] == '"':
            return i + 1
        if text.startswith("${", i):
            i = skip_interp(text, i)
            continue
        i += 1
    raise Unterminated("no closing \"")


def skip_string(text: str, i: int) -> int:
    """Index just past the indented string opening at i."""
    i += 2
    while i < len(text):
        # `''$`, `''\` and `''''` are the escapes; `''` alone closes.
        if text.startswith("''$", i) or text.startswith("''\\", i):
            i += 3
            continue
        if text.startswith("''''", i):
            i += 4
            continue
        if text.startswith("''", i):
            return i + 2
        if text.startswith("${", i):
            i = skip_interp(text, i)
            continue
        i += 1
    raise Unterminated("no closing ''")


def skip_interp(text: str, i: int) -> int:
    """Index just past the `${...}` opening at i, strings and braces included."""
    i += 2
    depth = 1
    while i < len(text):
        if text.startswith("''", i):
            i = skip_string(text, i)
            continue
        if text[i] == '"':
            i = skip_dquote(text, i)
            continue
        if text[i] == "{":
            depth += 1
        elif text[i] == "}":
            depth -= 1
            if not depth:
                return i + 1
        i += 1
    raise Unterminated("no closing }")


def interps(raw: str):
    """Yield (start, end) of each Nix interpolation in a raw body."""
    i = 0
    while i < len(raw):
        # Quoted regions are not skipped: a `"` carries no interpolation of its
        # own, and the shell being linted is mostly inside quotes.
        if raw.startswith("${", i):
            if i >= 2 and raw[i - 2 : i] == "''":
                # `''${` is a shell expansion the author escaped on purpose.
                i += 2
                continue
            j = skip_interp(raw, i)
            yield i, j
            i = j
            continue
        i += 1


def nested_strings(expr: str) -> str:
    """The shell text of every indented string inside a Nix expression."""
    out, i = [], 0
    while i < len(expr):
        if expr.startswith("''", i):
            end = skip_string(expr, i)
            out.append(to_shell(expr[i + 2 : end - 2]))
            i = end
            continue
        if expr[i] == '"':
            i = skip_dquote(expr, i)
            continue
        i += 1
    return "".join(out)


def strip_indent(raw: str) -> str:
    """Apply Nix's own rule for indented strings: drop the common indentation.

    Without it a heredoc terminator that sits at column 0 in the generated
    script looks indented here, and shellcheck reports a here-document bug that
    the deployed script does not have.
    """
    lines = raw.split("\n")
    widths = [len(line) - len(line.lstrip(" \t")) for line in lines if line.strip()]
    cut = min(widths) if widths else 0
    return "\n".join(line[cut:] if line.strip() else line for line in lines)


def to_shell(raw: str) -> str:
    """The script as the shell sees it, with Nix values stubbed out."""
    raw = strip_indent(raw)
    out, last = [], 0
    for start, end in interps(raw):
        inner = raw[start + 2 : end - 1]
        out.append(raw[last:start])
        # An optionalString block contributes its own shell; anything else is a
        # Nix value the shell only ever sees as one word.
        out.append(nested_strings(inner) if "''" in inner else "$__nix")
        last = end
    out.append(raw[last:])
    # Escapes last: `''$` is a literal `$` (so `''${` a literal `${`), `''''`
    # a `''`, and `''\` is consumed.
    return "".join(out).replace("''''", "''").replace("''\\", "").replace("''$", "$")


def body_at(text: str, start: int) -> tuple[str, int]:
    if not text.startswith("''", start):
        raise Unterminated("expected ''")
    end = skip_string(text, start)
    return text[start + 2 : end - 2], end


def sites(path: str):
    """Yield (line, helper, name, raw_body_or_None) for each call site."""
    try:
        text = open(path, encoding="utf-8").read()
    except (OSError, UnicodeDecodeError):
        return
    for m in CALL.finditer(text):
        start = m.end()
        key = TEXT_KEY.search(text[start : start + 400])
        if key:
            start += key.end()
        while start < len(text) and text[start] in " \t\r\n":
            start += 1
        line = text.count("\n", 0, start) + 1
        if not text.startswith("''", start):
            continue
        try:
            raw, _ = body_at(text, start)
        except Unterminated:
            raw = None
        yield line, m.group(1), m.group(2), raw


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("files", nargs="*", help=".nix files (default: everything git tracks)")
    ap.add_argument("--shellcheck", default="shellcheck", help="shellcheck binary")
    ap.add_argument("--quiet", action="store_true", help="summary only")
    ap.add_argument(
        "--exclude",
        default="SC1090,SC1091,SC2034,SC2154,SC2317",
        help="shellcheck codes to ignore (a Nix-supplied path cannot be followed)",
    )
    args = ap.parse_args(argv)

    files = args.files or subprocess.run(
        ["git", "ls-files", "*.nix"], capture_output=True, text=True, check=True
    ).stdout.split()

    traps, lint, linted = [], [], 0
    for path in files:
        for line, helper, name, raw in sites(path):
            where = f"{path}:{line} {helper} \"{name}\""
            if raw is None:
                traps.append(f"{where}: unterminated indented string")
                continue
            for start, end in interps(raw):
                body = raw[start + 2 : end - 1]
                if "''" in body:  # a nested string, not an expansion
                    continue
                flat = " ".join(body.split())
                if SHELL_BODY.search(flat):
                    traps.append(
                        f"{where}: ${{{flat}}} is shell, not Nix — write ''${{{flat}}} to keep it"
                    )
            script = to_shell(raw)
            r = subprocess.run(
                [args.shellcheck, "-s", "bash", "-e", args.exclude, "-"],
                input=script.encode(),
                capture_output=True,
            )
            linted += 1
            if r.returncode:
                current = 0
                for ln in r.stdout.decode().splitlines():
                    hit = re.match(r"^In - line (\d+):$", ln)
                    if hit:
                        current = int(hit.group(1))
                    code = re.match(r"^\s*\^-- (SC\d+)", ln)
                    if code:
                        lint.append(f"{where}: script line {current}: {code.group(1)}")

    if not args.quiet:
        for group, title in ((traps, "shell expansion read as Nix interpolation"), (lint, "shellcheck")):
            if group:
                print(f"\n{title}:")
                for item in group:
                    print(f"  {item}")
    print(
        f"nix-shell-lint: {linted} shell script(s), {len(traps)} trap(s), {len(lint)} shellcheck finding(s)"
    )
    return 1 if traps or lint else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
