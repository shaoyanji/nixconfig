# AGENTS.md

`Taskfile.yml` plus the `taskfiles/*` shards are the canonical entrypoint for every executable task.

Use this document to orient yourself to the routing map; follow `docs/task-control-plane.md` for namespace policy, `taskfiles/README.md` for ownership, and `.agents/README.md` for quick helper lookups.

`.agents/*` is guidance-only and never replaces the Taskfile truth.

Operator helpers now include the `agents:xs:*` wrappers (see `taskfiles/agents.yml`), which run `scripts/task/xs-helper.sh` against the local and service stores for artifact, contract, record, and trace work. NAS client recovery logic is living under `modules/profiles/nas-client.nix`, so storage/mount guidance should reference that profile rather than the old `hosts/common/localmounts.nix`.
