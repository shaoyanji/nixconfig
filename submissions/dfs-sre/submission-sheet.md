# DFS Deutsche Flugsicherung — Ingenieur Site Reliability (m/w/d)

BA-Referenz `17761-1172604-2-S`, DFS-Referenz **J000000038**, Am DFS Campus 1, 63225 Langen.
Native Typst-Quellen, `packet`-Symlink entfernt. Stand: Paket fertig, **nichts eingereicht**.

| Feld | Wert |
| :--- | :--- |
| Role ID | `dfs-sre` |
| Arbeitgeber | DFS Deutsche Flugsicherung GmbH, Langen (Hessen) |
| Rolle | Ingenieur Site Reliability (m/w/d) |
| DFS-Referenz | J000000038 |
| BA-Referenz | 17761-1172604-2-S |
| Ansprechpartnerin | Jessica Kuprat, karriere\@dfs.de |
| Sprache | Deutsch |
| Gehalt | keine Bandbreite im Inserat; keine Zahl im Brief |
| Fit | 3 (DB-Eintrag 5 wie beauftragt) |

## Fit-Map

| Anforderung | Nachweis | Urteil |
| :--- | :--- | :--- |
| Linux-Betrieb, sicherheitskritisch | Dreizehn deklarierte Hosts, Gates, Rollback | stark im Betrieb, Domäne fehlt |
| Telemetrie- und Monitoringschleife | Ledger alle 15 Minuten, PSI, cgroups, Alerting | stark |
| Hochverfügbarkeit / Wiederanlauf | Generation-Rollback, Rebuild, geübte Wiederherstellung | stark |
| Fehlersuche mit Beweisen | journald, cgroups, tcpdump, strace, Incident-Notizen | stark |
| Deklarative Reproduzierbarkeit | Gepinnte Inputs, identische Prüfung in CI und Host | stark |
| Flugsicherung / Echtzeitsysteme | **nicht vorhanden** | **Lücke** |
| Schichtbetrieb im Kontrollzentrum | **keine Praxis** | **Lücke** |
| Sicherheitsüberprüfung | Bereitschaft erklärt, Entscheidung bei der Stelle | offen |
| Tauglichkeitsuntersuchung | Bereitschaft erklärt | offen |
| Umzug nach Langen | eingeplant | erfüllt |

## Warum hier Fit 3 und nicht 5 steht

Der Auftrag führt die Stelle als "Priority lead, fit 5". Fachlich trägt das Paket den Betriebsteil stark:
Telemetrie als Schleife statt als Dashboard, Ursache vor Maßnahme, Wiederanlauf als Entwurfsteil. Zwei Dinge
tragen es nicht: **keine Erfahrung in einer sicherheitskritischen Echtzeitumgebung** und **keine
Schichtpraxis in einem Kontrollzentrum**. Bei der DFS entscheidet zusätzlich die Sicherheitsüberprüfung —
für einen nichtdeutschen Staatsangehörigen eine Entscheidung der zuständigen Stelle, keine Formsache. Fünf
wäre eine Bewertung, die im Fachgespräch zurückkommt; drei ist die Zahl, die der Brief verteidigen kann.

## Was der Brief zusagt

- **Sicherheitsüberprüfung und Tauglichkeitsuntersuchung**: Bereitschaft, ausdrücklich und mit dem Hinweis,
  dass beides Zeit kostet und eine Verweigerung das Verfahren beendet.
- **Schichtdienst und Präsenz in Langen**: selbstverständlich, Umzug eingeplant.
- **Kein Sponsoring**: US-Staatsbürger mit deutscher Niederlassungserlaubnis.
- **Die Grenze der Zusage**: ob eine Überprüfung für einen nichtdeutschen Staatsangehörigen erteilt wird,
  entscheidet die zuständige Stelle — das steht im Brief, nicht im Kleingedruckten.

## Vergütung

Keine Bandbreite im Inserat. Bei einer DFS-Ingenieurstelle mit Tarifbindung wäre eine Forderung ohne
Kenntnis der Gruppe geraten; die Zahl bleibt beim Gespräch.

## Prüfungen

| Prüfung | Ergebnis |
| :--- | :--- |
| `packet`-Symlink | entfernt |
| `chmod u+w *.pdf` vor dem Bau | ausgeführt |
| `typst compile lebenslauf.typ` | exit 0, keine Warnungen |
| `typst compile anschreiben.typ` | exit 0, keine Warnungen |
| `pdfinfo lebenslauf.pdf` | **2 Seiten** |
| `pdfinfo anschreiben.pdf` | **1 Seite** |
| Marker | `J000000038`, `Kuprat`, `Sicherheitsüberprüfung`, `Telemetrie`, `PSI` |
| `task checks:prose` | 241 prose files, exit 0 |
| sha256 Lebenslauf | `706cbee3806a0b2b13f673a4f4ceec052e09875a70766b31d8a05e07f5c4ca0f` |
| sha256 Anschreiben | `d70a85278d8983c4aae121ca575e8e9fe3d73061730e314bc4a4a09625459e86` |

## Nächste Schritte

1. Über die DFS-Karriereseite mit Referenz **J000000038** bewerben (oder per E-Mail an karriere\@dfs.de).
2. Sicherheitsüberprüfung früh ansprechen — nicht erst nach der Zusage.
3. Im Gespräch klären, wie viel der Rolle Schicht und wie viel Projektarbeit ist.
