"""The wire half the content CLIs share: HTTP, row lookup, and the text forms.

`career.py` and `portfolio.py` write two different vocabularies through the same
NpgsqlRest pattern — one GET per table, one upsert, one delete, camelCase
parameters, `sort: null` appends. This module is that pattern once, so a third
corpus is a field map rather than a third client.

Endpoint names come from the table, not a literal: `career_role` is published as
`/api/career-roles`, which is what the SQL file is called.
"""

from __future__ import annotations

import json
import os
import re
import sys
import urllib.error
import urllib.request

DEFAULT_API = os.environ.get(
    "APPFLOW_API", "https://delphi.cloudforest-kardashev.ts.net:8450"
)


# --- HTTP -------------------------------------------------------------------


def get(api: str, path: str) -> object:
    with urllib.request.urlopen(f"{api}{path}", timeout=30) as response:
        return json.loads(response.read().decode() or "null")


def post(api: str, path: str, payload: dict) -> object:
    request = urllib.request.Request(
        f"{api}{path}",
        data=json.dumps(payload).encode(),
        headers={"content-type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        body = response.read().decode() or "null"
    return json.loads(body)


def route(table: str) -> str:
    return table.replace("_", "-")


def rows(api: str, table: str) -> list[dict]:
    return get(api, f"/api/{route(table)}s") or []


def upsert(api: str, table: str, payload: dict) -> dict:
    result = post(api, f"/api/{route(table)}-upsert", payload)
    return (result or [{}])[0]


def delete(api: str, table: str, row_id: str, language: str) -> list[dict]:
    return post(
        api,
        f"/api/{route(table)}-delete",
        {"id": row_id, "language": language},
    ) or []


# --- lookup -----------------------------------------------------------------


def find(api: str, table: str, row_id: str, language: str | None = None) -> list[dict]:
    """Every row with this id, narrowed by language. The id is shared across the
    languages, so a write that names neither is ambiguous, not lucky."""
    return [
        row
        for row in rows(api, table)
        if row.get("id") == row_id and (language is None or row.get("language") == language)
    ]


def one(api: str, table: str, row_id: str, language: str | None) -> dict | None:
    found = find(api, table, row_id, language)
    if len(found) > 1:
        languages = ", ".join(sorted(row.get("language") or "?" for row in found))
        print(f"{table} {row_id} exists in {languages}; pass --language", file=sys.stderr)
        return None
    return found[0] if found else None


def ordered(items: list[dict]) -> list[dict]:
    return sorted(items, key=lambda row: (row.get("sort") or 0, row.get("id") or ""))


def write(api: str, table: str, body: dict, dry: bool) -> dict:
    if dry:
        print(json.dumps(body, ensure_ascii=False, indent=2, sort_keys=True))
        return body
    result = upsert(api, table, body)
    print(
        f"{result.get('id', body['id'])}  language={result.get('language', body['language'])}"
        f"  sort={result.get('sort', body.get('sort'))}"
    )
    return result


# --- text forms -------------------------------------------------------------
#
# A list is text in the row: one item per line, or comma-separated tags. NULL
# means the artifact has no such field and '' that it has an empty one; the
# export keeps the difference so a round trip is byte-comparable.


def joined_lines(items: list[str]) -> str:
    return "\n".join(items)


def joined_tags(items: list[str]) -> str:
    return ",".join(items)


def split_lines(text: str | None) -> list[str] | None:
    if text is None:
        return None
    return text.split("\n") if text != "" else []


def split_tags(text: str | None) -> list[str] | None:
    if text is None:
        return None
    return [tag.strip() for tag in text.split(",") if tag.strip()]


# --- artifact shape ---------------------------------------------------------


def keep_order(entry: dict, previous: dict | None) -> dict:
    """Order a rebuilt entry like the one it replaces.

    The committed artifacts disagree on key order: one CV is `jq -S` output and
    the portfolio is hand-ordered, so the writer cannot choose a canonical order
    without rewriting a document it did not author. Keys the previous entry did
    not have keep the position the field table gave them.
    """
    if not previous:
        return entry
    shaped = {key: entry[key] for key in previous if key in entry}
    shaped.update({key: value for key, value in entry.items() if key not in shaped})
    return shaped


# --- ids --------------------------------------------------------------------


def slug(text: str | None) -> str:
    return re.sub(r"[^a-z0-9]+", "-", (text or "").lower()).strip("-")[:56] or "unknown"


def year(date: str | None) -> str:
    return (date or "")[:4] or "undated"
