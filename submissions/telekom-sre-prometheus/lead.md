# Lead — Deutsche Telekom AG / T-Systems International GmbH, Site Reliability Engineer (SRE) (m/w/d)

**Stage: prep.** BA advert `12444-563465374109756-DT-S`, posted 30+ days ago, multiple sites,
part-time possible. Nothing submitted.

| Field | Value |
| :--- | :--- |
| Company | Deutsche Telekom AG / T-Systems International GmbH |
| Role | Site Reliability Engineer (SRE) (m/w/d) |
| Apply URL | https://www.arbeitsagentur.de/jobsuche/jobdetail/12444-563465374109756-DT-S |
| Source | Bundesagentur für Arbeit (BA ID 12444-563465374109756-DT-S) |
| Location | various (Kassel, Bielefeld, München, Berlin, Karlsruhe, Hannover, Dresden, Magdeburg, Saarbrücken, Darmstadt) |
| Language | German, C1 required |
| Salary | 85.000 – 95.000 EUR requested |
| Fit | 5 (recorded) — see the correction below |

## Why it is a lead

The role builds the monitoring and observability stack for distributed fog and edge infrastructure:
Prometheus, Grafana, Loki, Alertmanager, dashboards for hardware and network state, alerting for
disconnected and air-gapped operation, retention under CPU, memory and storage limits. Those
*problems* — telemetry design, alert delivery, resource-bounded collectors, retention as a budget —
are what this fleet's sentinel and ledger do.

## Correction: the tool stack is not what the fit score assumed

An earlier version of this file said the fleet "runs the monitoring stack… Prometheus, Grafana,
Loki, Alertmanager". That is false, and the packet does not repeat it:

| Claimed | Reality |
| :--- | :--- |
| Prometheus server | **none** — no `services.prometheus` in `modules/` or `hosts/` |
| PromQL, federation, remote write | never operated |
| Grafana | **none** in the tree |
| Loki / LogQL | **none**; logs are journald plus an event store |
| Alertmanager | **none**; gatus and the sentinel do the paging |
| node_exporter | **yes**, declared on `hosts/gok`, `:9100` |
| Telemetry pipeline | **yes**, hand-written: sentinel ledger every 15 minutes |
| Alert delivery | **yes**, with delivery confirmation through a bridge, de-duplicated by state hash |

## Gaps, honestly

- No Prometheus server, Grafana, Loki or Alertmanager administration: the metrics and logs half of
  the must-have list is a gap, the exporter and the alerting design are not.
- Kubernetes monitoring: containers have only been pinned build environments, never a supervised
  cluster.
- Air-gapped and disconnected-edge operation: rebuilt hosts and offline closures are adjacent, not
  production-proven in a carrier network.
- IaC here is Nix, not Terraform or Ansible.
- Enterprise scale and shift on-call are new; German is C1.

## Next action

Submit through the Telekom careers route the BA advert links to, quoting the BA reference.
