# Lead: BWI GmbH — Senior Infrastructure/Platform Engineer (m/w/d)

Fit: 3
Stand: 22.11.2026
Stellen-ID: 64059
Ort: Bonn, Köln, Meckenheim (hybrid)
Ansprechpartnerin: Darina Kache, Recruiterin

## Warum interessant

Die BWI ist das IT-Systemhaus der Bundeswehr und betreibt eine der größten IT-Infrastrukturen Deutschlands. Die Stelle sitzt in der Abteilung DevSecOps Engineering im Competence Center IT-Security (CCITS): dort werden die sicherheitskritischen Softwareprojekte umgesetzt und betrieben. Die Aufgabe ist konkret: eine Kubernetes-Infrastruktur in eigenen Rechenzentren für air-gapped Environments bauen und betreiben, dazu eine containerbasierte Edge-Computing-Umgebung als Produkt.

Der Reiz liegt in der Randbedingung. Air-gapped heißt: keine Paketquelle im Internet, keine bequeme Cloud, jede Abhängigkeit muss mitgeliefert und geprüft werden. Genau so ist die eigene Flotte gebaut — kein Dienst mit öffentlicher Schnittstelle, eigene Zertifizierungsstelle, Geheimnisse im Repository, Installation über PXE statt über einen Anbieter.

## Was passt — und zwar auffällig genau

Das Profil nennt ausdrücklich: **Nix/NixOS**, Linux und Härtung von Linux-Systemen, Automation, Infrastructure as Code, Go wünschenswert.

- NixOS ist keine Randnotiz, sondern die Betriebsgrundlage: dreizehn Hosts über drei Hardware-Generationen, jeder Dienst ein Modul, jeder Host eine Feature-Liste.
- Infrastructure as Code im Wortsinn: jede Änderung ein Commit, jedes Gate prüft denselben Zustand, der ausgerollt wird, jeder Stand als Generation rückrollbar.
- Härtung: nftables, Segmentierung, WireGuard, minimale Rechte, Ressourcenlimits je Dienst.
- Automation und Go: Sentinel-Ledger alle 15 Minuten, Go-Bridge für Alarmzustellung mit Bestätigung, PXE- und ISO-Auslieferung für Bare-Metal-Installationen.
- PKI-Hygiene: eigene SSH-CA mit kurzlebigen Zertifikaten, TLS über eigene CA, sops und age.
- Dokumentation als Teil der Arbeit: jede Prozedur ein Runbook, damit Betrieb nicht an einer Person hängt.

## Was fehlt

- **Kubernetes im Produktivbetrieb — die Kernanforderung der Stelle.** Kein CKA, kein CKS, keine Cluster-Administration.
- Container-Orchestrierung als Produkt, Edge-Computing-Plattformen.
- Ceph und Enterprise-Network-Storage; die eigene Speicherpraxis sind restic, NAS-Ziele und lokale Volumes.
- Enterprise-Virtualisierung (VMware, Hyper-V); die eigene Virtualisierungserfahrung sind QEMU- und MicroVM-Gäste unter NixOS.
- DevSecOps-Toolchains im Unternehmensmaßstab (SAST, DAST, SBOM).
- Betrieb in einem VS-NfD- oder Geheimschutzumfeld.

## Weg

Bewerbung über das BWI-Karrierportal, Stellen-ID 64059. Keine Frist genannt. Recruiterin Darina Kache ist auf der Anzeige benannt.

## Gehalt

Eigene Vorstellung 88.000 bis 92.000 EUR, wie vorgegeben und im Anschreiben genannt. Die Anzeige nennt ein Einstiegsband von **71.000 bis 91.650 EUR** brutto im Jahr und sagt, gerechtfertigte Abweichungen seien im Einzelfall möglich. Die Vorstellung liegt damit am oberen Rand und darüber; das Anschreiben begründet sie mit der Betriebsverantwortung über die ganze Flotte und bietet ein Gespräch darüber an.

## Fit-Begründung: 3 von 5

Drei, weil die Kernanforderung fehlt. Die Stelle baut und betreibt Kubernetes für air-gapped Rechenzentren; Kubernetes-Kenntnisse im Umfang CKA/CKS sind keine Kür, sondern die Messlatte. Wer das nicht hat, braucht Einarbeitung in genau dem Teil, der die Arbeitszeit füllt. Das ist keine Frage der Haltung, sondern des Könnens.

Warum nicht 4: Die Vorgabe lautete 4, aber die Anzeige wurde erst beim Abruf vollständig sichtbar, und dort steht Kubernetes an erster Stelle der Aufgaben und als „sehr gute Kenntnisse" im Profil. Eine 4 würde eine Passung behaupten, die der Aufgabentext nicht hergibt.

Warum überhaupt 3 und nicht 2: Das Profil nennt Nix/NixOS, Linux-Härtung, Automation und Go ausdrücklich — und das ist vorhanden, dokumentiert und öffentlich nachprüfbar. Dazu air-gapped Denkweise aus eigener Praxis und die Bereitschaft zur SÜ2. Ein Gespräch ist realistisch, die Einarbeitung wäre echt.
