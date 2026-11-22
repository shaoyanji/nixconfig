# Dossier — hep global GmbH, IT-Systemadministration und Infrastruktur

Stand: 22. November 2026
Art: Initiativbewerbung, keine ausgeschriebene Stelle
Ort: Güglingen, Baden-Württemberg (zweites Office: Hamburger Speicherstadt)

## 1. Lage

Für hep global ist am 22.11.2026 **keine Stelle in der IT-Systemadministration ausgeschrieben**. Das ist keine Annahme, sondern zweimal geprüft:

- Das Personio-Portal des Unternehmens (`hep-global-gmbh.jobs.personio.de/xml?language=de`) antwortet mit HTTP 200 und listet genau drei Positionen: Kaufmännischer Assetmanager (m/w/d) – PV & BESS, Projektentwickler Solar & BESS (m/w/d), Senior PV / BESS engineer (m/w/d).
- Die Karriereseite (`hep.global/karriere/`, HTTP 200) enthält keine technische IT-Stelle.

Damit ist die Bewerbung eine Initiativbewerbung — und das ist bei diesem Arbeitgeber ein vorgesehener Weg, keine Notlösung. Die Karriereseite schreibt es selbst:

> Auch wenn wir derzeit keine passende Stelle ausgeschrieben haben, die deinen Vorstellungen entspricht, freuen wir uns über deine Initiativbewerbung. Zeige uns, warum du Teil unseres Teams werden möchtest und welche Fähigkeiten und Erfahrungen du mitbringst.

Das Paket ist deshalb ohne Ausschreibungstext gebaut. Es gibt in diesem Verzeichnis bewusst keine `job-description.txt`: Eine Anzeige zu erfinden und dann gegen sie zu schreiben, würde die Prüfung wertlos machen, die dieses Paket belegen soll.

## 2. Warum hep global

hep global entwickelt, baut und betreibt Solar-Freiflächenanlagen und Batteriespeicher, mit Sitz in Güglingen und einem zweiten Office in der Hamburger Speicherstadt. Der Neubau in Güglingen von 2017 ist nahezu energieautark — ein Unternehmen, dessen Produkt Strom ist und dessen Gebäude den eigenen Anspruch vorführt.

Für eine IT-Stelle ist das der interessante Teil: Ein Solarpark liefert keine Rechnung, sondern eine Messreihe. Wechselrichter, Zähler, Wetterstationen und Speicher melden über Jahre Werte, aus denen Ertrag, Verfügbarkeit und am Ende Rendite folgen. Wenn diese Kette an einer Stelle still falsch wird, sieht man es nicht im Dashboard, sondern erst beim Jahresvergleich. Wer Anlagen betreibt, braucht deshalb beides: jemanden, der die Systeme am Laufen hält, und jemanden, der weiß, was in den Zahlen steht.

Genau diese Kombination ist im Lebenslauf selten, weil sie selten in einer Person liegt: Messtechnik am Fraunhofer ISE, danach kaufmännische Betreuung von Solar-PV, danach fünf Jahre allein verantworteter Systembetrieb.

## 3. Der Fraunhofer-ISE-Teil, auf dem das Paket steht

2012, von März bis September, wissenschaftliche Hilfskraft am Fraunhofer ISE in Freiburg:

- Laborgeräte über selbst geschriebene C++-Anwendungen angesteuert.
- Messreihen in Python ausgewertet.
- Heliostat-Ungenauigkeiten interferometrisch vermessen, Geometriematrizen in Mathematica geprüft.

Der Wert liegt nicht in der Institutszeile, sondern in der Erfahrung, die dahinter steht: Eine Messung ist kein Wert, sondern eine Kette aus Gerät, Zeitbasis, Nullpunkt, Kalibrierung und Auswertung. Ein Heliostat, der um Milliardengrade daneben steht, produziert keine Fehlermeldung, sondern eine Zahl, die plausibel aussieht. Diese Denkweise — Messfehler suchen, statt Messwerte zu glauben — ist bei Anlagen mit Ertragsgarantie direkt geldwert.

## 4. Was Matt mitbringt

| Feld | Nachweis |
| :--- | :--- |
| Systembetrieb | Dreizehn Linux-Server über drei Hardware-Generationen, 2020–2025, allein verantwortet |
| Netz | WireGuard zwischen Standorten, nftables, DNS, Zertifikate über eine eigene Zertifizierungsstelle |
| Automatisierung | Deklarativer Bestand, gleicher Zustand in CI geprüft, Rückrollung über Generationen in Minuten |
| Überwachung | Sentinel-Ledger: Jobstatus, Generation-Alter, Disk- und PSI-Druck alle 15 Minuten, Alarmierung mit Zustellbestätigung |
| Sicherung | restic auf NAS-Ziele, Rückspielungen geprüft statt Sicherungsläufe gezählt |
| Messtechnik | Geräteanbindung in C++, Auswertung in Python, Interferometrie, 3D-Geometrie (Fraunhofer ISE, 2012) |
| Anlagenverständnis | 10 MW Solar-PV kaufmännisch betreut, Portfolio über USD 100 Mio., 2016–2020 |
| Dokumentation | Runbook je Verfahren, Betriebswissen nicht an einer Person |
| Ausbildung | M.Sc. Erneuerbare-Energien-Management, Freiburg, 1,8 |
| Sprachen und Status | Deutsch C1, Englisch Muttersprache, US-Staatsangehörigkeit mit Niederlassungserlaubnis |

## 5. Was fehlt

Diese Punkte stehen im Anschreiben und im Lebenslauf, nicht nur in diesem Dossier:

- **Windows-Seite.** Kein Betrieb von Windows Server, Active Directory, GroupPolicies, Entra ID. Wenn hep global microsoft-geprägt ist, ist das ein Jahr Einarbeitung, nicht ein Monat.
- **Virtualisierung.** Kein VMware, kein Hyper-V, kein Proxmox im Produktivbetrieb über die eigene Flotte hinaus.
- **Netzwerkhardware.** Keine Cisco-, Fortinet- oder Aruba-Konfiguration; Firewall-Wissen auf nftables-Ebene, nicht auf Herstellerebene.
- **Service-Desk-Skala.** Nutzende betreut, aber kein Ticketsystem in einem Unternehmen mit mehreren hundert Mitarbeitenden.
- **Compliance-Rahmen.** Keine ISO-27001-Zertifizierung, kein BSI-Grundschutz.
- **Führung.** Keine disziplinarische Personalverantwortung.

## 6. Die nächstgelegene echte Stelle — und warum nicht darauf

Unter den drei offenen Positionen ist der **Senior PV / BESS engineer (m/w/d)** die technischere. Er ist aber keine IT-Stelle: Er verlangt Anlagenengineering, Auslegung und Projektierung von PV- und Speicherprojekten, nicht Systemadministration. Eine Bewerbung darauf würde die eigene Erfahrung gegen eine Anforderung stellen, die sie nicht erfüllt — und die Mess- und Systembetriebsseite bliebe unerwähnt.

Der **Projektentwickler Solar & BESS** liegt noch weiter weg. Der **Kaufmännische Assetmanager** ist bereits als eigenes Paket gebaut (`submissions/hep-global/`, Fit 4) und bleibt unverändert.

Die Initiativbewerbung ist damit die ehrlichste Form: Sie sagt, was gesucht wird (eine IT-Stelle), und liefert den Grund, warum dieses Unternehmen von dieser Person profitieren würde, auch ohne ausgeschriebene Stelle.

## 7. Weg der Einreichung

Die Karriereseite nennt zwei Kanäle: das Bewerbungsformular im Jobportal (Personio) und ein Kontaktformular. Allgemeine Adresse: `info@hep.global`. Laut Karriereseite erhält jede Bewerbung eine Bestätigung per E-Mail — der Eingang ist also nachweisbar.

Vor dem Absenden zu klären:

1. Ob eine Initiativbewerbung über das Personio-Formular einer ausgeschriebenen Stelle zugeordnet werden muss oder ob es einen eigenen Eingang gibt.
2. An welche Rolle im Unternehmen das Anschreiben adressiert werden sollte (IT-Verantwortliche statt Personalabteilung). Die Anrede ist bewusst allgemein gehalten, solange kein Name bekannt ist.
3. Ob eine Initiativbewerbung ohne konkrete Stelleüberhaupt in den Prozess aufgenommen wird oder nur archiviert.

## 8. Gehalt

Weder Anzeige noch Karriereseite nennen eine Zahl, und es gibt keine Anzeige, gegen die man sie ableiten könnte. Im Anschreiben steht deshalb keine Zahl und in diesem Dossier keine Schätzung. Ein Betrag wird im Gespräch genannt, sobald die Rolle und ihr Zuschnitt bekannt sind.

## 9. Risiken

- **Initiativbewerbungen verschwinden.** Ohne Stelle gibt es keinen Prozess, der auf eine Antwort drängt. Ohne Rückmeldung nach zwei Wochen ist das erledigt und wird nicht nachverfolgt.
- **Die Rolle existiert vielleicht nicht.** Ein Unternehmen dieser Größe kann IT extern betreiben lassen. Dann ist die Bewerbung höflich, aber gegenstandslos.
- **Standort.** Güglingen ist rund zwei Stunden von Gutach im Breisgau entfernt. Ein Umzug ist zugesagt, aber er ist eine echte Bedingung, keine Floskel.
- **Windows-Lücke.** Wenn die Stelle zu zwei Dritteln aus Microsoft-Administration besteht, ist das Anschreiben ehrlich, aber chancenlos.

## 10. Nächste Schritte

1. Kanal klären (Abschnitt 7) und die Bewerbung über das Personio-Formular oder das Kontaktformular einreichen.
2. Zeugnisse ergänzen — sie fehlen in jedem Paket dieses Bestands.
3. Nach dem Absenden: eine Woche warten, dann einmal telefonisch nachfassen, danach abschließen.
4. DB-Eintrag `hep-global-infra` auf `applied` setzen, sobald eingereicht.
