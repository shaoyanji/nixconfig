# portfolio services — three SQLite indexes on delphi, and the verbs that fill them

Three Go services hold the portfolio's own data on `delphi`: scraped job
postings, watched products with price history, and the household inventory. A
fourth, `clanker-runner`, runs the InstaBox jobs beside them, and a fifth,
`link-vault`, keeps what was read and filed from the web; both share the same
shape. Each binds loopback only, and each is published by a `tailscale serve`
mount — nothing opens a port in the firewall, so the mount is the whole exposure
(`modules/services/service-portal.nix` is the pattern). Each one serves an HTML
reader and a JSON API from the same binary, over SQLite with an FTS5 index.
`tailnetHost` is a required option: writes are accepted only from the configured
tailnet origin, so a service cannot start without the name it expects.

| Service | Option | Module | Loopback | Tailnet |
| :--- | :--- | :--- | :--- | :--- |
| job-db-scraper | `services.jobDbScraper.enable` | `modules/services/job-db-scraper.nix` | `127.0.0.1:8101` | `:8464` |
| private-deals | `services.privateDeals.enable` | `modules/services/private-deals.nix` | `127.0.0.1:8102` | `:8465` |
| inventory-site | `services.inventorySite.enable` | `modules/services/inventory-site.nix` | `127.0.0.1:8103` | `:8466` |
| clanker-runner | `services.clankerRunner.enable` | `modules/services/clanker-runner.nix` | `127.0.0.1:8104` | `:8467` |
| link-vault | `services.linkVault.enable` | `modules/services/link-vault.nix` | `127.0.0.1:8106` | `:8468` |

## What each one holds

**job-db-scraper** — postings scraped from boards, deduplicated on the URL and
searchable by title, company and location. `GET /api/postings?q=` runs the FTS
query; `POST /api/postings` files one; `GET /api/stats` counts postings,
companies and locations; `GET /api/scrape` and `POST /api/scrape` read and
trigger the service's own sweep, which is off by default on this host.

`GET /api/analytics?days=&limit=` is the board's shape rather than its rows:
active, remote, `avg_score` and unscored counts, then companies (postings and
mean score), lanes (postings and best score), locations, boards and score bands.
The "Board analytics" panel draws the first four as bars and the bands as a
histogram, and a company or lane bar is a filter rather than a label — clicking
one narrows the list below.

`POST /api/postings/batch` files up to 500 at once (`{postings: […]}` or
`{items: […]}`), drops duplicates inside the batch and answers
`created`/`updated`/`skipped`/`failed` with up to 25 per-item errors, so one bad
record costs one record. `apps:ingest` posts in chunks of that size.

Every posting carries a deterministic `score` 0–100 — weighted terms for the
lane (DevOps, SRE, Platform, Kubernetes, NixOS, …), a DACH bonus, a remote
bonus, capped at 100, with the matched lanes returned beside it — stored as an
indexed column, so `?sort=score` is how the board reads first. Alerts are that
score with a floor: `services.jobDbScraper.minAlertScore` (80) and an `ntfyUrl`,
`GET /api/alerts` for the queue and `POST /api/alerts/evaluate` to re-run it. A
row in `job_score_alerts` is keyed on the posting's fingerprint and carries
`attempts` and `notify_error`, so a failed send is retried rather than dropped.
The batch evaluates alerts before it answers.

**private-deals** — products, deals, watchlists and price history.
`GET /api/deals?q=` searches deals and takes `min_discount`, `max_price`,
`merchant`, `category` and `watchlist` alongside it; `POST /api/deals` files one;
`GET /api/products`, `GET /api/price-history` and `GET /api/export.csv` read the
rest. Deals carry `price` and `list_price` — the struck-through original — plus
`discount_pct`.

`GET /api/analytics?window=&limit=` reads that window as figures and movement:
`top_discounts`, `biggest_drops`, `merchants`, `categories`, and
`history.daily` — the average price per day behind the panel's sparkline. The
panel's heading carries the window and the mean price the report computed.

`POST /api/deals/batch` is the same contract for deals. Watchlists are what an
alert is about: a deal enters `deal_alerts` as `target-price` (at or below the
product's `target_price`), `price-drop` (under 95% of its current price) or
`watchlist-match` (a watched product with any active deal), fingerprinted on
deal, currency and price, so the same deal at the same price notifies once.
`GET /api/watchlists`, `POST /api/watchlists/{id}/items` and
`DELETE …/items/{product}` build the set; `GET /api/alerts` lists the queue,
`POST /api/alerts/evaluate` re-runs it, and `services.privateDeals.ntfyUrl` is
where a match goes.

**inventory-site** — fleet hardware and personal assets with serials, warranties
and value. `GET /api/items?q=` searches; `POST /api/items`, `PUT /api/items/{id}`
and `DELETE /api/items/{id}` write; `GET /api/meta/{kind}` lists the vocabularies
(rooms, categories, owners); `GET /api/export.json` dumps everything.

`GET /api/analytics?days=&limit=` values the register rather than counting it:
items, quantity, `value_cents` in their currency, archived, value by category and
location, warranty buckets, tags, and the event trail (`events`, `events_total`,
`events_recent`). The "Analytics & valuation" panel renders it, and its category
and location rows filter the list the same way the board's bars do.

`asset_events` is the custody trail: `POST /api/items/{id}/events` records a
`checkout`, a `checkin` or a `note` with actor, from/to location and a note,
`GET …/events` reads it back, and the detail dialog draws it as a timeline.
`GET /api/items/{id}/qr.svg` renders a printable label whose QR encodes the
item's URL at the configured origin, so a sticker on the shelf opens the record.

Warranty is a queue rather than a column: `warranty_alerts` holds one row per
item and expiry date inside the `-warranty-warn-days` window (30), and the
service evaluates on start and every six hours — `GET /api/alerts` lists the
queue, `POST /api/alerts/evaluate` runs it by hand, and `notify_count` /
`last_error` say what happened to each row. `GET /api/stats` counts assets,
units, tracked value and warranties inside 90 days; the UI's warranty badge is
read off `warranty_until`.

**clanker-runner** — InstaBox machine state, wake and exec triggers, and a run
history of Nix and agent-browser jobs. `GET /api/machines` lists them,
`GET /api/machines/{machine}` reads one, `POST /api/machines/{machine}/wake` and
`POST …/exec` are the doors, and `GET /api/jobs` is the history. Same binary
shape as the three indexes, but the data is a runner's state rather than an index
you read with a query.

Presets are code, not rows: four jobs — an agent-browser DOM check, a Nix profile
status, a clanker disk hygiene report, and one validated nixpkgs tool run — each
pinned to `clanker` and naming the parameters it needs. `GET /api/presets` lists
them and `POST /api/presets/{id}/run` runs one with overrides for machine, URL,
selector, package and args. `GET /api/schedules` reads the recurring half: a
schedule names a preset, a machine, its params and an `interval_seconds` between
15 and a week, and carries `next_run_at`, `last_run_at`, `last_job_id` and
`last_error`. `POST /api/schedules` creates one (`start_immediately` for the
first run), `DELETE /api/schedules/{id}` removes it, and the service's own loop
runs what is due — the UI's schedules panel is that list, not a second source.

**link-vault** — links worth keeping, with the page text behind them.
`GET /api/links?q=` searches title, description, content, excerpt, site name and
tags through one FTS5 index; `POST /api/links` files one and `POST /api/links/batch`
files many, both keyed on the canonical URL so a second add updates instead of
duplicating. A link is `unread`, `read` or `archived` (`POST /api/links/{id}/state`),
carries tags and an optional collection, and `DELETE /api/links/{id}` removes it.

Extraction is layered and named rather than hidden: `POST /api/links/{id}/extract`
(or `POST /api/extract` for a preview that stores nothing) tries Firecrawl
(`/v2/scrape`), Tavily (`/extract`), Context.dev and then a plain HTTP read, and
`GET /api/extraction/providers` says which of them a configured key enables.
`GET /api/collections` and `POST /api/collections` are the shelves, `GET /api/tags`
is the vocabulary actually in use, and `POST /api/import` takes a batch of URLs.
`GET /api/export.json` and `GET /api/export.md` are the way out: the markdown one
opens `# Link vault export` and gives each link a second-level heading whose
title is linked to the URL, followed by its state, source, collection and tags.

## The portal's live badges

The portal's service cards are compiled from the flake; the badge beside one is
the only live part. `service-portal-telemetry` (`127.0.0.1:8105`, proxied by nginx
at `/api/telemetry`, no mount or firewall port of its own) polls the targets under
`services.servicePortal.telemetry.targets` — five of them today: `job-db`,
`private-deals`, `inventory-site`, `clanker-runner` and `link-vault` — every 10 s
with a 750 ms timeout per request, and answers `{generated_at, services}`, each
service carrying `status`, `latency_ms`, `checked_at`, `health`, `stats` and the
metrics its target declares. A target names up to three stats keys for its badge;
`link-vault` reads `bookmarks`, `read` and `tags`, which are exactly the keys
`GET /api/stats` answers with.

Status is `offline` when `/api/health` does not answer, `degraded` when it answers
`ok: false` or `/api/stats` fails, `online` otherwise; `unknown` is a target the
first poll has not reached. A card carries `data-live-for="<target>"` and
`lib/delphi/juno.js` fills it with a dot, the status word and the first three
metrics, with the check time or the error in the tooltip. A failing aggregate
removes the decoration and nothing else: the card's structure is compiled truth,
it stays readable, and `telemetry unavailable` says which half broke.

## The verbs that fill them

Reading a page happens in the CLI scripts, not in the services, so a sweep needs
no credentials on `delphi`:

| Task | Script | Reads through | Writes to |
| :--- | :--- | :--- | :--- |
| `apps:page` | `scripts/task/job-page-scrape.py` | `http` GET plus JSON-LD, or Firecrawl, Tavily, agent-browser | stdout JSON, one object per URL |
| `apps:ingest` | `scripts/task/jobs-ingest.py` | stdin or `--in` | `POST /api/postings/batch` on job-db-scraper |
| `deals:page` | `scripts/task/deals-page-scrape.py` | agent-browser, Firecrawl, Context.dev, Tavily, plain GET | stdout JSON, one object per URL |
| `deals:ingest` | `scripts/task/deals-ingest.py` | stdin or `--in` | `POST /api/deals/batch` on private-deals |
| `agents:web` | `scripts/task/web-research.py` | Firecrawl `/v2/search`, Tavily and Context at once, or agent-browser | stdout JSON, TOON, or a cited markdown report |
| `dev:inventory:site` | `scripts/task/inventory-sync.py` | `nix eval .#inventory.hosts`, or `--in` a JSON dump | `POST /api/items` on inventory-site |
| `agents:portfolio:seed` | `scripts/task/portfolio-seed.py` | the scrapers and ingesters above, or `--jobs-from` / `--deals-from` | the batch routes and `POST /api/items`, one lane at a time |

`agents:portfolio:seed` is those pairs as one run, for when three services need
filling and nobody wants to remember which scraper feeds which ingester:

```bash
task agents:portfolio:seed -- --jobs https://boards.greenhouse.io/acme
task agents:portfolio:seed -- --deals-from deals.json --only deals
task agents:portfolio:seed -- --jobs-from jobs.json --only jobs --dry-run
```

It scrapes each page it is given, merges the pages into one document, and hands
that to the batch route on the loopback defaults (`--api-jobs`, `--api-deals`,
`--api-inventory` move them). `--jobs-from` and `--deals-from` reuse a saved
scrape instead of fetching; inventory runs by `--eval` unless `--inventory-from`
names a hosts JSON, and `--inventory-hosts` narrows it. `--only` picks lanes by
name (`jobs`, `deals`, `inventory`), `--dry-run` shapes every payload and posts
nothing, and `--format toon` renders the summary an agent reads. A page with no
postings is a zero rather than a failure; a refused record exits 1 with the first
error named, while the lanes that succeeded still report what landed.

One verb proves all five services end to end, and is the one to run after a
deploy or a schema change:

```bash
task agents:portfolio:smoke                      # loopback defaults on delphi
task agents:portfolio:smoke -- --expect-hit --query fleet
task agents:portfolio:smoke -- --format toon     # the summary an agent reads
task agents:portfolio:smoke -- --browser         # adds the rendered-DOM check
```

It asks each service for `/api/health` (which must name the service it thinks it
is), `/api/stats`, `/api/analytics` where one exists (JSON that still names its
window), `/` as HTML carrying the element the JS fills, and one search.
inventory-site also renders the QR label for its first asset — on an empty register
the check reports itself skipped and says why instead of passing as though it had
looked — clanker-runner answers `/api/machines`, `/api/presets` and
`/api/schedules`, and link-vault searches `/api/links` and reads `/api/tags`. An
empty result passes — "nothing matched" is an answer — so the check works on a
fresh database; `--expect-hit` is for when the data should be there. Each base is
overridable — `--jobs`, `--deals`, `--inventory`, `--clanker`, `--link-vault` — so
the same verb can point at the tailnet mounts. Exit 1 names the service that
failed.

`--browser` opens each page and re-reads the element its JS fills. This host has
no `agent-browser`, so `--clanker-browser` runs that half on InstaBox `clanker`
through `scripts/task/clanker-browser.sh`; the page then has to be one `clanker`
can reach, which a tailnet-only service is not.

```bash
task apps:page -- --backend http https://boards.greenhouse.io/acme > jobs.json
task apps:ingest -- --api https://delphi.cloudforest-kardashev.ts.net:8464 --in jobs.json

task deals:page -- --backend firecrawl --max 5 https://www.techbargains.com/ > deals.json
task deals:ingest -- --api https://delphi.cloudforest-kardashev.ts.net:8465 --in deals.json

task agents:web -- search "nix flake devshell" --max 5
task agents:web -- search "nix flake devshell" --max 4 --format markdown
task agents:web -- health https://nixos.org/ --via clanker

task dev:inventory:site DRY=1                        # what would be filed
task dev:inventory:site DRY=0 ONLY=delphi,frieren    # write two hosts
```

`--format markdown` on `agents:web` renders the same answer as a report: linked
titles, `[sN]` citations in the text, and those ids resolved again under
`## Sources`, which is the half that gets pasted into a document.

Every ingester prints a summary of what it filed, and exits 1 when the server
refused a record. A refusal inside a batch is counted and named by index (25 per
call) while the rest of the chunk still lands, and a service that predates the
batch route falls back to one request per record. Both are idempotent: the URL
is the identity the server fingerprints, so a second run updates instead of
duplicating. `deals:ingest` maps the scraper's `original_price` to the store's
`list_price`.

`dev:inventory:site` is the exception that proves the rule, because its identity
is not derived — it writes inventory-site's own `source=inventory.toml` and
`source_key=host/<name>`, exactly what `POST /api/import/inventory-toml` writes,
so a sync and an import update one row per host rather than filing each twice.
Hardware lands in the notes (so `q=ryzen` finds the Ryzen machines), traits in
tags, and a `preserved` host stays unarchived. It reads the compiled registry,
so it can only describe a host the flake already knows.

## Where the browser and the keys live

`agent-browser` is installed on `clanker`; the tasks reach it through
`task instabox:exec -- clanker …`, which is why `web-research.py health` defaults
to `--via clanker` and `deals-page-scrape.py --backend browser` works from a
laptop that has no Chromium. Provider keys are read by name from
`~/.hermes/.env` (`FIRECRAWL_API_KEY`, `TAVILY_API_KEY`, `CONTEXT_API_KEY`) and
never printed; a missing key is reported as one refused layer, not a crash.

## Facts live in the config

Ports, options and host attachment are compiled data, so read them rather than
this page when they disagree:

```bash
nix eval --json .#inventory.hosts.delphi | jq '.services'   # tailnet ports and names
task docs:build   # docs/generated/modules-registry.md, fleet-inventory.md
task --list-all --json | jq -r '.tasks[].name' | grep -E '^(apps|deals|agents:web|agents:portfolio|dev:inventory:site)'
```

The sibling surfaces are [`email-archive`](email-archive.md) on `:8450` (the
mailbox the job lane reads for replies), [`agent-turns`](agent-turns.md) on
`:8460`, and the reader skills `.agents/skills/agent-browser`,
`.agents/skills/instabox` and `.agents/skills/apps`.
