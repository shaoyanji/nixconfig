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
| `POST /api/add-email` | one message in; JSON body, camelCase keys (`messageId`, `bodyPlain`) |

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
top-level `NpgsqlRest.FileSystemPath` (as some examples show) is silently
ignored; both `UploadOptions.Enabled` and
`UploadHandlers.FileSystemCreatePathIfNotExists` have to be set, and
`FileSystemUseUniqueFileName` is what keeps two attachments from the same mail
from colliding. The path is configured and empty; serving uploads needs a
routine annotated `@upload`, which does not exist yet.

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

## Verify

```bash
systemctl status npgsqlrest email-archive-db-init --no-pager
ss -tlnp | grep ':8080'                       # 127.0.0.1, never 0.0.0.0
sudo tailscale serve status | grep 8450       # tailnet-only front
curl -s http://127.0.0.1:8080/health          # Healthy + database check

# from a tailnet client
curl -s 'https://delphi.cloudforest-kardashev.ts.net:8450/api/list-emails?lim=5' | jq
curl -s 'https://delphi.cloudforest-kardashev.ts.net:8450/api/emails-search?q=invoice' | jq

# full-text, in psql
sudo -u postgres psql -d email_archive \
  -c "SELECT subject FROM emails WHERE search_vector @@ to_tsquery('english','invoice') LIMIT 5;"
```

Only SQL files are published; there is no auth layer in front of them, which is
why the tailnet is the boundary and the bind is loopback.

## Google Drive mirror (off until a token exists)

The sync is one-way — Drive holds a mirror, never the source of truth — and it
is declared but **disabled** in `hosts/delphi/email-archive.nix`: a sops template
whose key is missing fails activation, so the token has to exist first.

```bash
# 1. on a machine with a browser, authorize the archive remote
rclone authorize drive            # prints a JSON token blob

# 2. store it (paste the blob as the JSON value)
sops set modules/secrets.yaml '["email-archive"]["gdrive-token"]' '"{\"access_token\":…}"'

# 3. flip gdrive.enable = true in hosts/delphi/email-archive.nix, rebuild, then
sudo systemctl start email-archive-gdrive-sync.service
systemctl list-timers email-archive-gdrive-sync.timer
```

The client id and secret already exist in sops (`googleDrive/clientId`,
`googleDrive/clientSecret`) and `scripts/drive-auth.sh auth` runs the same
handshake with the funnel for a headless host.

## Not done here

- **No backup of `email_archive` yet.** `services.postgresBackupDrill` and
  `services.postgresqlBackup` are opt-in; a database that matters needs one.
- **No auth on the API.** Tailnet membership is the only gate; the generated
  endpoints are open to any tailnet peer.
- **No importer.** Nothing fills `emails` yet; the mail tooling on this host is
  `mail-agent` (`docs/mail-agent.md`), which reads the live inbox and does not
  archive into this schema.
