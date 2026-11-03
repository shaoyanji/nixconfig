# kg-closure.jq — the reverse closure "who does a change to $root break".
#
# `.` is the compiled graph ({nodes, edges}); `--arg root` is a node id
# (host:frieren, skill:qmd, doc:docs/x.md). Output: the impacted ids, root
# excluded, sorted so two implementations can be compared byte for byte.
#
# Why this is a file and not a one-liner in each caller
# -----------------------------------------------------
# Two scripts used to carry their own version of this walk, and each got it
# wrong in a different direction (measured 2026-11-02, host:schneeeule):
#
#   engine (tools/kg-engine)         7   the transitive closure — correct
#   checks:kg:sidecar one-liner      2   DIRECT inbound edges only, so the gate
#                                        failed on a correct engine
#   kg-preflight fallback           10   accumulated each frontier into `seen`
#                                        without deduplicating, so a node reached
#                                        on two paths was counted twice
#
# The gate then reported "engine 7 vs jq 2" as engine drift. One definition
# removes the question: rstep() rebuilds the whole reachable set each hop, so
# there is no frontier/seen bookkeeping left to get wrong.
def rstep($edges):
  . as $s
  | ($s + [$edges[] | select(.to as $t | $s | index($t)) | .from] | unique);

. as $g
| ($root) as $r
| $g.edges as $E
| ([$r] | until(rstep($E) == .; rstep($E)))
| . - [$r]
| unique
| sort
