# Bewerbung — MPCDF, Linux Systems Administrator

Stand: 22. November 2026
Fit: 4
Sprache: Deutsch
Status: migriert auf native Typst-Quellen, kompiliert und gemessen

## Stelle

| Feld | Wert |
| :--- | :--- |
| Arbeitgeber | Max Planck Computing and Data Facility (MPCDF) |
| Rolle | Linux Systems Administrator (m/w/d) |
| Ort | Garching bei München |
| Umfeld | Hochleistungsrechnen und wissenschaftliche Datenverarbeitung |
| Quelle | Anzeige liegt im Paket |
| Weg | https://www.mpg.de/26871563/linux-system-administrator-in-m-w-d |

## Migration

| Vorher | Nachher |
| :--- | :--- |
| Legacy-Symlink (sofern vorhanden) | entfernt, keiner mehr auffindbar |
| JSON-Derivate | entfernt |
| `lebenslauf.pdf`, `anschreiben.pdf` (444) | durch native Quellen ersetzt, beschreibbar |

## Gemessene Artefakte

| Datei | Seiten | Bytes | Wörter | SHA-256 (gekürzt) |
| :--- | :--- | :--- | :--- | :--- |
| `lebenslauf.pdf` | 2 | 37813 | 556 | `98c9746acdc98c57` |
| `anschreiben.pdf` | 1 | 23513 | 299 | `d9bf5cd68e2ac7d5` |

## Fit-Map

| Anforderung | Nachweis im Paket | Bewertung |
| :--- | :--- | :--- |
| Linux-Knoten betreiben und wiederherstellen | 13 Hosts, drei Hardware-Generationen, fünf Jahre allein | Stark |
| Reproduzierbare Knoten-Auslieferung | Beschreibung als Quelle, PXE, Gate, Rückrollung in Minuten | **Stärkster Nachweis** |
| Ressourcen messen und begrenzen | cgroups, Namespaces, PSI, Speicherdruck als Messgrößen erster Ordnung | Stark |
| Telemetrie und Störungserkennung | Ledger alle 15 Minuten, Prüfungen von außen, Alarmbrücke mit Zustellbestätigung | Stark |
| Messdisziplin, nachvollziehbare Daten | Fraunhofer ISE 2012: Messaufbau, Auswertung in Python, Ablage | **Stark** |
| Ingenieurmethodik | B.Sc. Colorado School of Mines, Mess- und Versuchstechnik | Stark |
| Slurm, Lustre, parallele Dateisysteme | nicht vorhanden | **Lücke** |
| InfiniBand, Fabric-Management | nicht vorhanden | **Lücke** |
| RHEL im Clusterbetrieb, Puppet/Ansible | nicht vorhanden | **Lücke** |
| GPU- und CUDA-Betrieb | nicht vorhanden | **Lücke** |
| Deutsch, Englisch | C1, Muttersprache | Erfüllt |

## Fit-Begründung: 4

Die Stelle verlangt Knoten in großer Zahl, reproduzierbar aufgesetzt, mit Messgrößen überwacht — und genau das ist fünf Jahre lang allein gemacht worden, wenn auch in kleinerem Maßstab und ohne Cluster-Scheduler.

Vier, weil die Anzeige keinen Cluster-Scheduler voraussetzt und Knotenbetrieb hier direkt belegt ist.

## Offene Punkte

1. **Slurm, Lustre, InfiniBand, RHEL, GPU-Betrieb** als Lücke im Anschreiben benannt.
2. **Maßstab** — dreizehn Knoten sind kein Rechenzentrum; die Methode überträgt sich, die Zahl nicht.
3. **Zeugnisse** fehlen.
4. Umzug nach Garching als Bereitschaft genannt.
