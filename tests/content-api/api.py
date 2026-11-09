#!/usr/bin/env python3
"""A stand-in for the archive's career and portfolio endpoints.

Shared by tests/career-cli and tests/portfolio-cli, because both CLIs speak the
same wire: one GET per table, one upsert, one delete, camelCase keys, `sort:
null` appends within a language. A stub per CLI would let the two drift apart
without either fixture noticing.

It is not a database. Two behaviours are deliberate:

* an upsert with a key missing is refused, because NpgsqlRest answers a missing
  parameter with a 404 and a test that tolerated a sparse body would pass a
  client the real endpoint rejects;
* `sort: null` appends, the same rule the SQL implements.

Binds 127.0.0.1 on an ephemeral port and prints `PORT=<n>` so a test never picks
a port twice.
"""

import json
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer

REQUIRED = {
    "career_role": [
        "id", "language", "employer", "position", "location", "url",
        "startDate", "endDate", "description", "summary", "highlights",
        "keywords", "sort",
    ],
    "career_project": [
        "id", "language", "name", "resumeName", "entity", "type", "url",
        "startDate", "endDate", "description", "highlights", "keywords",
        "roles", "sort",
    ],
    "portfolio_project": [
        "id", "language", "title", "sourceTitle", "role", "period", "badge",
        "sector", "description", "stack", "impact", "highlights", "link",
        "links", "featured", "sort",
    ],
}

STATE = {table: [] for table in REQUIRED}


def route(table):
    """The endpoint name: NpgsqlRest derives it from the file, not the table."""
    return table.replace("_", "-")


def upsert(table, body):
    missing = [key for key in REQUIRED[table] if key not in body]
    if missing:
        raise ValueError(f"missing parameter: {missing[0]}")
    row = {key: body[key] for key in REQUIRED[table]}
    row["language"] = row["language"] or "en"
    if row["sort"] is None:
        same = [item["sort"] or 0 for item in STATE[table] if item["language"] == row["language"]]
        row["sort"] = max(same) + 1 if same else 0
    for index, item in enumerate(STATE[table]):
        if item["id"] == row["id"] and item["language"] == row["language"]:
            STATE[table][index] = row
            return row
    STATE[table].append(row)
    return row


def delete(table, body):
    keep = [
        item for item in STATE[table]
        if not (item["id"] == body.get("id") and item["language"] == body.get("language"))
    ]
    removed = [item for item in STATE[table] if item not in keep]
    STATE[table][:] = keep
    return [{"id": item["id"], "language": item["language"]} for item in removed]


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def answer(self, code, body):
        data = json.dumps(body).encode()
        self.send_response(code)
        self.send_header("content-type", "application/json")
        self.send_header("content-length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        path = self.path.split("?")[0]
        if path == "/_state":
            return self.answer(200, STATE)
        for table in REQUIRED:
            if path == f"/api/{route(table)}s":
                return self.answer(200, STATE[table])
        return self.answer(404, {"error": "no route"})

    def do_POST(self):
        length = int(self.headers.get("content-length") or 0)
        try:
            body = json.loads(self.rfile.read(length) or b"{}")
        except json.JSONDecodeError:
            return self.answer(400, {"error": "not json"})
        path = self.path.split("?")[0]
        for table in REQUIRED:
            if path == f"/api/{route(table)}-upsert":
                try:
                    return self.answer(200, [upsert(table, body)])
                except ValueError as error:
                    return self.answer(404, {"error": str(error)})
            if path == f"/api/{route(table)}-delete":
                return self.answer(200, delete(table, body))
        return self.answer(404, {"error": "no route"})


if __name__ == "__main__":
    server = HTTPServer(("127.0.0.1", 0), Handler)
    print(f"PORT={server.server_address[1]}", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        sys.exit(0)
