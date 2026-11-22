# Bewerbung — Deutsche Telekom AG / T-Systems, SRE Observability/Tracing

Stand: 22. November 2026
Fit: 2
Sprache: Deutsch
Status: Dossier neu gebaut für den in der Aufgabe genannten Arbeitgeber; Anzeigentext wiederhergestellt; Fit nach Lesen der Must-Haves auf 2 gesetzt

## Stelle

| Feld | Wert |
| :--- | :--- |
| Arbeitgeber | Deutsche Telekom AG / T-Systems International GmbH |
| Rolle | Site Reliability Engineer (SRE), Schwerpunkt Observability |
| Referenz | 12444-563465374109848-DT-S, Chiffre 563465374109848 |
| Standorte | Darmstadt, Berlin, Dresden, Karlsruhe, Kassel, Saarbrücken, Hannover, Bielefeld, Magdeburg, München |
| Veröffentlicht | 12.07.2026, Eintritt ab 30.10.2026 |
| Vergütung | in der Anzeige keine Angabe |
| Weg | https://telekom.jobs/ — Referenz im Anschreiben genannt |

## Gemessene Artefakte

| Datei | Seiten | Bytes | Wörter | SHA-256 (gekürzt) |
| :--- | :--- | :--- | :--- | :--- |
| `lebenslauf.pdf` | 2 | 39518 | 625 | `160a2cad218466ab` |
| `anschreiben.pdf` | 1 | 24500 | 360 | `1c0145b518e35427` |

## Fit-Map

| Anforderung (Must-Have) | Nachweis im Paket | Bewertung |
| :--- | :--- | :--- |
| OpenTelemetry: Collector, OTLP, SDKs, Auto-Instrumentation | nicht vorhanden | **Kernlücke** |
| Distributed Tracing: Span-Korrelation, Context Propagation, Sampling | Konzept bekannt, nicht im Betrieb; Korrelation bisher über Zeitstempel und Hostnamen | **Kernlücke** |
| Jaeger: Trace Storage, Indexierung, Query-Optimierung | nicht vorhanden | **Kernlücke** |
| SIEM-Integration, CEF, Syslog | Syslog aus journald im Betrieb, CEF und SIEM nicht | Teilweise |
| Go, Python oder Shell | Go-Brücke mit Zustellbestätigung, Python-Auswertung, Shell für Rollout | Erfüllt |
| Kubernetes-Observability, Cloud-Native | nicht vorhanden | **Lücke** |
| IT-Sicherheit, Security Awareness | eigene CA mit kurzlebigen Zertifikaten, Secrets pro Host, nftables, WireGuard, Härtung | Stark |
| SRE- oder Infrastrukturbetrieb | fünf Jahre allein, 13 Hosts, drei Hardware-Generationen, Gates und Rückrollung | Stark |
| Deutsch C1 | C1, Englisch Muttersprache | Erfüllt |
| Analytische, strukturierte Arbeitsweise | Messreihen und Vorlaufgrößen statt Ausfallmeldungen; Dokumentation als Teil des Betriebs | Stark |

| Anforderung (Nice-to-Have) | Nachweis | Bewertung |
| :--- | :--- | :--- |
| OTel-Pipelines für Metrics, Logs, Traces | Ledger und Prüfungen selbst gebaut, ohne OTel | Indirekt |
| Jaeger-Administration | nicht vorhanden | Lücke |
| Korrelation Logs/Metrics/Traces | Korrelation über Zeitstempel und Host, nicht über Trace-Kontext | Indirekt |
| Telemetrie-Standards für Cloud-Native | Standards im eigenen Verbund, nicht cloud-nativ | Teilweise |
| Air-Gap-, Edge-, Fog-Betrieb | Betrieb ohne externe Abhängigkeiten, Auslieferung über das Netz | Teilweise |

## Fit-Begründung: 2

Die Anzeige benennt OpenTelemetry, verteiltes Tracing und Jaeger als Must-Have — das ist der Titel der Stelle, nicht ein Nebensatz. Nichts davon ist vorhanden; das Anschreiben sagt es im dritten Absatz und nennt auch die Korrelation über Zeitstempel als das, was sie ist: Handarbeit, die bei dreizehn Knoten trägt und bei verteilten Diensten nicht mehr.

Zwei statt drei, weil die Differenzierung der Stelle genau in der fehlenden Technik liegt. Getragen wird die Bewerbung von der Betriebsform: Beobachtung als Schleife, Alarme mit bestätigter Zustellung, Werkzeuge selbst geschrieben, Änderungen geprüft und rückrollbar.

## Offene Punkte

1. **Anzeige weiter gelistet**: die Jobdetails-API antwortet mit 404, die öffentliche Detailseite derselben Referenz am 22.11.2026 mit 200 und nennt als Beginn „ab sofort" (API-Datensatz: 30.10.2026). Eine frühere Fassung dieses Blattes hielt die Stelle für geschlossen — das war eine Fehlfolgerung aus dem API-Status. Vor dem Absenden nur noch klären, unter welcher Referenz sie im Telekom-Portal läuft.
2. **Vor-Ort-Anteil**: die Anzeige nennt ein hybrides Modell, das BA-Feld `homeofficemoeglich` steht auf `false`. Im Schreiben steht deshalb Bereitschaft zu regelmäßiger Anwesenheit in Karlsruhe, keine Fernarbeitszusage.
3. **Zeugnisse** fehlen weiterhin; ohne sie geht das Paket nicht raus.
4. **Kein Gehaltswunsch** im Schreiben, weil die Anzeige keine Spanne nennt.
