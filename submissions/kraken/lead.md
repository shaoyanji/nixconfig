# Lead: Kraken — Infrastructure / DevOps Engineer

Fit: 4
Stand: 22.11.2026
Ort: nicht aus einer Anzeige bestätigt; Lever-Board `kraken` liefert keine offenen Stellen
Sprache: Englisch
Quellenlage: **kein Anzeigentext abrufbar**

## Quellenlage

Die Lever-API für `kraken` antwortet mit HTTP 200 und einem leeren Array (2 Bytes); auf jobs.lever.co/kraken sind keine offenen Stellen sichtbar. Das Paket stützt sich deshalb auf die Aufgabenbeschreibung aus dem Auftrag: 24/7-Betrieb von Bare-Metal-Linux, strikte Minimalrechte mit kurzlebigen CA-Zertifikaten, sops-verschlüsselte Secrets, Telemetrie mit geschlossenem Kreis und automatisierte Wiederherstellung nach Störungen. Vor dem Absenden muss die Requisition bestätigt werden.

## Warum interessant

Die vier genannten Punkte sind genau die, die auf der eigenen Flotte gebaut wurden — nicht als Projekt, sondern als Betriebsnotwendigkeit: kurzlebige Zertifikate aus eigener CA, Secrets je Host mit sops, ein Ledger alle 15 Minuten mit Zustellbestätigung, Rückrollung als Task. Dazu Bare Metal über drei Hardware-Generationen, ohne Cloud-Ausweichmöglichkeit.

## Was passt

- Bare-Metal-Betrieb: dreizehn Hosts, drei Hardware-Generationen, Beschaffung bis Außerbetriebnahme.
- Least Privilege: eigene SSH-CA, kurzlebige Zertifikate statt verteilter Schlüssel.
- Secrets: sops/age je Host, verschlüsselt im Repository, Schlüssel getrennt.
- Netzgrenze: WireGuard-Mesh ohne öffentlichen Listener, nftables-Regeln am Rand.
- Telemetrie: Ledger alle 15 Minuten, Gatus-Prüfungen, Alarmzustellung mit Bestätigung.
- Incident-Resilienz: Rückrollung über Generationen, geprüfte Wiederherstellungen, Runbooks.
- Werkzeuge in Python und Go, Git als einzige Quelle.
- Englisch Muttersprache, Deutsch C1, Niederlassungserlaubnis.

## Was fehlt

- **Kubernetes und Cloud-Infrastruktur** — nicht betrieben.
- **Unternehmensweite Rufbereitschaft** — Betrieb mit einer Person, nicht mit einer Rotation.
- **Krypto- und Exchange-Domäne** — keine Erfahrung mit Handels- oder Finanzinfrastruktur.
- **Formales Incident Command** — Wiederherstellung geübt, aber nicht nach Verfahrensrahmen.
- **Größenordnung** — 13 Hosts statt Flotten mit vielen hundert Maschinen.

## Weg

Bewerbung über das Lever-Board, sobald eine passende Requisition sichtbar ist. Derzeit keine offene Stelle auffindbar.

## Gehalt

Keine Zahl im Anschreiben; keine Anzeige, also keine Bandbreite.

## Fit-Begründung: 4 von 5

Vier, wie vorgegeben. Die vier Kernpunkte des Auftrags sind belegte Praxis: Bare Metal, kurzlebige Zertifikate, sops-Secrets, geschlossene Telemetrie und Rückrollung.

Nicht 5, weil die Skalierung und die Rufbereitschaft fehlen und die Domäne neu ist. Vier heißt: Gespräch plausibel, sobald die Stelle bestätigt ist.
