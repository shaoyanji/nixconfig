# Lead: smartclip Europe GmbH - Site Reliability Engineer Observability & Internal Tools

Fit: 3
Stand: 22.11.2026

## Warum interessant

Die Ausschreibung beschreibt fast wörtlich, was im eigenen Betrieb gebaut wurde: Alarme, die wirklich ankommen, ein Ledger statt eines Dashboards, Werkzeuge selbst schreiben statt SaaS einkaufen. Dazu remote als Standard und eine Vier-Tage-Option.

## Was passt

- Selbst gebaute Telemetrie: Sentinel-Ledger mit Jobstatus, Generation-Alter, Disk- und PSI-Druck alle 15 Minuten.
- Alarmierung mit Zustellbestätigung über eine Go-Bridge, also Alarme, die nicht ins Leere laufen.
- Linux-Interna: nftables, systemd-Units, Ressourcenlimits, eigene Zertifizierungsstelle.
- Security in der Pipeline: sops mit age, Gates je Host, kurzlebige Zertifikate.
- Öffentliches Repository als Nachweis, dass gebaut wird.

## Was fehlt

- Prometheus und Grafana sind Pflicht und nicht im Produktivbetrieb; die eigenen Werkzeuge sind Ersatz, nicht Ersatznachweis.
- Forgejo nicht verwendet.
- SLO- und Error-Budget-Sprache bisher nicht formal geführt.

## Weg

Bewerbung über die Originalanzeige, im Zweifel direkt bei smartclip. Die Prometheus-Lücke ist ein Muss-Kriterium; wer sie nicht im Anschreiben anspricht, wird vermutlich vor dem Gespräch aussortiert.
