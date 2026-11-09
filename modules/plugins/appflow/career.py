#!/usr/bin/env python3
"""career.py — add and edit the career corpus in the database.

The database is the source of truth for the CV prose. `lib/matt/resume.json` and
`lib/matt/lebenslauf.json` are exports: `export` rebuilds them from the rows, so
the committed files are an artifact of the database rather than a second place
where a role can be added and forgotten.

Two tables, because the artifacts join them differently: a role is identified by
its employer, a translated project by its English name (`resumeName`). One row is
one language, so the German corpus is edited in the same place as the English one
and neither can quietly fall behind.

    career.py roles [--language en]          the corpus, in CV order
    career.py projects [--language de]
    career.py show role ID
    career.py add role --employer … --position …
    career.py add project --name …
    career.py set role ID --position "Lead"  only the flags you give change
    career.py rm project ID --yes           --yes is required: deleting prose is final
    career.py import --from FILE [--language en] [--dry]
    career.py export --into lib/matt/resume.json

Reads come from `/api/career-roles` and `/api/career-projects`; writes post to
`career-role-upsert` / `career-project-upsert`. A list is stored as text — one
highlight per line, one comma-separated keyword — so the row is editable with
psql too (modules/plugins/appflow/schema.sql).

`import` is the migration and the re-seed: every entry becomes a row keyed by a
derived id (`role-<employer>-<year>`, `project-<english-name>-<year>`), so
running it again updates the same rows instead of appending copies. `export`
then has to reproduce the file it read, and the fixture asserts exactly that.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request

DEFAULT_API = os.environ.get(
    "APPFLOW_API", "https://delphi.cloudforest-kardashev.ts.net:8450"
)


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


# flag dest -> wire key, in the order an argument list reads. `str` copies the
# value, the two functions turn a repeated flag into the row's text form.
ROLE_FIELDS = [
    ("employer", "employer", str),
    ("position", "position", str),
    ("location", "location", str),
    ("url", "url", str),
    ("start", "startDate", str),
    ("end", "endDate", str),
    ("description", "description", str),
    ("summary", "summary", str),
    ("highlight", "highlights", joined_lines),
    ("keyword", "keywords", joined_tags),
]

PROJECT_FIELDS = [
    ("name", "name", str),
    ("resume_name", "resumeName", str),
    ("entity", "entity", str),
    ("type", "type", str),
    ("url", "url", str),
    ("start", "startDate", str),
    ("end", "endDate", str),
    ("description", "description", str),
    ("highlight", "highlights", joined_lines),
    ("keyword", "keywords", joined_tags),
    ("role", "roles", joined_tags),
]

FIELDS = {"role": ROLE_FIELDS, "project": PROJECT_FIELDS}

# wire key -> artifact key, for the export. The corpus is JSON Resume, and the
# keys are its names rather than the column names.
ROLE_ARTIFACT = [
    ("name", "employer"),
    ("position", "position"),
    ("location", "location"),
    ("url", "url"),
    ("startDate", "startDate"),
    ("endDate", "endDate"),
    ("description", "description"),
    ("summary", "summary"),
    ("highlights", "highlights"),
    ("keywords", "keywords"),
]

PROJECT_ARTIFACT = [
    ("name", "name"),
    ("resumeName", "resumeName"),
    ("entity", "entity"),
    ("type", "type"),
    ("url", "url"),
    ("startDate", "startDate"),
    ("endDate", "endDate"),
    ("description", "description"),
    ("highlights", "highlights"),
    ("keywords", "keywords"),
    ("roles", "roles"),
]

ARTIFACT = {"role": ROLE_ARTIFACT, "project": PROJECT_ARTIFACT}

LIST_FIELDS = {"highlights"}
TAG_FIELDS = {"keywords", "roles"}

# flag dest -> key in a JSON Resume entry, for `import`.
ENTRY_KEY = {
    "employer": "name",
    "start": "startDate",
    "end": "endDate",
    "highlight": "highlights",
    "keyword": "keywords",
    "resume_name": "resumeName",
    "role": "roles",
}


# --- the wire ---------------------------------------------------------------


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


def rows(api: str, table: str) -> list[dict]:
    return get(api, f"/api/career-{table}s") or []


def upsert(api: str, table: str, payload: dict) -> dict:
    result = post(api, f"/api/career-{table}-upsert", payload)
    return (result or [{}])[0]


def delete(api: str, table: str, row_id: str, language: str) -> list[dict]:
    return post(
        api,
        f"/api/career-{table}-delete",
        {"id": row_id, "language": language},
    ) or []


# --- ids --------------------------------------------------------------------


def slug(text: str | None) -> str:
    return re.sub(r"[^a-z0-9]+", "-", (text or "").lower()).strip("-")[:56] or "unknown"


def year(date: str | None) -> str:
    return (date or "")[:4] or "undated"


def derived_id(table: str, entry: dict) -> str:
    if table == "role":
        return f"role-{slug(entry.get('name'))}-{year(entry.get('startDate'))}"
    # A translated project names its English counterpart, and the id has to match
    # the English row's so both languages agree on what the project is.
    base = entry.get("resumeName") or entry.get("name")
    return f"project-{slug(base)}-{year(entry.get('startDate'))}"


# --- reading ----------------------------------------------------------------


def ordered(items: list[dict]) -> list[dict]:
    return sorted(items, key=lambda row: (row.get("sort") or 0, row.get("id") or ""))


def role_line(row: dict) -> str:
    span = " - ".join(part for part in (row.get("startDate"), row.get("endDate")) if part)
    return f"{row.get('id', ''):<40} {row.get('language', ''):<3} {(row.get('position') or '')[:28]:<28} {(row.get('employer') or '')[:26]:<26} {span}"


def project_line(row: dict) -> str:
    span = " - ".join(part for part in (row.get("startDate"), row.get("endDate")) if part)
    return f"{row.get('id', ''):<48} {row.get('language', ''):<3} {(row.get('name') or '')[:44]:<44} {span}"


LINE = {"role": role_line, "project": project_line}


def print_rows(table: str, items: list[dict]) -> None:
    if not items:
        print(f"no {table}s")
        return
    for item in items:
        print(LINE[table](item))


def find(api: str, table: str, row_id: str, language: str | None = None) -> list[dict]:
    """Every row with this id, narrowed by language. The id is shared across the
    two corpora, so a write that names neither is ambiguous, not lucky."""
    return [
        row
        for row in rows(api, table)
        if row.get("id") == row_id and (language is None or row.get("language") == language)
    ]


def one(api: str, table: str, row_id: str, language: str | None) -> dict | None:
    found = find(api, table, row_id, language)
    if len(found) > 1:
        languages = ", ".join(sorted(row.get("language") or "?" for row in found))
        print(
            f"{table} {row_id} exists in {languages}; pass --language",
            file=sys.stderr,
        )
        return None
    return found[0] if found else None


# --- writing ----------------------------------------------------------------


def payload(table: str, args: argparse.Namespace, row: dict | None = None) -> dict:
    """Every parameter the endpoint needs, taken from `row` and overridden by flags."""
    row = row or {}
    out = {wire: row.get(wire) for _, wire, _ in FIELDS[table]}
    out["id"] = args.id or row.get("id")
    out["language"] = args.language or row.get("language") or "en"
    out["sort"] = row.get("sort")
    for dest, wire, convert in FIELDS[table]:
        value = getattr(args, dest, None)
        if value is not None:
            out[wire] = value if convert is str else convert(value)
    return out


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


def add(api: str, table: str, args: argparse.Namespace, dry: bool) -> int:
    if table == "role" and not (args.employer and args.position):
        print("add role: --employer and --position are required", file=sys.stderr)
        return 2
    if table == "project" and not args.name:
        print("add project: --name is required", file=sys.stderr)
        return 2
    language = args.language or "en"
    body = payload(table, args)
    if not body["id"]:
        body["id"] = derived_id(table, body)
    body["language"] = language
    # An add must not silently overwrite: a derived id that already exists is a
    # second role at the same employer in the same year, and the caller has to
    # say which one it means.
    existing = find(api, table, body["id"], language)
    if existing and not args.replace:
        print(
            f"add {table}: {body['id']} already exists in {language};"
            f" use `set-{table} {body['id']}` or --replace",
            file=sys.stderr,
        )
        return 1
    body["sort"] = None
    write(api, table, body, dry)
    return 0


def set_row(api: str, table: str, args: argparse.Namespace, dry: bool) -> int:
    row = one(api, table, args.id, args.language)
    if row is None:
        print(f"set {table}: no {table} {args.id}", file=sys.stderr)
        return 1
    changed = [
        dest for dest, _, _ in FIELDS[table] if getattr(args, dest, None) is not None
    ]
    if not changed:
        print(f"set {table}: nothing to change", file=sys.stderr)
        return 2
    body = payload(table, args, row)
    # `--language` selects a row; it never moves one. The pair (id, language) is
    # the key, so posting the flag as a value would write a second row rather
    # than edit this one.
    body["language"] = row["language"]
    write(api, table, body, dry)
    print(f"changed: {', '.join(changed)}", file=sys.stderr)
    return 0


def remove(api: str, table: str, args: argparse.Namespace, dry: bool) -> int:
    row = one(api, table, args.id, args.language)
    if row is None:
        print(f"rm {table}: no {table} {args.id}", file=sys.stderr)
        return 1
    if not args.yes:
        print(
            f"rm {table}: {args.id} ({row.get('language')}) would be deleted; pass --yes",
            file=sys.stderr,
        )
        return 2
    if dry:
        print(f"would delete {table} {args.id} ({row.get('language')})")
        return 0
    removed = delete(api, table, args.id, args.language or row.get("language") or "en")
    if not removed:
        print(f"rm {table}: the endpoint removed nothing for {args.id}", file=sys.stderr)
        return 1
    print(f"deleted {table} {args.id} ({removed[0].get('language')})")
    return 0


def do_import(api: str, args: argparse.Namespace) -> int:
    raw = sys.stdin.read() if args.source == "-" else open(args.source, encoding="utf-8").read()
    document = json.loads(raw)
    if not isinstance(document, dict):
        print("import: the source is not a JSON Resume object", file=sys.stderr)
        return 2
    language = args.language or "en"
    written = 0
    for table, key in (("role", "work"), ("project", "projects")):
        entries = document.get(key) or []
        for index, entry in enumerate(entries):
            body = {wire: None for _, wire, _ in FIELDS[table]}
            body["id"] = derived_id(table, entry)
            body["language"] = language
            body["sort"] = index
            for dest, wire, convert in FIELDS[table]:
                name = ENTRY_KEY.get(dest, dest)
                if name not in entry:
                    continue
                value = entry[name]
                if convert is not str:
                    value = convert(value) if value is not None else None
                body[wire] = value
            if args.dry:
                print(json.dumps(body, ensure_ascii=False, sort_keys=True))
            else:
                upsert(api, table, body)
            written += 1
    print(f"imported {written} entries as {language} from {args.source}")
    return 0


def do_export(api: str, args: argparse.Namespace) -> int:
    language = args.language or "en"
    try:
        with open(args.into, encoding="utf-8") as handle:
            document = json.load(handle)
    except FileNotFoundError:
        document = {}
    if not isinstance(document, dict):
        print(f"export: {args.into} is not a JSON Resume object", file=sys.stderr)
        return 2

    for table, key in (("role", "work"), ("project", "projects")):
        selected = [row for row in rows(api, table) if row.get("language") == language]
        entries = []
        for row in ordered(selected):
            entry = {}
            for name, column in ARTIFACT[table]:
                value = row.get(column)
                if value is None:
                    continue
                if name in LIST_FIELDS:
                    entry[name] = split_lines(value)
                elif name in TAG_FIELDS:
                    entry[name] = split_tags(value)
                else:
                    entry[name] = value
            entries.append(entry)
        document[key] = entries
        print(f"{key}: {len(entries)} from {language} rows")

    out = args.out or args.into
    with open(out, "w", encoding="utf-8") as handle:
        # Sorted keys and a two-space indent, the shape `task matt:gist:sync`
        # writes with `jq -S`, so a re-export is a no-op in git.
        handle.write(json.dumps(document, ensure_ascii=False, indent=2, sort_keys=True) + "\n")
    print(f"wrote {out}")
    return 0


# --- the command line -------------------------------------------------------


def add_common(parser: argparse.ArgumentParser, table: str, required: bool) -> None:
    # `--dry` is top-level and accepted after the verb too, because a task appends
    # its CLI_ARGS at the end of the command line.
    parser.add_argument("--dry", action="store_true", default=argparse.SUPPRESS)
    parser.add_argument("--id", default=None, help="row id; derived from the entry when absent")
    parser.add_argument("--language", default=None, help="en or de (default en)")
    for dest, _, convert in FIELDS[table]:
        if dest in ("highlight", "keyword", "role"):
            parser.add_argument(
                f"--{dest.replace('_', '-')}",
                action="append",
                default=None,
                metavar="TEXT",
                help="repeatable",
            )
            continue
        flag = f"--{dest.replace('_', '-')}"
        help_text = "required" if required and dest in ("employer", "position", "name") else dest
        parser.add_argument(flag, default=None, help=help_text)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--api", default=DEFAULT_API)
    parser.add_argument("--dry", action="store_true", help="print the body instead of writing it")
    sub = parser.add_subparsers(dest="command", required=True)

    show = sub.add_parser("show", help="one row, every field")
    show.add_argument("table", choices=["role", "project"])
    show.add_argument("id")

    for table in ("role", "project"):
        listing = sub.add_parser(f"{table}s", help=f"list {table}s in CV order")
        listing.add_argument("--language", default=None)
        listing.add_argument("--json", action="store_true")

        adder = sub.add_parser(f"add-{table}", help=f"add or replace a {table}")
        add_common(adder, table, required=True)
        adder.add_argument("--replace", action="store_true", help="overwrite an existing id")

        setter = sub.add_parser(f"set-{table}", help=f"edit fields of one {table}")
        setter.add_argument("id")
        add_common(setter, table, required=False)

        remover = sub.add_parser(f"rm-{table}", help=f"delete one {table}")
        remover.add_argument("id")
        remover.add_argument("--language", default=None)
        remover.add_argument("--yes", action="store_true", help="required")

    importer = sub.add_parser("import", help="load a JSON Resume's work and projects into the rows")
    importer.add_argument("--dry", action="store_true", default=argparse.SUPPRESS)
    importer.add_argument("--from", dest="source", required=True, help="JSON Resume file, or - for stdin")
    importer.add_argument("--language", default=None)

    exporter = sub.add_parser("export", help="rebuild a JSON Resume's work and projects from the rows")
    exporter.add_argument("--into", required=True, help="the document to merge into (basics, skills, education)")
    exporter.add_argument("--out", default=None, help="write here instead of in place")
    exporter.add_argument("--language", default=None)

    args = parser.parse_args()
    api = args.api.rstrip("/")

    if args.command in ("roles", "projects"):
        table = args.command[:-1]
        items = rows(api, table)
        if args.language:
            items = [row for row in items if row.get("language") == args.language]
        items = ordered(items)
        if args.json:
            print(json.dumps(items, ensure_ascii=False))
        else:
            print_rows(table, items)
        return 0

    if args.command == "show":
        found = find(api, args.table, args.id)
        if not found:
            print(f"show: no {args.table} {args.id}", file=sys.stderr)
            return 1
        for row in ordered(found):
            print(json.dumps(row, ensure_ascii=False, indent=2, sort_keys=True))
        return 0

    if args.command.startswith("add-"):
        return add(api, args.command[4:], args, args.dry)
    if args.command.startswith("set-"):
        return set_row(api, args.command[4:], args, args.dry)
    if args.command.startswith("rm-"):
        return remove(api, args.command[3:], args, args.dry)
    if args.command == "import":
        return do_import(api, args)
    if args.command == "export":
        return do_export(api, args)
    return 2


if __name__ == "__main__":
    try:
        sys.exit(main())
    except urllib.error.HTTPError as error:
        body = error.read().decode(errors="replace")[:300]
        print(f"career: HTTP {error.code} from {error.url}: {body}", file=sys.stderr)
        sys.exit(2)
    except urllib.error.URLError as error:
        print(f"career: cannot reach {error.filename or DEFAULT_API}: {error.reason}", file=sys.stderr)
        sys.exit(2)
