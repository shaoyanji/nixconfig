# Bewerbung — Fraunhofer LBF Darmstadt, IT-System-Engineer / Network-Engineer

Stand: 22. November 2026
Fit: 2
Sprache: Deutsch
Status: migriert auf native Typst-Quellen, kompiliert und gemessen

## Stelle

| Feld | Wert |
| :--- | :--- |
| Arbeitgeber | Fraunhofer-Institut für Betriebsfestigkeit und Systemzuverlässigkeit LBF |
| Rolle | IT-System-Engineer / Network-Engineer (all genders) |
| Kennziffer | 86030 |
| Ort | Darmstadt |
| Umfang | 39 h/Woche, Teilzeit möglich, **zunächst 2 Jahre befristet** |
| Vergütung | bis TVöD EG 12 |
| Quelle | jobs.fraunhofer.de, Anzeige im Paket (veröffentlicht 20.11.2026) |
| Kontakt | Thorsten Hering, Manuel Matern — +49 6151 705-8514 / -8349 |

## Migration

| Vorher | Nachher |
| :--- | :--- |
| `packet` → `/nix/store/q47d019r1fbfmkjsrpas4cigwji7rcdv-…` (Symlink) | entfernt |
| `selection.json` (444), `resume.json`, `letter.json` | entfernt |
| `lebenslauf.pdf`, `anschreiben.pdf` (444) | durch native Quellen ersetzt, beschreibbar |

## Gemessene Artefakte

| Datei | Seiten | Bytes | Wörter | SHA-256 (gekürzt) |
| :--- | :--- | :--- | :--- | :--- |
| `lebenslauf.pdf` | 2 | 38369 | 554 | `ec4b57cb17a5d9b6` |
| `anschreiben.pdf` | 1 | 24641 | 330 | `780a9bd425956b05` |

## Fit-Map

| Anforderung der Anzeige | Nachweis im Paket | Bewertung |
| :--- | :--- | :--- |
| Netzwerkinfrastruktur betreiben und weiterentwickeln | Linux-Netze über mehrere Standorte, Adressierung und DNS beschrieben | Teilweise |
| Core-/Distribution-Switching Cisco, HPE/Aruba | nicht vorhanden | **Kernlücke** |
| Next-Generation-Firewalls (Palo Alto) | nftables-Regeln als Code | **Kernlücke** |
| LAN / WAN / WLAN / NAC | LAN und Standortkopplung per WireGuard; WLAN und NAC nicht | Teilweise |
| DNS, DHCP, IPAM | DNS vorhanden; DHCP und IPAM nicht belegt | **Teilweise** |
| Netzwerküberwachung und Dokumentation | Ledger mit Zeitstempel, Prüfungen von außen, Dokumentation aus dem Bestand | Stark |
| Maschinenpark vernetzen (Industrie 4.0, IoT) | reproduzierbare Umgebungen, Rückrollung in Minuten, PXE | Stark im Prinzip |
| Beratung der Mitarbeitenden | Nutzende ohne Administratorrolle betreut, Anleitungen geschrieben | Stark |
| Informationssicherheit nach ISO 27001 / TISAX | Sicherheitspraxis vorhanden, Auditierung nicht | **Lücke** |
| Netzwerkautomation (Ansible, GitLab, CI/CD, Python) | CI/CD über Gates, Python und Go; Ansible nicht | **Teilweise** |
| Studium Informatik oder vergleichbar | M.Sc. Renewable Energy Management (fachfremd) | Teilweise |
| CCNA/CCNP, LPIC, ITIL | keine Zertifizierung | **Lücke** |
| Deutsch und Englisch | C1, Muttersprache | Erfüllt |

## Fit-Begründung: 2

Die Anzeige ist eine Enterprise-Netzstelle mit Cisco, Palo Alto und Aruba ClearPass; Linux steht dort nur als Grundkenntnis „von Vorteil". Die Kernkompetenz fehlt vollständig, Zertifizierungen ebenfalls.

Zwei, nicht drei: Eine 3 würde unterstellen, Enterprise-Netztechnik sei austauschbar — in einem Institut mit TISAX-Anforderungen ist sie das nicht. Nicht 1, weil Automatisierung, Überwachung, Dokumentation und der reproduzierbare Umbau genau die Fähigkeiten sind, an denen solche Projekte scheitern.

## Offene Punkte

1. **Cisco, Palo Alto, NAC, 802.1X, IPAM, Ansible, CCNA** als Lücke im Anschreiben benannt, inklusive Bereitschaft zur Zertifizierung.
2. **Befristung 2 Jahre** mit angestrebter Verlängerung.
3. **Studienfach** fachfremd.
4. **Zeugnisse** fehlen.
