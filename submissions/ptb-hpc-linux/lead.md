# Lead: PTB Berlin - Linux-Systemadministration HPC und Compute-Server

Fit: 4
Stand: 22.11.2026
Frist: 23.11.2026 (morgen)

## Warum interessant

Die Physikalisch-Technische Bundesanstalt ist das nationale Metrologieinstitut. Referat 9.55 Hochleistungsrechnen betreibt in Berlin-Charlottenburg ein HPC-Cluster und Compute-Server unter Linux als Dienstleistung für die Fachabteilungen, dazu virtualisierte Serverinfrastruktur. Gesucht wird jemand für Linux-Administration, Rechteverwaltung und Automatisierung, Clusterbetrieb, Support für wissenschaftliche Nutzende, Bereitstellung fachspezifischer Software und die strategische Weiterentwicklung der Infrastruktur. Unbefristet, E 10 TVöD Bund, Vollzeit, mit mobilen Arbeitsanteilen.

Der Bezug ist doppelt: wissenschaftliche IT aus eigener Zeit (Fraunhofer ISE 2012, Laborgeräte und Messdaten) und Betrieb einer Flotte, die als Code dokumentiert ist statt in Köpfen.

## Was passt

- Linux-Betrieb über dreizehn Hosts und drei Hardware-Generationen, inklusive Beschaffung, Installation und Inbetriebnahme.
- Automatisierung des Serverbetriebs: jeder Dienst ein Modul, jeder Host eine Feature-Liste, jede Änderung ein Commit mit Gate und Rückrollung; Werkzeuge in Shell, Python und Go.
- Rechteverwaltung deklarativ: Rollen je Host, kein Konto von Hand.
- Überwachung mit Sentinel-Ledger alle 15 Minuten, Gatus-Prüfungen und einer Go-Bridge, die eine Alarmzustellung bestätigt.
- Sicherung mit restic auf ein NAS, Wiederherstellungen werden durchgeführt, nicht nur der Job geprüft.
- Sicherheit: sops und age, eigene SSH-Zertifizierungsstelle mit kurzlebigen Zertifikaten, keine öffentliche Schnittstelle, Ressourcenlimits je Dienst.
- Dokumentation als Runbook, Anleitung von Nutzenden, Support bei Hard- und Softwarefragen.
- Energieeffizienz als Thema: stromsparende Hardware, Limits je Dienst, PSI-Druck im Ledger.
- Deutsch C1, Englisch Muttersprache; Bereitschaft zur Sicherheitsüberprüfung nach § 9 SÜG.

## Was fehlt

- Slurm und HPC-Scheduler-Betrieb: keine Praxis.
- Parallele Programmiermodelle (MPI, OpenMP) und Prozessorarchitekturen im HPC-Kontext.
- Verteiltes Dateisystem wie Lustre oder GPFS.
- Ansible: die Automatisierung ist Nix plus Git, nicht Ansible.
- Proxmox und Servervirtualisierung.
- BSI-Anforderungen als formale Umsetzung; Sicherheitshygiene ist vorhanden, Grundschutz nicht.
- Rated E 10: die eigene Erwartung von 85.000 bis 95.000 EUR liegt darüber.

## Weg

Ausschließlich über den Button "ONLINE BEWERBEN" der Anzeige, Kennziffer 26-163-9C. Keine Bewerbung per E-Mail, keine per Post. Hochgeladen werden Lebenslauf, Zeugnisse und Anschreiben. Mit der Abgabe wird die Bereitschaft zur Sicherheitsüberprüfung nach § 9 SÜG erklärt. Fachfragen: Dr. Daniel Lübbert, 030 3481-8450.

Die Frist ist morgen, der 23.11.2026. Alles andere ist zweitrangig.

## Gehalt

E 10 TVöD Bund, Stufe nach anrechenbarer Erfahrung, unbefristet. Verhandelbar ist die Stufe, nicht die Gruppe. Keine Zahl im Anschreiben.
