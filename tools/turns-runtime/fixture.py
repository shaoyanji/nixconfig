#!/usr/bin/env python3
"""Build the fixture all three prototypes render: 120 turns, same bytes.

The shape mirrors what the real dashboard shows (id, source, subject, action,
a branch/commit and a couple of files), so a row is a real row and not a
placeholder — the history frame is the biggest write any of them does.
"""
import json
import sys

SOURCES = ["buffy", "antigravity", "cpg-storybook", "turns-ui", "clanker"]
TOPICS = [
    "turns: a ? key list, and a finder that survives a reload",
    "deploy: gate the cloud host on the cache it actually uses",
    "kg: answer the blast radius without jq in the path",
    "secrets: restore the token the rekey dropped",
    "mail: sort the archive by sender trust, not by subject",
    "cache: warm one closure and prove the substitution",
    "docs: one fact one home, and the page that says where",
]


def main():
    rows = []
    for i in range(120):
        rows.append(
            {
                "id": f"00000000-0000-4000-8000-{i:012d}",
                "source": SOURCES[i % len(SOURCES)],
                "subject": TOPICS[i % len(TOPICS)],
                "action": (
                    f"Turn {i}: the read path is the page, the stream and the "
                    "history frame; a prototype that serves all three honestly "
                    "can be compared with another that does the same work."
                ),
                "when": f"2026-11-{(i % 7) + 1:02d}T{(i % 24):02d}:00:00Z",
                "branch": "main" if i % 3 else "",
                "commit": f"{i:08x}"[:8] if i % 2 else "",
            }
        )
    json.dump(rows, sys.stdout, separators=(",", ":"))
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
