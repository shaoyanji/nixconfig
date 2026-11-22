#!/usr/bin/env python3
"""Every command a packaged wrapper calls must come from its runtimeInputs.

xs-notify shipped calling awk with `runtimeInputs = [coreutils curl jq]`. A
systemd unit's PATH has no awk, so the timer exited 127 every minute from
2026-11-21 until the input was added by hand. A wrapper is a closed PATH, and
nothing compared its script against that PATH.

Only *known* commands are judged: a token that names nothing in the table is
ignored, so variables, function names and `case` patterns cost nothing. The
price of that choice is the reverse: a command absent from the table is not
checked either, so the table is the thing to extend when a wrapper grows.

Scope is wrappers whose `text` is one external file (`builtins.readFile …;`).
An inline heredoc's command set is not visible to a file scan, so those are
counted and skipped rather than half-judged.

A script excuses a command the wrapper cannot supply (a desktop tool from the
session PATH, a binary the caller installs) with a line carrying
`shell-input-ok: <command> <reason>`.
"""

from __future__ import annotations

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]

# Command -> the package attribute that installs it.
PROVIDES = {
    # coreutils
    **{
        cmd: "coreutils"
        for cmd in (
            "cat cp mv rm mkdir rmdir ln head tail cut tr sort uniq wc sleep seq "
            "date stat readlink dirname basename mktemp chmod touch du df tee "
            "sha1sum sha256sum md5sum base64 timeout env install sync realpath "
            "nproc yes split tac fmt od shuf pwd id whoami hostname"
        ).split()
    },
    # bash builtins need no package, and judging them would be a false alarm
    # every time a script echoes or prints.
    **{cmd: None for cmd in ("echo printf read test true false cd export set".split())},
    "awk": "gawk",
    "gawk": "gawk",
    "sed": "gnused",
    "grep": "gnugrep",
    "egrep": "gnugrep",
    "find": "findutils",
    "xargs": "findutils",
    "diff": "diffutils",
    "cmp": "diffutils",
    "patch": "patch",
    "ssh": "openssh",
    "scp": "openssh",
    "sftp": "openssh",
    "rsync": "rsync",
    "curl": "curl",
    "wget": "wget",
    "jq": "jq",
    "python3": "python3",
    "sqlite3": "sqlite",
    "git": "git",
    "flock": "util-linux",
    "setsid": "util-linux",
    "mount": "util-linux",
    "umount": "util-linux",
    "systemctl": "systemd",
    "journalctl": "systemd",
    "ffprobe": "ffmpeg",
    "ffmpeg": "ffmpeg",
    "file": "file",
    "sops": "sops",
    "tailscale": "tailscale",
    "fuzzel": "fuzzel",
    "rofi": "rofi",
}

# Command positions: after a separator or a substitution, or a line start.
CANDIDATE = re.compile(
    r"(?:^|[;|&({]|\$\(|`|\b(?:then|do|else)\b)\s*([A-Za-z][\w.+-]*)(?!\s*=)",
    re.M,
)


def runtime_inputs(text: str) -> list[str] | None:
    """Identifiers inside `runtimeInputs = … [ … ];`, found by bracket depth.

    A `sed` range to the next `];` over-reads a one-line `[pkgs.x];` list and
    swallows the following `text = …` line, so the depth is counted instead.
    """
    start = text.find("runtimeInputs")
    if start < 0:
        return None
    open_at = text.find("[", start)
    if open_at < 0:
        return None
    depth = 0
    for i in range(open_at, len(text)):
        ch = text[i]
        if ch == "[":
            depth += 1
        elif ch == "]":
            depth -= 1
            if depth == 0:
                body = text[open_at + 1 : i]
                body = re.sub(r"#.*", "", body)
                names = re.findall(r"\b[A-Za-z_][A-Za-z0-9_+-]*\b", body)
                return [n for n in names if n not in {"with", "pkgs", "inherit"}]
    return None


def external_script(text: str) -> str | None:
    m = re.search(r"text\s*=\s*builtins\.readFile\s+([^;]+);", text)
    return m.group(1).strip() if m else None


def strip_heredocs(text: str) -> str:
    """Blank heredoc bodies: their commands run on the far end of the ssh.

    dsh-remote feeds a shell to the remote host; judging `systemctl` inside that
    block against the local wrapper's PATH would be wrong, and the script does
    call a local `sed` on the same line, which must still be seen.
    """
    out: list[str] = []
    marker: str | None = None
    for line in text.splitlines():
        if marker is not None:
            if line.strip() == marker:
                marker = None
            out.append("")
            continue
        out.append(line)
        m = re.search(r"<<-?\s*['\"]?([A-Za-z_][A-Za-z0-9_]*)['\"]?", line)
        if m and "<<<" not in line:
            marker = m.group(1)
    return "\n".join(out)


def commands_in(script_text: str) -> set[str]:
    # A comment is not a command. `${x#y}` survives: the strip needs whitespace
    # or line start before the `#`.
    stripped = re.sub(r"(?m)(^|\s)#.*$", r"\1", strip_heredocs(script_text))
    return set(CANDIDATE.findall(stripped))


def main() -> int:
    judged = skipped = 0
    failures: list[tuple[str, str, str, str, list[str]]] = []

    for nix in sorted(ROOT.glob("modules/**/*.nix")):
        text = nix.read_text(encoding="utf-8", errors="replace")
        if "writeShellApplication" not in text:
            continue
        rel = nix.relative_to(ROOT)
        script = external_script(text)
        if not script:
            print(f"note: {rel} wraps inline text, not an external file — not judged", file=sys.stderr)
            skipped += 1
            continue
        path = (nix.parent / script.strip('"')).resolve()
        if not path.is_file():
            print(f"note: {rel} names {script}, which does not exist — not judged", file=sys.stderr)
            skipped += 1
            continue
        declared = runtime_inputs(text)
        if not declared:
            print(f"note: {rel} declares no runtimeInputs — not judged", file=sys.stderr)
            skipped += 1
            continue
        judged += 1

        body = strip_heredocs(path.read_text(encoding="utf-8", errors="replace"))
        excused = set(re.findall(r"shell-input-ok:\s*([A-Za-z][\w.+-]*)", body))
        have = set(declared)
        for cmd in sorted(commands_in(body)):
            package = PROVIDES.get(cmd)
            if package is None or cmd in excused or package in have:
                continue
            failures.append((str(rel), str(path.relative_to(ROOT)), cmd, package, declared))

    for nix, script, cmd, package, declared in failures:
        print(f"FAIL {nix}: {script} calls `{cmd}`, which needs `{package}`")
        print(f"     declared: {' '.join(sorted(declared))}")
        print(f"     fix: add {package} to runtimeInputs, or a 'shell-input-ok: {cmd} <reason>' line in {script}")

    print(f"shell-inputs: judged {judged} wrapper(s), skipped {skipped}, {len(failures)} violation(s)")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
