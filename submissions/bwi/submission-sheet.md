# Bewerbung BWI GmbH — Senior Infrastructure/Platform Engineer (m/w/d)

Stand: 22. November 2026
Fit: 3
Stellen-ID: 64059

## Stelle

| Feld | Wert |
| :--- | :--- |
| Arbeitgeber | BWI GmbH, IT-Systemhaus der Bundeswehr — DevSecOps Engineering im CCITS |
| Rolle | Senior Infrastructure/Platform Engineer (m/w/d) |
| Standorte | Bonn, Köln, Meckenheim (mobil und Vertrauensarbeitszeit) |
| Adresse | Auf dem Steinbüchel 22, 53340 Meckenheim |
| Ansprechpartnerin | Darina Kache, Recruiterin |
| Entgelt laut Anzeige | 71.000 bis 91.650 EUR brutto p.a., Abweichungen im Einzelfall möglich |
| Eigene Vorstellung | 88.000 bis 92.000 EUR, im Anschreiben begründet |
| Sicherheit | Sicherheitsüberprüfung SÜ2 |
| Weg | BWI-Karrierportal, Stellen-ID 64059 |

## Dokumente

| Dokument | Datei | Hinweis |
| :--- | :--- | :--- |
| Anschreiben | `anschreiben.pdf` | Eine Seite, deutsch, an Frau Kache, mit Gehalt und SÜ2-Bereitschaft |
| Lebenslauf | `lebenslauf.pdf` | Zwei Seiten, deutsch |
| Quellen | `lebenslauf.typ`, `anschreiben.typ` | Typst, eigenständig kompilierbar |
| Zeugnisse | keine Datei | Muss ergänzt werden |

## Abgleich mit dem Anzeigentext

| Anforderung | Nachweis | Einschätzung |
| :--- | :--- | :--- |
| Kubernetes-Infrastruktur in air-gapped Rechenzentren bauen und betreiben | Keine Praxis | **Kernlücke** |
| Sehr gute Kubernetes-Kenntnisse, ideal CKA/CKS | Kein Zertifikat, keine Cluster-Administration | **Kernlücke** |
| Infrastructure as Code und Automation | Flake mit Modulen, Gates, Rückrollung; CI prüft den Ausrollzustand | Stark |
| **Nix/NixOS** (ausdrücklich im Profil) | Dreizehn Hosts, drei Generationen, deklarativer Betrieb, MicroVMs | Sehr stark |
| Linux und Härtung von Linux-Systemen | nftables, Segmentierung, minimale Rechte, systemd-Limits | Sehr stark |
| Programmiersprachen, Go wünschenswert | Go-Bridge für Alarmierung, Go-Router der KI-Plattform | Stark |
| Virtualisierung | QEMU- und MicroVM-Gäste unter NixOS | Teilweise |
| Network Storage, z. B. Ceph | restic auf NAS-Ziele; kein Ceph | **Lücke** |
| Container-basierte Edge-Umgebung als Produkt | Keine Produktverantwortung für Container-Plattformen | **Lücke** |
| Mindestens 4 Jahre einschlägige Berufserfahrung | Zehn Jahre Betrieb und Automatisierung | Erfüllt |
| Fließendes Deutsch, gutes Englisch | Deutsch C1, Englisch Muttersprache | Erfüllt |
| Reisebereitschaft | Vorhanden, im Anschreiben genannt | Erfüllt |
| SÜ2-Bereitschaft | Erklärt | Erfüllt |

## Fit-Begründung: 3 von 5

Die Vorgabe nannte 4. Nach dem Abruf der Anzeige am 22.11.2026 steht dort Kubernetes an erster Stelle der Aufgaben und als „sehr gute Kenntnisse (ideal im Umfang CKA/CKS)" im Profil; dazu eine containerbasierte Edge-Umgebung als Produkt. Das ist der Kern der Stelle, und er fehlt. Deshalb 3, nicht 4 — eine 4 würde eine Passung behaupten, die der Aufgabentext nicht hergibt.

Warum nicht 2: Das Profil nennt Nix/NixOS, Linux-Härtung, Automation und Go ausdrücklich, und genau das ist vorhanden, dokumentiert und öffentlich nachprüfbar. Air-gapped Denkweise — keine öffentliche Schnittstelle, eigene CA, PXE-Installation aus eigenem Archiv — ist gelebte Praxis. Ein Gespräch ist realistisch.

## Offene Punkte

1. **Kubernetes ist die Kernanforderung und fehlt.** Im Anschreiben im dritten Absatz benannt, nicht versteckt.
2. **Gehalt:** Vorstellung 88.000 bis 92.000 EUR liegt über dem oberen Bandrand von 91.650 EUR; im Anschreiben begründet und gesprächsbereit.
3. Zeugnisse fehlen.
4. **SÜ2:** Bereitschaft erklärt; US-Staatsangehörigkeit mit unbefristetem Niederlassungsrecht kann den Ablauf beeinflussen. Vor dem Absenden mit Frau Kache klären.
5. **Präsenz:** rund 3,5 h von Meckenheim; Präsenzblöcke angeboten, Umzug als spätere Option.
6. Ceph, VMware und Hyper-V im Lebenslauf als nicht vorhanden geführt.

## Paket

| Datei | Inhalt |
| :--- | :--- |
| `job-description.txt` | Anzeigentext vom 22.11.2026, mit Abgleichsnotiz am Ende. |
| `lead.md` | Fit, Lücken, Weg, Gehalt. |
| `lebenslauf.typ` | Typst-Quelle, eigenständig kompilierbar. |
| `anschreiben.typ` | Typst-Quelle, eigenständig kompilierbar. |
| `lebenslauf.pdf` | Zwei Seiten. |
| `anschreiben.pdf` | Eine Seite. |
| `submission-sheet.md` | Diese Übersicht. |
