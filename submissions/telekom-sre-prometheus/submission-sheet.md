# Bewerbung Deutsche Telekom AG / T-Systems – Site Reliability Engineer (SRE) (m/w/d)

Stand: 22. November 2026
BA-Referenz: 12444-563465374109756-DT-S
Fit: 5

## Stelle

| Feld | Wert |
| :--- | :--- |
| Arbeitgeber | Deutsche Telekom AG, Einsatz bei T-Systems International GmbH |
| Rolle | Site Reliability Engineer (SRE) (m/w/d) |
| Arbeitsorte | Kassel, Bielefeld, München, Berlin, Karlsruhe, Hannover, Dresden, Magdeburg, Saarbrücken, Darmstadt |
| Anstellung | Vollzeit, ab sofort; auch in Teilzeit möglich |
| Arbeitsmodell | Hybrid mit mobilen Tagen und flexiblen Arbeitszeiten |
| Schwerpunkt | Monitoring-Stack aus Prometheus, Grafana, Loki und AlertManager für verteilte Fog- und Edge-Infrastruktur |
| Besonderheit | Betrieb in ressourcenbeschränkten, teils getrennten oder Air-Gap-Umgebungen |
| Vergütung | Keine Spanne in der Anzeige; kein Zielfenster vorgegeben |
| Fachlicher Kontakt | thomas.arbeit@t-systems.com |
| Anzeige | https://www.arbeitsagentur.de/jobsuche/jobdetail/12444-563465374109756-DT-S |

Die Anzeige liegt als Spiegel bei der Bundesagentur für Arbeit und ist dort seit über 30 Tagen veröffentlicht. Die Originalstelle läuft über das Telekom-Jobportal; die BA-Seite verlinkt dorthin. Die Bewerbung geht über Telekom beziehungsweise T-Systems, nicht über die BA.

## Bewerbungsweg

1. BA-Anzeige öffnen: `https://www.arbeitsagentur.de/jobsuche/jobdetail/12444-563465374109756-DT-S`
2. Der Bewerbungslink führt in das Telekom-Jobportal, im Seitenquelltext sichtbar als `https://jobwelt.telekom.com/jpapps/n/ext`.
3. Dort die Stelle über die BA-Referenz oder den Titel suchen und das Formular öffnen.
4. Das Formular wurde nicht gerendert; es ist ohne Sitzung nicht öffentlich. Die Feldliste unten ist die übliche Telekom-Maske und vor dem Absenden zu prüfen. Es wurde nichts abgeschickt und kein Konto angelegt.

## Kandidat

| Feld | Wert |
| :--- | :--- |
| Name | Matt Ji |
| Adresse | Am Burgerhof 4, 79261 Gutach im Breisgau, Deutschland |
| E-Mail | matt@bountystash.com |
| Telefon | +49 1733281570 |
| Sprachen | Deutsch C1, Englisch Muttersprache |
| Abschluss | M.Sc. Erneuerbare-Energien-Management, Albert-Ludwigs-Universität Freiburg, 2014 |
| Berufserfahrung | Zehn Jahre, davon fünf Jahre eigene Infrastruktur- und DevOps-Verantwortung |
| Arbeitsberechtigung | US-Staatsangehörigkeit mit unbefristeter deutscher Niederlassungserlaubnis; keine Visumsunterstützung nötig |
| Verfügbarkeit | Ab sofort |
| Nächster Standort | Karlsruhe, rund 100 km von Gutach im Breisgau |

## Abgleich mit der Ausschreibung

| Anforderung | Nachweis | Einschätzung |
| :--- | :--- | :--- |
| Prometheus: PromQL, Federation, Remote Write, lokale Retention | Kein Prometheus-Server; node_exporter läuft auf einem Always-on-Knoten als Metrikquelle | Lücke beim Stack, Exposition vorhanden |
| Grafana: Dashboards, Alerting, Provisioning-as-Code | Kein Grafana im Einsatz | Lücke |
| Loki: LogQL, Retention, Compaction | Kein Loki im Einsatz | Lücke |
| AlertManager: Routing, Inhibition, Eskalation | Eigene Go-Bridge bestätigt Zustellung, ohne Routing oder Inhibition | Teilweise: Zustellzusage ja, Regelwerk nein |
| Monitoring und Betrieb von Kubernetes | Container als Grundlage, kein Cluster betrieben | Lücke |
| Ressourcenbeschränkte Umgebungen, CPU, Speicher, Storage | Kleine Always-on-Appliance, PSI-Druck statt Lastmittel, schlanke Dienste | Stark |
| Offline-, Air-Gap-, Disconnected-Betrieb | Keine Air-Gap-Umgebung betrieben; Flotte hängt am Tailnet | Lücke |
| YAML-Konfiguration | Taskfiles und CI-Workflows täglich, deklarative Konfiguration im Repository | Stark |
| Infrastructure as Code, GitOps | Zustand vollständig im Repository, Ausrollen über Tasks und Pull Request | Stark |
| Linux-Systemadministration | NixOS, systemd, nftables, Rollback je Generation | Stark |
| IT-Sicherheit und Security Awareness | sops mit age, eigene SSH-CA, kurzlebige Zertifikate, Least Privilege | Stark |
| SRE- oder Infrastruktur-Betrieb | Fünf Jahre Plattformbetrieb mit Ledger, Gates und Alerting | Stark |
| Deutsch C1 | C1, Englisch Muttersprache | Übertrifft |

Auswahl im Lebenslauf: 16 von 30 Highlights, 4 von 5 Projekten.

## Was das Paket bewusst nicht behauptet

Die Must-Haves nennen Prometheus mit PromQL, Federation und Remote Write, Grafana mit Provisioning-as-Code, Loki mit LogQL und Compaction sowie AlertManager mit Routing und Inhibition. Nichts davon läuft in dieser Flotte. Das Anschreiben sagt das im dritten Absatz und bietet stattdessen den geschlossenen Telemetriekreis, die Zustellzusage der Alarm-Bridge, den PSI-basierten Engpassblick und die YAML- und IaC-Praxis an. Wer hier einen fertigen Stack erwartet, soll es vor dem Gespräch wissen.

## Gehalt

Die Anzeige nennt keine Spanne, und es wurde kein Zielfenster vorgegeben. Im Anschreiben steht daher keine Zahl. Wenn das Portal ein Pflichtfeld hat, vor dem Absenden einen Wert festlegen; die Parallelbewerbungen liegen zwischen 85.000 und 95.000 EUR.

## Formularzuordnung

Das Telekom-Formular wurde nicht gerendert. Die folgende Zuordnung ist die übliche Maske und vor dem Absenden gegen die Beschriftungen zu prüfen.

### Person

| Feld | Wert |
| :--- | :--- |
| Anrede | Herr |
| Vorname | Matt |
| Nachname | Ji |
| E-Mail | matt@bountystash.com |
| Telefon | +49 1733281570 |
| Straße | Am Burgerhof 4 |
| PLZ | 79261 |
| Ort | Gutach im Breisgau |
| Land | Deutschland |
| Geburtsdatum | Nur angeben, wenn Pflichtfeld; Wert aus dem PII-Speicher |

### Stelle und Konditionen

| Feld | Wert |
| :--- | :--- |
| Referenz | 12444-563465374109756-DT-S |
| Standortwunsch | Karlsruhe |
| Eintritt | Ab sofort |
| Beschäftigungsart | Vollzeit |
| Gehaltswunsch | Nur bei Pflichtfeld; Wert vorher festlegen |
| Frühere Beschäftigung bei Telekom | Nein |
| Schwerbehinderung | Keine Angabe, solange freiwillig |

### Anhänge

| Dokument | Datei | Hinweis |
| :--- | :--- | :--- |
| Lebenslauf | `lebenslauf.pdf` | Zwei Seiten |
| Anschreiben | `anschreiben.pdf` | Eine Seite |
| Zeugnisse | keine Datei | Nur anhängen, wenn das Formular danach fragt |

## Offene Punkte vor dem Absenden

1. Stelle im Telekom-Jobportal über die BA-Referenz finden; die BA-Seite ist nur der Spiegel.
2. Feldnamen und Pflichtflags im gerenderten Formular prüfen.
3. Prometheus-, Grafana-, Loki-, AlertManager- und Kubernetes-Lücken nicht überspielen; das Anschreiben benennt sie.
4. Standort Karlsruhe bestätigen und die Präsenztage klären.
5. Gehaltswunsch nur eintragen, wenn das Feld Pflicht ist, und vorher einen Wert festlegen.
6. Nach dem Absenden Bestätigung und Eingangs-E-Mail sichern.
7. Delphi-Datensatz steht auf `stage=prep`; nach dem Absenden auf `applied` wechseln.

## Paket

| Datei | Inhalt |
| :--- | :--- |
| `job-description.txt` | Bereinigte Ausschreibung mit Aufgaben, Must-Haves, Nice-to-Haves und Standorten. |
| `lebenslauf.pdf` | Deutscher Lebenslauf, zwei Seiten. |
| `anschreiben.pdf` | Deutsches Anschreiben, eine Seite, mit benannter Stack-Lücke. |
| `selection.json` | Audit der ausgewählten Highlights und Projekte. |
| `submission-sheet.md` | Diese Feldzuordnung. |
