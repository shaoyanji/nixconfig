# IONOS SE — Staff Network Reliability Engineer (f/m/d)

Greenhouse `ionos2` req **4971782101**, Karlsruhe. English packet. Native Typst sources, `packet` symlink and
JSON leftovers removed. Status: built and checked, **nothing submitted**.

| Field | Value |
| :--- | :--- |
| Role ID | `ionos-staff-nre` |
| Employer | IONOS SE |
| Role | Staff Network Reliability Engineer (f/m/d) |
| Req | 4971782101 |
| Site | Karlsruhe — about 1.5 h from Gutach |
| Language | **English** (posting language) |
| Compensation | no figure in the letter — none supplied |
| Fit | 2 (DB entry 4) |

## Fit map

| Requirement | Evidence | Verdict |
| :--- | :--- | :--- |
| Network design and operation | nftables, WireGuard, DNS zone, TLS CA, MTU analysis | strong at fleet scale |
| Telemetry and alerting | Fifteen-minute ledger, silence as a fault | strong |
| Linux depth | systemd, journald, cgroups/PSI, tcpdump, strace | strong |
| Change discipline / rollback | Gate identical in CI and host, generation rollback | strong |
| AI-assisted operations with verification | Daily AI drafting, artefact verified before production | strong, specific |
| Data-centre networking (BGP, EVPN, switching) | **not done** | **gap** |
| Carrier-grade / staff-level scope | **no staff-scope ownership** | **gap** |
| Regional anchor | Baden-Württemberg, Karlsruhe ~1.5 h | fulfilled |

## The judgment call on this packet

A Staff NRE at a hosting provider is a senior network engineer first and a reliability engineer second. The corpus
is the reverse ratio: strong on reliability, gate design, telemetry and Linux interiors; thin on protocols that
carry a data centre. So the letter states that plainly — *"I would be learning the protocols and the hardware
rather than repeating work I have done"* — and the sheet scores **fit 2** against the 4 written to the DB.

What makes it worth sending anyway is the one requirement that is genuinely rare and clearly present: **AI in
operations with real verification**. The letter's line — *a machine may propose, a check must dispose* — is backed
by practice, not attitude: AI drafts configuration, scripts and docs, then every artefact is read and checked
against the running system before it can reach a production path. Most candidates answer that question with
enthusiasm; this one answers it with a control.

## Checks

| Check | Result |
| :--- | :--- |
| `packet` symlink | removed |
| Legacy JSON | removed |
| `chmod u+w *.pdf` | applied |
| `typst compile lebenslauf.typ` | exit 0, no warnings |
| `typst compile anschreiben.typ` | exit 0, no warnings |
| `pdfinfo lebenslauf.pdf` | **2 pages** |
| `pdfinfo anschreiben.pdf` | **1 page** |
| Markers | `4971782101`, `BGP`, `EVPN`, `a machine may propose`, `1.5 hours` |
| `task checks:prose` | 241 prose files, exit 0 |
| sha256 CV | `3adc1e179fd23f011267c84ce2bf9b4ccdc1459b0f453f5d0f53ec9a268993e5` |
| sha256 letter | `ad406bfd76c83fa89a8cded768d72f8478705cefb40dcdc95a85ddfef44c1e8a` |
| DB read-back | verified after upsert (see notes) |

## Next steps

1. Apply through the Greenhouse link with req 4971782101.
2. If invited, ask which protocols dominate the estate — BGP/EVPN underlay, DDoS scrubbing, or peering — because
   the answer determines how steep the first six months are.
3. Keep this behind the Freiburg packets in priority: same country, far better fit at 25 km.
