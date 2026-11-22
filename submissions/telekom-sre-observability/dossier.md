# Dossier — T-Systems SRE Observability/Tracing

Stand: 22. November 2026
Fit: 2 von 5
Bewerber: Matt Ji, Gutach im Breisgau
Arbeitgeber: Deutsche Telekom AG / T-Systems International GmbH

## 1. Die Stelle in einem Absatz

T-Systems sucht einen Site Reliability Engineer, der eine Observability-Plattform für verteilte Cloud-, Edge- und Kubernetes-Umgebungen aufbaut und betreibt: Pipelines für Metrics, Logs und Traces, OpenTelemetry Collector und OTLP, Auto-Instrumentation, Jaeger als Tracing-Backend, Korrelation zwischen den drei Signalarten, Anbindung von Security- und Infrastruktur-Events an zentrale SIEM-Systeme, Telemetrie-Standards für Kubernetes. Zehn Standorte, hybrides Modell, Eintritt ab 30.10.2026, keine Vergütungsangabe.

## 2. Anforderungen und Belege

| Anforderung | Art | Beleg im Paket | Urteil |
| :--- | :--- | :--- | :--- |
| OpenTelemetry (Collector, OTLP, SDKs, Auto-Instrumentation) | Must | keiner | fehlt |
| Distributed Tracing (Span-Korrelation, Context Propagation, Sampling) | Must | Konzept, Korrelation über Zeitstempel und Host | fehlt im Betrieb |
| Jaeger (Storage, Indexierung, Query) | Must | keiner | fehlt |
| SIEM-Integration, CEF, Syslog | Must | journald/Syslog im Betrieb, CEF nicht | halb |
| Go, Python oder Shell | Must | Go-Alarmbrücke, Python-Auswertung, Shell-Rollout | vorhanden |
| Kubernetes-Observability | Must | keiner | fehlt |
| Security Awareness | Must | eigene CA, kurzlebige Zertifikate, sops/age, nftables, Härtung | stark |
| SRE-/Infrastrukturbetrieb | Must | fünf Jahre, 13 Hosts, drei Generationen, Gates, Rückrollung | stark |
| Deutsch C1 | Must | C1, Englisch Muttersprache | vorhanden |
| OTel-Pipelines, Jaeger-Admin, Korrelation, Cloud-Native-Standards | Nice | Ledger und Prüfungen selbst gebaut | indirekt |
| Air-Gap-, Edge-, Fog-Betrieb | Nice | Verbund ohne externe Abhängigkeiten, Netzinstallation | teilweise |

## 3. Was die Bewerbung trägt

Die Beobachtungsschleife ist gebaut, nicht behauptet: ein Ledger schreibt alle fünfzehn Minuten Jobstatus, Generation-Alter, Plattenplatz und Druck; Prüfungen laufen von außen; ein Alarmkanal in Go gilt erst als gemeldet, wenn die Zustellung bestätigt ist. Wer Alarme ohne Zustellbestätigung gebaut hat, weiß, warum Trace-Kontext und Sampling keine Kosmetik sind.

Dazu die Messdisziplin: 2012 am Fraunhofer ISE Messaufbau, Geräteansteuerung in C++, Auswertung in Python, Ablage nachvollziehbar. Diese Herkunft erklärt, warum im Betrieb zuerst der Verlauf gelesen wird und nicht das Dashboard.

## 4. Was die Bewerbung nicht trägt

Der Werkzeugstapel der Stelle: OpenTelemetry, Jaeger, verteiltes Tracing, SIEM/CEF, Kubernetes, Prometheus, Loki. Alle fünf Must-Have-Technologien außer Go/Python/Shell und SRE-Erfahrung fehlen. Das ist keine Lücke am Rand, das ist der Titel.

## 5. Entscheidung: 2

Die Betriebsform passt, die Technik nicht. Bei einer Stelle, die eine Plattform einführt, wäre ein Bewerber ohne OTel-Erfahrung eine Einarbeitung von Monaten auf dem Kerngebiet — deshalb zwei, nicht drei oder vier. Der Nutzen dieser Bewerbung liegt im Gespräch über Beobachtung und Alarmierung, falls der Arbeitgeber bereit ist, den Stack beizubringen.

## 6. Logistik

- Nächster Standort: Karlsruhe, rund anderthalb Stunden von Gutach im Breisgau; Bereitschaft zu regelmäßiger Anwesenheit steht im Schreiben.
- Hybrides Modell laut Anzeige, BA-Feld `homeofficemoeglich: false` — keine Fernarbeitszusage im Schreiben.
- Zeugnisse fehlen; ohne sie geht nichts raus.
- Die Anzeige ist offen: öffentliche BA-Detailseite am 22.11.2026 mit 200, Beginn „ab sofort"; nur die API liefert 404. Im Telekom-Portal die dortige Referenz klären.
- Eine benachbarte Referenz (…756-DT-S) ist eine andere SRE-Stelle ohne Observability-Schwerpunkt und nicht zitierfähig für diese Bewerbung.

## 7. Fragen für ein Gespräch

1. Wird die Plattform neu aufgebaut oder abgelöst? Welche Signale sind heute schon instrumentiert?
2. Wie groß ist das Telemetrievolumen, und wo liegt die Kostengrenze — Sampling-Quote, Retention, Trace Storage?
3. Welche SIEM-Ziele sind angebunden, und wer entscheidet über CEF-Mapping?
4. Wie viele Standorte sind real besetzt, und wie viel Vor-Ort-Anteil erwartet die Rolle in Karlsruhe?
5. Wird die Einarbeitung in OpenTelemetry und Jaeger als Teil der Stelle gesehen oder vorausgesetzt?

## 8. Dateien

| Datei | Inhalt |
| :--- | :--- |
| `job-description.txt` | Anzeigentext mit Referenz, Standorten und Must-Haves, plus Quellenstatus |
| `lebenslauf.typ` / `.pdf` | Zwei Seiten, deutsch |
| `anschreiben.typ` / `.pdf` | Eine Seite, deutsch, Lücke im dritten Absatz |
| `submission-sheet.md` | Messwerte, Fit-Map, offene Punkte |
| `lead.md` | Kurzfassung für die Pipeline |
| `dossier.md` | Dieses Dokument |
