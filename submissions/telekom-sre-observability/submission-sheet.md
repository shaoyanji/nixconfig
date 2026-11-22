# Bewerbung — Deutsche Telekom IT GmbH, Senior SRE Observability

Stand: 22. November 2026
Fit: 4
Sprache: Deutsch
Status: Paket kompiliert; KRITIS- und Werkzeuglücke im Anschreiben benannt

## Stelle

| Feld | Wert |
| :--- | :--- |
| Arbeitgeber | Deutsche Telekom IT GmbH |
| Rolle | Senior Site Reliability Engineer, Schwerpunkt Observability |
| Umfeld | KRITIS-Telekommunikation, Fernarbeit in Deutschland |
| Quelle | Auftrag vom 22.11.2026, Bewerbungsweg telekom.jobs |
| Vergütung | im Anschreiben keine Zahl |

## Dokumente

| Dokument | Datei | Hinweis |
| :--- | :--- | :--- |
| Anschreiben | `anschreiben.pdf` | Eine Seite, deutsch, Lücke im dritten Absatz |
| Lebenslauf | `lebenslauf.pdf` | Zwei Seiten, deutsch |
| Quellen | `lebenslauf.typ`, `anschreiben.typ` | Typst, eigenständig kompilierbar |
| Zeugnisse | keine | fehlen weiterhin |

Vorher lag hier ein Paket zur Ausschreibung der Deutschen Telekom AG / T-Systems (Referenz 12444-563465374109848-DT-S, Observability/Tracing, zehn Standorte). Der Auftrag nennt jetzt die Deutsche Telekom IT GmbH mit KRITIS-Bezug und Fernarbeit; beide Dokumente sind neu geschrieben, die alten Typst-Quellen ersetzt.

## Anforderungsprüfung

| Anforderung | Nachweis | Bewertung |
| :--- | :--- | :--- |
| Betrieb von Linux-Hosts im Dauerbetrieb | 13 Hosts, drei Hardware-Generationen, fünf Jahre | Stark |
| Beobachtung als Schleife | Ledger alle 15 Minuten mit Zeitstempel, Gatus-Prüfungen, Auswertung von Druck und Speicher | Stark, eigenbau |
| Alarmierung mit Zustellbestätigung | Alarmkanal in Go, Erfolg erst nach bestätigter Zustellung | Stark |
| Automatisierte Störungserkennung | Alter der Generation, Speicher- und Prozessdruck als Vorlaufgrößen | Stark |
| Prometheus, Thanos, Loki, OpenTelemetry | nicht betrieben | **Lücke** |
| KRITIS und Regulierung (BSIG, IT-Grundschutz, Audits) | kein regulierter Betrieb verantwortet | **Lücke** |
| Kubernetes, Cloud | nicht vorhanden | **Lücke** |
| Deutsch C1 | C1, Englisch Muttersprache | Erfüllt |
| Fernarbeit aus Deutschland | Wohnsitz Freiburg, Niederlassungserlaubnis | Erfüllt |

## Begründung Fit 4

Die Beobachtungsschleife ist vorhanden und selbst gebaut: Ledger, Prüfungen von außen, Alarmkanal, der Zustellung bestätigt, Vorlaufgrößen statt Ausfallmeldungen. Das ist die Arbeit, die die Rolle beschreibt, nur mit eigenen Werkzeugen statt mit Prometheus.

Keine 5, weil zwei Dinge fehlen, die diese Stelle besonders macht: regulierter KRITIS-Betrieb mit Nachweispflichten, und der Werkzeugstapel selbst. Beides steht im Anschreiben, ohne Weichzeichner.

## Offene Punkte

1. **Prometheus, Loki, OpenTelemetry, Kubernetes** als Lücke benannt; die Bereitschaft, den hiesigen Stapel zu übernehmen, steht im letzten Absatz des dritten Teils.
2. **KRITIS-Auditierung** nicht vorhanden.
3. Zeugnisse fehlen.

## Paket

| Datei | Inhalt |
| :--- | :--- |
| `job-description.txt` | Ausschreibungstext, Stand vor dem Umbau. |
| `lead.md` | Fit, Lücken, Weg. |
| `lebenslauf.typ` | Typst-Quelle, zwei Seiten. |
| `anschreiben.typ` | Typst-Quelle, eine Seite. |
| `lebenslauf.pdf` | Zwei Seiten. |
| `anschreiben.pdf` | Eine Seite. |
| `submission-sheet.md` | Diese Übersicht. |
