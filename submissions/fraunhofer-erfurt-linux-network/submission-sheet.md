# Bewerbung — Fraunhofer IOF Erfurt, Senior Netzwerkspezialist Linux

Stand: 22. November 2026
Fit: 3
Sprache: Deutsch
Status: migriert auf native Typst-Quellen, kompiliert und gemessen

## Stelle

| Feld | Wert |
| :--- | :--- |
| Arbeitgeber | Fraunhofer-Institut für Angewandte Optik und Feinmechanik IOF |
| Einheit | Fraunhofer-Zentrum Erfurt, Abteilung Photonische Quanten Systeme |
| Rolle | Senior Netzwerkspezialist — Schwerpunkt Linux (all genders) |
| Projekt | QUANT-GPlCz, QKD in realen Glasfasernetzen |
| Umfang | 39 h/Woche, Teilzeit möglich, **befristet bis 31.08.2029**, TVöD |
| Quelle | jobs.fraunhofer.de, Anzeige im Paket (veröffentlicht 20.11.2026) |

## Migration

| Vorher | Nachher |
| :--- | :--- |
| `packet` → `/nix/store/rrd6lsv4a1sb7ccsr30w13zg12g2gik6-…` (Symlink) | entfernt |
| `selection.json` (Modus 444) | entfernt |
| `lebenslauf.pdf`, `anschreiben.pdf` (Modus 444) | durch native Quellen ersetzt, beschreibbar |

## Gemessene Artefakte

| Datei | Seiten | Bytes | Wörter | SHA-256 (gekürzt) |
| :--- | :--- | :--- | :--- | :--- |
| `lebenslauf.pdf` | 2 | 38718 | 577 | `6dcfb72e9397ab17` |
| `anschreiben.pdf` | 1 | 24622 | 328 | `b105a36889b0c803` |

## Fit-Map

| Anforderung der Anzeige | Nachweis im Paket | Bewertung |
| :--- | :--- | :--- |
| LAN-Infrastruktur planen, betreiben, dokumentieren | Netze über mehrere Standorte, Adressierung, DNS, Dokumentation aus dem Bestand | Stark, klein skaliert |
| WAN-Infrastruktur | Standortkopplung per WireGuard, kein WAN-Routing | **Teilweise** |
| Firewall-Infrastruktur | nftables-Regeln als Code, keine Appliances | **Teilweise** |
| Linux-Netzwerksysteme administrieren | 13 Hosts, systemd, Namespaces, Boot über Netz | Stark |
| Glasfaser- und Testbed-Weiterentwicklung | reproduzierbare Umgebungen, aber keine Glasfasertechnik | **Lücke Glasfaser** |
| Sicherheitskonzepte mitgestalten | eigene CA, kurzlebige Zertifikate, sops/age, minimale Rechte | Stark |
| 2nd-/3rd-Level-Support, komplexe Störungen | Störungsbearbeitung ohne Eskalationsstufe, Dokumentation | **Teilweise** |
| Steuerung externer Dienstleister | nicht vorhanden | **Lücke** |
| Architekturentscheidungen, Standards | Modulaufbau, Gates, Standards im eigenen Bestand | Teilweise |
| Studium Informatik/Physik/Mathematik oder vergleichbar | M.Sc. Freiburg (fachfremd), langjährige Praxis | Teilweise |
| Deutsch C1, Englisch B2 | C1, Muttersprache | Erfüllt |
| Forschungsumfeld | Fraunhofer ISE 2012, Messaufbau, geteilte Rechner | Stark |

## Fit-Begründung: 3

Die Rolle ist eine Netzwerkstelle mit Linux-Schwerpunkt, und der Netzwerkteil ist der Prüfstein: WAN, Firewall-Appliances, Glasfaser-Testbeds. Der Linux-Teil und der Gedanke des reproduzierbaren Testbeds sind dagegen genau die eigene Stärke, und die Fraunhofer-Erfahrung ist echt.

Keine 4, weil drei der genannten Aufgabenfelder nicht belegt sind. Keine 2, weil Linux-Netze von Grund auf bauen und einen übernehmbaren Betrieb hinterlassen der Kern der Stelle ist.

## Offene Punkte

1. **WAN-Routing, Firewall-Appliances, Glasfaser/QKD, Dienstleistersteuerung** als Lücke im Anschreiben benannt.
2. **Befristung bis 31.08.2029** — im Anschreiben nicht bewertet, im Gespräch zu klären.
3. **Studienfach** fachfremd; die Anzeige nennt Informatik, Physik, Mathematik oder vergleichbar.
4. **Zeugnisse** fehlen.
