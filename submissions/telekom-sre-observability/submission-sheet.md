# Bewerbung Deutsche Telekom / T-Systems — SRE Observability/Tracing

Stand: 22. November 2026
Fit: 4
Sprache: Deutsch (C1)

## Stelle

| Feld | Wert |
| :--- | :--- |
| Arbeitgeber | Deutsche Telekom AG / T-Systems International GmbH |
| Rolle | Site Reliability Engineer (SRE) (m/w/d), Schwerpunkt Observability |
| Referenz | 12444-563465374109848-DT-S, Chiffre 563465374109848 |
| Standorte | Darmstadt, Berlin, Dresden, Karlsruhe, Kassel, Saarbrücken, Hannover, Bielefeld, Magdeburg, München |
| Veröffentlicht | 12.07.2026, Eintritt ab 30.10.2026 |
| Vergütung | keine Angabe in den BA-Daten |
| Quelle | Arbeitsagentur-Jobdetails-API, HTTP 200 am 22.11.2026 |

## Dokumente

| Dokument | Datei | Hinweis |
| :--- | :--- | :--- |
| Anschreiben | `anschreiben.pdf` | Eine Seite, deutsch, mit der OpenTelemetry-Lücke im dritten Absatz |
| Lebenslauf | `lebenslauf.pdf` | Zwei Seiten, deutsch |
| Quellen | `lebenslauf.typ`, `anschreiben.typ` | Typst, eigenständig kompilierbar |
| Zeugnisse | keine Datei | Muss ergänzt werden |

## Abgleich

| Anforderung | Nachweis | Einschätzung |
| :--- | :--- | :--- |
| Observability verteilter Systeme | Eigene Toolchain: Ledger, Gatus, Go-Bridge mit Zustellbestätigung | Teilweise — Praxis ja, Stack nein |
| OpenTelemetry | Nicht vorhanden | **Lücke** |
| Verteiltes Tracing | Nicht vorhanden | **Lücke** |
| Prometheus, Grafana, Loki, AlertManager | Nicht vorhanden | **Lücke** |
| Linux-Plattform und Interna | systemd, cgroup-Limits, PSI, Namespaces, nftables | Stark |
| Deklarativer Betrieb, GitOps-Nähe | Git als einzige Quelle, Gates, Generationen, Rückrollung | Stark |
| Betrieb großer verteilter Systeme | Einzelne Flotte, kein Multi-Team-Betrieb | **Lücke** |
| Karlsruhe als Standort | Rund 1,5 h, Wohnsitz Baden-Württemberg | Erfüllt |
| Deutsch C1 | C1, Englisch Muttersprache | Erfüllt |
| Arbeitserlaubnis | US-Staatsangehörigkeit mit Niederlassungserlaubnis | Erfüllt |

## Fit-Begründung: 4 von 5

Vier laut Vorgabe, und die Begründung trägt: Observability ist hier gebaute Praxis, nicht Theorie — ein Ledger, das jede Viertelstunde schreibt, Prüfungen, die laufen, und Alarme, deren Zustellung bestätigt wird.

Nicht 5, weil OpenTelemetry und Tracing ausdrücklich gefordert sind und vollständig fehlen, dazu Prometheus, Grafana und Loki. Vier beschreibt die Passung der Denkweise, nicht die Übereinstimmung des Stacks.

## Offene Punkte

1. **OpenTelemetry und Tracing fehlen**; im Anschreiben benannt, nicht versteckt.
2. **Anzeige ist alt:** veröffentlicht 12.07.2026, Eintritt ab 30.10.2026 verstrichen, weiterhin gelistet. Vor dem Absenden prüfen, ob sie offen ist.
3. **Homeoffice-Flag:** BA-Daten sagen `homeofficemoeglich: false`; im Anschreiben steht deshalb nur hybrid mit Präsenz bei Bedarf, keine Behauptung über Telekom-Regeln.
4. Zeugnisse fehlen.
5. Keine Gehaltsangabe im Anschreiben; ein früherer Plan notierte 85k, die Vorgabe nennt keine Zahl.

## Paket

| Datei | Inhalt |
| :--- | :--- |
| `job-description.txt` | Vollständige Anzeige aus der BA-API mit Abgleichsnotiz. |
| `lead.md` | Fit, Lücken, Weg, Gehalt. |
| `lebenslauf.typ` | Typst-Quelle, eigenständig kompilierbar. |
| `anschreiben.typ` | Typst-Quelle, eigenständig kompilierbar. |
| `lebenslauf.pdf` | Zwei Seiten. |
| `anschreiben.pdf` | Eine Seite. |
| `submission-sheet.md` | Diese Übersicht. |
