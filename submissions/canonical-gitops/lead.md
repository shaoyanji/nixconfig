# Lead: Canonical — Senior Site Reliability / Gitops Engineer

Fit: 4
Stand: 22.11.2026
Ort: Home based - Worldwide; Canonical nennt Remote Deutschland ausdrücklich als möglich
Greenhouse-Req: 5517891
Rolle: Senior SRE / GitOps im Information-Systems-Team
Sprache: Englisch

## Quellenlage

Verzeichnis und Datensatz waren nicht vorhanden; das Paket ist neu. Die Anzeige liegt vollständig über die Greenhouse-API vor (HTTP 200 am 22.11.2026), Titel und Ort bestätigt. Keine Altlasten zu entfernen.

## Warum interessant

Das Information-Systems-Team betreut die Systeme, auf denen Canonical und ein großer Teil der Ubuntu-Nutzerschaft arbeiten — Betrieb als Software, Git als einzige Wahrheit, Änderungen über Pipelines statt über Handarbeit. Genau so ist die eigene Flotte gebaut: ein Flake, ein Modul je Dienst, ein Gate vor dem Rollout, Rollback als Task.

## Was passt

- Git als einzige Wahrheit: Hosts, Dienste und Rollen liegen deklarativ im Repository, keine handgeänderten Zustände.
- CI/CD mit Zähnen: ein Gate prüft Module und Assertions, bevor ausgerollt wird; Build und Rollout teilen denselben evaluierten Zustand.
- Linux-Systemtechnik im Detail: systemd, Netzwerk, nftables, Tailnet, Zertifikate über eigene CA.
- Python und Go für Werkzeuge, die Handarbeit ersetzen: Rollout-Tooling, Ledger, Alarm-Bridge.
- Observability selbst gebaut: Gatus, JSONL-Ledger alle 15 Minuten, Auswertung in Python und Go, Alarmzustellung bestätigt.
- Sicherheit als Teil der Automatisierung: sops/age, eigene SSH-CA, keine öffentlichen Listener.
- Open Source als Arbeitsgrundlage: NixOS, Gatus, restic, sops, Tailscale; öffentliches Repository.
- Englisch Muttersprache, Deutsch C1, US-Staatsangehörigkeit mit Niederlassungserlaubnis, remote aus Deutschland.

## Was fehlt

- **Kubernetes und ArgoCD** — nicht betrieben; die Anzeige nennt Kubernetes.
- **Fleet-Größe** — 13 Hosts statt Flotten in Millionen-Höhe.
- **Upstream-Maintainer-Rolle** in einem großen Projekt.
- **Corporate-IT-Flottenmanagement** über viele Standorte und Nutzergruppen.

## Weg

Greenhouse-Bewerbung über Req 5517891, englischsprachig.

## Gehalt

Keine Zahl im Anschreiben; die Anzeige nennt keine.

## Fit-Begründung: 4 von 5

Vier, wie vorgegeben. Die Arbeitsweise ist die gesuchte: Git als Quelle der Wahrheit, Automatisierung vor Prozedur, Prüfung vor dem Rollout, selbst gebaute Beobachtbarkeit. Dazu die Selbstständigkeit, die eine global verteilte Firma verlangt.

Nicht 5, weil Kubernetes und ArgoCD fehlen und die Flottengröße um Größenordnungen kleiner ist als die Systeme, die das IS-Team betreut.
