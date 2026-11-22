# Bewerbung STACKIT / Schwarz Digits — (Senior) Platform Engineer, Control Plane Platform

Stand: 22. November 2026
Fit: 3 von 5
Sprache: Deutsch (C1), Englisch Muttersprache
Status: Paket neu gebaut; Requisition vor dem Absenden klären

## Stelle

| Feld | Wert |
| :--- | :--- |
| Arbeitgeber | Schwarz Digits KG — STACKIT, IT - Cloud Services |
| Rolle | (Senior) Platform Engineer - STACKIT Control Plane Platform (m/w/d) |
| Standort | Bad Friedrichshall; Gutach im Breisgau rund 2 h entfernt |
| Referenz | 1923 (Portal SDE-131335); die Vorgabe nennt GT2321 |
| Quelle | jobsuche-bw.de, HTTP 200 am 22.11.2026 |
| Gehalt | keine Angabe in der Anzeige, keine Zahl im Anschreiben |

**Zuordnungslücke:** GT2321 führt im Bestand die Schwesterstelle „(Senior) Site Reliability Engineer - STACKIT Control Plane". Der hinterlegte Anzeigentext gehört zur Platform-Engineer-Anzeige mit Referenz 1923. Vor dem Absenden muss klar sein, welche der beiden Requisitionen besetzt wird.

## Dokumente

| Dokument | Datei | Hinweis |
| :--- | :--- | :--- |
| Anschreiben | `anschreiben.pdf` | Eine Seite, deutsch, Kubernetes-Lücke im dritten Absatz |
| Lebenslauf | `lebenslauf.pdf` | Zwei Seiten, deutsch |
| Quellen | `lebenslauf.typ`, `anschreiben.typ` | Typst, eigenständig kompilierbar |
| Zeugnisse | keine Datei | Muss ergänzt werden |

Ein Altlast-Symlink `packet → /nix/store/...` war nicht vorhanden; das Verzeichnis enthält nur native Quellen und PDFs.

## Abgleich

| Anforderung | Nachweis | Einschätzung |
| :--- | :--- | :--- |
| Mehrjährige DevOps-, SRE- oder Platform-Erfahrung | Fünf Jahre deklarierter Flottenbetrieb, davor IT-Administration | Erfüllt |
| Fundierte Kubernetes-Architektur | Nicht vorhanden | **Kernlücke** |
| Fortgeschrittene Programmierung, vorzugsweise Go | Alarm-Bridge, Router, Auswertungen in Go | Stark |
| Operator-Pattern | Nicht vorhanden | **Lücke** |
| SDN: Istio, Calico | nftables, DNS, WireGuard — keine CNI | **Lücke** |
| CI/CD: Git, Concourse, Flux | Git als einzige Quelle mit eigenen Gates; Concourse und Flux fehlen | Teilweise |
| Templating: Helm, Kustomize | Nicht vorhanden | **Lücke** |
| IaC: Terraform, Pulumi | Deklarativ in Nix; Terraform und Pulumi fehlen | Teilweise |
| Monitoring implementieren und warten | Ledger alle 15 Minuten, Gatus, Zustellbestätigung | Stark, eigene Toolchain |
| Interne Werkzeuge zur Automatisierung | Alarm-Bridge, PXE-Auslieferung, Task-Einstiegspunkte | Stark |
| Security Best Practices | sops/age, eigene CA, kurzlebige Zertifikate, keine offenen Sockets | Stark |
| Souveräne europäische Cloud | Eigene Hardware, keine US-Dienste, keine öffentlichen Listener | Stark (Haltung) |
| Englisch, idealerweise Deutsch | Englisch Muttersprache, Deutsch C1 | Erfüllt |

## Fit-Begründung: 3 von 5

Drei, wie im Bestand. Werkzeugbau, Go, Linux-Interna, Monitoring und Betriebsdisziplin sind vorhanden, und die Anzeige beschreibt genau diese Arbeit.

Nicht höher, weil Kubernetes-Architektur als fundierte Kenntnis gefordert ist und vollständig fehlt — samt Operator-Pattern, CNI, Helm und Terraform. Die Vorgabe nannte 4; eine Vier würde behaupten, die Control Plane ohne Einarbeitung tragen zu können.

Nicht 2, weil ein Teil der Stelle aus Werkzeugen besteht, die hier selbst gebaut wurden.

## Offene Punkte

1. **Kubernetes-Lücke** steht im Anschreiben, nicht nur im Datenblatt.
2. **Requisition klären:** GT2321 (SRE Control Plane) oder 1923 (Platform Engineer Control Plane Platform).
3. Fit 3 statt der Vorgabe 4, mit Begründung oben.
4. Zeugnisse fehlen.
5. Präsenz in Bad Friedrichshall: rund 2 h, Präsenzblöcke machbar, Umzug optional.
6. Keine Gehaltsangabe, weil die Anzeige keine nennt.

## Paket

| Datei | Inhalt |
| :--- | :--- |
| `job-description.txt` | Anzeigentext mit Zuordnungs- und Abgleichsnotiz. |
| `lead.md` | Fit, Lücken, Weg, Quellenlage. |
| `lebenslauf.typ` | Typst-Quelle, zwei Seiten. |
| `anschreiben.typ` | Typst-Quelle, eine Seite. |
| `lebenslauf.pdf` | Zwei Seiten. |
| `anschreiben.pdf` | Eine Seite. |
| `submission-sheet.md` | Diese Übersicht. |
