# The xs turn body, rendered by `jq -n -f` from `task agents:xs:post`.
#
# This file is the schema. The shim (modules/services/agent-turns/shim.py) fixes
# the field set and rejects an unknown key, so a field is added here once and no
# caller ever assembles JSON by hand. Every value arrives as a `--arg` string,
# which is why prose with quotes cannot corrupt the body.
#
# Lists arrive comma- or newline-separated; blank entries disappear, so FILES=""
# renders [] rather than [""].
def tolist:
  [splits("[\n,]")] | map(gsub("^\\s+|\\s+$"; "")) | map(select(length > 0));

# rationale, base_commit and branch are `string or null` in the shim, and an
# empty string is not null — it fails the hash check on base_commit.
def ornull: if length > 0 then . else null end;

{
  id: $id,
  ts: $ts,
  source: $source,
  kind: "turn",
  subject: $subject,
  action: $action,
  rationale: ($rationale | ornull),
  base_commit: ($base_commit | ornull),
  branch: ($branch | ornull),
  files_changed: ($files | tolist),
  commits: ($commits | tolist),
  claims: ($claims | tolist),
  outcome: $outcome
}
