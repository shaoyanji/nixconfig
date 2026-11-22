# Dossier — STACKIT / Schwarz Digits, (Senior) Platform Engineer Control Plane Platform

Stand: 22. November 2026
Fit: 3 von 5
Bewerber: Matt Ji, Gutach im Breisgau
Arbeitgeber: Schwarz Digits KG — STACKIT, Abteilung IT - Cloud Services
Standort: Bad Friedrichshall
Referenz: 1923 (Portal SDE-131335 / 1923-15454); die Vorgabe nennt GT2321

## 1. Die Stelle in einem Absatz

STACKIT baut eine Plattform, auf der andere ihre Produkte betreiben. Die Rolle entwickelt interne Werkzeuge, die die Bereitstellung dieser Infrastruktur automatisieren, verantwortet Monitoring für Verfügbarkeit und Performance, unterstützt Entwicklungsteams beim Betrieb ihrer Dienste und trägt zu Sicherheits- und Compliance-Vorgaben bei. Vorausgesetzt werden fundierte Kubernetes-Architektur, fortgeschrittene Programmierung vorzugsweise in Go, Erfahrung mit Operator-Pattern, Software-Defined Networking, CI/CD, Templating und Infrastructure as Code.

## 2. Zuordnung: geklärt am 22.11.2026

Die Vorgabe nannte GT2321, der Anzeigentext im Paket gehört aber zur Platform-Engineer-Anzeige. Beide Requisitionen sind jetzt belegt: GT1923 ist die Anzeige "(Senior) Platform Engineer - STACKIT Control Plane Platform", Referenz 1923, Standort Am Campus 1, 74177 Bad Friedrichshall, Abteilung IT - Cloud Services — Titel und Aufgabe decken sich mit der Vorgabe. GT2321 ist die Schwesterstelle "(Senior) Site Reliability Engineer - STACKIT Control Plane", Referenz 2321, und verlangt zusätzlich Expertenwissen über die Interna der Control Plane: API Server, Controller Manager, Scheduler und etcd. Das Paket bewirbt sich damit auf 1923; der GT2321-Vermerk der Vorgabe war eine Fehlzuordnung. Wäre 2321 gemeint, läge der Fit bei 2 statt 3, weil die Control-Plane-Interna nicht vorhanden sind.

## 3. Aufgaben laut Anzeige

| Aufgabe | Im Paket belegt durch |
| :--- | :--- |
| Interne Werkzeuge zur Automatisierung der Bereitstellung | Alarm-Bridge, PXE-Auslieferung, Task-Einstiegspunkte in Go und Python — Handarbeit ersetzt, nicht dokumentiert |
| Monitoring implementieren und warten | Eigenes Ledger alle 15 Minuten, Gatus-Prüfungen, Zustellbestätigung des Alarmwegs |
| Entwicklungsteams beim Betrieb ihrer Services unterstützen | Fünf Jahre lang ohne zweiten Menschen: Runbooks, Tasks, Anleitungen für Nutzende |
| Kubernetes-Technologien verfolgen | Nicht vorhanden — offen im Anschreiben benannt |
| Security Best Practices und Compliance | sops und age je Host, eigene CA mit kurzlebigen Zertifikaten, nftables als Code, keine offenen Listener |

## 4. Anforderungen und Belege

| Anforderung | Art | Beleg im Paket | Urteil |
| :--- | :--- | :--- | :--- |
| Mehrjährige DevOps-, SRE- oder Platform-Erfahrung | Muss | fünf Jahre Flottenbetrieb allein, davor IT-Verantwortung | erfüllt |
| Fortgeschrittene Programmierung, vorzugsweise Go | Muss | Alarm-Bridge, Router, Auswertungen in Go | stark |
| Monitoring für Verfügbarkeit und Performance | Muss | Ledger, Prüfungen, Alarmzustellung mit Bestätigung | stark |
| Interne Werkzeuge zur Automatisierung | Muss | Werkzeuge ersetzen Handarbeit, Git als einzige Quelle | stark |
| Security Best Practices | Muss | sops/age, eigene CA, Segmentierung, keine offenen Sockets | stark |
| Problemlösung und Fehlerbehebung | Muss | Diagnose aus Messreihen statt Vermutung; Rückrollung in Minuten | stark |
| Englisch, idealerweise Deutsch | Muss | Englisch Muttersprache, Deutsch C1 | erfüllt |
| Fundierte Kubernetes-Architektur | Muss | keiner | **Kernlücke** |
| Operator-Pattern, CRDs, Controller | Muss | keiner | **fehlt** |
| Software-Defined Networking: Istio, Calico | Muss | nftables, DNS, WireGuard — keine CNI | **fehlt** |
| Templating: Helm, Kustomize | Muss | keiner; deklarativ in Nix | **fehlt** |
| Infrastructure as Code: Terraform, Pulumi | Muss | deklarativ in Nix, kein HCL | teilweise |
| CI/CD: Git, Concourse, Flux | Muss | Git mit eigenen Gates; Concourse und Flux nicht | teilweise |

## 5. Was das Dossier trägt

Die Plattformarbeit ist nicht behauptet, sondern gebaut: dreizehn Hosts über drei Hardware-Generationen, deklarativ beschrieben, jede Änderung durch ein Gate geprüft, jeder Stand als Generation rückrollbar. Monitoring ist eigene Messung statt Lizenz — ein Ledger mit Jobstatus, Generation-Alter, Plattenplatz und Druck alle fünfzehn Minuten, Prüfungen von außen, ein Alarmweg, der erst nach bestätigter Zustellung als gemeldet gilt. Werkzeuge dafür sind in Go und Python geschrieben, nicht eingekauft.

Dazu die Sicherheitsseite, die in der Anzeige als eigener Punkt steht: Secrets je Host mit sops und age, eine eigene Zertifizierungsstelle mit kurzlebigen Zertifikaten, Firewall als Code, kein öffentlich erreichbarer Verwaltungsdienst. Und die Arbeitsweise, die eine Plattform braucht: eine Quelle, Gates, Runbooks, Rückrollung.

## 6. Was das Dossier nicht trägt

Kubernetes. Die Anzeige fordert fundierte Architekturkenntnis, dazu Operator-Pattern, Istio oder Calico, Helm oder Kustomize, Terraform oder Pulumi und CI/CD-Werkzeuge wie Concourse oder Flux. Nichts davon ist vorhanden; das Anschreiben sagt es im dritten Absatz und nennt es Aufwand, nicht Formfehler. Dazu fehlt der Maßstab: dreizehn Hosts sind keine mandantenfähige Cloud mit Quotas.

## 7. Entscheidung: 3

Keine 4, weil die Control Plane ohne Kubernetes-Kenntnis am ersten Tag nicht zu tragen ist — die Anzeige nennt es als Muss, nicht als Wunsch. Keine 2, weil ein großer Teil der Stelle aus genau der Arbeit besteht, die hier fünf Jahre lang allein gemacht wurde: Werkzeuge bauen, Monitoring selbst messen, deklarativ ausliefern, Sicherheit in die Lieferkette legen.

## 8. Logistik

- Bad Friedrichshall liegt rund zwei Stunden von Gutach im Breisgau; Präsenzblöcke sind machbar, ein Umzug in den Raum Heilbronn ist Gesprächsstoff, keine Zusage.
- Keine Gehaltsangabe in der Anzeige, deshalb keine Zahl im Anschreiben.
- Niederlassungserlaubnis vorhanden, kein Sponsor nötig; Deutsch C1, Englisch Muttersprache.
- Zeugnisse fehlen; ohne sie geht das Paket nicht raus.

## 9. Fragen für ein Gespräch

1. Welche Requisition wird tatsächlich besetzt — GT2321 (SRE Control Plane) oder 1923 (Platform Engineer Control Plane Platform)?
2. Wie viel der Control Plane ist Operator-Entwicklung, wie viel Betrieb bestehender Komponenten?
3. Ist Kubernetes-Architektur eine Bedingung beim Eintritt oder Einarbeitung in den ersten Monaten?
4. Wie groß ist das Team, und gibt es Rufbereitschaft für die Plattform?
5. Welche Sprache dominiert im Team — die Anzeige nennt Englisch als Basis, Deutsch als ideal?

## 10. Dateien und Messwerte

| Datei | Inhalt | Seiten | Bytes | Wörter | SHA-256 (gekürzt) |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `lebenslauf.pdf` | Lebenslauf, deutsch | 2 | 36401 | 516 | `dd5c853cdf2b067e` |
| `anschreiben.pdf` | Anschreiben, deutsch | 1 | 24693 | 359 | `f3b7ecd846a103f0` |
| `lebenslauf.typ` | Typst-Quelle | — | — | — | — |
| `anschreiben.typ` | Typst-Quelle | — | — | — | — |
| `job-description.txt` | Anzeigentext mit Zuordnungshinweis | — | — | — | — |
| `submission-sheet.md` | Übersicht, Abgleich, offene Punkte | — | — | — | — |
| `lead.md` | Kurzfassung für die Pipeline | — | — | — | — |

Beide PDFs wurden am 22.11.2026 aus den Typst-Quellen neu gebaut und sind byte-identisch mit den eingecheckten Dateien; das Verzeichnis enthält keine Altlast-Symlinks.
