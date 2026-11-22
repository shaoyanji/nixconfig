# Lead: Deutsche Telekom / T-Systems — Site Reliability Engineer (SRE)

Fit: 4
Stand: 22.11.2026
Sprache: de
Referenz: 12444-563465374109756-DT-S

## Warum interessant

Die Stelle ist Telemetrie für Infrastruktur, die nicht im Rechenzentrum steht: Prometheus, Grafana, Loki und AlertManager für verteilte Fog- und Edge-Umgebungen, dazu Alerting für autonome Betriebsmodelle, Disconnected- und Air-Gap-Szenarien, lokale Retention und Datenmanagement unter knappen CPU-, Speicher- und Storage-Ressourcen. Arbeitsorte sind unter anderem Karlsruhe und Darmstadt; hybrides Arbeiten mit mobilem Anteil ist zugesagt. Von Gutach im Breisgau ist Karlsruhe rund anderthalb Stunden entfernt, das ist der nächste der genannten Standorte und der Grund, warum diese Bewerbung überhaupt sinnvoll ist.

## Was passt, ehrlich betrachtet

Betriebstelemetrie ist nicht angelesen, sondern gebaut: Ein Sentinel-Job schreibt alle 15 Minuten Jobstatus, Generation-Alter, Disk- und PSI-Druck in ein JSONL-Ledger. Gatus prüft Endpunkte, und eine Go-Bridge bestätigt eine Alarmzustellung erst, wenn die Nachricht tatsächlich ankommt — das ist der Unterschied zwischen Alerting und Benachrichtigung. Dazu Ressourcenlimits je Dienst, Speicherdruck als Messgröße erster Ordnung, restic mit durchgeführten Wiederherstellungen und Rollback je Generation. Alles läuft in einem Tailnet, ohne öffentliche Schnittstelle, auf eigener Hardware: ressourcenbegrenzt, ohne Managed Cloud.

## Was fehlt, und zwar vollständig

- Prometheus: kein Betrieb, kein PromQL, keine Federation, kein Remote Write, keine lokale Retention.
- Grafana: keine Dashboards, kein Provisioning as Code.
- Loki: kein Betrieb, kein LogQL, keine Compaction.
- AlertManager: kein Routing, keine Inhibition, keine Eskalationskonzepte.
- Kubernetes: kein Monitoring und kein Betrieb von Clustern.
- YAML als Konfigurationssprache im großen Stil; die eigene Konfiguration ist Nix.
- Terraform, Ansible, GitOps-Werkzeuge.
- OpenTelemetry.

Der Abgleich ist damit eindeutig: Die Denkweise und die Betriebserfahrung passen, der Werkzeugkasten der Must-Haves fehlt. Deshalb Fit 4 und nicht 5 — die Vorgabe nannte 5, das hält einer Prüfung der Must-Have-Liste nicht stand.

## Weg

Bewerbung über das Telekom-/T-Systems-Portal, Referenz 12444-563465374109756-DT-S. Fachliche Fragen: thomas.arbeit@t-systems.com. Keine Frist in der Anzeige genannt; Vollzeit, Teilzeit möglich, Start ab sofort.

## Gehalt

Keine Bandbreite genannt ("wettbewerbsfähiges Gehaltspaket"). Keine Zahl im Anschreiben; Tarifbindung und Eingruppierung erst im Gespräch.
