# Lead: KAYAK - Staff Data Platform Engineer (Berlin)

Fit: 4
Stand: 22.11.2026

## Why it is interesting

KAYAK runs a shared data platform for analytics, machine learning, BI and AI features across the metasearch brands (momondo, Cheapflights, HotelsCombined). The role is a staff individual contributor on that platform: near-real-time streaming, lakehouse storage, schema management, semantic layer, distributed query infrastructure, data contracts, observability, cost and latency trade-offs. Berlin, three days a week in the office in Friedrichshain.

The overlap that matters is not "data engineering" in the pipeline-building sense. It is the part of the profile that treats storage and telemetry as designed systems: an append-only event log with content-addressed specifications, a telemetry ledger that is the source of truth for job health, delivery-confirmed alerting, and all of it declared in code with gates and rollback.

## What matches

- Event-log modelling with immutable, content-addressed records (bountystash): the same reasoning data contracts and schema evolution need.
- Telemetry ledger design: a Sentinel job writes job status, generation age, disk and PSI pressure every 15 minutes into JSONL; Gatus probes endpoints; a Go bridge confirms delivery.
- Declarative infrastructure: whole fleet as code in Git, per-host feature lists, gates and rollback per generation, CI running the same gate as the machines.
- Python and Go in production tooling, SQL and PostgreSQL in daily use, Bash for the glue.
- Storage discipline: restic backups with restores actually performed; retention and capacity watched, not assumed.
- Linux depth where it touches performance: PSI pressure, resource limits per service, systemd hardening, no service exposed.
- Mentoring and standards: runbooks, skill pages, task menu; led a team and built incentive structures at O3 Energy.
- English native; German C1; relocation to Berlin workable, three days on site acceptable.

## What is missing

- Lakehouse stack: no Iceberg, Parquet, S3, Trino, no semantic layer, no metadata or governance system.
- Streaming: no Kafka, Flink, event-driven ingestion with exactly-once semantics, consumer lag management, checkpointing.
- Orchestration: no Airflow or comparable scheduler at data scale.
- Cloud: no AWS or equivalent public cloud in production; no Kubernetes operation.
- Java and JVM frameworks: not used.
- Seven years of professional data engineering with domain-wide staff scope: the years are there in systems, not in data engineering, and staff-level scope at a company like KAYAK is a different scale than a thirteen-host fleet.
- No experience with analytics consumers, BI semantics, or the social side of platform adoption across many teams.

## Route

Arbeitnow listing, which forwards to KAYAK's own careers site. No deadline in the ad. Apply through KAYAK careers; the listing is the source, not the application form.

## Compensation

Not stated. KAYAK is Booking Holdings; Berlin staff-level compensation is typically well above the 85-95k EUR target, but nothing in the ad confirms it. No number in the letter; ask in the first call.
