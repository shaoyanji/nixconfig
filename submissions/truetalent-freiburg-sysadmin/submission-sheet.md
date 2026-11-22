# True Talent Solutions Partners — Senior System Administrator, Freiburg im Breisgau

Arbeitnow-Inserat `343319`, Vermittler für ein nicht genanntes SaaS-Unternehmen. Native Typst-Quellen,
kein JSON-Build. Stand: Paket fertig, **nichts eingereicht**.

| Feld | Wert |
| :--- | :--- |
| Role ID | `truetalent-freiburg-sysadmin` |
| Arbeitgeber | True Talent Solutions Partners (Kunde: SaaS-Unternehmen, Name nicht genannt) |
| Rolle | Senior System Administrator |
| Ort | **Freiburg im Breisgau, vor Ort** — rund 20 km von Gutach, ~25 Minuten Arbeitsweg |
| Sprache | Deutsch C1, Englisch B2 |
| Gehalt | keine Bandbreite genannt; im Gespräch erfragen |
| Fit | 3 (DB-Eintrag 3) |

## Fit-Map

| Anforderung (Inserat) | Nachweis | Urteil |
| :--- | :--- | :--- |
| Server, Netzwerk, Storage über Windows und Linux administrieren | Linux stark; **Windows nicht betreut** | halb |
| Produktionserfahrung Virtualisierung, insbesondere **Proxmox** | MicroVMs, systemd-Slices, PXE-Provisionierung; **kein Proxmox** | **Lücke** |
| Kubernetes, Ceph, Netzwerk | K8s nicht betrieben; **kein Ceph** | **Lücke** |
| Serveradministration, Netzwerk, IT-Sicherheit | WireGuard, nftables Default-Deny, DNS, TLS/CA, Minimalrechte | stark |
| Microsoft 365 und Azure in hybriden Umgebungen | **nicht vorhanden** | **Lücke** |
| ISO 27001 / C5-Projekte | Praktiken vorhanden (Patch-Tests, Doku, Rechte), Zertifizierung nicht begleitet | teilweise |
| Deutsch C1, Englisch B2 | Anschreiben und Unterlagen auf Deutsch | stark |
| Vor-Ort-Präsenz | 20 km Entfernung, ausdrücklich zugesagt | **stark** |

## Ehrliche Einordnung

Der Standort ist der Grund, dieses Paket zu bauen: 20 Kilometer, keine Umzugsdebatte, keine
Hybrid-Verhandlung. Fachlich ist die Stelle jedoch breiter als das Profil — Windows, Microsoft 365, Azure,
Proxmox und Ceph sind vier bis fünf Baustellen, von denen keine im Lebenslauf steht. Fit **3** trägt der
Standort plus Linux-Betrieb und Sicherheitspraxis; die Zertifizierungs- und Virtualisierungsanteile fehlen.

Der Vermittler nennt weder Arbeitgeber noch Gehaltsband. Vor einem echten Aufwand (Gespräche, Aufgabe)
sollte beides geklärt sein — sonst bewirbt man sich auf eine Rolle, deren Rahmen man nicht kennt.

## Warum nicht behauptet wird, was nicht da ist

Der Auftrag nennt "Proxmox virtualization, Ceph storage clusters, ISO 27001/C5 security compliance" als
Hervorhebungen. Alle drei sind im Profil nicht vorhanden und stehen deshalb als Lücke im Anschreiben. Was
stattdessen belegt ist: Bare-Metal-Betrieb, deklarierte Systeme, Netzwerk und Härtung, Monitoring, sowie
die Praktiken hinter einem Compliance-Rahmen (Patch-Tests vor Rollout, prüfbare Dokumentation,
Minimalrechte).

## Prüfungen

| Prüfung | Ergebnis |
| :--- | :--- |
| `typst compile lebenslauf.typ` | exit 0, keine Warnungen |
| `typst compile anschreiben.typ` | exit 0, keine Warnungen |
| `pdfinfo lebenslauf.pdf` | **2 Seiten** (Budget 2) |
| `pdfinfo anschreiben.pdf` | **1 Seite** (Budget 1) |
| `task checks:prose` | 235 prose files, exit 0 |
| sha256 Lebenslauf | `a55d2ec5e1630cc9cd5616faaf2a4749a1583c7d3ff099440cb658add7f7a762` |
| sha256 Anschreiben | `df017fd3b1e8dfff4a9bc7531b49beb43f0e85e58b9b038809a6629afaa90ac6` |

## Nächste Schritte

1. Beim Vermittler Arbeitgeber, Band und den Windows-Anteil erfragen — erst dann Aufwand investieren.
2. Falls die Antwort passt: über den Arbeitnow-Link bewerben, Anschreiben und Lebenslauf anhängen.
3. Im Gespräch die Proxmox-/Ceph-Lücke offen ansprechen und den Betriebsteil als sofort verfügbaren
   Beitrag anbieten.
