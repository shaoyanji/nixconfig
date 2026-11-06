---
name: mail-alias
description: Create, list and revoke disposable forwarding addresses on the ImprovMX domain — per-service aliases that make a leak traceable, plus the registry drift check. Pick me before signing up anywhere with a real address.
version: 0.1.0
platforms: [linux]
metadata:
  hermes:
    tags: [mail, dns, improvmx, aliases]
---

# mail-alias — disposable forwarding addresses

One domain forwards to one inbox: `@mail.shaoyanji.is-a.dev` → `jisifu@gmail.com`.
An alias is per-service on purpose. When mail starts arriving from somewhere you
never signed up for, the local part names the service that leaked or sold it, and
revoking one address is a single command.

`jisifu@gmail.com` cannot be un-given; a per-service alias can, and revoking it
is a record of what leaked. Any service that is not a primary identity gets an
alias, not the inbox.

## Before you add an alias

Read the live set first — the free plan allows 25 and six are in use:

```bash
task mail:aliases            # live aliases + declared kind/expiry
task mail:alias:drift        # registry vs live; must say "agree"
```

If `drift` reports `live, undeclared`, someone created an alias in the dashboard
and did not declare it: add it to `modules/config/mail-aliases.toml` (or delete
it). An undeclared alias is an address nobody owns.

## The four verbs

```bash
task mail:alias:tmp LABEL=notion              # notion-<hex>@…, expires in 30 days
task mail:alias:tmp LABEL=trial DAYS=7        # shorter window for a trial
task mail:alias:add NAME=bank KIND=permanent NOTE="bank statements"
task mail:alias:rm NAME=notion-3f9a1c2b       # asks first; YES=1 to skip
task mail:alias:prune                         # lists expired; YES=1 deletes
```

`tmp` is the default choice: it stamps `kind = "temporary"`, an `expires` date and
a `note` naming the service, then prints the revoke command for that address.
`add` is the same call without the expiry. Everything lands in
`modules/config/mail-aliases.toml`, the declared side of the drift check; writes
go through `scripts/task/mail-alias.sh` because it re-parses the file after every
table it appends or removes, and restores its backup if the edit broke it.

## Verify a change actually happened

A status code is not evidence here: the API returns a bare `404` both for "no
such route" and for "wrong domain spelling", and `DELETE …/aliases/<name>`
answers `200` while removing nothing. The script therefore re-reads the live
list after every write — but if you touch the API by hand, confirm with
`task mail:aliases` before believing anything.

The domain spelling is the other trap: `mail.shaoyanji.is-a-dev` (hyphen) 404s
for every route while `mail.shaoyanji.is-a.dev` (dot) works. The script resolves
the configured name against the account's own list, so a typo names the real
domains instead of looking like an outage.

## Records and the one real gap

```bash
task mail:alias:verify    # API verdict, then the same four records from DNS
task mail:alias:doctor    # auth, plan, counts, records, drift in one report
```

MX and SPF pass. **DMARC is missing**: the record belongs to `is-a.dev`, whose
nameservers serve JSON files from the `is-a-dev/register` repo. The open PR adds
one file, `domains/_dmarc.mail.shaoyanji.json`, holding `"TXT": ["v=DMARC1;
p=reject;"]` under `records` and the owner's username. DKIM has no expected
value on this plan.

## The key

`IMPROVMX.API.KEY` in `modules/secrets/apikeys.yaml` (sops, free plan: 30
requests/min per endpoint). The script decrypts it at run time with the user's
age key; nothing is exported and no rebuild is involved. If sops cannot decrypt,
the command exits 2 rather than guessing.

## Exit codes

`mail:alias:drift` — 0 agree, 1 drift, 2 unreachable.
`mail:alias:prune` — 0 nothing expired, 1 expired entries listed, 2 refused.
Every write — 2 when the API could not be reached or the change could not be
proven, and in that case nothing was recorded in the registry.
