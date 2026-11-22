# Bewerbung STACKIT / Schwarz Digits — (Senior) Platform Engineer, Control Plane Platform

Stand: 22. November 2026
Fit: 3
Sprache: Deutsch (C1), Englisch Muttersprache

## Stelle

| Feld | Wert |
| :--- | :--- |
| Arbeitgeber | Schwarz Digits KG — STACKIT, Abteilung IT - Cloud Services |
| Rolle | (Senior) Platform Engineer - STACKIT Control Plane Platform (m/w/d) |
| Standort | Bad Friedrichshall |
| Referenz | 1923 (Portal-Ref. SDE-131335 / 1923-15454); Vorgabe nennt GT2321 |
| Quelle | jobsuche-bw.de, HTTP 200 am 22.11.2026 |
| Gehalt | keine Angabe in der Anzeige, keine Zahl im Anschreiben |

**Zuordnungslücke:** GT2321 führt im Bestand die Schwesterstelle "(Senior) Site Reliability Engineer - STACKIT Control Plane". Der hinterlegte Text gehört zur Platform-Engineer-Anzeige (Ref. 1923). Vor dem Absenden klären, welche Requisition besetzt wird.

## Dokumente

| Dokument | Datei | Hinweis |
| :--- | :--- | :--- |
| Anschreiben | `anschreiben.pdf` | Eine Seite, deutsch, mit der Kubernetes-Lücke im ersten Absatz |
| Lebenslauf | `lebenslauf.pdf` | Zwei Seiten, deutsch |
| Quellen | `lebenslauf.typ`, `anschreiben.typ` | Typst, eigenständig kompilierbar |
| Zeugnisse | keine Datei | Muss ergänzt werden |

## Abgleich

| Anforderung | Nachweis | Einschätzung |
| :--- | :--- | :--- |
| Mehrjährige DevOps-, SRE- oder Platform-Erfahrung | Zehn Jahre Betrieb, fünf Jahre deklarierter Flottenbetrieb | Erfüllt |
| Fundierte Kubernetes-Architektur | Nicht vorhanden | **Kernlücke** |
| Fortgeschrittene Programmiererfahrung, vorzugsweise Go | Go-Bridge, Go-Router, Auswertungen | Stark |
| Kubernetes Operator Pattern | Nicht vorhanden | **Lücke** |
| SDN: Istio, Calico | nftables, DNS, WireGuard — keine CNI | **Lücke** |
| CI/CD: Git, Concourse, Flux | Git als einzige Quelle mit eigenen Gates; Concourse und Flux fehlen | Teilweise |
| Templating: Helm, Kustomize | Nicht vorhanden | **Lücke** |
| IaC: Terraform, Pulumi | Deklarativ in Nix; Terraform und Pulumi fehlen | Teilweise |
| Monitoring-Systeme implementieren und warten | Sentinel-Ledger, Gatus, Zustellbestätigung | Stark, mit eigener Toolchain |
| Interne Tools zur Automatisierung | Alarm-Bridge, PXE-Auslieferung, Task-Einstiegspunkte | Stark |
| Security Best Practices | sops, age, eigene CA, kurzlebige Zertifikate, keine offenen Sockets | Stark |
| Englisch, idealerweise Deutsch | Englisch Muttersprache, Deutsch C1 | Erfüllt |

## Fit-Begründung: 3 von 5

Drei, weil Werkzeugbau, Go, Linux-Interna, Monitoring und Betriebsdisziplin echt vorhanden sind und die Anzeige genau diese Arbeit beschreibt.

Nicht höher, weil Kubernetes-Architektur als fundierte Kenntnis gefordert ist und vollständig fehlt — samt Operator-Pattern, CNI, Helm und Terraform.

Nicht 2, weil ein Teil der Stelle aus Werkzeugen besteht, die hier selbst gebaut wurden.

## Offene Punkte

1. **Kubernetes-Lücke** steht im ersten Absatz des Anschreibens.
2. **Requisition klären:** GT2321 (SRE Control Plane) oder 1923 (Platform Engineer Control Plane Platform).
3. Zeugnisse fehlen.
4. Präsenz: Bad Friedrichshall rund 2 h von Gutach im Breisgau; Präsenzblöcke, Umzug optional.
5. Keine Gehaltsangabe, weil die Anzeige keine nennt.

## Paket

| Datei | Inhalt |
| :--- | :--- |
| `job-description.txt` | Anzeigentext vom 22.11.2026 mit Zuordnungs- und Abgleichsnotiz. |
| `lead.md` | Fit, Lücken, Weg, Quellenlage. |
| `lebenslauf.typ` | Typst-Quelle, eigenständig kompilierbar. |
| `anschreiben.typ` | Typst-Quelle, eigenständig kompilierbar. |
| `lebenslauf.pdf` | Zwei Seiten. |
| `anschreiben.pdf` | Eine Seite. |
| `submission-sheet.md` | Diese Übersicht. |
