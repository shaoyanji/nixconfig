# email-archive — NpgsqlRest over a full-text mailbox on delphi

A REST surface over an archived mailbox. NpgsqlRest turns annotated `.sql` files
into endpoints, so the query *is* the API — every path is an explicit contract,
type-checked against the schema at startup. Everything is tailnet-only: the app
binds `127.0.0.1:8080` and a `tailscale serve` mount on **8450** publishes it at
the host's MagicDNS name, where tailscaled terminates TLS.

| Endpoint | What |
| :--- | :--- |
| `GET /api/list-emails?lim=20` | newest first; `lim` is required |
| `GET /api/emails-search?q=invoice` | `websearch_to_tsquery` over the generated vector, with `<<…>>` snippets |
| `POST /api/add-email` | one message in: nine camelCase keys, `recipients`/`labels` comma-separated, upserts on `messageId` |
| `GET /openapi.json` | the machine-readable contract (OpenAPI 3.0.3, generated from the SQL files) |
| [`mail-atlas`](mail-atlas.md) | browser reading surface over the same rows: fuzzy search, tags, graph (tailnet 8452) |
| [`gemini-mail`](gemini-mail.md) | reader over the same rows from a Gemini client: search, newest, one message (tailnet 1966) |

| Layer | Home |
| :--- | :--- |
| module, options, unit, role, mount wiring | `modules/services/email-archive.nix` |
| schema (`emails`, generated `tsvector`, GIN index) | `modules/services/email-archive.sql` |
| the endpoints themselves | `modules/services/email-archive-endpoints/*.sql` |
| this host's enable + attachment mirror switch | `hosts/delphi/email-archive.nix` |
| the tailnet mount and its portal card | `hosts/delphi/configuration.nix` (`services.servicePortal.mounts`) |
| role password | sops `email-archive/db-password` |

## Why these shapes

**One package, pinned.** Upstream publishes a self-contained NativeAOT binary
per arch (`npgsqlrest-linux-arm64`, v3.21.0, 37 MB); it links only libc/libm, so
the derivation is `fetchurl` + `autoPatchelfHook`. There is no .NET runtime on
the host and no container. Two packaging facts cost a debug cycle each:
NativeAOT **dlopens** OpenSSL and GSSAPI, so they never appear as `NEEDED` and
must be added with `runtimeDependencies`; and `pkgs.openssl` resolves to the
`bin` output, whose `lib/` is empty, so the entry has to be `pkgs.openssl.out`.
The remaining `Cannot load library libgssapi_krb5.so.2` line is harmless — no
Kerberos in this path.

**The password never enters the store or a JSON file.** The shipped
`appsettings.json` already supports `{!PGPASSWORD}` placeholders in the
connection string (`Config.ParseEnvironmentVariables`), so the module renders a
`PGPASSWORD` environment file from sops and writes the connection string with a
placeholder. `Config.AddEnvironmentVariables` stays `false` so the file — not
ambient env — is the configuration.

**There are no table endpoints, by design.** NpgsqlRest removed its CRUD plugin
from the standalone client in 3.14 — *"exposing raw tables directly is a
questionable engineering practice"* — so `CommentsMode`/`OnlyAnnotated` will never
publish `emails` itself. The three files in `email-archive-endpoints/` are the
API, and a SQL error in one fails startup (`ErrorMode = "Exit"`) instead of
surfacing as a 500.

**A JSON array is not a `text[]`.** A body value `["a@b","c@d"]` for `recipients`
fails inside Npgsql — *"Writing values of 'List<Object>' is not supported for
parameters having NpgsqlDbType 'Unknown'"* — so those two columns cross as
comma-separated text and `string_to_array` splits them. The body must also carry
exactly the nine keys the query names: a missing key is a 404 just like an
unknown one, which is the POST-side twin of the query-parameter rule below. An
empty string means *no value*, and every assignment is `nullif`-guarded, so the
update never overwrites a column with nothing.

**`add-email` is an upsert on `message_id`.** A repeated id updates the row in
place and still answers `200` with `[{id, messageId}]`, so an importer can re-send
a batch without a watermark and without a 500 for "already archived".

**`UrlPathPrefix` must stay `/api`.** `""` builds routes with no leading slash
and every request 404s while the app reports that it started; `null` falls back
to `/api` anyway.

**An unknown query parameter is a 404, not a 400.** A misspelled or unregistered
parameter looks exactly like a missing endpoint, which is how two of these
endpoints appeared broken while working. It also means `@param lim integer
default 20` has to be avoided: the defaulted parameter was never registered, so
`?lim=2` 404'd. The parameters that exist are required; the search row cap is
literal because `ts_headline` plus two bind parameters fails inside Npgsql
(500, `The value cannot be an empty string (Parameter 'key')`).

**The upload settings are `NpgsqlRest.UploadOptions.UploadHandlers.*`.** A
top-level `FileSystemPath` (as some examples show) is silently ignored; both
`Enabled` and `FileSystemCreatePathIfNotExists` have to be set, and
`UseUniqueFileName` keeps two attachments from one mail apart. The path is empty
because serving uploads needs a routine annotated `@upload`, which does not exist.

**Ownership is asserted by the init unit, not `ensureDBOwnership`.**
`ensureDBOwnership` only accepts a database *named after the role*, and this one
is `email_archive` for `npgsqlrest`. So `email-archive-db-init` runs as
`postgres`, re-asserts the role password from a systemd credential, sets the
database owner, and then applies the schema **as the archive role over TCP** —
the same path the app uses, so a wrong `pg_hba` line fails at activation instead
of as an API that starts and 500s. It is ordered after
`postgresql-setup.service`, not `postgresql.service`: `ensureUsers` and
`ensureDatabases` run in the former, *after* the server is up, so the obvious
ordering starts the init unit against a cluster with no role in it.

**Only metadata and plain text are stored.** `attachment_path` names a file
under `/var/lib/npgsqlrest/attachments`; the bytes never enter PostgreSQL and
are never base64'd into a row.

## The schema

`modules/services/email-archive.sql` is idempotent and is re-applied on every
activation:

```sql
CREATE TABLE IF NOT EXISTS emails (
  id bigserial PRIMARY KEY,
  message_id text UNIQUE NOT NULL,
  thread_id text, sender text, recipients text[], subject text,
  sent_at timestamptz, labels text[], body_plain text, attachment_path text,
  search_vector tsvector GENERATED ALWAYS AS (
    to_tsvector('english',
      coalesce(subject,'') || ' ' || coalesce(sender,'') || ' ' || coalesce(body_plain,''))
  ) STORED
);
CREATE INDEX IF NOT EXISTS emails_search_idx ON emails USING GIN (search_vector);
CREATE INDEX IF NOT EXISTS emails_sent_at_idx ON emails (sent_at DESC);
CREATE INDEX IF NOT EXISTS emails_thread_id_idx ON emails (thread_id);
```

Generated + `STORED` rather than a trigger: the vector cannot drift from the
row, and there is no function to forget on a bulk load.

## Triage: a tier, an owner, and a loop

`email_triage` is a verdict *about* a message, not a property of it. Keyed
`(message_id, classifier)` so two classifiers can disagree and both rows stand,
and so re-classifying never rewrites the archive.

| column | meaning |
| :--- | :--- |
| `tier` | `person`, `action`, `digest`, `robot`, `review`, `ignore` — ignore is reversible: the queue skips it and `resolved_at` stays null, unlike `triage-resolve` |
| `owner` | `human`, `none`, or `agent:<name>` — `agent:ci` is a run failure |
| `reason` | one line: the rule that fired, or the engine's choice and margin |
| `confidence` | rule confidence, or the engine's top probability |
| `resolved_at` | set by whatever dealt with it; an unresolved row is the queue |

The classifier (`modules/services/email-triage.py`) runs rules first, in an
order that decides the queue: VIP, declared pointers, CI, plugin claims (sender
**or** subject), deadline signals → `action`, records → `digest`, one-shot codes
and alerts → `robot`, machine senders → `digest`. The residue reaches `julia-1`
(3 ms per question); a verdict that does not lead the runner-up by
`triage.margin` becomes **`review`**. The second architecture (`laya`) then
overrides it in **either direction** — a definite verdict replaces the other
model's, and only a tie keeps `julia`'s tier — so the queue pays for a
classification, not for a tie. A sender that writes repeatedly with no deadline
is a feed and becomes `digest`; a declared **pointer** (`triage.pointers`, one a
day from an assistant) is exempt and stays in front of a person for a week.
`triage.expireDays` resolves `review` rows nobody touched in 30 days; `person`,
`action` and pointers are never expired.

**One decision per sender, not per message.** `task agents:mail:sweep
SENDER=<substring> DRY=1` counts what a selector matches (by tier and sender)
and `DRY=0` resolves the block through `/api/triage-resolve`. At least one
selector is required, so a typo cannot empty the queue. Measured 2026-11-03: the
human queue went 511 → 50 in one pass. 203 rows were a machine sender filed as a
person's action item and 104 were one-shot codes or records; the 30-day expiry
took the old review tail, and the two consumers took their own (235 CI notices,
43 application mails to the pipeline). What is left is 21 action rows, 2 people
and 27 reviews.

**The VIP list is encrypted config, not state.** `modules/secrets.yaml` carries
`email-archive.vip-senders`; sops-nix lands it as a 0400 file at `triage.vipFile`,
so a family address in this public tree is a leak and a plaintext state file is a
second thing to remember. A `sops --set` plus a rebuild is the whole edit.

## The job pipeline lives here too

`applications` and `application_mail` are the workflow's pipeline
(`shaoyanji/antigravity-application-workflow`) in the same database as the mail
that moves it. `stage` is derived at import with the rules `task apps:overview`
prints, beside the workflow's freeform `status`, so nothing is paraphrased and
the CLI and the database cannot disagree.

| verb | how |
| :--- | :--- |
| load the pipeline | `task agents:apps:import FILE=<applications.json>` (`FILE=-` reads stdin) |
| link mail to an application | automatic in that task: the employer's name in sender or subject, or the record's own `message_id` |
| read it | `task agents:apps:pipeline`, `GET /api/applications`, `GET /api/application-mail?application_id=` |
| what still needs a human | `GET /api/application-attention` — applications whose linked mail is unresolved |
| record a change from mail | `task agents:apps:set ID= STATUS= NEXT=` → `POST /api/application-update` |
| let an agent do it | `task agents:apps:sync` (`DRY=1` to preview) — reads the ATS queue, writes status + next action per provable message, resolves the mail, appends `~/.local/state/email-archive/apps-sync.jsonl` |
| publish the JSON | `task agents:apps:export OUT=data/applications.json` — the workflow's own shape, key for key, generated from the database |
| hydrate the tracker | the same sync: mail that names an employer the pipeline does not have creates a record with `origin = 'discovered'`, its `message_id`, and the status the message proves (`task agents:apps:discovered`) |
| the plugin's own dashboard | `GET /api/plugins` — one row per owner with open/resolved counts; `task agents:hub` |

**Direction: the database writes, the JSON is exported.** `agents:apps:sync` moves a status only
forward (`received < follow-up < interview < rejected`, oldest message first), refuses a message that
names no tracked employer, and picks by role then recency when one employer has several records,
recording the alternatives in the ledger.

A link is evidence, not a verdict: `matched_by` and `confidence` say how it was
made, links are never deleted, and a record whose `company` is really a role name
("AI Generative Engineer German") is refused rather than allowed to absorb every
recruiter reply — measured at 74 links, 0 for that record, where token matching
had given it ~30.

**`owner = agent:apps`.** ATS mail (`greenhouse`, `lever`, `personio`, `join.com`,
`softgarden`, …) is routed to the pipeline instead of to a person; job alerts
(`indeed`, `stepstone`, `linkedin`) are `digest`. `/api/attention` excludes every
`agent:*` owner, so the person queue stays about people.

**CI closes its own loop.** A GitHub `Run failed:` notice is `robot` with
`owner = agent:ci`. `task agents:ci:fix RUN=<id>` pulls the failing job and its
log into one bounded prompt and starts a `hermes` subagent in a detached tmux
session; when the run is green, `task agents:ci:resolve MESSAGE_ID=<id>` sets
`resolved_at` and the message leaves the queue. Nothing is deleted: the body
stays searchable and the resolution is the record. The triage unit's
`ExecStartPost` then runs `task agents:ci:drain`: a notice older than 14 days is
stale and only the newest per repo+workflow survives, which closed 234 of 237 on
the first run. A queue nobody drains is a mailbox with a nicer name.

## Verify

```bash
systemctl status npgsqlrest email-archive-db-init --no-pager
ss -tlnp | grep ':8080'                       # 127.0.0.1, never 0.0.0.0
sudo tailscale serve status | grep 8450       # tailnet-only front
curl -s http://127.0.0.1:8080/health          # Healthy + database check

# from a tailnet client
curl -s 'https://delphi.cloudforest-kardashev.ts.net:8450/api/list-emails?lim=5' | jq
curl -s 'https://delphi.cloudforest-kardashev.ts.net:8450/api/emails-search?q=invoice' | jq
```

```bash
task agents:mail:attention              # what needs a person, newest first
task agents:mail:triage CLI_ARGS=--report   # tier counts, agent queue
task agents:mail:triage CLI_ARGS=--dry-run  # verdicts without writing them
task agents:ci:queue                    # unresolved CI an agent owns
```

Every one of these prints TOON: `toon -e` of the API's own JSON, which is what an
agent reads. `FORMAT=text` gives a person the table it printed yesterday.

## What it can and cannot do

| Capability | State |
| :--- | :--- |
| what needs a person | `GET /api/attention?lim=N` — person, action, review; unresolved; VIPs first |
| an agent's own inbox | `GET /api/agent-queue?owner=agent&lim=N` |
| the newsletter batch | `GET /api/triage-digest?days=7&lim=N` |
| judge / resolve a message | `POST /api/triage-upsert`, `POST /api/triage-resolve` |
| **send mail** | **no.** There is no SMTP in this module; `mail-agent` sends through himalaya |
| **upload an attachment** | **no.** The upload handlers are configured, but no routine is annotated `@upload`, so `attachment_path` is written only by the importer, from mail that already arrived |
| HTML-only mail | converted to text with `html2markdown` at ingest (and by `--refill`), so 100 % of archived rows carry a body |
| auth | none; tailnet membership is the gate |
| MCP / agent tool | none; an agent calls the HTTP API, or reads `/openapi.json` |

himalaya is the **ingest transport only**; the query path is PostgreSQL's own
full-text search over a schema an agent can rely on.

## The hub: plugins, and the rival on 8451

The archive is a hub, not a mailbox: each owner is a **plugin** that claims mail and
acts on it. CI and the pipeline are built in (their rules are richer than a sender
list); anything else is `services.emailArchive.plugins` — a sender list, a tier and
an owner — so adding one is config with no code change, and `GET /api/plugins`
reports every owner with its open count. `task agents:hub` prints that table.

```nix
plugins.fleet = { senders = ["gatus@" "alerts@frieren"]; tier = "action"; };
# -> owner agent:fleet, queue /api/agent-queue?owner=agent:fleet
```

A second architecture competes by answering the same four core routes with the same
shapes — nothing about PostgreSQL or NpgsqlRest is part of the contract. **8451 is
reserved for that rival**; mounting one is a single `services.servicePortal.mounts`
entry, and the benchmark already takes a base URL:

```bash
task dev:email:bench                                  # champion, loopback
BASE=https://delphi.cloudforest-kardashev.ts.net:8451 task dev:email:bench   # a rival
```

| Route | Contract |
| :--- | :--- |
| `GET /health` | 200, any body |
| `GET /api/list-emails?lim=N` | 200, array of rows carrying `id, messageId, sender, subject, sentAt, labels, attachmentPath, bodyLength` |
| `GET /api/emails-search?q=<text>` | 200, array of rows carrying `id, messageId, sender, subject, sentAt, snippet` |
| `POST /api/add-email` | 200, array with `id` + `messageId`; nine camelCase keys |
| any unknown or missing parameter | **4xx** — 400 and 404 both pass, because the rejection is the contract and the status is the engine's |

The battery is fixed (`invoice`, `order`, `receipt`, `unsubscribe`,
`verification`, `notification`, `security`, `ticket`, `trip`, `account`, plus
`lim` of 1/20/100), 30 iterations after 3 warmups, and the report is p50/p95/max
plus one `score` = 1000 / (p95 geometric mean) × correctness.

Champion baseline, 2026-11-03 on delphi, 400 rows:

```
list-emails     p50 4.6–5.3 ms    p95 ≤ 6.1 ms
emails-search   p50 2.5–32 ms     p95 ≤ 33.6 ms    (the 50-row hits are the slow ones)
checks          15/15 passed
p95 geomean     8.82 ms
score           113.33
```

The score is *relative to this machine and this dataset*: 400 rows fit in memory.
What makes it comparable is the fixed battery — the same 15 checks run against a
rival, and `--out` carries every sample, so a disagreement is checked, not argued.

## The importer

`email-archive-import` (`modules/services/email-archive-import.py`, driven by
`email-archive-import.timer`) walks the live mailbox with himalaya — the same
account `mail-agent` uses — and POSTs each new message to the loopback API. It
never opens the database, so it holds no database credential. It does read the
login user's `~/.config/himalaya/config.toml`, whose password is a command, and
it writes attachments under the archive's tree; that is why the unit runs as
root with `ProtectHome=read-only` rather than as the archive user.

- **No watermark.** A run takes the newest `importer.limit` messages that are not
  in the archive yet and stops, so successive runs walk further back through the
  mailbox until it is exhausted. Message identity, not a timestamp, is the
  dedupe: the endpoint upserts and the known set comes from `list-emails`.
- **Bounded per run, derived from the archive.** Envelope pages are cheap, a body
  is one IMAP read. `limit` (200 on delphi) is what a run takes; the scan depth
  follows the known-id set (`--max-pages 0`), so a run never stops at a window
  smaller than the archive — the bug that made the importer exit 0 while finding
  only known mail. `TimeoutStartSec` is 45 min because a backfill is hundreds of
  reads.
- **Attachments** land in
  `/var/lib/npgsqlrest/attachments/<sha256(message_id)[:16]>/`, are chowned to the
  archive user, and `attachment_path` names that directory. An existing
  non-empty directory *is* the record that the download happened — himalaya
  suffixes a name collision instead of overwriting, so a second pass would only
  duplicate files.
- **HTML is converted, not dropped.** A message whose only body part is
  `text/html` — the majority of bulk mail — is run through **`html2markdown`**
  (`modules/scripts/html2markdown.nix`, the upstream Go CLI at v2.5.2 built with
  `buildGoModule`) and the markdown is stored as `body_plain`. `--refill`
  revisits rows an older run stored without text.
- **`thread_id` is the parent `In-Reply-To` id**, because Gmail's thread id is
  not an IMAP header.
- **The gate is `task checks:email:bodies`.** It runs `html2markdown` over the
  newest N envelopes' HTML parts — the same extraction the importer uses — and
  fails if a body part converts to nothing; then it asks the API whether those
  messages were archived with a non-zero body length. Both halves matter: one
  proves the converter works, the other proves it reached the store.

  ```bash
  task checks:email:bodies                # 20 envelopes
  task checks:email:bodies SAMPLE=50      # wider sample
  ```

  **Resolve the binary by path, never by name.** The login profile already
  carries an `html2markdown` command (`modules/shell/nushell.nix`) that runs
  `html2text` — a gate that answered to PATH would measure the wrong converter.

```bash
sudo systemctl start email-archive-import      # one run now
journalctl -u email-archive-import -n 20       # imported / skipped / failed
systemctl list-timers email-archive-import     # next elapse
curl -s 'http://127.0.0.1:8080/api/list-emails?lim=5' | jq
```

## Google drive mirror (skipped until a remote exists)

The sync is one-way — Drive holds a mirror, never the source of truth. The timer
runs from first boot and the unit carries `ConditionPathExists` on
`/var/lib/npgsqlrest/rclone.conf`: **skipped, not failed**, until that file
exists. That is the calendar's rule — the OAuth client is declared, the **token is
state** — and the same `googleDrive/clientId` + `clientSecret` pair drives both.

```bash
rclone authorize drive                  # 1. on a browser machine: prints a token blob
sudo -u npgsqlrest rclone --config /var/lib/npgsqlrest/rclone.conf \
  config create gdrive-email drive scope=drive \
  client_id="$(sops -d modules/secrets.yaml | yq -r '.["googleDrive"]["clientId"]')" \
  client_secret="$(sops -d modules/secrets.yaml | yq -r '.["googleDrive"]["clientSecret"]')" \
  token="$(cat token.json)"             # 2. the blob from step 1
sudo systemctl start email-archive-gdrive-sync   # 3. no rebuild; the next tick keeps it
```

## Where a guest lives

A plugin declares four things — `rules` (mail it claims), `sql` (endpoints), `schema`
(DDL applied after the core schema), `packages` — and the hub knows nothing else.
Its module lives under `modules/plugins/<name>/` with its README, tables and code;
removing the import removes its routing, endpoints and schema in one edit.

The first guest is `modules/plugins/appflow/`, deliberately not modeled on the
upstream project: the JSON is a data source, and documents are a Nix build —
`typst` from this flake's pin, one template per language, artifact is a store path.

The token is state, not sops: rotating it is `rclone config reconnect` with no
rebuild, and `rm` of the conf plus a remote stop returns the unit to *skipped*.

## Not done here

- **No backup of `email_archive` yet.** `services.postgresBackupDrill` and
  `services.postgresqlBackup` are opt-in; a database that matters needs one.
- **No auth on the API.** Tailnet membership is the only gate; the generated
  endpoints are open to any tailnet peer.
- **Only the inbox is imported.** `importer.mailbox` is one folder; sent mail and
  Gmail's All Mail are not walked, and labels are the source folder only.
- **No HTML source kept.** The converted text is stored; the original `text/html`
  part is not, so a better converter later means re-reading the mailbox, not a
  migration.
