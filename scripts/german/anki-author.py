#!/usr/bin/env python3
"""Author Anki decks from a TOML file: the authoring half, separate from the
client that reviews (deutsch-srs) and the server that stores (anki-sync-server).

A deck file is one `[notetype]`, then `[[deck]]` blocks, each holding
`[[deck.card]]` entries with `front`, `back` and `tags`, plus an optional
`requires` naming the card this one tests: the drill's prerequisite, and the
card to re-read when the drill keeps failing. Each card also carries an
`id-`/`req-` tag pair, which is how a reader resolves the edge without ids.
`check` validates the file and prints what it would build; `build` writes a
schema-11 collection that Anki and
the sync server both accept, either standalone or merged over an existing
collection. Merging reconciles by guid, so re-running a build after a card was
edited updates that note instead of adding a second copy.

Examples:
  anki-author check --deck decks/b2.toml
  anki-author build --deck decks/b2.toml --out b2.anki2
  anki-author build --deck decks/b2.toml --base collection.anki2 --out merged.anki2
  anki-author build --deck decks/b2.toml --out b2.apkg --format apkg
"""

import argparse
import hashlib
import html
import json
import os
import re
import shutil
import sqlite3
import string
import sys
import time
import zipfile

try:
    import tomllib
except ModuleNotFoundError:  # pragma: no cover - python < 3.11
    sys.exit("anki-author needs python 3.11+ (tomllib)")

# Schema 11 is the last one Anki publishes as a single SQLite file and the one
# the sync server migrates from, so it is what this tool writes.
SCHEMA_VERSION = 11

FIRST_NOTE_ID = 1_700_000_000_000

# What a `requires` edge looks like on the card, when the notetype does not say.
DEFAULT_REQUIRES_LABEL = "Requires"

DEFAULT_CONF = {
    "activeDecks": [1],
    "curDeck": 1,
    "newSpread": 0,
    "collapseTime": 1200,
    "timeLim": 0,
    "estTimes": True,
    "dueCounts": True,
    "curModel": None,
    "nextPos": 1,
    "sortType": "noteFld",
    "sortBackwards": False,
    "addToCur": True,
}

DEFAULT_DCONF = {
    "1": {
        "id": 1,
        "name": "Default",
        "mod": 0,
        "usn": 0,
        "maxTaken": 60,
        "autoplay": True,
        "replayq": True,
        "timer": 0,
        "new": {
            "delays": [1, 10],
            "order": 1,
            "initialFactor": 2500,
            "perDay": 20,
            "ints": [1, 4, 7],
            "separate": True,
            "bury": True,
        },
        "rev": {"perDay": 100, "ease4": 1.3, "fuzz": 0.05, "minSpace": 1, "maxIvl": 36500, "bury": True},
        "lapse": {"delays": [10], "mult": 0, "minInt": 1, "leechFails": 8, "leechAction": 0},
    }
}

DDL = """
CREATE TABLE col (
    id integer primary key, crt integer not null, mod integer not null,
    scm integer not null, ver integer not null, dty integer not null,
    usn integer not null, ls integer not null, conf text not null,
    models text not null, decks text not null, dconf text not null, tags text not null
);
CREATE TABLE notes (
    id integer primary key, guid text not null, mid integer not null,
    mod integer not null, usn integer not null, tags text not null,
    flds text not null, sfld integer not null, csum integer not null,
    flags integer not null, data text not null
);
CREATE TABLE cards (
    id integer primary key, nid integer not null, did integer not null,
    ord integer not null, mod integer not null, usn integer not null,
    type integer not null, queue integer not null, due integer not null,
    ivl integer not null, factor integer not null, reps integer not null,
    lapses integer not null, left integer not null, odue integer not null,
    odid integer not null, flags integer not null, data text not null
);
CREATE TABLE revlog (
    id integer primary key, cid integer not null, usn integer not null,
    ease integer not null, ivl integer not null, lastIvl integer not null,
    factor integer not null, time integer not null, type integer not null
);
CREATE TABLE graves (usn integer not null, oid integer not null, type integer not null);
CREATE INDEX ix_notes_usn on notes (usn);
CREATE INDEX ix_cards_usn on cards (usn);
CREATE INDEX ix_revlog_usn on revlog (usn);
CREATE INDEX ix_cards_nid on cards (nid);
CREATE INDEX ix_cards_sched on cards (did, queue, due);
CREATE INDEX ix_revlog_cid on revlog (cid);
CREATE INDEX ix_notes_csum on notes (csum);
"""


class DeckError(Exception):
    pass


def load(path):
    try:
        with open(path, "rb") as handle:
            data = tomllib.load(handle)
    except OSError as err:
        raise DeckError(str(err)) from err
    except tomllib.TOMLDecodeError as err:
        raise DeckError(f"{path}: {err}") from err
    if "notetype" not in data:
        raise DeckError("missing [notetype] block (id, name)")
    for key in ("id", "name"):
        if key not in data["notetype"]:
            raise DeckError(f"[notetype] needs {key}")
    decks = data.get("deck") or []
    if not decks:
        raise DeckError("no [[deck]] block")
    return data


def validate(data):
    notetype = data["notetype"]
    seen_ids = {notetype["id"]: "notetype"}
    total, report = 0, []
    for deck in data["deck"]:
        for key in ("id", "name"):
            if key not in deck:
                raise DeckError(f"[[deck]] needs {key}: {deck}")
        if deck["id"] in seen_ids:
            raise DeckError(f"id {deck['id']} used twice ({seen_ids[deck['id']]} and deck {deck['name']})")
        seen_ids[deck["id"]] = deck["name"]
        cards = deck.get("card") or []
        if not cards:
            raise DeckError(f"deck {deck['name']} has no [[deck.card]]")
        fronts = set()
        for index, card in enumerate(cards, 1):
            for key in ("front", "back"):
                if not str(card.get(key, "")).strip():
                    raise DeckError(f"{deck['name']} card {index}: empty {key}")
            if card["front"] in fronts:
                raise DeckError(f"{deck['name']} card {index}: duplicate front {card['front']!r}")
            fronts.add(card["front"])
        report.append((deck["name"], len(cards)))
        total += len(cards)
    return report, total


def slug(text):
    """`zwar … aber` -> `zwar-aber`, `während (kontrastiv)` -> `waehrend-kontrastiv`.

    The readable half of a card key, so it has to survive umlauts: tags are
    ASCII."""
    folded = text.lower().translate(
        str.maketrans({"ä": "ae", "ö": "oe", "ü": "ue", "ß": "ss"})
    )
    return re.sub(r"[^a-z0-9]+", "-", folded).strip("-")


# How much of the readable slug a card key keeps. Long enough to recognise in
# Anki's tag list, short enough that a paragraph-long task front stays a tag
# rather than a copy of the card.
CARD_KEY_HEAD = 40


def card_key(front):
    """The tag pair that makes a prerequisite edge walkable in the client.

    A card carries `id-<key>`, a drill carries `req-<key>`, so following the
    edge is a tag lookup — the reader never has to re-derive this function.
    The readable head says what the card is about; the digest keeps two long
    fronts that open the same way from colliding.
    """
    digest = hashlib.sha1(front.encode("utf-8")).hexdigest()[:6]
    head = slug(front)[:CARD_KEY_HEAD].rstrip("-")
    return f"{head}-{digest}" if head else digest


def prerequisites(data):
    """front -> the front it requires. Validated once, used by check and build."""
    by_front = {}
    for deck in data["deck"]:
        for card in deck["card"]:
            by_front.setdefault(card["front"], []).append(card)

    edges = {}
    for front, cards in by_front.items():
        for card in cards:
            target = card.get("requires")
            if target is None:
                continue
            if not isinstance(target, str) or not target.strip():
                raise DeckError(f"{front!r}: requires must name a card front")
            if target == front:
                raise DeckError(f"{front!r}: requires itself")
            matches = by_front.get(target) or []
            if not matches:
                near = sorted(
                    f
                    for f in by_front
                    if target.lower() in f.lower() or f.lower() in target.lower()
                )
                hint = f" — did you mean: {', '.join(repr(n) for n in near[:3])}" if near else ""
                raise DeckError(f"{front!r}: requires {target!r}, which is not a card here{hint}")
            if len(matches) > 1:
                raise DeckError(
                    f"{front!r}: requires {target!r}, which names {len(matches)} cards — "
                    "a prerequisite has to be unambiguous"
                )
            edges[front] = target

    # A prerequisite chain has to end somewhere, and it has to end at a card.
    for start in edges:
        seen, step = [start], edges[start]
        while step in edges:
            if step in seen:
                raise DeckError("requires cycle: " + " -> ".join([*seen, step]))
            seen.append(step)
            step = edges[step]
    return edges


def render_back(card, data, edges):
    """The authored back, then the rule this card tests."""
    target = edges.get(card["front"])
    if target is None:
        return card["back"]
    label = html.escape(data["notetype"].get("requires_label", DEFAULT_REQUIRES_LABEL))
    return f"{card['back']}<br><br><b>{label}:</b> <i>{html.escape(target)}</i>"


def note_tags(card, edges):
    tags = ["id-" + card_key(card["front"])]
    tags += [t for t in str(card.get("tags", "")).split() if t]
    target = edges.get(card["front"])
    if target is not None:
        tags.append("req-" + card_key(target))
    return f" {' '.join(tags)} " if tags else ""


def plain(html):
    text, depth = [], 0
    for ch in html:
        if ch == "<":
            depth += 1
        elif ch == ">":
            depth = max(0, depth - 1)
        elif depth == 0:
            text.append(ch)
    return "".join(text).strip()


def csum(sfld):
    return int(hashlib.sha1(sfld.encode("utf-8")).hexdigest()[:8], 16)


def notetype_json(data, now_ms):
    nt = data["notetype"]
    deck_id = data["deck"][0]["id"]

    def field(name, order):
        return {
            "name": name,
            "ord": order,
            "sticky": False,
            "rtl": False,
            "font": "Arial",
            "size": 20,
            "media": [],
        }

    return {
        "id": nt["id"],
        "name": nt["name"],
        "type": 0,
        "mod": now_ms // 1000,
        "usn": 0,
        "sortf": 0,
        "did": deck_id,
        "tmpls": [
            {
                "name": "Karte 1",
                "ord": 0,
                "qfmt": "{{Vorne}}",
                "afmt": "{{FrontSide}}<hr id=answer>{{Hinten}}",
                "bqfmt": "",
                "bafmt": "",
                "did": None,
                "bfont": "",
                "bsize": 0,
            }
        ],
        "flds": [field("Vorne", 0), field("Hinten", 1)],
        "css": (
            ".card {\n font-family: arial;\n font-size: 20px;\n text-align: left;\n"
            " color: black;\n background-color: white;\n}\n"
            ".nightMode .card { color: white; background-color: black; }\n"
            "i { color: #444; }\n.nightMode i { color: #bbb; }"
        ),
        "latexPre": "\\documentclass[12pt]{article}\\special{papersize=3in,5in}\\usepackage[utf8]{inputenc}"
        "\\usepackage{amssymb,amsmath}\\pagestyle{empty}\\setlength{\\parindent}{0in}\\begin{document}",
        "latexPost": "\\end{document}",
        "latexsvg": False,
        "req": [[0, "any", [0, 1]]],
        "tags": data["deck"][0].get("tags", []),
        "vers": [],
    }


def deck_json(deck, now_s):
    return {
        "id": deck["id"],
        "name": deck["name"],
        "desc": deck.get("description", ""),
        "conf": 1,
        "dyn": 0,
        "collapsed": False,
        "usn": 0,
        "mod": now_s,
        "newToday": [0, 0],
        "revToday": [0, 0],
        "lrnToday": [0, 0],
        "timeToday": [0, 0],
        "extendNew": 10,
        "extendRev": 50,
        "browserCollapsed": False,
    }


def schema11_base(base):
    """A `.apkg` is a zip holding collection.anki2; accept either form."""
    if not zipfile.is_zipfile(base):
        return base
    with zipfile.ZipFile(base) as archive:
        for name in ("collection.anki2", "collection.anki21"):
            if name in archive.namelist():
                target = f"{base}.{name}"
                with archive.open(name) as src, open(target, "wb") as dst:
                    shutil.copyfileobj(src, dst)
                return target
    raise DeckError(f"{base} is a zip without a collection inside")


def open_collection(path, base, now):
    if base:
        base = schema11_base(base)
        if os.path.exists(path) and os.path.samefile(path, base):
            raise DeckError("--out must differ from --base")
        shutil.copyfile(base, path)
        con = sqlite3.connect(path)
        version = con.execute("select ver from col").fetchone()[0]
        if version != SCHEMA_VERSION:
            con.close()
            raise DeckError(
                f"--base is schema {version}, not {SCHEMA_VERSION}: the sync server migrates a "
                "collection on upload, so merge over the original schema-11 file (the .apkg), "
                "not the copy downloaded back from the server"
            )
        return con

    if os.path.exists(path):
        os.remove(path)
    con = sqlite3.connect(path)
    con.executescript(DDL)
    con.execute(
        "insert into col (id, crt, mod, scm, ver, dty, usn, ls, conf, models, decks, dconf, tags)"
        " values (1, ?, ?, ?, ?, 0, 0, 0, ?, '{}', '{}', ?, '{}')",
        (
            now // 1000,
            now,
            now,
            SCHEMA_VERSION,
            json.dumps(DEFAULT_CONF),
            json.dumps(DEFAULT_DCONF),
        ),
    )
    return con


def guid_for(deck_id, front):
    """The identity of a card: same deck and front, same note, on every build."""
    return hashlib.sha1(f"{deck_id}\x00{front}".encode("utf-8")).hexdigest()[:16]


def insert(con, data, now, edges):
    """Add the notes this file does not have yet, update the ones it does.

    Rebuilding over the collection this tool produced has to be an edit, not a
    second copy: a drill that just gained a prerequisite keeps its review
    history, and a corrected back replaces the old one.
    """
    now_s = now // 1000
    key = str(data["notetype"]["id"])

    models = json.loads(con.execute("select models from col").fetchone()[0])
    decks = json.loads(con.execute("select decks from col").fetchone()[0])
    if key in models:
        fields = models[key].get("flds") or []
        if len(fields) != 2:
            raise DeckError(
                f"the collection's notetype {key} has {len(fields)} fields, but this tool "
                "writes two (Vorne/Hinten) — give the deck file a new notetype id"
            )
    else:
        models[key] = notetype_json(data, now)
    for deck in data["deck"]:
        entry = deck_json(deck, now_s)
        old = decks.get(str(deck["id"]))
        if old:
            # Keep a filtered deck filtered; the name and description still come
            # from the file, because renaming a deck is the author's decision.
            entry["conf"] = old.get("conf", 1)
            entry["dyn"] = old.get("dyn", 0)
        decks[str(deck["id"])] = entry
    con.execute(
        "update col set models = ?, decks = ?, mod = ?, usn = 1",
        (json.dumps(models, ensure_ascii=False), json.dumps(decks, ensure_ascii=False), now),
    )

    existing = dict(con.execute("select guid, id from notes").fetchall())
    # Ids and card ids share one counter above both tables, so a merge can never
    # hand out an id that the base collection already uses.
    counter = (
        max(
            con.execute("select coalesce(max(id), 0) from notes").fetchone()[0],
            con.execute("select coalesce(max(id), 0) from cards").fetchone()[0],
            FIRST_NOTE_ID - 1,
        )
        + 1
    )
    due = (con.execute("select coalesce(max(due), 0) from cards").fetchone()[0] or 0) + 1

    added = updated = 0
    for deck in data["deck"]:
        for card in deck["card"]:
            front = card["front"]
            sfld = plain(front)
            flds = front + "\x1f" + render_back(card, data, edges)
            tags = note_tags(card, edges)
            guid = guid_for(deck["id"], front)
            existing_id = existing.get(guid)
            if existing_id is not None:
                con.execute(
                    "update notes set mod = ?, usn = 0, tags = ?, flds = ?, sfld = ?, csum = ?"
                    " where id = ?",
                    (now_s, tags, flds, sfld, csum(sfld), existing_id),
                )
                updated += 1
                continue
            note_id = counter
            con.execute(
                "insert into notes (id,guid,mid,mod,usn,tags,flds,sfld,csum,flags,data)"
                " values (?,?,?,?,?,?,?,?,?,0,'')",
                (note_id, guid, data["notetype"]["id"], now_s, 0, tags, flds, sfld, csum(sfld)),
            )
            con.execute(
                "insert into cards (id,nid,did,ord,mod,usn,type,queue,due,ivl,factor,reps,lapses,"
                "left,odue,odid,flags,data)"
                " values (?,?,?,?,?,?,0,0,?,0,0,0,0,0,0,0,0,'')",
                (counter + 1, note_id, deck["id"], 0, now_s, 0, due),
            )
            added += 1
            counter += 2
            due += 1
    return added, updated


def write_apkg(anki2, out):
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as archive:
        archive.write(anki2, "collection.anki2")
        archive.writestr("media", "{}")


def cmd_check(args):
    data = load(args.deck)
    report, total = validate(data)
    edges = prerequisites(data)
    print(f"{args.deck}: notetype {data['notetype']['name']} ({data['notetype']['id']})")
    for name, count in report:
        print(f"  {count:4d}  {name}")
    print(f"  {total:4d}  cards, {len(report)} decks — ok")
    if edges:
        print(f"  {len(edges):4d}  require another card of this file")
    return 0


def cmd_build(args):
    data = load(args.deck)
    report, total = validate(data)
    edges = prerequisites(data)
    now = int(time.time() * 1000)

    out = args.out
    fmt = args.format
    if fmt == "apkg":
        work = out + ".anki2.tmp"
    else:
        work = out

    con = open_collection(work, args.base, now)
    try:
        added, updated = insert(con, data, now, edges)
        con.commit()
        con.execute("vacuum")
        con.commit()
        notes = con.execute("select count(*) from notes").fetchone()[0]
        cards = con.execute("select count(*) from cards").fetchone()[0]
    finally:
        con.close()

    if fmt == "apkg":
        write_apkg(work, out)
        os.remove(work)

    for name, count in report:
        print(f"{count:4d}  {name}")
    base_note = "standalone" if not args.base else f"merged over {args.base}"
    print(
        f"{added} added, {updated} updated, {base_note}; "
        f"collection now {notes} notes / {cards} cards -> {out}"
    )
    return 0


def main(argv=None):
    parser = argparse.ArgumentParser(prog="anki-author", description=__doc__.splitlines()[0])
    sub = parser.add_subparsers(dest="command", required=True)

    check = sub.add_parser("check", help="validate a deck file and count its cards")
    check.add_argument("--deck", required=True)
    check.set_defaults(func=cmd_check)

    build = sub.add_parser("build", help="write an .anki2 (or .apkg) from a deck file")
    build.add_argument("--deck", required=True)
    build.add_argument("--out", required=True)
    build.add_argument(
        "--base",
        help="existing collection to merge into (edits reconcile by guid, new cards are added)",
    )
    build.add_argument("--format", choices=("anki2", "apkg"), default="anki2")
    build.set_defaults(func=cmd_build)

    args = parser.parse_args(argv)
    try:
        return args.func(args)
    except DeckError as err:
        print(f"anki-author: {err}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
