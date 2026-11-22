# STACKIT / Schwarz Digits — Senior Kubernetes Engineer (m/f/d), GT4121

Bad Friedrichshall (Am Campus 1) · IT Cloud Services · Vollzeit · Anzeige vom 2026-07-15, am 2026-11-22 mit HTTP 200 und `data-job-id="GT4121"` geprüft.
Die deutsche Fassung der Anzeige liefert 404; `job-description.txt` ist der englische Text mit Herkunftskopf. Kontakt: Tatjana Kirschner,
`recruiting@mail.schwarz`. Kein Band veröffentlicht; Gehaltsvorstellung **85.000 EUR**.

**Status:** vorbereitet, nicht beworben. Fit **2**: die Stelle verlangt Operatoren, Controller und CRDs in Go sowie Gardener oder ClusterAPI, und
beides ist im Repository nicht vorhanden.

## Altbestand: schon in der Historie, jetzt aufgeräumt

Dieses Paket war als einziges der Reihe bereits versioniert (Aufnahme in `9738979c`), ein Stage-Commit war deshalb nicht nötig. Im Neubau-Commit
entfernt: der Symlink `packet` in den Nix-Store und die drei JSON-Dateien des Generators. Die PDFs wurden ersetzt.

| Artefakt | sha256 (erste 16) | Was es war |
| :--- | :--- | :--- |
| `lebenslauf.pdf` | `4236a8e6b3f68d8b…` | Nix-CV, „System- und Sicherheitsingenieur", ohne Bezug zu Containern |
| `anschreiben.pdf` | `7269a72b609ec209…` | Nix-Anschreiben, deutsch, ohne die Kubernetes-Lücke so klar zu benennen |
| `selection.json` | `fb7928495370d663…` | Generator-Auswahl (Budget, JD, Projekte, Skills) |
| `lebenslauf.json` | `9b39c35e2e6a591d…` | Generator-Zwischenstand des CV |
| `letter.json` | `e5b6b6c34f16849f…` | Generator-Zwischenstand des Anschreibens |
| `packet` (Symlink) | → `/nix/store/7mnfxl0hg9npdbw7dpn2iw7fdmlfc4vj-appflow-packet-stackit-schwarz-digits-senior-kubernetes-engineer` | Nix-Store-Paket, außerhalb des Repos nicht reproduzierbar |
| `submission-sheet.md` | `6beec62a62b39a3f…` | das vorige Blatt, Vorgänger dieser Datei |

## Dateien

| Datei | Seiten | Wörter | Warnungen | sha256 (erste 16) |
| :--- | :--- | :--- | :--- | :--- |
| `lebenslauf.pdf` | 2 | 921 | 0 | `545f67771d96dc32` |
| `anschreiben.pdf` | 1 | 406 | 0 | `533a28f6e17a0710` |

## Vier Säulen der Anzeige, gegen das Repository geprüft

| Säule | Beleg im Repo | Im Dokument |
| :--- | :--- | :--- |
| Container und Virtualisierung | `hosts/microvms/*`: microvm.nix mit cloud-hypervisor, vsock, virtiofs, TCG-Rückfall; `microvm-host.nix` mit isolierter Bridge, NAT und udev-Taps; systemd-Slices als Ressourcengrenze | vollständig behauptet, ohne Kubernetes-Anspruch |
| Deklarative Systeme | dreizehn NixOS-Hosts aus einem Flake mit gepinnten Inputs, Modullisten je Host, Auswertungslauf pro Host als Freigabe, Rollback per Generation | vollständig behauptet |
| Telemetrie und Betrieb | Sentinel-Journal alle fünfzehn Minuten (Job-Status, Generationsalter, Disk/Inode, PSI) mit Alarm auf Zustand und Stille; PostgreSQL-Migrationen und Wiederherstellungsdrill (EXP-042) | vollständig behauptet |
| Linux-Systemtechnik | systemd, nftables-Freigaben je Dienst und Netz, WireGuard-Mesh, DNS-Failover mit VRRP, tcpdump bis zur MTU-Grenze, ZFS und SMART/NVMe | vollständig behauptet |

## Lücken, in beiden Dokumenten benannt

Kein Kubernetes im Produktivbetrieb, weder Einzelcluster noch Multi-Cluster, kein Gardener und kein ClusterAPI. Keine Operatoren, Controller oder CRDs in
Go — die Go-Arbeit sind Dienste und Kommandozeilenwerkzeuge (23 Go-Dateien im Repository). Kein Kyverno, kein Falco, kein GitOps mit Argo oder Flux,
kein Betrieb von CNI oder etcd. Keine Zertifizierung (CKA, CKS) und keine Mitarbeit an einem Upstream-Projekt. Skalierung: Einzelbetreiber mit dreizehn
Hosts und einem microVM-Labor, nicht eine Kundenplattform mit vielen Clustern.

## Weg

Bewerbung über den Apply-Button der Anzeige (RocketApply auf SAP BTP, `data-job-id="GT4121"`); das Formular liegt hinter einer Session und wurde nicht
ausgefüllt. Sprache: Deutsch, weil der Arbeitgeber ein deutsches Unternehmen ist und die Anzeige Deutsch als Plus nennt; Englisch ist ohnehin
Muttersprache. Umzug nach Bad Friedrichshall ist erklärt (rund 190 km von Gutach im Breisgau), Eintritt ab 01.12.2026, kein Sponsoring nötig.

## Prüfungen

| Prüfung | Ergebnis |
| :--- | :--- |
| `typst compile` beider Quellen | je 0 Warnungen |
| Seitenbudget | CV 2 Seiten, Anschreiben 1 Seite (vor dem Commit geprüft) |
| `**` in den Quellen | 0 |
| Typografische Anführungszeichen | 0 |
| `task checks:prose` | Exit 0 |
| Altbestand | Symlink und drei JSON-Dateien entfernt, PDFs ersetzt, Hashes oben |
