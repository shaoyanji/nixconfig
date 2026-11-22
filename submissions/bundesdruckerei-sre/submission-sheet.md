# Bundesdruckerei Gruppe GmbH — Site Reliability Engineer (m/w/d)

**BA `15933-0067012870-S`.** Standort Berlin (10969), Beginn ab sofort, Ausschreibung 30+ Tage
online. Status: Paket fertig, **nichts eingereicht**.

| Feld | Wert |
| :--- | :--- |
| Role ID | `bundesdruckerei-sre` |
| BA-Referenz | 15933-0067012870-S |
| Arbeitgeber | Bundesdruckerei Gruppe GmbH |
| Standort | Berlin, Präsenz; Rufbereitschaft und Schichtbetrieb |
| Sprache | Deutsch, C1 |
| Gehalt | keine Zahl im Anschreiben — die Ausschreibung nennt keine Bandbreite |
| Bewerbungsweg | BA-Inserat verweist auf den Arbeitgeber; Kontakt ist per Zeichenabfrage geschützt |

## Fit-Map

| Anforderung (Ausschreibung) | Nachweis | Urteil |
| :--- | :--- | :--- |
| SLOs aus Kunden-SLAs, Error Budgets, Fehlertoleranz | Messung, Schwellen aus PSI, Alarmzustellung, Rollback-Zeiger; formale SLO-/Error-Budget-Governance über Teams ist neu | teilweise |
| Mit Software- und DevOps-Engineers Designs und Architekturen entwickeln | Eine Deklaration für dreizehn Hosts, Modulgrenzen, Entscheidungen als Notizen im Repo | stark im kleinen Maßstab |
| Build, Test, Deployment standardisieren und automatisieren | Gate in CI und Host mit derselben Prüfung; Deployment als ein Schritt | stark |
| Datenschutz- und Qualitätsanforderungen | Secrets pro Host (SOPS/age), Minimalrechte, Default-Deny, Dokumentation | stark im Muster |
| CI-Umgebung aufbauen und betreiben | **Keine CI-Plattform aufgebaut**; Gates laufen in vorhandener CI | **Lücke** |
| Container-Registries administrieren und synchronisieren | **Keine Registry administriert**; Container nur als gepinnte Bauumgebung | **Lücke** |
| Virtuelle Netzwerkinfrastruktur aufbauen und betreiben | WireGuard-Mesh, nftables Default-Deny, DNS/MTU-Diagnose mit tcpdump, eigene CA | stark |
| Störungen analysieren, sauber dokumentieren | journald, cgroups, tcpdump; Ursache/Wirkung/Behebung dokumentiert | stark |
| Cloud (AWS, Azure) | Oracle-Cloud-Hosts, kleines AWS-Lambda-Projekt; keine Multi-Account-Architektur | teilweise |
| Monitoring, Debugging, Performance-Messung | Sentinel-Ledger, PSI als Lastsignal, Disk-Druck, Generation Age | stark |
| Container und Orchestrierung | **Kubernetes/Orchestrierung nicht produktiv**; MicroVMs als deklarierte Gäste | **Lücke** |
| Regex, Scripting, dynamische Sprachen (bash, Python, Ruby, Go) | Go, Python, Bash im Tagesgeschäft; Parser und Regex in Werkzeugen | stark |
| Verteilte Versionskontrolle (git, hg) | Git als einzige Quelle für Konfiguration, Code und Entscheidungen | stark |
| SRE-Methodik und -Kultur | SRE-Praktiken selbst aufgebaut: Gate, Rollback, Ledger, Dokumentation | stark im Ansatz |
| Rufbereitschaft und Schichtbetrieb | ausdrücklich zugesagt | erfüllt |
| Sicherheitsüberprüfung | Bereitschaft zugesagt (nicht in der Ausschreibung gefordert, aber üblich) | erfüllt |

## Was das Anschreiben sagt

Es beginnt mit der Kette Zusage → SLO → Error Budget → Deployment-Entscheidung und ordnet die eigene
Arbeit darin ein. Der zweite Absatz beschreibt Deklaration, Gate, Release und Rollback als Garantie
sowie das Ledger als Telemetrie. Der dritte nennt die virtuellen Netze, die CA, Secrets und Git als
Quelle. Der vierte ist die Lückenliste: keine Container-Orchestrierung, keine Registry, keine
CI-Plattform, Cloud nur als Nebenrolle, formale SLO-Governance neu — dazu die ausdrückliche Zusage
für Rufbereitschaft, Schicht und Sicherheitsüberprüfung. Der fünfte definiert souveräne Infrastruktur
als Nachvollziehbarkeit und klärt Berlin, Umzug und Sprachstand.

## Gehalt

Die Ausschreibung nennt keine Bandbreite, deshalb steht keine Zahl im Anschreiben. Die Frage nach dem
Band gehört ins Erstgespräch; die Referenz sind Berliner SRE-Gehälter für Tarif- und
Tarif-ähnliche Arbeitgeber, nicht die eigene Wunschzahl.

## Prüfungen

| Prüfung | Ergebnis |
| :--- | :--- |
| `pdfinfo lebenslauf.pdf` | **2 Seiten** (Budget 2) |
| `pdfinfo anschreiben.pdf` | **1 Seite** (Budget 1) |
| `task checks:prose` | 215 prose files, exit 0 |
| selection | 9/26 highlights, 4/8 projects |
| sha256 Lebenslauf | `947358b79706aaacbb33565e55f74e24206023fc816f0b3be7619c63f54fd857` |
| sha256 Anschreiben | `22438291fedb8c334c9897988574d0c8633dea1d02de86f3a1839d6a7cf41cfa` |

## Nächste Schritte

1. Bewerbungsweg klären: das BA-Inserat verlinkt auf den Arbeitgeber, die Kontaktdaten sind hinter
   der Zeichenabfrage — über die Bundesdruckerei-Karriereseite gehen.
2. Berlin entscheiden: 700 km, Präsenz plus Schicht und Rufbereitschaft heißt Umzug, nicht Pendeln.
3. Für das Erstgespräch die SLO-Frage vorbereiten: Messung und Alarmzustellung sind belegbar, ein
   Error-Budget-Prozess über Teams ist der Lernanteil.
