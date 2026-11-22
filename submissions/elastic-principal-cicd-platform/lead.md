# Lead: Elastic — Principal CI/CD & Platform Engineer

Fit: 4
Date: 22 November 2026
Location: Remote, EMEA
Source: brief only; no requisition fetched, route https://jobs.elastic.co/
Language: English

## State on arrival

A directory and DB row existed for this id, with no Typst sources and no usable packet; `letter.json` and any other JSON were removed, as were store symlinks and stale PDFs. The packet is new.

## Why it is interesting

The role is about the pipeline as a product: what it refuses, how fast the fast path is, and whether engineers trust it. That is the shape of the work in this repository, only at a different scale.

## What carries

- Reproducibility with meaning: pinned inputs, the same commit producing the same system.
- Gating on the evaluated configuration, not on exit code zero.
- Rollback as the previous generation.
- Matrix derived from inventory, so registration is what puts a host under test.
- Cost-tiered gates and sweeps that cannot take their own machine down.
- Documentation generated from the graph that drives the task menu.
- Linux depth: systemd, cgroups, namespaces, PSI, boot and initrd, nftables, WireGuard.
- Python and Go tooling.

## What does not

- CI at Elastic scale — thousands of builds a day, queueing, runner economics.
- Bazel, Gradle, distributed build caches, Kubernetes runners.
- The Java ecosystem the build depends on.

## Fit reasoning: 4

Briefed as 4 and the advert supports it. The judgement a principal CI/CD role needs — where a pipeline should refuse, what to cache, how to keep the fast path safe — is evidenced. The specific stack and the scale are not, and the letter says so in its third paragraph rather than letting the reader discover it.

A 5 would require the stack; a 3 would ignore five years of building exactly this kind of gate.

## Route

Apply through jobs.elastic.co. Confirm level and remote scope for EMEA from Germany. Certificates still missing.
