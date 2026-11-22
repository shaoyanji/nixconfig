# Lead: Deutsche Telekom / T-Systems — SRE Observability/Tracing

Fit: 4
Stand: 22.11.2026
Referenz: 12444-563465374109848-DT-S
Standorte: unter anderem Karlsruhe (rund 1,5 h von Gutach im Breisgau)

## Quellenlage

Die Anzeige ist über die Arbeitsagentur-Jobdetails-API vollständig abrufbar (HTTP 200 am 22.11.2026) und liegt im Paket. Veröffentlicht am 12.07.2026, Eintritt ab 30.10.2026, zehn Standorte, Vergütung ohne Angabe. Das BA-Feld `homeofficemoeglich` steht auf `false`, obwohl Telekom-Stellen üblicherweise hybrid ausschreiben — im Gespräch klären, nicht im Anschreiben behaupten.

## Warum interessant

Die Rolle soll Transparenz, Stabilität und Zuverlässigkeit verteilter Systeme herstellen, mit Observability und Tracing als Schwerpunkt und OpenTelemetry ausdrücklich im Text. Das ist die Arbeit, die hier fünf Jahre lang ohne Werkzeugkasten gemacht wurde: messen, bevor jemand fragt, und Alarme so bauen, dass sie ankommen.

Karlsruhe ist der nächste der zehn Standorte und der Grund, warum diese Bewerbung sinnvoll ist.

## Was passt

- Betriebstelemetrie selbst gebaut: Sentinel-Ledger mit Jobstatus, Generation-Alter, Disk- und PSI-Druck alle 15 Minuten.
- Alarmierung mit Zustellbestätigung über eine Go-Bridge — ausgelöster und zugestellter Alarm werden nicht verwechselt.
- Endpunktprüfungen mit Gatus, Störungsdiagnose aus Ledger und Logs statt aus Vermutungen.
- Linux-Interna: cgroup-Limits, PSI, systemd-Härtung, Namespaces, nftables.
- Deklarativer Betrieb mit Generationen und Rückrollung; Git als einzige Quelle mit Gates.
- Karlsruhe rund anderthalb Stunden entfernt, Baden-Württemberg als Wohnsitz, Niederlassungserlaubnis.

## Was fehlt

- **OpenTelemetry** und verteiltes Tracing — beides im Aufgabentext genannt.
- Prometheus, Grafana, Loki, AlertManager.
- Kubernetes und Betrieb großer verteilter Systeme in Produktionsumgebungen.
- SLO-/Error-Budget-Programme im Teammaßstab.
- Erfahrung mit Telekom-/T-Systems-Prozessen.

## Weg

Bewerbung über das Telekom-/T-Systems-Portal mit der BA-Referenz. Keine Frist im Datensatz; Eintritt ab 30.10.2026 ist bereits verstrichen, die Anzeige wird aber weiter geführt — vor dem Absenden prüfen, ob sie noch offen ist.

## Gehalt

Die Anzeige nennt keine Vergütung. Ein früherer Plan notierte 85k als Ziel; die Vorgabe nennt keine Zahl, deshalb steht im Anschreiben keine.

## Fit-Begründung: 4 von 5

Vier laut Vorgabe. Die Begründung, die ich mittragen kann: Observability ist hier keine Theorie, sondern gebaute Praxis — ein Ledger, das jede Viertelstunde schreibt, Prüfungen, die wirklich laufen, und Alarme, deren Zustellung bestätigt wird. Wer das ohne Prometheus und Grafana gebaut hat, versteht, was die Werkzeuge leisten sollen.

Nicht 5, weil OpenTelemetry und Tracing ausdrücklich gefordert sind und vollständig fehlen; dazu Prometheus, Grafana und Loki. Vier beschreibt die Passung der Denkweise, nicht die Übereinstimmung des Stacks.
