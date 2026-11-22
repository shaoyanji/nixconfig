# Deutsche Telekom AG / T-Systems — Site Reliability Engineer (SRE) (m/w/d)

**BA `12444-563465374109756-DT-S`.** Posted 30+ days ago, multiple sites, part-time possible,
hybrid. Status: packet prepared, **nothing submitted**.

| Field | Value |
| :--- | :--- |
| Role ID | `telekom-sre-prometheus` |
| BA reference | 12444-563465374109756-DT-S |
| Employer | Deutsche Telekom AG / T-Systems International GmbH |
| Sites | Kassel, Bielefeld, München, Berlin, **Karlsruhe**, Hannover, Dresden, Magdeburg, Saarbrücken, Darmstadt |
| Contract | Vollzeit, Teilzeit möglich, ab sofort, hybrid |
| Salary | **85.000 – 95.000 EUR** band; letter states **90.000** |
| Language | German, C1 required |
| Contact | fachliche Fragen: thomas.arbeit@t-systems.com (published in the advert) |

## Correction carried into this packet

`lead.md` previously claimed the fleet "runs the monitoring stack… Prometheus, Grafana, Loki,
Alertmanager". It does not, and both the lead and the sheet now say so: there is **no Prometheus
server, no Grafana, no Loki and no Alertmanager** in this repository. What exists is a `node_exporter`
declared on `hosts/gok` (`:9100`), a hand-written sentinel ledger, gatus health checks and alert
delivery with confirmation through a bridge. The CV keeps the posting's vocabulary for tools the
fleet does not run out of its bullets and puts them in the letter as gaps.

## Fit map

| Requirement (Must-have) | Evidence | Verdict |
| :--- | :--- | :--- |
| Prometheus: PromQL, federation, remote write, local retention | **No Prometheus server operated.** Retention and resource budgets are handled by hand in the ledger | **gap** |
| Grafana: dashboards, alerting, provisioning-as-code, logs | **No Grafana.** Dashboards are the ledger plus plain HTML | **gap** |
| Loki: LogQL, retention, compaction, alerting | **No Loki.** Logs run through journald and an event store | **gap** |
| Alertmanager: routing, inhibition, escalation, notification | **No Alertmanager.** gatus and the sentinel page; state changes are hashed and posted once | partial — alert design yes, the product no |
| Kubernetes monitoring and cloud-native | Containers only as pinned build environments; no supervised cluster | **gap** |
| Edge/fog: constrained CPU, memory, storage | ARM boards, MicroVMs, per-slice memory limits, PSI instead of guessed thresholds | strong |
| Offline, air-gap, disconnected operation | Hosts rebuild offline from a pinned closure; no carrier air-gap production | partial — adjacent |
| Very good YAML | YAML and Nix are the fleet's configuration formats | strong |
| IT security and security awareness | SOPS/age, SSH CA with short-lived certificates, nftables default-deny, KEV-based vulnerability practice | strong |
| SRE or infrastructure operations experience | Three years operating a thirteen-host fleet; incidents end in a gate | strong in scale, small in size |
| German C1 | Letter and CV in German, C1 | strong |
| Nice: IaC (Terraform, Ansible), GitOps, Linux admin, OpenTelemetry | IaC is Nix; GitOps in substance; Linux admin strong; no OpenTelemetry | partial |

## What the CV says, measured on the built PDF

**node_exporter, PSI × several, cgroup, Linux, systemd, YAML, Sentinel, Ledger** appear; measured on
the text, **Prometheus, Grafana, Loki, Alertmanager, PromQL and Kubernetes are not in the CV**. That is
deliberate: the letter names them and says exactly which part is missing.

## Application route

The BA advert carries no form of its own and hides the contact behind a character test; the
application goes through the Telekom careers route with the documents below and the BA reference
quoted. Salary answer: 90.000 EUR, inside the 85.000 – 95.000 band.

| Document | File |
| :--- | :--- |
| Lebenslauf | `lebenslauf.pdf` (2 Seiten) |
| Anschreiben | `anschreiben.pdf` (1 Seite) |
| Quellen | `lebenslauf.json`, `letter.json` |
| Projektion | `packet/selection.json` |

## Checks

| Check | Result |
| :--- | :--- |
| `pdfinfo lebenslauf.pdf` | **2 pages** (budget 2) |
| `pdfinfo anschreiben.pdf` | **1 page** (budget 1) |
| `task checks:prose` | 211 prose files, exit 0 |
| selection | 9/25 highlights, 4/8 projects |
| sha256 CV | `53a2cb7a07557b7262af8964b0d75298dbcbdcaa500e6a57546acc2effffe1cf` |
| sha256 letter | `a3a973438bc7c50ec4967df35ec56a635f8ef4fe34dcb26c4e10532a80d02388` |

## Next actions

1. Apply through the Telekom careers route quoting the BA reference; the BA page forwards.
2. Prepare the honest Prometheus answer for the first call: exporter, metrics design, retention and
   alert delivery are real; PromQL, federation and remote write are the learning list.
3. Karlsruhe as the preferred site keeps the commute at ~130 km — ask whether the team sits there or
   only the contract does.
