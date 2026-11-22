# Bewerbung EnBW — Platform / DevOps Engineer Linux & Kubernetes (w/m/d)

Stand: 22. November 2026
Fit: 4 von 5
Referenz: C-TIPCP
Sprache: Deutsch
Status: Paket neu gebaut, **Stelle laut Karriereseite besetzt (HTTP 410)**

## Stelle

| Feld | Wert |
| :--- | :--- |
| Arbeitgeber | EnBW Energie Baden-Württemberg AG |
| Rolle | Platform / DevOps Engineer Linux & Kubernetes (w/m/d) |
| Standort | Karlsruhe; hybrid und onsite |
| Vertrag | unbefristet, Vollzeit, Teilzeit und Homeoffice möglich, 30 Tage Urlaub |
| Frist | keine genannt |
| Weg | careers.enbw.com, Referenz C-TIPCP |

## Aufgabe

Automatisierungen und Plattform-APIs für Linux- und Kubernetes-Umgebungen, Betrieb der Systeme, Monitoring für zuverlässige Plattformservices, Self-Service-Prozesse und produktionsnahe Automatisierungen. Genannte Technologien: Linux, Kubernetes, Git, Go, Python. Der Aufgabenkern stammt aus dem Stellenindex, weil die Originalseite HTTP 410 liefert.

## Dokumente

| Dokument | Datei | Hinweis |
| :--- | :--- | :--- |
| Anschreiben | `anschreiben.pdf` | Eine Seite, deutsch, Lücken im dritten Absatz |
| Lebenslauf | `lebenslauf.pdf` | Zwei Seiten, deutsch |
| Quellen | `lebenslauf.typ`, `anschreiben.typ` | Typst, eigenständig kompilierbar |
| Zeugnisse | keine Datei | Muss ergänzt werden |

## Abgleich

| Anforderung | Nachweis | Einschätzung |
| :--- | :--- | :--- |
| Linux-Plattformbetrieb | Dreizehn Hosts, drei Hardware-Generationen, systemd, cgroups, Netzwerk | Stark |
| Automatisierung und Plattform-APIs | Go und Python, Rollout-Werkzeuge, Alarm-Bridge, Auswertungen | Stark |
| Monitoring für zuverlässige Services | Sentinel-Ledger alle 15 Minuten, Gatus, Zustellbestätigung, PSI- und Disk-Druck | Stark |
| Deklarative Infrastruktur | NixOS-Module, gepinnte Inputs, Gate vor dem Rollout, Rückrollung über Generationen | Stark |
| KRITIS-Zuverlässigkeit | Keine regulierte Umgebung betrieben; Audit-Spur, Rückrollung und geprüfte Wiederherstellungen als Praxis | **Teilweise** |
| Kubernetes | Keine Produktivpraxis | **Lücke**, steht im Titel |
| Helm, GitOps | Nicht eingesetzt | **Lücke** |
| Git | Git als einzige Quelle aller Änderungen | Stark |
| Energiedomäne | M.Sc. REM 1,8, Fraunhofer ISE, 10 MW PV bei O3 Energy | Stark |
| Region Baden-Württemberg | Wohnsitz Gutach im Breisgau, Karlsruhe rund 1,5 h | Erfüllt |
| Arbeitserlaubnis | US-Staatsangehörigkeit mit Niederlassungserlaubnis | Erfüllt |

## Fit-Begründung: 4 von 5

Vier, weil die Substanz stimmt: Linux-Plattform, deklarativer Betrieb, Automatisierung in Go und Python, Telemetrie und die Energiedomäne aus Studium, Forschung und Asset-Steuerung. Dazu ein Standort im eigenen Bundesland.

Nicht fünf, weil Kubernetes im Titel steht und nicht in der Erfahrung, und weil KRITIS-Betrieb eine eigene Praxis ist, die hier nicht vorliegt. Vier heißt: Gespräch plausibel, Einarbeitung in Kubernetes und Regulatorik real.

## Offene Punkte

1. **Stelle besetzt.** careers.enbw.com antwortet mit HTTP 410, „the job you are trying to apply for has been filled". Das Paket ist fertig, aber nicht absendbar; auf eine neue Ausschreibung derselben Rolle oder eine verwandte EnBW-Plattformstelle warten.
2. **Kubernetes und KRITIS** stehen im Anschreiben als Lücken, nicht als Behauptungen.
3. Fit 4 statt der früheren Vorgabe 5.
4. Zeugnisse fehlen.
5. Präsenzanteil in Karlsruhe klären; hybrid ist genannt, der Umfang nicht.
6. Keine Gehaltszahl im Anschreiben.

## Paket

| Datei | Inhalt |
| :--- | :--- |
| `job-description.txt` | Aufgabenkern mit Quellenhinweis auf den HTTP-410-Stand. |
| `lead.md` | Fit, Lücken, Weg, Gehalt. |
| `lebenslauf.typ` | Typst-Quelle, zwei Seiten. |
| `anschreiben.typ` | Typst-Quelle, eine Seite. |
| `lebenslauf.pdf` | Zwei Seiten. |
| `anschreiben.pdf` | Eine Seite. |
| `submission-sheet.md` | Diese Übersicht. |
