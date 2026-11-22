# VertiGIS GmbH — Cloud Engineer (m/w/x), Cloud-Betrieb von SaaS-Lösungen

Arbeitnow-Inserat `315547`, gefunden im Scouting-Lauf 2026-11-22. Paket am selben Tag gebaut,
**nichts eingereicht**. Eigenständige Typst-Quellen neben den PDFs.

| Feld | Wert |
| :--- | :--- |
| Role ID | `vertigis-cloud-engineer` |
| Arbeitgeber | VertiGIS GmbH (GIS-Lösungen für Energie, Wasser, Behörden, Telekommunikation) |
| Team | sechs Cloud Engineers und GIS-Consultants, CloudOps |
| Ort | **Homeoffice / hybrid**, Standorte in Deutschland und Österreich |
| Sprache | Deutsch C1, Englisch B2 |
| Gehalt | **keine Bandbreite veröffentlicht**; im Gespräch erfragen |
| Fit | 3 |

## Wie die Stelle gefunden wurde

3.545 Anzeigen über die Arbeitnow-API (Seiten 1–14; ab Seite 15 antwortet die API nicht mehr, das ist die
Obergrenze des Boards). Gefiltert nach Titel und Ort, dann nach Beschreibungssignalen (Linux, Kubernetes,
Automatisierung, IaC, Monitoring), anschließend gegen `submissions/` und die Delphi-Datenbank abgeglichen.

Ausgeschlossen, weil bereits vorhanden: **Makersite**, **Biz Factory**, **KD Pharma**, **shopware**,
**truetalent**. Ausgeschlossen nach Lesen der Anzeige: **Actian** (Director-Rolle mit Teamaufbau, keine
Führungserfahrung), **Intetics** (IT-Service-Management, UN-Erfahrung verlangt), **Oxoia** (Baden in der
Schweiz, nicht Baden-Württemberg), **Yubo** (Paris), **ElevenLabs** (Full-Stack, keine Infrastruktur).

Ergebnis des Laufs, ehrlich: **keine frische Anzeige verbindet tiefes Linux mit Produktions-Kubernetes und
Remote-Deutschland**. Die, die es tun, sind bereits bearbeitet (shopware) oder als Lead erfasst
(truetalent, Freiburg). VertiGIS ist die beste verbleibende echte Öffnung: Betrieb, IaC, CI/CD und
Monitoring in einer Rolle, remote in Deutschland, mit einem Kundensektor, der zum Energiehintergrund passt.

## Fit-Map

| Anforderung (Inserat) | Nachweis | Urteil |
| :--- | :--- | :--- |
| Betrieb und Weiterentwicklung von Cloud-Infrastruktur / SaaS auf Azure | Oracle-Hosts, keine Azure-Umgebung | **Lücke** |
| Infrastructure as Code, vorzugsweise Bicep | NixOS-Module und Flake: deklarativ, geprüft, versioniert — Werkzeug fehlt | Konzept ja, Werkzeug nein |
| Netzwerk- und IT-Sicherheit, Absicherung von Cloud-Umgebungen | WireGuard, nftables Default-Deny, eigene DNS-Zone, TLS/CA, kurzl. Zertifikate | stark |
| CI/CD-Pipelines inkl. Funktionsprüfung nach Deployment | Gate in CI und Host, Rollback per Generation | stark im Muster |
| Monitoring und Log-Analyse im laufenden Betrieb | Ledger alle 15 Minuten, journald, PSI, Alerting, tcpdump | stark |
| Störungsbehebung im Kundenbetrieb | Incident-Analyse über Host-, Unit- und Zeitgrenzen | stark |
| Dokumentation und Wartungsfenster | Runbooks, Änderungen als Generation mit Rückweg | stark |
| Systemhärtung nach CIS-Benchmark | Default-Deny, Minimalrechte, SOPS/age; CIS selbst nicht zertifiziert | teilweise |
| Sehr gutes Deutsch (C1), Englisch (B2) | Anschreiben und Unterlagen auf Deutsch | stark |
| ArcGIS / VertiGIS-Produkte | keine Kenntnis | Lücke, unwichtig |

## Bewertung

Der Betriebsteil ist die eigentliche Substanz der Stelle, und dort ist das Profil stark: Störungen
analysieren, Änderungen nachvollziehbar ausrollen, Monitoring als Aufzeichnung, Härtung als Voreinstellung.
Azure und Bicep sind der Preis dafür. Die Anzeige verlangt ausdrücklich **kein** Studium und keine
bestimmte Ausbildung, sondern praktische Erfahrung in genau diesen Betriebsfeldern — das ist der Grund,
warum eine Bewerbung trotz der Cloud-Lücke sinnvoll ist.

Fit **3**, nicht 4: Wer eine Azure-Landing-Zone betreiben soll, erwartet Azure-Erfahrung, und die fehlt.

## Remote und Standort

Homeoffice ist zugesagt, hybrid möglich, Standorte in Deutschland und Österreich. Aus Gutach im Breisgau
ist das ohne Umzug machbar; für Wartungsfenster und Abstimmung ist Präsenz eingeplant, nicht vorausgesetzt.
Kein Konflikt wie bei den Berliner Rollen im Bestand.

## Prüfungen

| Prüfung | Ergebnis |
| :--- | :--- |
| `typst compile lebenslauf.typ` | exit 0, keine Warnungen |
| `typst compile anschreiben.typ` | exit 0, keine Warnungen |
| `pdfinfo lebenslauf.pdf` | **2 Seiten** (Budget 2) |
| `pdfinfo anschreiben.pdf` | **1 Seite** (Budget 1) |
| `task checks:prose` | 228 prose files, exit 0 |
| sha256 Lebenslauf | `5c1e34eb85f10b0b6ed659101d03c7e17bbb7c6285a5b83702a42955bf94fe2d` |
| sha256 Anschreiben | `281741b311e1af0c5e0424a90cba289fb8036efccbac7dc48acf299c57ef7b59` |

## Nächste Schritte

1. Über den Arbeitnow-Link bewerben, Anschreiben und Lebenslauf anhängen.
2. Im Erstgespräch die Azure-Lücke ansprechen und den Betriebsteil als sofort verfügbaren Beitrag anbieten.
3. Bandbreite erfragen; die Anzeige nennt keine Zahl.
