# appflow-board — the job pipeline as a page

A read-only view of the application tracker, on delphi's tailnet. It exists
because the pipeline had grown to 157 rows with 83 linked messages and the only
ways to see it were a task that reads a checkout delphi does not have, or psql.

## What it is

`services.appflowBoard` is an nginx vhost on loopback plus one static page.
The vhost proxies four GET routes of the mail hub's NpgsqlRest
(`services.emailArchive`, loopback 8080) and serves the page from the store:

| Route | What the page shows |
| :--- | :--- |
| `/api/applications?lim=500` | every row: company, role, stage, status, next action, mail count |
| `/api/application-pipeline` | stage counts and how many of each carry a next action |
| `/api/application-get?id=` | the record behind a click: notes, fit, category, language, origin |
| `/api/application-mail?applicationId=&lim=` | the messages behind that record, with the verdict each one carries |
| `/api/applications-discovered?lim=` | employers the mail hub found on its own (proxied, not on the page yet) |

Parameter names are the endpoint's, not the SQL's: the plugin writes
`:application_id` and NpgsqlRest exposes `applicationId`, which is why a
snake_case query is a 404 and not an empty list.

There is no snapshot job and no second copy of the data. The board is a viewer,
which is why it cannot disagree with the CLI: both read the same rows.

## Why the allowlist is exact

The plugin publishes `application-update` and `application-upsert` beside the
read routes. Proxying `/api/` would put writes on the tailnet from a page that
only reads, so the vhost names four paths exactly and a route added to the plugin
later is not reachable until it is named here too.

## Exposure

- nginx binds `127.0.0.1:8462`.
- The tailnet front is a portal mount (`services.servicePortal.mounts.appflow`)
  on 8463; the port is not the vhost's, because `tailscale serve` and nginx
  cannot share a socket.
- Nothing opens a firewall port and there is no public counterpart.

## What it does not do

- No writes, no auth of its own: the tailnet is the boundary, as with the media
  relay.
- No derived follow-up date. The 7-day rule belongs in `sql/application-due.sql`
  and `agents:apps:due`, so the board and the task plane cannot apply two
  different clocks.
- No packet, no PDF, no file listing: the pipeline is text and the artifacts are
  built on demand.
