# portfolio services — three SQLite indexes on delphi, and the verbs that fill them

Three Go services hold the portfolio's own data on `delphi`: scraped job
postings, watched products with price history, and the household inventory. Each
binds loopback only, and each is published by a `tailscale serve` mount — nothing
opens a port in the firewall, so the mount is the whole exposure
(`modules/services/service-portal.nix` is the pattern). Each one serves an HTML
reader and a JSON API from the same binary, over SQLite with an FTS5 index.
`tailnetHost` is a required option: writes are accepted only from the configured
tailnet origin, so a service cannot start without the name it expects.

| Service | Option | Module | Loopback | Tailnet |
| :--- | :--- | :--- | :--- | :--- |
| job-db-scraper | `services.jobDbScraper.enable` | `modules/services/job-db-scraper.nix` | `127.0.0.1:8101` | `:8464` |
| private-deals | `services.privateDeals.enable` | `modules/services/private-deals.nix` | `127.0.0.1:8102` | `:8465` |
| inventory-site | `services.inventorySite.enable` | `modules/services/inventory-site.nix` | `127.0.0.1:8103` | `:8466` |

## What each one holds

**job-db-scraper** — postings scraped from boards, deduplicated on the URL and
searchable by title, company and location. `GET /api/postings?q=` runs the FTS
query; `POST /api/postings` files one; `GET /api/stats` counts postings,
companies and locations; `GET /api/scrape` and `POST /api/scrape` read and
trigger the service's own sweep, which is off by default on this host.

**private-deals** — products, deals, watchlists and price history.
`GET /api/deals?q=` searches deals and takes `min_discount`, `max_price`,
`merchant`, `category` and `watchlist` alongside it; `POST /api/deals` files one;
`GET /api/products`, `GET /api/price-history` and `GET /api/export.csv` read the
rest. Deals carry `price` and `list_price` — the struck-through original — plus
`discount_pct`.

**inventory-site** — fleet hardware and personal assets with serials, warranties
and value. `GET /api/items?q=` searches; `POST /api/items`, `PUT /api/items/{id}`
and `DELETE /api/items/{id}` write; `GET /api/meta/{kind}` lists the vocabularies
(rooms, categories, owners); `GET /api/export.json` dumps everything.

## The verbs that fill them

Reading a page happens in the CLI scripts, not in the services, so a sweep needs
no credentials on `delphi`:

| Task | Script | Reads through | Writes to |
| :--- | :--- | :--- | :--- |
| `apps:page` | `scripts/task/job-page-scrape.py` | `http` GET plus JSON-LD, or Firecrawl, Tavily, agent-browser | stdout JSON, one object per URL |
| `apps:ingest` | `scripts/task/jobs-ingest.py` | stdin or `--in` | `POST /api/postings` on job-db-scraper |
| `deals:page` | `scripts/task/deals-page-scrape.py` | agent-browser, Firecrawl, Context.dev, Tavily, plain GET | stdout JSON, one object per URL |
| `deals:ingest` | `scripts/task/deals-ingest.py` | stdin or `--in` | `POST /api/deals` on private-deals |
| `agents:web` | `scripts/task/web-research.py` | the three hosted providers at once, or agent-browser | stdout only |
| `dev:inventory:site` | `scripts/task/inventory-sync.py` | `nix eval .#inventory.hosts`, or `--in` a JSON dump | `POST /api/items` on inventory-site |

```bash
task apps:page -- --backend http https://boards.greenhouse.io/acme > jobs.json
task apps:ingest -- --api https://delphi.cloudforest-kardashev.ts.net:8464 --in jobs.json

task deals:page -- --backend firecrawl --max 5 https://www.techbargains.com/ > deals.json
task deals:ingest -- --api https://delphi.cloudforest-kardashev.ts.net:8465 --in deals.json

task agents:web -- search "nix flake devshell" --max 5
task agents:web -- health https://nixos.org/ --via clanker

task dev:inventory:site DRY=1                        # what would be filed
task dev:inventory:site DRY=0 ONLY=delphi,frieren    # write two hosts
```

Every ingester prints a summary of what it filed, and exits 1 when the server
refused a record — one refusal does not stop the rest. Both are idempotent: the
URL is the identity the server fingerprints, so a second run updates instead of
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
task --list-all --json | jq -r '.tasks[].name' | grep -E '^(apps|deals|agents:web|dev:inventory:site)'
```

The sibling surfaces are [`email-archive`](email-archive.md) on `:8450` (the
mailbox the job lane reads for replies), [`agent-turns`](agent-turns.md) on
`:8460`, and the reader skills `.agents/skills/agent-browser`,
`.agents/skills/instabox` and `.agents/skills/apps`.
