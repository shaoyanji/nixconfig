# SVA System Vertrieb Alexander — DevOps Engineer / Consultant Linux (m/w/d), j734

Formular `f734`, **Geschäftsstelle Freiburg**, Schnewlinstraße 12. Native Typst-Quellen, `packet`-Symlink und
JSON entfernt. Stand: Paket fertig, **nichts eingereicht**. **[eingereicht laut Apps-DB `sva-devops-consultant-linux` — Stand dieses Blatts liegt vor der Einreichung]**

| Feld | Wert |
| :--- | :--- |
| Role ID | `sva-devops-consultant-linux` (Verzeichnis `sva-linux`) |
| Arbeitgeber | SVA System Vertrieb Alexander GmbH, HQ Wiesbaden |
| Rolle | DevOps Engineer / Consultant Linux (m/w/d) |
| Kennung / Formular | **j734** / f734 |
| Standort | **Freiburg**, Schnewlinstraße 12 — rund 25 km |
| Gehalt | **85.000 € brutto p. a.**, im Anschreiben genannt |
| Sprache | Deutsch |
| Fit | 4 (DB-Eintrag 5 wie beauftragt) |

## Fit-Map

| Anforderung | Nachweis | Urteil |
| :--- | :--- | :--- |
| Enterprise Linux administrieren | Dreizehn Hosts, Updates, Patches, Rebuild, Außerbetriebnahme | stark |
| Deklarative Automatisierung | Flake mit gepinnten Inputs, Rebuild als Pfad | stark |
| Telemetrie / Monitoring | Ledger alle 15 Minuten, PSI, cgroups, Alerting | stark |
| Netzwerk und Sicherheit | nftables Default-Deny, WireGuard, CA, SOPS/age | stark |
| Kundenorientierte Lieferung | Beratung bei Smart Energy 360, IT-Verantwortung mit Tochtergesellschaften | vorhanden |
| Herstellerzertifizierungen (RH etc.) | **keine** | **Lücke** |
| Kubernetes / OpenShift | **nicht produktiv administriert** | **Lücke** |
| Präsenz Freiburg | 25 km, ausdrücklich zugesagt | **stark** |
| Deutsch C1 | Unterlagen und Brief in C1 | erfüllt |

## Zwei SVA-Bewerbungen: Reihenfolge beachten

In diesem Repo liegt bereits ein Paket für **j456** (`submissions/sva-container/`, DevOps Engineer Container
und Cloud, dieselbe Geschäftsstelle Freiburg). Beide Anzeigen laufen über dasselbe Portal und dieselbe
Formularfamilie. Zwei Bewerbungen auf zwei Stellen desselben Hauses sind zulässig, aber sie sollten nicht
am selben Tag eintreffen, und der Bezug sollte offen sein: Wer sich auf zwei Rollen bewirbt, ohne das zu
sagen, wirkt unentschieden; wer es sagt, wirkt interessiert.

**Empfohlene Reihenfolge:** zuerst `j734` (diese Stelle — Linux und Automatisierung ohne Cluster-Betrieb,
also die passgenauere Bewerbung), zwei bis drei Tage später `j456` mit einem Satz Bezug.

## Gehalt

**85.000 € brutto p. a.** aus dem Auftrag, im Brief als Vorstellung genannt. SVA veröffentlicht in `j734`
keine Bandbreite; die Zahl ist damit eine Verhandlungsposition, keine Messlatte.

## Prüfungen

| Prüfung | Ergebnis |
| :--- | :--- |
| `packet`-Symlink, JSON | entfernt |
| `chmod u+w *.pdf` vor dem Bau | ausgeführt |
| `typst compile lebenslauf.typ` | exit 0, keine Warnungen |
| `typst compile anschreiben.typ` | exit 0, keine Warnungen |
| `pdfinfo lebenslauf.pdf` | **2 Seiten** |
| `pdfinfo anschreiben.pdf` | **1 Seite** |
| Marker | `j734`, `Schnewlinstraße`, `85.000`, `Freiburg`, `Niederlassungserlaubnis`; CV: `Telemetrie`, `Freiburger Geschäftsstelle`, `Kundenprojekte` |
| `task checks:prose` | 241 prose files, exit 0 |
| sha256 Lebenslauf | `0c52291b60ce9f8932372371883d554692a2a4a71530ca54bd412bb6b152a7e7` |
| sha256 Anschreiben | `6ce6434f4137ceaefa860850f5ec49c4a6c31d3e73f5875c71a6e9754dd7faf5` |

## Nächste Schritte

1. Über das SVA-Portal mit **j734 / f734** bewerben, Geschäftsstelle Freiburg wählen.
2. Zwei bis drei Tage später `j456` (`sva-container`) mit einem Satz Bezug nachreichen.
3. Im Gespräch klären, ob Zertifizierungen im ersten Jahr vorgesehen sind — bei einem Systemhaus üblich.
