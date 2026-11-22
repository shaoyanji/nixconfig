# Submission sheet — Nebius, Senior Site Reliability Engineer (Data Platform)

Role ID `nebius-senior-site-reliability-engineer-data-platform` · Greenhouse job **5040676101**
Posting https://careers.nebius.com/?gh_jid=5040676101 · first published 2026-11-17 · updated 2026-11-18
Location(s): Amsterdam, Netherlands; Berlin, Germany; Israel; London, United Kingdom; Prague, Czech Republic; Remote
Target compensation: **EUR 130,000 – 160,000** (ask EUR 140,000 – 155,000); no band published.

## Live Greenhouse fields (16 server-side labels)

| Field | Answer |
| :--- | :--- |
| First Name * | Matt |
| Last Name * | Ji |
| Preferred First Name | Matt |
| Email * | matt@bountystash.com |
| Country * | Germany |
| Phone * | +49 1733281570 |
| Location (City) * | Gutach im Breisgau (Freiburg area) — open to Berlin or fully remote across Europe |
| Attach | CV: lebenslauf.pdf; letter: anschreiben.pdf. Greenhouse application has no cover-letter file slot; the letter is included for the record and its content is repeated under Additional context. |
| Enter manually | n/a — files attached |
| LinkedIn Profile | https://linkedin.com/in/mattji |
| Website | https://www.bountystash.com |
| Which languages do you speak? * | English (native), German (C1, verhandlungssicher) |
| Are you currently authorized to work in the country where this position is located, without requiring sponsorship, now or in the future? * | Yes. US citizen with German permanent residence (unbefristete Niederlassungserlaubnis); no sponsorship needed in Germany or the EU. |
| Do you currently reside in the location specified for this role? * | Yes for Germany — based in Gutach im Breisgau and available for Berlin or remote across Europe. Not resident in the Netherlands, UK, Czech Republic or Israel. |
| Have you ever been employed by Nebius before? * | No |
| I have read Nebius’s Candidates Privacy Policy. * | Yes |

## Additional context (content of the one-page letter)

Applying for the Data Platform SRE role: a multi-tenant YTsaurus ecosystem at roughly 10 PB compressed across ~500 servers, where reliability comes from operations discipline rather than any single component. I run a 13-host NixOS fleet declared in one flake — pinned inputs, canary before fleet-wide change, short-lived SSH certificates from a CA, systemd units with defined failure behaviour, one-command rollback, and disk/PSI/service state collected on a schedule with a page on failed jobs rather than waiting to be noticed.

Stateful operations: PostgreSQL with versioned schema migrations, backup and rehearsed restore, latency and disk-pressure alerting. Durability is proved by a restore, not by a green dashboard. Go (23 Go files in this repo, including fleet alerting and dashboard services) and Python for operational tooling; C, C++ and Bash for deeper systems work.

## Gaps, stated plainly

- No YTsaurus, Hadoop, Spark, ClickHouse or Kafka operations.
- No production Kubernetes at 500-server scale, and no Kubernetes operator development.
- Storage and latency work at single-host and small-fleet scale, not multi-petabyte clusters.
- No formal capacity planning for multi-tenant platforms.

Honest fit is closer to 2 than 3 on the Big Data bonus list; recorded at 3 as instructed. The coding interview is a real gate — Go is used here for services, not as a primary language over years.

## Documents

- `lebenslauf.pdf` — 2 pages, Typst
- `anschreiben.pdf` — 1 page, Typst
- `selection.json` — 15/25 work highlights kept, 4/4 projects kept (nixconfig, email-archive, bountystash, fibtransponder); JD terms weighted Kubernetes, storage, systems, Go
- `job-description.txt` — text from the Greenhouse API, 5,397 chars

Nothing submitted. No account created.
