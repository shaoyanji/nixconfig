# Bechtle AG / KubeOps — Cloud Platform Engineer (w/m/d) (Remote)

Job **72406**, 100 % Remote (Deutschland), Sitz Bisingen / Balingen. Quelle des Anzeigentextes ist der
BA-Spiegel `15086-44517367-1019-S`, weil die SuccessFactors-URL bei Bechtle auf eine Fehlerseite leitet.
Native Typst-Quellen, `packet`-Symlink und JSON entfernt. Stand: gebaut und geprüft, **nichts eingereicht**.

| Feld | Wert |
| :--- | :--- |
| Role ID | `bechtle-cloud-platform-engineer-remote` |
| Arbeitgeber | Bechtle AG, Bereich **KubeOps** (ca. 90 Mitarbeitende) |
| Rolle | Cloud Platform Engineer (w/m/d) (Remote) |
| Job-ID | 72406 |
| Ansprechpartner | Christopher Waldraff, christopher.waldraff\@bechtle.com |
| Ort | 100 % Remote (Deutschland); Sitz Balingen/Bisingen, BW |
| Sprache | Deutsch (Kundenumfeld), Englisch gut |
| Gehalt | keine Bandbreite im Inserat; keine Zahl im Brief |
| Fit | 3 (DB-Eintrag 4) |

## Was die Anzeige verlangt

Cloud-native Plattformen und Workloads entwickeln und automatisieren; **CI/CD- und DevSecOps-Lösungen**;
Infrastruktur nach **IaC-Prinzipien**; Betrieb und Weiterentwicklung einer **Private Cloud** samt
Plattformservices; Integration in bestehende Systemlandschaften; Zusammenarbeit mit Entwickler:innen und DevOps
Engineers. Skills: **Kubernetes/Docker** fortgeschritten, **IaC idealerweise Terraform**, **GitLab/GitHub**,
**Linux** stark, DevSecOps, Deutsch sicher im Kundenumfeld, **Bereitschaft zu SÜ2**. Arbeitsmodell: 90
Präsenztage im Jahr, sonst Remote; ab 60 km Entfernung vollständig remote möglich.

## Fit-Map

| Anforderung | Nachweis | Urteil |
| :--- | :--- | :--- |
| Linux-Kenntnisse | NixOS, systemd, journald, cgroups/PSI, nftables, tcpdump | stark |
| IaC-Prinzipien | deklarierter Zustand, gepinnte Inputs, Rollback | stark, in Nix |
| Kubernetes / Docker | **nicht als Administrator betrieben** | **Lücke** |
| Terraform | **nicht eingesetzt** | **Lücke** |
| GitLab / GitHub CI/CD | Gates gebaut, aber nicht auf diesen Plattformen | **Lücke** |
| DevSecOps / Härtung | Default-Deny, SOPS/age, SSH-CA, Minimalrechte | stark |
| Souveränität / sensible Umgebungen | lokale Inferenz auf eigener Hardware | stark, selten |
| Remote-Disziplin | fünf Jahre ortsunabhängig, schriftliche Übergabe | stark |
| Deutsch im Kundenumfeld | C1, alle Unterlagen deutsch | erfüllt |
| SÜ2 | Bereitschaft erklärt, Erteilung bei der zuständigen Stelle | offen |

## Ehrliche Einordnung

Drei der fünf geforderten Werkzeugbereiche — Kubernetes/Docker, Terraform, GitLab/GitHub — fehlen. Der Brief
sagt das im vierten Absatz und bietet statt einer Behauptung die Schicht darunter an: Linux, Automatisierung,
Härtung, Nachvollziehbarkeit. Zwei Dinge sprechen trotzdem für die Bewerbung: die Rolle ist zu 100 % remote
ausgeschrieben, und das Profil bringt fünf Jahre ortsunabhängige Arbeit mit schriftlicher Übergabe mit; und
KubeOps adressiert Public Sector und regulierte Kunden, wo Souveränität und prüfbarer Betrieb zählen — beides
ist belegbar vorhanden (lokale Inferenz, SOPS/age, Default-Deny).

Fit **3**, nicht 4: die Werkzeuglücken sind zu groß für eine Selbstverständlichkeit, aber klein genug für eine
Bewerbung, wenn der Kunde Einarbeitung akzeptiert.

## SÜ2 — wie es im Brief steht

Bereitschaft wird erklärt, zusammen mit der Grenze: US-Staatsbürger mit deutscher Niederlassungserlaubnis, und
über die Erteilung entscheidet die zuständige Stelle. Diese Formulierung steht in jedem Paket mit
Sicherheitsüberprüfung (SVA, DFS, hier) — sie ist die einzige, die später nicht als Täuschung gelesen werden
kann.

## Prüfungen

| Prüfung | Ergebnis |
| :--- | :--- |
| `packet`-Symlink | entfernt (zeigte auf `…-appflow-packet-bechtle-cloud-platform-engineer-remote`) |
| Legacy-JSON | `lebenslauf.json`, `letter.json`, `selection.json` entfernt |
| `chmod u+w *.pdf` | ausgeführt |
| `typst compile lebenslauf.typ` | exit 0, keine Warnungen |
| `typst compile anschreiben.typ` | exit 0, keine Warnungen |
| `pdfinfo lebenslauf.pdf` | **2 Seiten** |
| `pdfinfo anschreiben.pdf` | **1 Seite** |
| Marker | `72406`, `Waldraff`, `KubeOps`, `SÜ2`, `Terraform` |
| `task checks:prose` | 241 prose files, exit 0 |
| sha256 Lebenslauf | `db874b62217f38d10fd2c0bb29e106a5e6679367ef1205c692dacabbccf193fd` |
| sha256 Anschreiben | `c7e515167386d980cd4e9c2d83909edfba32e44fb482b82e4bd9d7b2c6893bcb` |

## Nächste Schritte

1. Über das Bechtle-Portal (Job 72406) bewerben, Anschreiben an Herrn Waldraff.
2. Vor dem Gespräch klären, ob der Cluster-Betrieb oder die Plattform-Automatisierung den Schwerpunkt bildet.
3. SÜ2 früh ansprechen; bei KubeOps im Public-Sector-Umfeld ist sie kein Nebensatz.
