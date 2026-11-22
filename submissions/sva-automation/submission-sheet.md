# SVA System Vertrieb Alexander — DevOps Consultant Infrastructure Automation (m/w/d)

Native Typst-Quellen, `packet`-Symlink und JSON entfernt. Status: gebaut und geprüft, **nichts eingereicht**.

| Feld | Wert |
| :--- | :--- |
| Role ID | `sva-automation` |
| Arbeitgeber | SVA System Vertrieb Alexander GmbH |
| Rolle | DevOps Consultant Infrastructure Automation (m/w/d) |
| Standort | Freiburg, Schnewlinstraße 12 (gewählt) — rund 25 km |
| Sprache | Deutsch |
| Gehalt | keine Zahl im Brief — keine Bandbreite im Auftrag genannt |
| Fit | 3 (DB-Eintrag 4) |

## Fit-Map

| Anforderung | Nachweis | Urteil |
| :--- | :--- | :--- |
| Infrastrukturautomatisierung | Go, Python, Bash, Nix hinter einer Task-Oberfläche | stark |
| Deklarative Systeme | Flake mit gepinnten Inputs, Rebuild als Pfad | stark |
| Linux-Engineering | systemd, journald, cgroups/PSI, nftables, tcpdump | stark |
| Wartbarkeit der Automatisierung | kleine Werkzeuge mit klarer Schnittstelle, Hilfetexte | stark |
| Kundenkommunikation / Beratung | Smart Energy 360, IT-Verantwortung mit Tochtergesellschaften | vorhanden |
| Terraform / Ansible | **nicht produktiv** | **Lücke** |
| Kubernetes / Plattformprodukte | **nicht administriert** | **Lücke** |
| Herstellerzertifizierungen | **keine** | **Lücke** |
| Deutsch C1 | Unterlagen durchgehend deutsch | erfüllt |

## Drei SVA-Bewerbungen: Reihenfolge

Dies ist das **dritte** Paket für dasselbe Systemhaus in diesem Repo:

- `sva-linux` — DevOps Engineer / Consultant Linux, **j734** (Freiburg, ~25 km)
- `sva-container` — DevOps Engineer Container und Cloud, **j456** (Freiburg, ~25 km)
- `sva-automation` — DevOps Consultant Infrastructure Automation, dieses Paket

Drei Bewerbungen bei einem Arbeitgeber sind zulässig, aber nur in einer Reihenfolge sinnvoll, die den
Arbeitgeber nicht raten lässt. Empfehlung: **zuerst j734** (die passgenaueste Rolle, Linux ohne Cluster-Zwang),
dann **dieses Paket** zwei bis drei Tage später mit einem Satz Bezug, und **j456** zuletzt — es ist die Rolle
mit den größten Lücken. Wer alle drei am selben Tag schickt, wirkt nicht interessiert, sondern gestreut.

## Was das Paket trägt

Der Brief argumentiert Automatisierung als **Übergabefähigkeit**, nicht als Werkzeugliste: Der Kunde muss die
Automatisierung danach selbst betreiben können, sonst ist sie nur eine andere Form von Abhängigkeit. Dazu die
Sätze, die im Consulting zählen — kleine Werkzeuge mit klarer Schnittstelle, Hilfetexte, Runbooks,
Entscheidungen mit Begründung.

Die Lücken sind ehrlich benannt: keine Herstellerzertifizierungen, kein produktives Terraform/Ansible, keine
Kubernetes-Praxis, keine Erfahrung mit den SVA-Plattformprodukten.

## Prüfungen

| Prüfung | Ergebnis |
| :--- | :--- |
| `packet`-Symlink, JSON | entfernt |
| `chmod u+w *.pdf` | ausgeführt |
| `typst compile lebenslauf.typ` | exit 0, keine Warnungen |
| `typst compile anschreiben.typ` | exit 0, keine Warnungen |
| `pdfinfo lebenslauf.pdf` | **2 Seiten** |
| `pdfinfo anschreiben.pdf` | **1 Seite** |
| Marker | `Automatisierung`, `Schnewlinstraße`, `Freiburg`, `Niederlassungserlaubnis` |
| `task checks:prose` | 241 prose files, exit 0 |
| sha256 Lebenslauf | `89f42e6aed47d4dca1e9a778866f0decbee8ff5bfdec4a52531ffe1716f8b43f` |
| sha256 Anschreiben | `c2c1ea0ed14efea0ebf6dd68b8338fd192039c4b4450932e489f0fc1ad5c518d` |

## Nächste Schritte

1. Reihenfolge einhalten: j734 zuerst, dann dieses Paket, dann j456.
2. Im Anschreiben an die Geschäftsstelle Freiburg adressieren (bereits so gesetzt).
3. Im Gespräch klären, welche Automatisierungswerkzeuge SVA im Kundenprojekt tatsächlich einsetzt — davon hängt
   der Einarbeitungsaufwand ab.
