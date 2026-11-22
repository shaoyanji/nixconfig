# STACKIT / Schwarz Digits — (Senior) Site Reliability Engineer, STACKIT Control Plane (m/f/d)

Req **GT2321**, Bad Friedrichshall (Baden-Württemberg), hybrid. English dossier. Native Typst sources.
Stand: packet built, **nothing submitted**. **[applied per apps DB `stackit-schwarz-digits-senior-sre-control-plane` — this sheet's status predates submission]**

| Field | Value |
| :--- | :--- |
| Role ID | `stackit-schwarz-digits-senior-sre-control-plane` (directory `stackit-sre`) |
| Employer | STACKIT / Schwarz Digits |
| Role | (Senior) Site Reliability Engineer — STACKIT Control Plane |
| Req | GT2321 |
| Location | Bad Friedrichshall, Baden-Württemberg — hybrid |
| Language | **English** (CV and letter) |
| Compensation | band 85,000 – 110,000 EUR; letter states 95,000 – 105,000 |
| Fit | 3 (DB entry 4 as instructed) |

## Fit map

| Requirement | Evidence | Verdict |
| :--- | :--- | :--- |
| Reliability engineering, production discipline | Five years of gated changes, generation rollback, tested recovery | strong |
| Declarative infrastructure | One flake, pinned inputs, rebuild as a path | strong |
| Telemetry and alerting | Fifteen-minute ledger, PSI, cgroups, any-state-short-of-ok | strong |
| Failure analysis | journald, cgroups, tcpdump, strace to a cause | strong |
| High availability | No half-applied rollout, previous generation keeps serving | strong |
| Cloud control plane | **not operated** | **gap** |
| Kubernetes at scale / multi-tenancy | **not in production** | **gap** |
| Go / automation | Go service, tools behind one task surface | strong |
| Regional presence | resident in Baden-Württemberg, on-site days accepted | strong |

## The two gaps, stated in the letter

No cloud control plane operated and no production Kubernetes administration. The letter says this in the fourth
paragraph, in the same breath as what the smaller version of the guarantee looks like on a thirteen-host fleet —
and leaves the decision to the reader: exact-scale experience, or operating discipline plus the ability to learn
the platform. Writing it any other way would fail in the first technical conversation, and control-plane
interviews are technical early.

## Compensation

Advertisement carries 85,000 – 110,000 EUR. The letter asks **95,000 – 105,000**, inside the band, leaving room
at both ends. The figure comes from the assignment, not an estimate.

## Language choice

The advert is English and so is the dossier: a German application to an English requisition reads as a candidate
who ignored the posting. The CV header, sections and letter are English throughout; German C1 is stated rather
than demonstrated here, which is the one thing this packet cannot show.

## Checks

| Check | Result |
| :--- | :--- |
| `packet` symlink, JSON artifacts | removed |
| `chmod u+w *.pdf` before compile | applied |
| `typst compile lebenslauf.typ` | exit 0, no warnings |
| `typst compile anschreiben.typ` | exit 0, no warnings |
| `pdfinfo lebenslauf.pdf` | **2 pages** |
| `pdfinfo anschreiben.pdf` | **1 page** |
| Markers | `GT2321`, `control plane`, `Baden-Württemberg`, `95,000`, `permanent residence` |
| `task checks:prose` | 241 prose files, exit 0 |
| sha256 CV | `c94da85bf8e424869d184c584ec679dfe9abeed12b22274fe8be77a9d88b68b7` |
| sha256 letter | `bc04b44dbd20c8c05a1c3bcaa2dd762f0b16f9bde2c678054717e7e23fc6e312` |

## Next steps

1. Apply through the Schwarz Digits portal with req **GT2321**.
2. Ask early how much of the role is control-plane on-call versus platform build — it decides whether the gap matters.
3. Keep the German C1 line in the CV; it is the only proof of German in an otherwise English packet.
