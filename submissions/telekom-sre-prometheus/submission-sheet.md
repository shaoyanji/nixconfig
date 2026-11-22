# Bewerbung — T-Systems, Site Reliability Engineer (SRE) Prometheus

Stand: 22. November 2026
Fit: 3
Sprache: Deutsch
Status: Paket kompiliert, gemessen, Werkzeuglücke im Anschreiben benannt

## Stelle

| Feld | Wert |
| :--- | :--- |
| Arbeitgeber | Deutsche Telekom AG / T-Systems International GmbH |
| Rolle | Site Reliability Engineer (SRE) (m/w/d), Schwerpunkt Prometheus |
| Referenz | 12444-563465374109756-DT-S |
| Standorte | Kassel, Bielefeld, München, Berlin, Karlsruhe, Hannover, Dresden, Magdeburg, Saarbrücken, Darmstadt |
| Anstellung | Vollzeit, Teilzeit möglich, hybrid mit mobilem Arbeiten, ab sofort |
| Quelle | Arbeitsagentur-Jobdetails, Anzeige liegt vollständig im Paket |
| Fachliche Fragen | thomas.arbeit\@t-systems.com |

## Gemessene Artefakte

| Datei | Seiten | Bytes | Wörter | SHA-256 (gekürzt) |
| :--- | :--- | :--- | :--- | :--- |
| `lebenslauf.pdf` | 2 | 37566 | 524 | `7cdd0ea5455e0320` |
| `anschreiben.pdf` | 1 | 24903 | 320 | `c909a39787a5a084` |
| `lebenslauf.typ` | — | 5774 | — | `06a92a81bd110652` |
| `anschreiben.typ` | — | 3120 | — | `ad1a36017d98d70c` |

Vollständige Hashes: `sha256sum submissions/telekom-sre-prometheus/*.pdf`.

Beim Umbau entfernt: `selection.json` (Modus 444, read-only Derivation). Einen Store-Symlink gab es nicht mehr.

## Fit-Map

| Anforderung der Anzeige | Nachweis im Paket | Bewertung |
| :--- | :--- | :--- |
| Monitoring-Stack mit Prometheus | nicht betrieben, kein PromQL, keine Federation, kein Remote Write | **Kernlücke** |
| Grafana-Dashboards, Provisioning as Code | nicht vorhanden | **Kernlücke** |
| Loki, LogQL, Compaction | nicht vorhanden | **Kernlücke** |
| AlertManager: Routing, Inhibition, Eskalation | nicht vorhanden; eigene Go-Brücke mit Zustellbestätigung | **Kernlücke**, Denkweise vorhanden |
| Alerting für autonome Betriebsmodelle, Disconnected/Air-Gap | Bestand ohne öffentliche Schnittstelle, Prüfungen von außen, Vorlaufgrößen | Stark im Prinzip |
| Lokale Retention, Logrotation, Datenmanagement unter Knappheit | Vorlaufgrößen mit Zeitstempel, begrenzte Hardware, Rotation im Konzept | Teilweise |
| Performance-Optimierung unter begrenzten Ressourcen | PSI, Speicherdruck, Generation-Alter als Messgrößen erster Ordnung | Stark |
| Kubernetes-Monitoring | nicht vorhanden | **Lücke** |
| Infrastructure as Code, YAML | Nix-Flakes als IaC; YAML im großen Stil nicht | **Teilweise** |
| Linux-Performance: cgroups, PSI | täglich genutzt, inklusive Namespaces und Boot | Stark |
| Hochverfügbarkeit für kritische Infrastruktur | Rollback über Generationen, geprüfte Restores, Alarmzustellung bestätigt | Stark, klein skaliert |
| KRITIS mit Nachweispflichten | kein regulierter Betrieb verantwortet | **Lücke** |
| Deutsch C1 | C1, Englisch Muttersprache | Erfüllt |
| Präsenz Karlsruhe, hybrid | rund eineinhalb Stunden entfernt | Erfüllt |

## Fit-Begründung: 3

Die Anzeige führt Prometheus, Grafana, Loki und AlertManager als Must-Haves und die Rolle trägt „Prometheus" im Titel. Nichts davon ist betrieben worden. Was vorhanden ist, ist die Denkweise dahinter und die Betriebserfahrung darunter: Telemetrie als Schleife, Alarmierung als Zustellproblem, knappe Ressourcen als Anforderung, Linux als Messinstrument.

Eine 4 wäre zu behaupten, der Werkzeugkasten sei vorhanden. Eine 2 wäre zu behaupten, die Denkweise sei wertlos — und der Betrieb auf eigener Hardware ohne Reserve ist genau die Umgebung, für die Fog- und Edge-Knoten gebaut werden.

## Offene Punkte

1. **Prometheus, Grafana, Loki, AlertManager** als Kernlücke im Anschreiben benannt, ohne Weichzeichner.
2. **KRITIS** nicht vorhanden.
3. **Zeugnisse** fehlen weiterhin.
4. Mehrere Standorte zur Wahl; Karlsruhe ist der nächste und im Anschreiben genannt.

## Paket

| Datei | Inhalt |
| :--- | :--- |
| `job-description.txt` | Vollständige Anzeige. |
| `lead.md` | Fit, Lücken, Weg, Gehalt. |
| `lebenslauf.typ` | Typst-Quelle, zwei Seiten. |
| `anschreiben.typ` | Typst-Quelle, eine Seite. |
| `lebenslauf.pdf` | 2 Seiten, 524 Wörter. |
| `anschreiben.pdf` | 1 Seite, 320 Wörter. |
| `submission-sheet.md` | Diese Übersicht mit Messwerten. |
