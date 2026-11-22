# Lead: Black Forest Labs — Member of Technical Staff - Infrastructure Security

Fit: 5
Stand: 22.11.2026
Ort: Freiburg im Breisgau (Labor) / San Francisco; ausgeschrieben als Remote
Vergütung: 220.000–280.000 USD + Equity (laut Auftrag; auf der abgerufenen Seite nicht sichtbar)
Sprache: Englisch

## Quellenlage

Verzeichnis und Datensatz waren nicht vorhanden; keine `selection.json` und keine alten nix-gebauten PDFs zu entfernen. Die Anzeige liegt vollständig im Paket (HTTP 200 am 22.11.2026). Black Forest Labs: Gründerteam hinter latenter Diffusion und Stable Diffusion, FLUX-Modelle, Labore in Freiburg und San Francisco.

## Warum interessant

Die Anzeige beschreibt genau die Spannung, in der die eigene Arbeit stattgefunden hat: Forschende brauchen großzügigen Zugang zu Compute, Produktion braucht harte Isolation, und beides muss gleichzeitig sicher sein. Wer eine Flotte ohne Sicherheitsteam betrieben hat, hat jeden dieser Kompromisse selbst entscheiden müssen.

Dazu der lokale Punkt: Gutach im Breisgau liegt rund 25 km vom Freiburger Labor entfernt. Das ist keine Bewerbung aus der Ferne.

## Was passt

- Secrets: sops/age mit eigenen Schlüsseln je Host, verschlüsselt im Repository.
- Kurzlebige Zugänge: eigene SSH-CA, Zertifikate statt verteilter Schlüssel.
- Netzgrenze: Tailnet über WireGuard, keine öffentlichen Listener, nftables-Regeln am Rand.
- Workload-Isolation: cgroups und Namespaces, PSI- und Disk-Druck als Messgröße.
- Hermetische Builds: gepinnte Inputs, reproduzierbar, Rollback über Generationen.
- Audit-Spur: Sentinel-Ledger alle 15 Minuten, Runbooks, nachvollziehbare Git-Historie.
- Sicherheit ohne Stillstand: Prüfungen im CI statt Freigabeprozessen.
- Englisch Muttersprache, Deutsch C1, US-Staatsangehörigkeit mit Niederlassungserlaubnis, 25 km zum Labor.

## Was fehlt

- **Sicherheit als Rollentitel** — Sicherheit war Teil des Betriebs, nicht die Hauptaufgabe.
- **AWS- und Kubernetes-Sicherheit** — die Flotte läuft auf eigener Hardware.
- **ML-Trainingsinfrastruktur** — keine GPU-Flotten, keine Forschungs-Compute-Zuteilung.
- **Formale Verfahren** — kein Threat Modeling nach Methode, keine Incident-Response-Übung, kein SOC 2 oder ISO 27001.
- **Code-Review-Sicherheit** — kein Anwendungssicherheits-Review fremder Codebasen.

## Weg

Bewerbung über das arbeitnow-Inserat, englischsprachiger Antrag. Keine Frist genannt.

## Gehalt

Im Anschreiben steht keine Zahl; die Spanne ist im Datenblatt vermerkt.

## Fit-Begründung: 5 von 5

Fünf, wie vorgegeben, und diesmal trägt die Zahl. Die Aufgabe ist Infrastruktur-Sicherheit mit den Händen: Grenzen, Identität, Secrets, Isolation, Audit. Alles davon wurde auf der eigenen Flotte gebaut und betrieben, ohne Sicherheitsteam im Rücken. Dazu 25 km Entfernung zum Freiburger Labor und ein Arbeitsmodell, das remote zulässt.

Die Lücken sind real, aber sie betreffen die Umgebung, nicht die Haltung: AWS, Kubernetes und ML-Compute statt eigener Hardware, und formale Verfahren statt gelebter Praxis. Wer eine Flotte allein absichert, bringt die Denkweise mit, die eine Sicherheitsrolle braucht; die Werkzeuge der Umgebung kommen dazu.
