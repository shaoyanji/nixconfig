#!/usr/bin/env python3
"""portfolio.py — add and edit the Bountystash portfolio's projects in the database.

The rows are the source; `lib/bountystash/portfolio.json` and its German copy
`portfolio.de.json` are exports. The capsule that renders them
(`lib/gemini-portal.nix`) slugs a project by its title, so the id is derived from
that title and a translated row joins on `sourceTitle`, the English title — a
translation may rename the project but never introduce one.

    portfolio.py projects [--language en]
    portfolio.py show ID
    portfolio.py add-project --title … --sector 1 --link "Label=https://…"
    portfolio.py set-project ID --featured / --no-featured
    portfolio.py rm-project ID --yes
    portfolio.py import --from lib/bountystash/portfolio.json [--language de]
    portfolio.py export --into lib/bountystash/portfolio.json

The German corpus carries no English title, so importing it pairs rows by
position with the English rows already stored: the two files are parallel, and a
count mismatch is refused rather than paired by guess. That is why `--language de`
needs the English import to have run first.

A list is text in the row (content_api.py): `stack` comma-separated, `highlights`
one per line, `links` one `label<TAB>href` per line. A row's `NULL` means the
artifact omits the field and `''` that it has an empty one, which is what makes
the round trip byte-comparable.
"""

from __future__ import annotations

import argparse
import json
import sys
import urllib.error

from content_api import (
    DEFAULT_API,
    delete,
    find,
    joined_lines,
    joined_tags,
    one,
    ordered,
    rows,
    slug,
    split_lines,
    split_tags,
    upsert,
    write,
)

TABLE = "portfolio_project"

def joined_links(items: list[dict]) -> str:
    """`links` as the row holds it: one `label<TAB>href` per line."""
    return "\n".join(f"{item.get('label', '')}\t{item.get('href', '')}" for item in items)


def split_links(text: str | None) -> list[dict] | None:
    if text is None:
        return None
    links = []
    for line in text.split("\n"):
        if not line.strip():
            continue
        label, _, href = line.partition("\t")
        links.append({"label": label.strip(), "href": href.strip()})
    return links


def parse_link(value: str) -> dict:
    label, sep, href = value.partition("=")
    if not sep or not href.strip():
        raise argparse.ArgumentTypeError(f"--link wants Label=href, got {value!r}")
    return {"label": label.strip(), "href": href.strip()}



# flag dest -> wire key, in the order an argument list reads.
FIELDS = [
    ("title", "title", str),
    ("source_title", "sourceTitle", str),
    ("role", "role", str),
    ("period", "period", str),
    ("badge", "badge", str),
    ("sector", "sector", int),
    ("description", "description", str),
    ("stack", "stack", joined_tags),
    ("impact", "impact", str),
    ("highlight", "highlights", joined_lines),
    ("link", "link", str),
    ("links", "links", joined_links),
    ("featured", "featured", bool),
]

# wire key -> artifact key. `sourceTitle` is the join key, not a field the capsule
# reads, so it is never exported.
ARTIFACT = [
    ("title", "title"),
    ("role", "role"),
    ("period", "period"),
    ("badge", "badge"),
    ("sector", "sector"),
    ("description", "description"),
    ("stack", "stack"),
    ("impact", "impact"),
    ("highlights", "highlights"),
    ("link", "link"),
    ("links", "links"),
    ("featured", "featured"),
]

TAG_FIELDS = {"stack"}

# flag dest -> key in a portfolio entry, for `import`; only the plural differs.
ENTRY_KEY = {"highlight": "highlights"}


def derived_id(entry: dict) -> str:
    return f"project-{slug(entry.get('title'))}"


def portfolio_line(row: dict) -> str:
    return (
        f"{row.get('id', ''):<48} {row.get('language', ''):<3}"
        f" {(row.get('title') or '')[:48]:<48} {row.get('period') or ''}"
    )


def payload(args: argparse.Namespace, row: dict | None = None) -> dict:
    row = row or {}
    out = {wire: row.get(wire) for _, wire, _ in FIELDS}
    out["id"] = args.id or row.get("id")
    out["language"] = args.language or row.get("language") or "en"
    out["sort"] = row.get("sort")
    for dest, wire, convert in FIELDS:
        value = getattr(args, dest, None)
        if value is not None:
            if convert is str:
                out[wire] = value
            elif convert is bool:
                out[wire] = value
            else:
                out[wire] = convert(value)
    return out


def add(api: str, args: argparse.Namespace, dry: bool) -> int:
    if not args.title:
        print("add-project: --title is required", file=sys.stderr)
        return 2
    language = args.language or "en"
    body = payload(args)
    body["id"] = body["id"] or derived_id(body)
    body["language"] = language
    if language != "en" and not body.get("sourceTitle"):
        print(
            "add-project: a translated project needs --source-title (its English title)",
            file=sys.stderr,
        )
        return 2
    existing = find(api, TABLE, body["id"], language)
    if existing and not args.replace:
        print(
            f"add-project: {body['id']} already exists in {language};"
            f" use `set-project {body['id']}` or --replace",
            file=sys.stderr,
        )
        return 1
    body["sort"] = None
    write(api, TABLE, body, dry)
    return 0


def set_row(api: str, args: argparse.Namespace, dry: bool) -> int:
    row = one(api, TABLE, args.id, args.language)
    if row is None:
        print(f"set-project: no project {args.id}", file=sys.stderr)
        return 1
    changed = [dest for dest, _, _ in FIELDS if getattr(args, dest, None) is not None]
    if not changed:
        print("set-project: nothing to change", file=sys.stderr)
        return 2
    body = payload(args, row)
    body["language"] = row["language"]
    write(api, TABLE, body, dry)
    print(f"changed: {', '.join(changed)}", file=sys.stderr)
    return 0


def remove(api: str, args: argparse.Namespace, dry: bool) -> int:
    row = one(api, TABLE, args.id, args.language)
    if row is None:
        print(f"rm-project: no project {args.id}", file=sys.stderr)
        return 1
    if not args.yes:
        print(
            f"rm-project: {args.id} ({row.get('language')}) would be deleted; pass --yes",
            file=sys.stderr,
        )
        return 2
    if dry:
        print(f"would delete project {args.id} ({row.get('language')})")
        return 0
    removed = delete(api, TABLE, args.id, args.language or row.get("language") or "en")
    if not removed:
        print(f"rm-project: the endpoint removed nothing for {args.id}", file=sys.stderr)
        return 1
    print(f"deleted project {args.id} ({removed[0].get('language')})")
    return 0


def do_import(api: str, args: argparse.Namespace) -> int:
    raw = sys.stdin.read() if args.source == "-" else open(args.source, encoding="utf-8").read()
    document = json.loads(raw)
    if not isinstance(document, dict) or not isinstance(document.get("projects", []), list):
        print("import: the source is not a portfolio object with a projects list", file=sys.stderr)
        return 2
    language = args.language or "en"
    entries = document.get("projects") or []

    # The German file names no English project, so the two corpora are paired by
    # position. Refusing a count mismatch is the whole guard: a shift by one would
    # attach German prose to the wrong project, and nothing downstream can see it.
    english = ordered([row for row in rows(api, TABLE) if row.get("language") == "en"])
    if language != "en":
        if len(english) != len(entries):
            print(
                f"import: {len(entries)} German projects, {len(english)} English rows;"
                " import the English corpus first and keep the two parallel",
                file=sys.stderr,
            )
            return 1

    written = 0
    for index, entry in enumerate(entries):
        body = {wire: None for _, wire, _ in FIELDS}
        body["language"] = language
        body["sort"] = index
        for dest, wire, convert in FIELDS:
            name = ENTRY_KEY.get(dest, "sourceTitle" if dest == "source_title" else dest)
            if name not in entry:
                continue
            value = entry[name]
            body[wire] = value if convert is str else convert(value)
        if language == "en":
            body["id"] = derived_id(entry)
        else:
            body["id"] = english[index]["id"]
            body["sourceTitle"] = english[index]["title"]
        if args.dry:
            print(json.dumps(body, ensure_ascii=False, sort_keys=True))
        else:
            upsert(api, TABLE, body)
        written += 1
    print(f"imported {written} projects as {language} from {args.source}")
    return 0


def do_export(api: str, args: argparse.Namespace) -> int:
    language = args.language or "en"
    try:
        with open(args.into, encoding="utf-8") as handle:
            document = json.load(handle)
    except FileNotFoundError:
        document = {}
    if not isinstance(document, dict):
        print(f"export: {args.into} is not a portfolio object", file=sys.stderr)
        return 2

    selected = ordered([row for row in rows(api, TABLE) if row.get("language") == language])
    entries = []
    for row in selected:
        entry = {}
        for name, column in ARTIFACT:
            value = row.get(column)
            if value is None:
                continue
            if name == "highlights":
                entry[name] = split_lines(value)
            elif name in TAG_FIELDS:
                entry[name] = split_tags(value)
            elif name == "links":
                entry[name] = split_links(value)
            else:
                entry[name] = value
        entries.append(entry)
    document["projects"] = entries

    out = args.out or args.into
    with open(out, "w", encoding="utf-8") as handle:
        handle.write(json.dumps(document, ensure_ascii=False, indent=2, sort_keys=True) + "\n")
    print(f"projects: {len(entries)} from {language} rows")
    print(f"wrote {out}")
    return 0


def add_common(parser: argparse.ArgumentParser, required: bool) -> None:
    parser.add_argument("--dry", action="store_true", default=argparse.SUPPRESS)
    parser.add_argument("--id", default=None, help="row id; derived from the title when absent")
    parser.add_argument("--language", default=None, help="en or de (default en)")
    for dest, _, convert in FIELDS:
        flag = f"--{dest.replace('_', '-')}"
        if dest in ("stack", "highlight"):
            parser.add_argument(flag, action="append", default=None, metavar="TEXT", help="repeatable")
        elif dest == "links":
            parser.add_argument(flag, action="append", default=None, type=parse_link, metavar="LABEL=HREF", help="repeatable")
        elif dest == "featured":
            parser.add_argument(flag, action=argparse.BooleanOptionalAction, default=None)
        elif convert is int:
            parser.add_argument(flag, type=int, default=None)
        else:
            parser.add_argument(flag, default=None, help="required" if required and dest == "title" else dest)


def main() -> int:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("--api", default=DEFAULT_API)
    parser.add_argument("--dry", action="store_true", help="print the body instead of writing it")
    sub = parser.add_subparsers(dest="command", required=True)

    listing = sub.add_parser("projects", help="list projects in page order")
    listing.add_argument("--language", default=None)
    listing.add_argument("--json", action="store_true")

    show = sub.add_parser("show", help="one project, every field")
    show.add_argument("id")

    adder = sub.add_parser("add-project", help="add or replace a project")
    add_common(adder, required=True)
    adder.add_argument("--replace", action="store_true", help="overwrite an existing id")

    setter = sub.add_parser("set-project", help="edit fields of one project")
    setter.add_argument("id")
    add_common(setter, required=False)

    remover = sub.add_parser("rm-project", help="delete one project")
    remover.add_argument("id")
    remover.add_argument("--language", default=None)
    remover.add_argument("--yes", action="store_true", help="required")

    importer = sub.add_parser("import", help="load a portfolio's projects into the rows")
    importer.add_argument("--dry", action="store_true", default=argparse.SUPPRESS)
    importer.add_argument("--from", dest="source", required=True, help="portfolio JSON, or - for stdin")
    importer.add_argument("--language", default=None)

    exporter = sub.add_parser("export", help="rebuild a portfolio's projects from the rows")
    exporter.add_argument("--into", required=True, help="the document to merge into")
    exporter.add_argument("--out", default=None, help="write here instead of in place")
    exporter.add_argument("--language", default=None)

    args = parser.parse_args()
    api = args.api.rstrip("/")

    if args.command == "projects":
        items = rows(api, TABLE)
        if args.language:
            items = [row for row in items if row.get("language") == args.language]
        items = ordered(items)
        if args.json:
            print(json.dumps(items, ensure_ascii=False))
        elif not items:
            print("no projects")
        else:
            for item in items:
                print(portfolio_line(item))
        return 0

    if args.command == "show":
        found = find(api, TABLE, args.id)
        if not found:
            print(f"show: no project {args.id}", file=sys.stderr)
            return 1
        for row in ordered(found):
            print(json.dumps(row, ensure_ascii=False, indent=2, sort_keys=True))
        return 0

    if args.command == "add-project":
        return add(api, args, args.dry)
    if args.command == "set-project":
        return set_row(api, args, args.dry)
    if args.command == "rm-project":
        return remove(api, args, args.dry)
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
        print(f"portfolio: HTTP {error.code} from {error.url}: {body}", file=sys.stderr)
        sys.exit(2)
    except urllib.error.URLError as error:
        print(f"portfolio: cannot reach {error.filename or DEFAULT_API}: {error.reason}", file=sys.stderr)
        sys.exit(2)
