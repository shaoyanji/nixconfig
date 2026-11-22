# Lead: STACKIT / Schwarz Digits — Senior Kubernetes Engineer

Fit: 2
Stand: 22.11.2026
Ort: Bad Friedrichshall / Neckarsulm

## Quellenlage

Die Anzeige selbst war nicht abrufbar (JavaScript-Seite, keine Treffer über die Jobsuche von Schwarz Digits). Das Profil stammt aus den gleichzeitig ausgeschriebenen STACKIT-Stellen zur Control Plane (Ref. 2321), zu Kubernetes-Networking und zu DevOps/Cloud Engineering (Ref. 4627). Das ist eine Rekonstruktion, keine Zitierung dieser Stelle.

## Warum interessant

STACKIT baut eine souveräne Cloud in Europa und betreibt dafür Kubernetes als eigenes Produkt, inklusive Control Plane, Netzwerk und Speicher. Das ist Infrastrukturarbeit am unteren Ende des Stacks, nicht Plattformnutzung oben drauf — genau die Ebene, auf der die eigene Flotte gebaut ist: deklarativer Zustand, Generationen, Rückrollung, Gates, keine Handarbeit auf Maschinen.

Dazu Neckarsulm/Bad Friedrichshall: rund anderthalb bis zwei Stunden von Gutach im Breisgau, also im Bereich dessen, was mit hybridem Modell und Präsenzblöcken geht.

## Was passt

- Deklarativer Betrieb als Grundprinzip: ein Modul je Dienst, eine Feature-Liste je Host, jede Änderung ein Commit mit Gate, jeder Stand als Generation rückrollbar.
- Linux-Interna: cgroup-Limits je Dienst, PSI als Messgröße, systemd-Härtung, Namespaces, kein Dienst mit öffentlicher Schnittstelle.
- Netzwerk: nftables als Code, DNS, Segmentierung, WireGuard-Tailnet, PXE-Installationen.
- Go: Alarm-Bridge und Router der eigenen KI-Plattform, beide im Betrieb.
- Speicher und Sicherung: NAS-Ziele, restic, geprüfte Wiederherstellungen.
- Git als einzige Quelle mit CI-Gates; Telemetrie als Ledger mit Zustellbestätigung.

## Was fehlt

- **Kubernetes in jeder Form**: kein Clusterbetrieb, keine Control Plane, kein etcd, keine Operatoren, kein Helm, keine CRDs.
- CNI, Load-Balancer-Integration und eBPF.
- Terraform, Ansible, GitLab-CI.
- Datastores und Messaging im Plattformmaßstab (PostgreSQL, Redis, Kafka, NATS).
- Betrieb großer verteilter Systeme in Produktionsumgebungen über mehrere Teams.
- Cloud-Produktdenken: Mandantenfähigkeit, Quotas, Upgrade-Pfade für Kundencluster.

## Weg

Bewerbung über die STACKIT-/Schwarz-Digits-Karriereseite. Vor dem Absenden die Originalanzeige suchen und die Anforderungen gegen dieses Paket prüfen; die Stelle war über die Jobsuche nicht auffindbar.

## Gehalt

Keine Angabe in der Vorgabe, keine Zahl im Anschreiben.

## Fit-Begründung: 2 von 5

Zwei, weil die Rolle Kubernetes als Produkt baut und Kubernetes im Lebenslauf vollständig fehlt. Bei einem Cloud-Anbieter ist das nicht eine Anforderung unter zehn, sondern der Gegenstand der Arbeit: Control Plane, CNI, Upgrade-Pfade, Mandanten. Wer das nicht betrieben hat, braucht Monate, nicht Wochen.

Nicht 1, weil die Umgebung darunter echt passt: Linux-Interna, deklarativer Betrieb mit Generationen und Rückrollung, Go, Netze, Speicher, Telemetrie. Wer eine Flotte so betreibt, versteht die Denkweise hinter einem Cluster-Lebenszyklus; was fehlt, ist die konkrete Technik.
