# Bewerbung — Mittwald, DevOps Engineer Linux Hosting Platform

Stand: 22. November 2026
Fit: 3
Sprache: Deutsch
Status: migriert auf native Typst-Quellen, kompiliert und gemessen

## Stelle

| Feld | Wert |
| :--- | :--- |
| Arbeitgeber | Mittwald CM Service GmbH & Co. KG |
| Rolle | DevOps Engineer (m/w/d) — Linux Hosting Platform |
| Umfeld | Linux-Web- und Cloud-Hosting |
| Quelle | Anzeige liegt im Paket |
| Weg | https://www.arbeitsagentur.de/jobsuche/jobdetail/17338-f04a2b59e269f0c21e-S |

## Migration

| Vorher | Nachher |
| :--- | :--- |
| `packet` → `/nix/store/zlakw9ayqy5n7w50izg2brza0lx7m9z8-…` (Symlink) | entfernt |
| `selection.json` (444) | entfernt |
| `lebenslauf.pdf`, `anschreiben.pdf` (444) | durch native Quellen ersetzt, beschreibbar |

## Gemessene Artefakte

| Datei | Seiten | Bytes | Wörter | SHA-256 (gekürzt) |
| :--- | :--- | :--- | :--- | :--- |
| `lebenslauf.pdf` | 2 | 37369 | 513 | `6a3682550ea0d44d` |
| `anschreiben.pdf` | 1 | 24659 | 315 | `43c7b04f08ab06c5` |

## Fit-Map

| Anforderung | Nachweis im Paket | Bewertung |
| :--- | :--- | :--- |
| Linux-Server und Plattform betreiben | 13 Hosts, drei Hardware-Generationen, fünf Jahre allein | Stark |
| Reproduzierbare Server-Auslieferung | Beschreibung als Quelle, gepinnte Eingaben, Gate, Rückrollung in Minuten | **Stärkster Nachweis** |
| Netzwerk und Fernzugriff | Adressierung, DNS, WireGuard, nftables, keine öffentliche Verwaltung | Stark |
| Telemetrie und Störungserkennung | Ledger alle 15 Minuten, Prüfungen von außen, Alarmbrücke mit Zustellbestätigung | Stark |
| Sicherung und Wiederherstellung | restic mit durchgeführten Rückspielungen | Stark |
| Sicherheit im Betrieb | eigene CA, kurzlebige Zertifikate, sops/age, minimale Rechte | Stark |
| Automatisierung | Nix, Python, Go, Shell; Aufgaben und Prüfungen als Code | Stark |
| Kubernetes, Docker, Containerplattform | nicht vorhanden | **Lücke** |
| Terraform, Ansible, Cloud-Plattformen | nicht vorhanden | **Lücke** |
| Plesk, große MySQL-/PostgreSQL-Betriebe | nicht vorhanden | **Lücke** |
| Regulierter KRITIS-Betrieb | nicht verantwortet | **Lücke** |
| Deutsch, Englisch | C1, Muttersprache | Erfüllt |

## Fit-Begründung: 3

Der Kern der Stelle ist Betrieb von Servern, die andere nutzen — und zwar reproduzierbar, überwacht und wiederherstellbar. Genau das ist fünf Jahre lang allein gemacht worden.

Keine 4, weil die Anzeige Container-, Automatisierungs- und Cloud-Werkzeuge nennt und nichts davon vorhanden ist. Drei heißt: das Gespräch über Betrieb und Reproduzierbarkeit wird gut, das über den Werkzeugstapel ehrlich kurz.

## Offene Punkte

1. **Kubernetes, Docker, Terraform, Plesk, Datenbankbetrieb** als Lücke im Anschreiben benannt.
2. **KRITIS** nicht vorhanden.
3. **Standort** — Umzug nach Espelkamp oder Münster als Bereitschaft genannt; Anzeige prüfen.
4. **Zeugnisse** fehlen weiterhin.
