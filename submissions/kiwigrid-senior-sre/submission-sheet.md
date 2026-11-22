# Bewerbung — Kiwigrid, Senior Site Reliability Engineer

Stand: 22. November 2026
Fit: 3
Sprache: Deutsch
Status: migriert auf native Typst-Quellen, kompiliert und gemessen

## Stelle

| Feld | Wert |
| :--- | :--- |
| Arbeitgeber | Kiwigrid GmbH |
| Rolle | Senior Site Reliability Engineer (m/w/d) |
| Umfeld | Energie-IoT-Plattform, Smart Grid, erneuerbare Energien |
| Quelle | Anzeige liegt im Paket |
| Weg | https://kiwigrid.jobs.personio.de/job/36748 |

## Migration

| Vorher | Nachher |
| :--- | :--- |
| `packet` → `/nix/store/11axax6j3ipkwsc9xb0igmbgbpbh7lra-…` (Symlink) | entfernt |
| `selection.json` (444) und weitere JSON-Derivate | entfernt |
| `lebenslauf.pdf`, `anschreiben.pdf` (444) | durch native Quellen ersetzt, beschreibbar |

## Gemessene Artefakte

| Datei | Seiten | Bytes | Wörter | SHA-256 (gekürzt) |
| :--- | :--- | :--- | :--- | :--- |
| `lebenslauf.pdf` | 2 | 37924 | 531 | `a42fc63fbd6fbc6e` |
| `anschreiben.pdf` | 1 | 23374 | 308 | `da0ce2fc324da740` |

## Fit-Map

| Anforderung | Nachweis im Paket | Bewertung |
| :--- | :--- | :--- |
| Zuverlässigkeit einer Plattform, die andere nutzen | 13 Hosts, drei Hardware-Generationen, fünf Jahre, ein Betreiber | Stark, klein skaliert |
| Betrieb unter begrenzten Ressourcen | Edge-nahe Hardware ohne Reserve, Druck und Plattenplatz als Messgrößen | Stark |
| Telemetrie und Alarmierung | Ledger alle 15 Minuten, Gatus-Prüfungen, Go-Brücke mit Zustellbestätigung | **Stärkster Nachweis** |
| Incident Response | Störungsbearbeitung ohne Eskalationsstufe, Ursache dokumentiert | Stark |
| Reproduzierbare Auslieferung, Rückrollung | Gepinnte Eingaben, Gate vor dem Rollout, Rückkehr in Minuten | Stark |
| Domänenwissen Energie | 10 MW Solarleistung kaufmännisch betreut, Ertrags- und Betriebsdaten, M.Sc. Renewable Energy Management | **Stark** |
| Messumfeld und Datenhaltung | Fraunhofer ISE 2012, Messaufbau, nachvollziehbare Ablage | Stark |
| Kubernetes, Terraform, Ansible, Cloud | nicht vorhanden | **Lücke** |
| Prometheus, Grafana, Alertmanager | eigene Werkzeuge statt Standardstapel | **Lücke** |
| Regulierter KRITIS-Betrieb | nicht verantwortet | **Lücke** |
| Deutsch, Englisch | C1, Muttersprache | Erfüllt |

## Fit-Begründung: 3

Die Kombination ist selten: Plattformbetrieb unter Knappheit und energiewirtschaftliche Praxis in einer Person. Wer Einspeisedaten betreut hat, versteht, warum eine ausgefallene Messung eine Frist hat, und wer dreizehn Hosts allein betrieben hat, baut Telemetrie, die nicht nur aussieht wie Überwachung.

Keine 4, weil die Anzeige den Cloud- und Kubernetes-Stapel nennt und nichts davon vorhanden ist. Drei heißt: das Gespräch über Betrieb und Energie wird gut, das über den Werkzeugstapel ehrlich kurz.

## Offene Punkte

1. **Werkzeugstapel** als Lücke im Anschreiben benannt, mit der Bereitschaft, ihn zu übernehmen.
2. **KRITIS** nicht vorhanden.
3. **Zeugnisse** fehlen weiterhin.
4. Standort: Fernarbeit, Umzug nach Dresden oder Leipzig als Bereitschaft genannt — nur falls die Anzeige ihn verlangt.
