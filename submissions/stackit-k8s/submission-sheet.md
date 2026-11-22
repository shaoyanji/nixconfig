# Bewerbung STACKIT / Schwarz Digits — Senior Kubernetes Engineer

Stand: 22. November 2026
Fit: 2
Sprache: Deutsch (C1)

## Stelle und Quellenlage

| Feld | Wert |
| :--- | :--- |
| Arbeitgeber | STACKIT, IT- und Digitalsparte der Schwarz Gruppe (Schwarz Digits KG) |
| Rolle | Senior Kubernetes Engineer |
| Standort | Bad Friedrichshall / Neckarsulm, hybrid |
| Anzeige | Am 22.11.2026 nicht abrufbar: stackit.com rendert die Stellenseite per JavaScript, schwarz-digits.de/jobsearch liefert für "kubernetes" keine Treffer |
| Profilgrundlage | Wörtliche Anforderungen der parallel ausgeschriebenen STACKIT-Stellen: Control Plane SRE (Ref. 2321), Kubernetes Networking, DevOps/Cloud Engineer (Ref. 4627) |
| Gehalt | Keine Angabe in der Vorgabe, keine Zahl im Anschreiben |

## Dokumente

| Dokument | Datei | Hinweis |
| :--- | :--- | :--- |
| Anschreiben | `anschreiben.pdf` | Eine Seite, deutsch, beginnt mit der Kubernetes-Lücke |
| Lebenslauf | `lebenslauf.pdf` | Zwei Seiten, deutsch |
| Quellen | `lebenslauf.typ`, `anschreiben.typ` | Typst, eigenständig kompilierbar |
| Zeugnisse | keine Datei | Muss ergänzt werden |

## Abgleich

| Anforderung (aus den Schwesteranzeigen) | Nachweis | Einschätzung |
| :--- | :--- | :--- |
| Kubernetes-Betrieb, Cluster-Lebenszyklus | Nicht vorhanden | **Kernlücke** |
| Control Plane: API Server, Controller Manager, Scheduler, etcd | Nicht vorhanden | **Kernlücke** |
| CNI, Load Balancer, eBPF | Nicht vorhanden | **Lücke** |
| Go für Operatoren und Automatisierung | Go-Bridge mit Zustellbestätigung, Go-Router der KI-Plattform | Stark |
| Linux-Interna: Kernel-Tuning, Memory Management | cgroup-Limits, PSI, systemd-Härtung, Namespaces | Stark |
| Infrastructure as Code | Ein Modul je Dienst, Gates, Generationen, Rückrollung | Stark |
| Netzwerk: TCP/IP, Firewall, DNS | nftables als Code, DNS, Segmentierung, WireGuard | Stark |
| Datastores und Messaging (PostgreSQL, Redis, Kafka, NATS) | Keine Plattformpraxis; restic und NAS als Speichererfahrung | **Lücke** |
| CI/CD mit GitLab, Terraform, Ansible, Helm | Git als einzige Quelle mit eigenen Gates; kein GitLab, kein Terraform | Teilweise |
| Souveräne Cloud, Mandantenfähigkeit, Quotas | Keine Produkterfahrung | **Lücke** |
| Deutsch C1 | C1, Englisch Muttersprache | Erfüllt |
| Arbeitserlaubnis | US-Staatsangehörigkeit mit Niederlassungserlaubnis, kein Sponsor | Erfüllt |

## Fit-Begründung: 2 von 5

Zwei, weil Kubernetes der Gegenstand der Arbeit ist und im Lebenslauf vollständig fehlt: Control Plane, etcd, CNI, Upgrade-Pfade für Kundencluster. Bei einem Cloud-Anbieter ist das Monate Einarbeitung, nicht Wochen.

Nicht 1, weil die Ebene darunter passt: Linux-Interna, deklarativer Zustand mit Generationen und Rückrollung, Go, Netzwerk, Speicher und Telemetrie sind vorhanden und im öffentlichen Repository nachprüfbar.

## Offene Punkte

1. **Kubernetes-Lücke** steht im ersten Absatz des Anschreibens, nicht im letzten.
2. **Originalanzeige fehlt**: Anforderungen aus Schwesteranzeigen rekonstruiert. Vor dem Absenden die Stelle auf stackit.com oder schwarz-digits.de suchen und gegen dieses Paket prüfen.
3. Zeugnisse fehlen.
4. Präsenz: Neckarsulm rund 1,5 bis 2 h von Gutach im Breisgau; Präsenzblöcke angeboten, Umzug als spätere Option.
5. Keine Gehaltsangabe, weil die Vorgabe keine nennt.

## Paket

| Datei | Inhalt |
| :--- | :--- |
| `job-description.txt` | Profil aus den Schwesteranzeigen mit Quellenhinweis. |
| `lead.md` | Fit, Lücken, Weg, Quellenlage. |
| `lebenslauf.typ` | Typst-Quelle, eigenständig kompilierbar. |
| `anschreiben.typ` | Typst-Quelle, eigenständig kompilierbar. |
| `lebenslauf.pdf` | Zwei Seiten. |
| `anschreiben.pdf` | Eine Seite. |
| `submission-sheet.md` | Diese Übersicht. |
