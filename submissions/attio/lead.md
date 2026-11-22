# Lead: Attio — Senior Platform Engineer

Fit: 4
Stand: 22.11.2026
Ort: London (Board führt drei Stellen: London ×2, Polen); Bewerbung aus Deutschland, Remote-Basis EU
Ashby-ID: c05a61a4-ae7c-4d93-a920-08d60c7448ad
Sprache: Englisch

## Quellenlage

Kein Verzeichnis, kein Datensatz vorhanden — Paket neu. Die Anzeige liegt live über das Ashby-Board (HTTP 200 am 22.11.2026), vollständig im Paket. Drei Senior-Platform-Engineer-Ausschreibungen sind offen; die Londoner Fassung ist übernommen, die polnische ist inhaltlich gleich.

## Warum interessant

Attio beschreibt Plattformarbeit als Produkt: Kubernetes, Terraform, AWS, CI/CD und Observability als Dinge, die ein Team betreut und nicht nur benutzt. Genau so ist die eigene Flotte gebaut: ein Modul je Dienst, eine Feature-Liste je Host, ein Gate vor jedem Ausrollen, Prüfungen im selben evaluierten Zustand, der ausgerollt wird. Dazu 116 Mio. USD Finanzierung und ein Team, das klein genug ist, dass eine Person die Plattform wirklich verantwortet.

## Was passt

- Deklarative Systeme als Arbeitsweise, nicht als Schlagwort: NixOS-Flotte mit 13 Hosts über drei Hardware-Generationen.
- CI/CD mit Zähnen: ein Gate prüft Module und Assertions, bevor ausgerollt wird; Build und Rollout teilen denselben Zustand.
- Observability selbst gebaut: Gatus-Prüfungen, JSONL-Sentinel-Ledger alle 15 Minuten, Auswertung in Python und Go.
- Alarmierung mit Zustellbestätigung: eine Go-Bridge, die erst bestätigt, wenn die Nachricht angekommen ist.
- Go und Python für Werkzeuge, die den Betrieb tragen, statt nur für Skripte.
- Sicherheit als Teil der Plattform: sops/age, eigene SSH-CA, Tailnet ohne öffentliche Schnittstelle, nftables.
- Wiederherstellung geprüft, nicht Sicherungsläufe gezählt: restic mit verifizierten Restores.
- Englisch Muttersprache, Deutsch C1, US-Staatsangehörigkeit mit Niederlassungserlaubnis, Wohnsitz Deutschland.

## Was fehlt

- **Kubernetes** — nicht betrieben, weder Cluster noch Operator.
- **Terraform** — nicht verwendet; deklarativ gearbeitet, aber mit Nix statt HCL.
- **AWS** — keine Plattformverantwortung in der Cloud.
- Größenordnung: 13 Hosts statt einer Multi-Tenant-Plattform mit vielen Teams.
- London-Präsenz: die Anzeige nennt London, die Bewerbung kommt aus Deutschland.

## Weg

Ashby-Bewerbung über die Stellen-ID, englischsprachiger Antrag. Keine Frist genannt.

## Gehalt

Keine Zahl im Anschreiben; die Anzeige nennt keine.

## Fit-Begründung: 4 von 5

Vier, wie vorgegeben. Die Arbeitsweise passt: Plattform als betreutes Produkt, ein Gate statt Zusagen, Observability als Teil des Systems und nicht als Zukauf. Das ist selten und wird in der Anzeige ausdrücklich gesucht.

Nicht 5, weil Kubernetes, Terraform und AWS die drei Werkzeuge sind, um die sich die Stelle dreht, und keines davon in eigener Verantwortung betrieben wurde. Vier heißt: die Denkweise und die Betriebsdisziplin sind belegbar, die Werkzeuge müssen dazukommen.
