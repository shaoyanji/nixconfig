# RWTH Aachen — IT-Beschäftigte\*r Data & DevOps (V000011705)

Lehrstuhl für Technologie- und Innovationsmanagement (TIM), Bewerbung per E-Mail an
`dienhart@time.rwth-aachen.de`. Native Typst-Quellen. **Bewerbungsschluss 22.11.2026 — heute.**

| Feld | Wert |
| :--- | :--- |
| Role ID | `rwth-aachen` |
| Arbeitgeber | RWTH Aachen, TIM (Prof. Dr. Frank T. Piller) |
| Rolle | IT-Beschäftigte\*r Data & DevOps |
| Kennung | **V000011705** |
| Ansprechpartnerin | Frau Dienhart |
| Bewerbungsweg | E-Mail an `dienhart@time.rwth-aachen.de` |
| Vergütung | **TV-L**, Eingruppierung nach Stelle; keine Euro-Zahl im Brief |
| Sprache | Deutsch |
| Frist | **22.11.2026** |
| Fit | 4 (DB-Eintrag 4) |

## Fit-Map

| Anforderung | Nachweis | Urteil |
| :--- | :--- | :--- |
| Python-Datenpipelines | Ingest, Normalisierung, Qualitätsprüfung; KEV-Zeitreihe als Datenprodukt | stark |
| PostgreSQL | Schema, Migrationen, append-only Events, Abfrageindex | stark |
| Linux / NixOS-Betrieb | Dreizehn deklarierte Hosts, systemd, journald, cgroups | stark |
| Reproduzierbare Datenumgebungen | Gepinnte Umgebung, Rebuild als Pfad, Auswertung als Code | stark |
| Wissenschaftliche Begleitung | Fraunhofer ISE: Messdaten, Auswertung, eigene Werkzeuge | stark |
| Datenqualität / Telemetrie | Ertragsmodelle, Sensorausfälle, Abweichungsanalyse | stark |
| HPC / Cluster-Administration | **nicht vorhanden** | **Lücke** |
| Deutsch C1 | Unterlagen und Brief in C1 | erfüllt |
| Verfügbarkeit | ab sofort; Umzug nach Aachen eingeplant | erfüllt |

## Was der Brief offenlegt

Die einzige Lücke, die im Brief steht, ist **HPC**: kein Rechencluster administriert, kein Scheduler
betrieben. Das ist bei einer Universitätsstelle der plausible Stolperstein, deshalb steht er im vierten
Absatz statt im Gespräch. Alles andere wird nicht behauptet, sondern an Projekten gezeigt — Postgres mit
append-only Ereignissen, Pipelines in Python, deklarierte Umgebungen.

Der Fraunhofer-Abschnitt ist bewusst als Forschungsarbeit formuliert, nicht als IT-Job: Messkampagnen,
Wiederholbarkeit, eigene Werkzeuge. Das ist die Erfahrung, die eine Lehrstuhlstelle tatsächlich braucht.

## Vergütung

**TV-L**, keine Bandbreite im Inserat, keine Euro-Zahl im Brief. Die Eingruppierung richtet sich nach der
Stelle und der Qualifikation; eine Forderung wäre hier gegenstandslos.

## Fristlage

Der Bewerbungsschluss ist **heute, 22.11.2026**. Das Paket ist gebaut und geprüft; was fehlt, ist der Versand
der E-Mail an Frau Dienhart mit beiden PDFs. Eine Bewerbung nach Fristende ist bei einer Universität selten
noch verwertbar.

## Prüfungen

| Prüfung | Ergebnis |
| :--- | :--- |
| `chmod u+w *.pdf` vor dem Bau | ausgeführt |
| `typst compile lebenslauf.typ` | exit 0, keine Warnungen |
| `typst compile anschreiben.typ` | exit 0, keine Warnungen |
| `pdfinfo lebenslauf.pdf` | **2 Seiten** |
| `pdfinfo anschreiben.pdf` | **1 Seite** |
| Marker | `V000011705`, `Dienhart`, `PostgreSQL`, `Fraunhofer`, `TV-L` |
| `task checks:prose` | 239 prose files, exit 0 |
| sha256 Lebenslauf | `f599b23abb0f02b7ea29e87cb60490ee365776e4c904ebb193976c1128e55167` |
| sha256 Anschreiben | `afc3d2d39ee6e1bc68c2a4972963bd5ea7a3f4a466b0909ac9c20af3278cb26c` |

## Nächste Schritte

1. **Heute** E-Mail an `dienhart@time.rwth-aachen.de` mit Kennung V000011705, Anschreiben und Lebenslauf.
2. Zeugnisse und Notenauszug beilegen, falls vorhanden — bei TV-L-Stellen üblich.
3. Im Gespräch klären, wie viel der Stelle HPC/Cluster ist und wie viel Datenarbeit.
