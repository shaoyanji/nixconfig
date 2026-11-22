# Biz Factory GmbH — Systemadministrator / DevOps Engineer (Linux- und Kubernetes-basierte OSS-Infrastrukturen)

Berlin oder 100 % remote · keine Gehaltsangabe in der Anzeige · Posting arbeitnow 183922 · Ansprechpartner Robin.

**Laut App-DB: beworben** (JOIN-Bestätigung 310957, 2026-11-21, deutsche Unterlagen, Deutsch „verhandlungssicher", 84.000 EUR).
Der vorherige Stand dieses Sheets sagte „vorbereitet, nicht abgeschickt"; die DB-Zeile ist der spätere Stand.

Native Typst-Fassung, 2026-11-22 — Typst 0.15.1, nur DejaVu Sans.

## Dateien

| Datei | Seiten | Wörter | Warnungen | sha256 (erste 16) |
| :--- | :--- | :--- | :--- | :--- |
| `lebenslauf.pdf` | 2 | 912 | 0 | `8e321bc40757b7e0` |
| `anschreiben.pdf` | 1 | 334 | 0 | `8fc3c051a9ddc47f` |

`lebenslauf.typ`, `anschreiben.typ`, `job-description.txt`, dieses Sheet. `selection.json` in diesem Durchgang entfernt.

## Was sich geändert hat

Die alten PDFs kamen aus dem Datenbank-Build: 2 Seiten mit 668 Wörtern, dazu die übliche nicht belegte Werkzeugliste. Der Lebenslauf
beginnt jetzt mit dem Betrieb, um den es in der Anzeige geht — Flake über dreizehn Hosts, systemd-Units mit geschriebenem
Fehlerverhalten, sops hinter eigener CA, Rollback als Zeiger, gemeinsamer Binary-Cache, ein Gate für CI und Maschine — und nennt
PostgreSQL mit Migrationen und geprüftem Wiederherstellungsweg, das Mail-Archiv und das idempotente Ledger. Der Helpdesk-Teil der
Anzeige (Runbook, Doku, Schulung, Ticket nicht zweimal) steht als eigener Absatz im Profil, weil er hier wirklich zählt.

Eingereichte Bytes zum Nachweis: `lebenslauf.pdf` `9a646d01152f3e42…` (2 Seiten, 668 Wörter), `anschreiben.pdf` `0ef3996b6f0b9cf4…`
(1 Seite, 330 Wörter).

## Ehrliche Lücken — im Anschreiben genannt, nicht im Lebenslauf behauptet

| Anforderung | Stand |
| :--- | :--- |
| SLES / RHEL / Debian | Debian-nahe NixOS-Praxis, kein SLES-/RHEL-Betrieb als eigene Verantwortung |
| Kubernetes, OpenShift, OpenStack | Container als Build-Umgebung und MicroVM-Gäste mit Canary; kein Produktivcluster |
| GitLab CI/CD | eigenes Gate in CI und auf den Maschinen, GitLab nicht geführt |
| Icinga / Nagios | eigenes Ledger plus Gatus, Konzepte ja, Werkzeuge nein |
| MySQL / PostGIS | PostgreSQL im Betrieb; MySQL und PostGIS nicht |
| LDAP / Active Directory | nicht geführt |
| Python | vorhanden; Java, PHP, TypeScript nicht |

Fit **2 von 5** für die Werkzeugliste, stärker für Linux-Betrieb und Automatisierung. Die Anzeige sagt selbst, dass niemand alles
beherrschen muss — das ist der Grund, warum dieses Paket überhaupt sinnvoll ist.

## Formular auf arbeitnow (live gelesen 2026-11-21)

| Feld | Antwort |
| :--- | :--- |
| First name / Last name | Matt / Ji |
| Email address | matt@bountystash.com |
| CV / Resume | `lebenslauf.pdf` (.pdf erlaubt, max. 10 MB) |
| Honeypot `arbeitnow_name_2kRPe3tSAYjOedry` | leer lassen |
| `arbeitnow_valid_from` | leer lassen, setzt das Formular |
| Terms-Checkbox | Wortlaut vor dem Absenden lesen und bestätigen |

**Es gibt kein Anschreiben-Feld.** Das Formular nimmt genau eine Datei. Das Anschreiben geht, wenn überhaupt, als Antwort auf die
Bestätigungsmail mit — das ist eine Entscheidung, keine Lücke.

## Gehalt

Nicht ausgeschrieben. Eingereicht und hier festgehalten: **84.000 EUR brutto**, Untergrenze 70.000 EUR. Für Systemadministration und
DevOps in Berlin mit 100 % remote liegt das in der oberen Mitte.

## Prüfungen

| Prüfung | Ergebnis |
| :--- | :--- |
| `typst compile` beide Quellen | je 0 Warnungen |
| Seitenbudget | Lebenslauf 2, Anschreiben 1 |
| Nicht belegte Werkzeuge | nur im Absatz, der sie ausdrücklich verneint |
| `task checks:prose` | Exit 0 |
| Commit | native Fassung, `selection.json` im selben Commit entfernt |
