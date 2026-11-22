# shopware AG — Cloud Infrastructure Engineer – AWS (m/w/d)

Arbeitnow-Inserat `150808`. Quellen sind jetzt **native Typst-Dateien**; der frühere JSON-Build und der
`packet`-Symlink in den Nix-Store sind entfernt. Stand: Paket fertig, **nichts eingereicht**.

| Feld | Wert |
| :--- | :--- |
| Role ID | `shopware-cloud-infra` |
| Arbeitgeber | shopware AG, Schöppingen (~450 Mitarbeitende) |
| Rolle | Cloud Infrastructure Engineer – AWS (m/w/d), Team IT Infrastructure / IT Operations |
| Ort | **Homeoffice, hybrid oder vollständig remote innerhalb Deutschlands**, Vertragsort vereinbart |
| Sprache | Deutsch |
| Gehalt | keine Bandbreite veröffentlicht; im Gespräch erfragen |
| Fit | 3 |

## Fit-Map

| Anforderung (Inserat) | Nachweis | Urteil |
| :--- | :--- | :--- |
| Mehrjährige Erfahrung Cloud Infrastructure / Systems Engineering | Dreizehn Linux-Hosts deklarativ betrieben, Provisionierung, Rebuild, Rollback | stark |
| Fundierte Linux-Kenntnisse | NixOS, systemd, cgroups/PSI, journald, nftables, tcpdump | stark |
| Netzwerkarchitektur konzipieren und optimieren | WireGuard, Default-Deny, eigene DNS-Zone, MTU-Fehleranalyse, TLS/PKI | stark |
| Monitoring und Überwachung des Infrastrukturzustands | Ledger alle 15 Minuten, Alerting auf Zustand ungleich ok, Log-Analyse | stark, andere Werkzeuge |
| Terraform oder vergleichbares IaC | NixOS-Module und Flake: deklarativ, gepinnt, geprüft — Werkzeug fehlt | Konzept ja, Werkzeug nein |
| AWS-Architektur, CloudWatch | Oracle-Cloud-Hosts, ein Lambda-Projekt; keine AWS-Architektur | **Lücke** |
| Monitoring- und Kostendaten als Reports | Kosten als Entwurfsbedingung; Ledger als Datenquelle für Reports | teilweise |
| Sicherheit gemeinsam mit Spezialistin verbessern | SOPS/age, SSH-CA, kurzlebige Zertifikate, Minimalrechte | stark |
| KI-Infrastruktur mitgestalten | Modelle lokal auf eigener Hardware betrieben, kein Model-Routing im Produktbetrieb | teilweise |

## Zu den Werkzeugen im Auftrag

Der Auftrag nennt "Prometheus/Grafana monitoring" als Hervorhebung. Das ist im Profil **nicht** vorhanden
und steht deshalb auch nicht im Lebenslauf: Monitoring-Praxis ja (Ledger, Alerting, Log-Analyse), die
genannten Werkzeuge nein. Ein Paket, das Prometheus in die Überschrift schreibt, würde im ersten
technischen Gespräch zerfallen.

## Remote

Die Anzeige sagt ausdrücklich: vor Ort, hybrid oder **vollständig remote innerhalb Deutschlands**, mit im
Voraus vereinbartem Vertragsort. Kein Standortkonflikt — der einzige Satz im Paket, der ohne Vorbehalt
stimmt. Fünf Jahre ortsunabhängige Arbeit sind belegt, nicht behauptet.

## Prüfungen

| Prüfung | Ergebnis |
| :--- | :--- |
| `typst compile lebenslauf.typ` | exit 0, keine Warnungen |
| `typst compile anschreiben.typ` | exit 0, keine Warnungen |
| `pdfinfo lebenslauf.pdf` | **2 Seiten** (Budget 2) |
| `pdfinfo anschreiben.pdf` | **1 Seite** (Budget 1) |
| `task checks:prose` | 234 prose files, exit 0 |
| sha256 Lebenslauf | `aa82cc1215b93349296e1d195859205579313b3c526cc5255aa4c4373ec7be81` |
| sha256 Anschreiben | `c8e9546492bb8bbbb308b11001826d974a40b4a6493685d1f94364dc88e7155d` |
| Altlasten | `packet`-Symlink, `resume.json`, `letter.json`, `selection.json` entfernt |

## Nächste Schritte

1. Über den Arbeitnow-Link bewerben, Lebenslauf und Anschreiben anhängen.
2. Bandbreite erfragen — es gibt keine veröffentlichte Zahl.
3. Im Gespräch die AWS-Lücke ansprechen und den Betriebsteil als sofort verfügbaren Beitrag anbieten.
