# Lead: STACKIT / Schwarz Digits — (Senior) Platform Engineer, Control Plane Platform

Fit: 3
Stand: 22.11.2026
Ort: Bad Friedrichshall
Referenz: 1923 (Portal-Ref. SDE-131335 / 1923-15454); Vorgabe nennt GT2321

## Quellenlage

Die Anzeige ist live abrufbar (jobsuche-bw.de, HTTP 200 am 22.11.2026) und liegt vollständig im Paket. Es gibt allerdings eine Zuordnungslücke: Die Vorgabe nennt GT2321, im Bestand führt GT2321 aber die Schwesterstelle "(Senior) Site Reliability Engineer - STACKIT Control Plane". Der hinterlegte Text gehört zur Platform-Engineer-Anzeige mit Referenz 1923. Vor dem Absenden muss klar sein, welche Requisition besetzt wird — die beiden Anzeigen beschreiben dieselbe Abteilung, aber unterschiedliche Schwerpunkte.

## Warum interessant

Die Rolle baut interne Werkzeuge, die die Bereitstellung der STACKIT-Infrastruktur automatisieren, verantwortet Monitoring für Verfügbarkeit und Performance und unterstützt Entwicklungsteams dabei, ihre Services auf der Plattform zu betreiben. Das ist Plattformarbeit im Wortsinn: nicht ein Produkt bedienen, sondern die Werkzeuge bauen, mit denen andere ihre Produkte betreiben.

Der Teil, der wirklich passt, ist genau dieser: Werkzeuge schreiben statt einkaufen, Monitoring als eigene Messung statt als Dashboard-Abo, deklarativer Zustand statt Handarbeit. Die Control Plane selbst — Kubernetes-Architektur, Operator-Pattern, CNI — fehlt vollständig.

## Was passt

- Deklarativer Betrieb mit Gates: ein Modul je Dienst, eine Feature-Liste je Host, jede Änderung ein Commit, jeder Stand als Generation rückrollbar.
- Go im Betrieb: Alarm-Bridge mit Zustellbestätigung, Router der autarken KI-Plattform, Auswertungen über Ledger-Daten.
- Linux-Interna: cgroup-Limits, PSI, systemd-Härtung, Namespaces, PXE-Installationen.
- Monitoring als eigene Messung: Sentinel-Ledger alle 15 Minuten, Gatus, Zustellbestätigung.
- Netz und Security: nftables als Code, DNS, Segmentierung, WireGuard, eigene CA mit kurzlebigen Zertifikaten, sops und age.
- Git als einzige Quelle mit CI-Gates; Runbooks für jede Prozedur.

## Was fehlt

- **Kubernetes-Architektur** und Clusterbetrieb — Muss-Anforderung der Anzeige.
- Operator-Pattern, CRDs, Controller.
- Software-Defined Networking: Istio, Calico.
- Templating: Helm, Kustomize.
- IaC: Terraform, Pulumi.
- CI/CD: Concourse, Flux (Git und eigene Gates sind vorhanden, die Werkzeuge nicht).
- Betrieb großer verteilter Systeme in einem Cloud-Produkt, Mandantenfähigkeit, Quotas.

## Weg

Bewerbung über das Schwarz-Digits-/STACKIT-Portal zur Anzeige 1923, sofern diese Requisition gemeint ist; sonst GT2321 prüfen. Englisch ist laut Anzeige die Basissprache, Deutsch idealerweise zusätzlich — das Paket ist deshalb deutsch, mit englischem Anschreiben auf Wunsch in einem Durchgang ersetzbar.

## Gehalt

Keine Angabe in der Anzeige, keine Zahl im Anschreiben.

## Fit-Begründung: 3 von 5

Drei, weil die Plattform-Denkweise, Go, Linux-Interna und Monitoring echt vorhanden sind und die Rolle genau diese Werkzeugarbeit beschreibt.

Nicht höher, weil Kubernetes-Architektur als "fundierte Kenntnisse" gefordert ist und im Lebenslauf vollständig fehlt — samt Operator-Pattern, CNI, Helm und Terraform. Wer eine Control Plane baut, braucht das am ersten Tag.

Nicht 2, weil ein Teil der Stelle aus Werkzeugen besteht, die hier selbst geschrieben wurden: Monitoring, Alarmierung mit Zustellbestätigung, Automatisierung, interne Dienste für andere.
