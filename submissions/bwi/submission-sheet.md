# BWI GmbH — Senior Infrastructure/Platform Engineer (m/w/d)

Stellen-ID **64059** · Bonn · Köln · Meckenheim · Vollzeit, unbefristet · Bereich DevSecOps Engineering im Competence Center IT-Security (CCITS).
Ausgeschriebenes Band **71.000–91.650 EUR** brutto jährlich.

**Status:** beworben über das BWI-Karriereportal (Concludis 64059), Bestätigungsseite am 2026-11-22 geprüft. Dieses Paket ersetzt die Nix-PDFs durch
Typst-Quellen und bleibt bei den abgegebenen Aussagen.

## Altpaket, jetzt wirklich in der Historie

Alle fünf Dateien waren untracked und gingen zuerst unverändert in einen eigenen Commit (`appflow(bwi): stage das Altpaket vor dem Typst-Neubau`).
Im Neubau-Commit wurden sie ersetzt:

| Datei | sha256 (erste 16) | Was sie war |
| :--- | :--- | :--- |
| `lebenslauf.pdf` | `e5b297ead7b811a2…` | Nix-CV mit der Überschrift Senior Infrastructure/Platform Engineer — Linux, Kubernetes & NixOS |
| `anschreiben.pdf` | `8edd88d41b6b3744…` | Nix-Anschreiben, nannte Container-/Kubernetes-Grundlagen und CISA KEV, ohne Deckung im Repo |
| `selection.json` | `045afab07c44fb61…` | Auswahlausgabe |
| `submission-sheet.md` | `8313396b6a672f3b…` | das Blatt vom 2026-11-21, Vorgänger dieser Datei |

`job-description.txt` bleibt unverändert: eine echte Aufzeichnung der Anzeige.

## Dateien

| Datei | Seiten | Wörter | Warnungen | sha256 (erste 16) |
| :--- | :--- | :--- | :--- | :--- |
| `lebenslauf.pdf` | 2 | 952 | 0 | `fc413b748cd7d6bc` |
| `anschreiben.pdf` | 1 | 423 | 0 | `09d4ee939e9c990c` |

## Vier Säulen der Anzeige, gegen das Repository geprüft

| Säule | Beleg im Repo | Im Dokument |
| :--- | :--- | :--- |
| Linux-Systemtechnik und Härtung | systemd-Dienste mit `ProtectSystem=strict`, `ProtectHome`, `PrivateTmp`, `NoNewPrivileges`; ein Benutzer je Dienst; `firewall-scope.nix` mit Freigaben je Dienst und Netz samt datierten Streichungen | vollständig behauptet |
| Deklarative Nix-Konfiguration | dreizehn Hosts aus einem Flake mit gepinnten Inputs, Modullisten je Host, ein Auswertungslauf pro Host als Freigabe, Rollback auf die vorherige Generation | vollständig behauptet |
| DevSecOps-Automatisierung | Task-Control-Plane mit Planungslauf, JSON-Ausgabe und Exit-Code je Ergebnis; `.githooks/pre-commit` und `pre-push`; Gates für Format, Syntax und Textregeln; CI-Matrix aus dem Inventar | vollständig behauptet |
| Sicherheits- und Zugriffsposition | eigene SSH-CA mit kurzlebigen Zertifikaten, SOPS/age mit einem Schlüssel je Host, keine stehenden Schlüssel, Secrets im Repository statt auf dem Host | vollständig behauptet |

Dazu, als Betriebsarbeit und nicht als Zertifizierung: Telemetrie im Sentinel (Job-Status, Generationsalter, Disk/Inode, PSI) mit Alarm auf Zustand und
Stille, PostgreSQL mit geordneten Migrationen und einem Wiederherstellungsdrill, Virtualisierung im microVM-Labor auf KVM.

## Lücken, in beiden Dokumenten benannt

Kein Kubernetes im Produktivbetrieb, weder als Cluster noch air-gapped, und weder CKA noch CKS. Kein Ceph im Betrieb; Storage-Erfahrung sind ZFS,
SMART/NVMe, NFS/SMB und Backups. Virtualisierung aus KVM- und microVM-Laboren, nicht aus VMware oder OpenStack im Großbetrieb. Kein
BSI-Grundschutz-Projekt verantwortet; die Anzeige fordert es nicht, der Behördenkontext verlangt es faktisch. Skalierung: Einzelbetreiber mit dreizehn
Hosts, nicht ein Rechenzentrum mit tausenden Knoten.

Zwei Sätze des Altpakets sind deshalb entfallen: Container-/Kubernetes-Grundlagen als Kompetenz (zu weich für ein Profil, das CKA/CKS nennt, und ohne
Beleg) und die Behauptung, Schwachstellenarbeit laufe über CISA KEV und Aufwands-Cluster — dafür gibt es im Repository keinen Beleg.

## Weg und Formalien

Bewerbung über das BWI-Karriereportal (Concludis, ID 64059) oder `bewerbung@bwi.de`. Präsenz ist an einem der drei Standorte vorgesehen; die
Remotive-Fassung nennt remote, der Originaltext nicht, deshalb steht im Anschreiben der Umzug an einen Standort und keine Remote-Zusage.
Sicherheitsüberprüfung nach SÜG: Bereitschaft erklärt, ohne eine Zusage zu behaupten. US-Staatsbürgerschaft mit unbefristeter Niederlassungserlaubnis,
Deutsch C1, Englisch Muttersprache, Eintritt ab 01.12.2026, Reisebereitschaft ja.

**Gehalt:** 88.000–91.650 EUR, also an der Oberkante des Bands. Das vorige Blatt nannte 88.000–92.000 EUR und lag damit über dem ausgeschriebenen Band;
die Oberkante ist die belastbare Zahl und steht so im Anschreiben.

## Prüfungen

| Prüfung | Ergebnis |
| :--- | :--- |
| `typst compile` beider Quellen | je 0 Warnungen |
| Seitenbudget | CV 2 Seiten, Anschreiben 1 Seite (vor dem Commit geprüft; der erste Anlauf mit 528 Wörtern lief auf zwei Seiten und wurde nicht committet) |
| `**` in den Quellen | 0 |
| Typografische Anführungszeichen | 0 |
| `task checks:prose` | Exit 0 |
| Altpaket | zuerst gestaged, im Neubau ersetzt, Hashes oben |
