# shopware AG — Cloud Infrastructure Engineer – AWS (m/w/d)

Gefunden im Scouting-Lauf vom 2026-11-22 (Arbeitnow API, 3.545 Anzeigen, Titel- und Ortsfilter).
Stand: Paket fertig, **nichts eingereicht**.

| Feld | Wert |
| :--- | :--- |
| Role ID | `shopware-cloud-infra` |
| Arbeitgeber | shopware AG, Schöppingen (~450 Mitarbeitende) |
| Team | IT Infrastructure im Bereich IT Operations, interne IT |
| Ort | **Homeoffice, hybrid oder vollständig remote innerhalb Deutschlands** (Vertragsort wird vereinbart) |
| Quelle | Arbeitnow-Inserat `150808`, abgerufen 2026-11-22 |
| Gehalt | **keine Bandbreite veröffentlicht**; im Gespräch erfragen |
| Fit | 3 |

## Warum diese Stelle

Die Ausschreibung ist eine Linux-Stelle mit AWS-Anteil, keine AWS-Stelle mit Linux-Nebensatz: stabiler
Betrieb, Automatisierung und Weiterentwicklung der AWS-Umgebungen und **Netzwerkarchitektur**,
Monitoring und Kostenreporting, Sicherheit gemeinsam mit einer Spezialistin. Das entspricht dem
tatsächlichen Profil näher als jede Kubernetes-Plattformstelle im Lauf, und "vollständig remote
innerhalb Deutschlands" ist der einzige angebotene Rahmen, der 700 km Entfernung ohne Umzug löst.

## Fit-Map

| Anforderung (Inserat) | Nachweis | Urteil |
| :--- | :--- | :--- |
| Mehrjährige Erfahrung Cloud Infrastructure / Systems Engineering | Dreizehn Linux-Hosts deklarativ betrieben, Provisionierung, Rebuild, Rollback | stark |
| Fundierte Linux-Kenntnisse | NixOS, systemd, cgroups/PSI, journald, nftables, tcpdump | stark |
| Netzwerk- und Infrastruktursysteme verstehen und weiterentwickeln | WireGuard, Default-Deny, eigene DNS-Zone, MTU-Fehleranalyse | stark |
| Monitoring und Überwachung des Infrastrukturzustands | Sentinel-Ledger alle 15 min, Alerting auf Zustand ≠ ok, gatus | stark, andere Werkzeuge |
| Terraform / vergleichbares IaC | **NixOS-Module und Flake statt Terraform**; deklarativ, geprüft, versioniert | Konzept ja, Werkzeug nein |
| AWS-Architektur, CloudWatch | Oracle-Cloud-Hosts, ein Lambda-Projekt; **keine AWS-Architektur, kein CloudWatch** | **Lücke** |
| Monitoring- und Kostendaten als Reports | Kosten als Entwurfsbedingung (ARM, MicroVMs, Build-Cache); Ledger als Datenquelle | teilweise |
| Sicherheit der Systeme verbessern | SOPS/age, SSH-CA, kurzlebige Zertifikate, Minimalrechte | stark |
| KI-Infrastruktur mitgestalten | Modelle lokal auf eigener Hardware betrieben, kein Model-Routing im Produktbetrieb | teilweise |

## Zwei ehrliche Absagen im Anschreiben

Terraform ist nicht vorhanden, AWS nicht als Architektur, CloudWatch nicht aus dem Betrieb. Das steht
im vierten Absatz, bevor es im Gespräch kommt — mit dem Anknüpfungspunkt, den das Inserat selbst
anbietet ("Terraform oder ein vergleichbares IaC-Tool").

## Gehalt

Keine Zahl im Inserat, also keine Zahl im Anschreiben; der Brief bittet um die Bandbreite der Rolle.
Für die Verhandlung: Marktwert für Cloud Infrastructure Engineer mit AWS-Anteil in Deutschland liegt
grob bei 65.000 – 80.000; ohne AWS-Betriebserfahrung ist das obere Drittel nicht belegbar.

## Prüfungen

| Prüfung | Ergebnis |
| :--- | :--- |
| `pdfinfo lebenslauf.pdf` | **2 Seiten** (Budget 2) |
| `pdfinfo anschreiben.pdf` | **1 Seite** (Budget 1) |
| `task checks:prose` | 220 prose files, exit 0 |
| selection | 6/25 highlights, 4/8 projects |
| sha256 Lebenslauf | `6cf61fc8ab7104f533cbb42821c8768b27d32457f474b85794ef1e6bae8e848b` |
| sha256 Anschreiben | `729e6b7c2cf0c7226213196da8e22614f0d9a0c594bba6e95487448e94cf79ca` |

## Zweite Stelle im Lauf

`submissions/truetalent-freiburg-sysadmin/` — Senior System Administrator, **vor Ort Freiburg**
(~20 km), Proxmox/Kubernetes/Ceph, ISO 27001/C5. Nur Lead, kein Paket: Der Vermittler nennt den
Arbeitgeber nicht, das Gehalt nicht, und Windows/M365/Azure sind Pflicht. Erst klären, dann bauen.

## Nächste Schritte

1. Über den Arbeitnow-Link bewerben; Lebenslauf und Anschreiben anhängen.
2. Bandbreite erfragen — es gibt keine veröffentlichte Zahl.
3. Beim Vermittler in Freiburg Anruf statt Paket: Arbeitgeber, Band, Windows-Anteil.
