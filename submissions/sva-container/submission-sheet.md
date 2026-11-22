# SVA System Vertrieb Alexander — DevOps Engineer, Container und Cloud (j456)

Inserat `j456`, Standort **Freiburg, Schnewlinstraße 12** (~25 km von Gutach). Quellen sind jetzt native
Typst-Dateien; JSON-Build und `packet`-Symlink entfernt. Stand: Paket fertig, **nichts eingereicht**.

| Feld | Wert |
| :--- | :--- |
| Role ID | `sva-devops-engineer-container-und-cloud` (Verzeichnis `sva-container`) |
| Arbeitgeber | SVA System Vertrieb Alexander GmbH, Freiburg im Breisgau |
| Rolle | DevOps Engineer — Container und Cloud (m/w/d), j456 |
| Ort | Freiburg, Schnewlinstraße 12 — **rund 25 km** |
| Sprache | Deutsch |
| Gehalt | **85.000 € brutto p. a.**, als Vorstellung im Anschreiben genannt |
| Fit | 3 (DB-Eintrag 4 wie beauftragt) |

## Fit-Map

| Anforderung (Rolle) | Nachweis | Urteil |
| :--- | :--- | :--- |
| Linux-Systembetrieb | Dreizehn Hosts deklarativ, Gates, Rollback, Rebuild | stark |
| Infrastruktur-Automatisierung / IaC | Deklarierter Zustand, gepinnte Inputs, Task-Oberfläche | stark |
| CI/CD-Pipelines | Modul-Gate identisch in CI und Host, kein Rollout ohne Check | stark, ohne Pipeline-Aufbau |
| Kubernetes / OpenShift | **nicht produktiv administriert** | **Lücke** |
| Container-Plattformen | Container nur als gepinnte Bauumgebungen; MicroVMs | **Lücke** |
| Netzwerk und Härtung | nftables Default-Deny, WireGuard, CA, SOPS/age | stark |
| Monitoring und Fehlersuche | Ledger alle 15 Minuten, journald, cgroups, tcpdump | stark |
| Kundengespräch, Projekte vor Ort | Beratung bei Smart Energy 360; Betrieb für Tochtergesellschaften | vorhanden |
| Präsenz Freiburg | 25 km, zugesagt | **stark** |

## Zu den Hervorhebungen im Auftrag

Der Auftrag nennt "enterprise container platforms (Kubernetes/OpenShift)". Der Lebenslauf enthält bewusst
**keine** K8s-Zeile und keinen OpenShift-Satz: beides ist nicht vorhanden. Das Anschreiben behandelt es im
vierten Absatz als die eine Frage, an der die Bewerbung hängt, und bietet den Unterbau an — Linux,
Automatisierung, Netzwerk, Gates, Kundenverantwortung.

## Gehalt

Der Auftrag nennt **85.000 € p. a.**; die Zahl steht als Vorstellung im Anschreiben, weil sie vom Auftrag
kommt und nicht aus der Anzeige. SVA veröffentlicht in `j456` keine Bandbreite — im Gespräch ist die Zahl
deshalb eine Verhandlungsposition, keine Messlatte.

## Prüfungen

| Prüfung | Ergebnis |
| :--- | :--- |
| `typst compile lebenslauf.typ` | exit 0, keine Warnungen |
| `typst compile anschreiben.typ` | exit 0, keine Warnungen |
| `pdfinfo lebenslauf.pdf` | **2 Seiten** (Budget 2) |
| `pdfinfo anschreiben.pdf` | **1 Seite** (Budget 1) |
| `task checks:prose` | 235 prose files, exit 0 |
| sha256 Lebenslauf | `4011f41188c6a6c65058462e76f089b5fb6eb58fc8e9e1a6f24ecf0b67df045e` |
| sha256 Anschreiben | `7b661a60a7243c6babda22736b9110b9c311d59b1e300b89d73cbd3c3d2fd3a4` |
| Altlasten | `packet`-Symlink, JSON-Quellen entfernt |

## Nächste Schritte

1. Über den SVA-Link mit Kennung **j456** bewerben; Anschreiben und Lebenslauf anhängen.
2. Im Erstgespräch klären, wie viel der Rolle Kubernetes/OpenShift-Betrieb ist und wie viel Linux-Plattform
   darunter — davon hängt ab, ob die Bewerbung realistisch ist.
3. Die 85.000 € als Vorstellung verteidigen, aber an der Aufgabe argumentieren, nicht an Marktzahlen.
