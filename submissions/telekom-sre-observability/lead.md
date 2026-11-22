# Lead: Deutsche Telekom AG / T-Systems — SRE Observability/Tracing

Fit: 2
Stand: 22.11.2026
Referenz: 12444-563465374109848-DT-S (Chiffre 563465374109848)
Standorte: zehn, darunter Karlsruhe (rund 1,5 h von Gutach im Breisgau)
Veröffentlicht: 12.07.2026, Eintritt ab 30.10.2026
Weg: https://telekom.jobs/

## Quellenlage

Der Anzeigentext liegt vollständig im Paket (Abruf der Arbeitsagentur-Jobdetails-API, HTTP 200 am 22.11.2026). Ein erneuter Abruf derselben Referenz am 22.11.2026 liefert 404 — die Anzeige ist damit sehr wahrscheinlich geschlossen, der Eintrittstermin ohnehin verstrichen. Vor dem Absenden prüfen, ob die Rolle weiterläuft.

Das Verzeichnis enthielt zwischenzeitlich ein Paket für die Deutsche Telekom IT GmbH ohne Anzeigentext, weil der T-Systems-Text als veraltet entfernt worden war. Beides ist korrigiert: der Text ist wieder da, die Dokumente adressieren den Arbeitgeber aus der Aufgabe.

## Warum interessant

Die Rolle baut eine Observability-Plattform für verteilte Cloud-, Edge- und Kubernetes-Umgebungen: Pipelines für Metrics, Logs und Traces, Jaeger als Tracing-Backend, Korrelation zwischen den drei Signalen, Telemetrie-Standards. Das ist die Arbeit, die hier fünf Jahre lang ohne Werkzeugkasten gemacht wurde — Ledger, Prüfungen, Alarme mit bestätigter Zustellung.

Karlsruhe ist der nächste der zehn Standorte und der Grund, warum die Bewerbung trotz der Lücken sinnvoll ist.

## Was passt

- Beobachtung als Schleife: Ledger alle 15 Minuten, Prüfungen von außen, Vorlaufgrößen statt Ausfallmeldungen.
- Alarmweg in Go, der erst nach bestätigter Zustellung als gemeldet gilt.
- Linux-Interna: cgroups, Namespaces, PSI, systemd-Härtung, nftables.
- Sicherheitsseite: eigene CA mit kurzlebigen Zertifikaten, Secrets pro Host (sops, age), WireGuard.
- Go, Python, Shell — die Werkzeuge selbst geschrieben.
- Deklarativer Betrieb mit Gates und Rückrollung über Generationen.
- Karlsruhe rund anderthalb Stunden entfernt, Niederlassungserlaubnis, Deutsch C1.

## Was fehlt

- **OpenTelemetry**: Collector, OTLP, SDKs, Auto-Instrumentation — Must-Have.
- **Verteiltes Tracing**: Span-Korrelation, Context Propagation, Sampling — Must-Have.
- **Jaeger**: Trace Storage, Indexierung, Query-Optimierung — Must-Have.
- **SIEM und CEF** — Must-Have (Syslog dagegen im Betrieb).
- **Kubernetes und Cloud-Native-Plattformen** — Must-Have.
- Prometheus, Grafana, Loki, AlertManager.
- Betrieb in Air-Gap-, Edge- und Fog-Umgebungen.

## Wie die Lücke im Schreiben behandelt wird

Nicht weichgezeichnet: der dritte Absatz nennt OpenTelemetry, Jaeger, Tracing, SIEM/CEF und Kubernetes als nicht vorhanden. Der zweite Absatz macht die Korrelation über Zeitstempel und Hostnamen zum Argument — sie funktioniert bei dreizehn Knoten und ist genau das, was ein Collector automatisiert.

## Fit-Begründung: 2

Must-Have-Liste gelesen, Kern fehlt: OpenTelemetry, Tracing und Jaeger sind der Titel der Stelle. Die Betriebsform passt, die Technik nicht. Zwei heißt: ein Gespräch über Beobachtung, Alarmierung und Werkzeugbau ist möglich; eines über OTel-Pipelines, Sampling und Trace Storage nicht.

## Weg

Erst prüfen, ob die Rolle offen ist (BA-Referenz 404, Eintritt verstrichen). Dann Zeugnisse ergänzen und über telekom.jobs mit der Referenz bewerben. Kein Gehaltswunsch im Schreiben, weil die Anzeige keine Spanne nennt.
