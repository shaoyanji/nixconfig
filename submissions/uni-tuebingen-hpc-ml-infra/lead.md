# Lead: Universität Tübingen - HPC Systems Engineer, ML Cloud

Fit: 3
Stand: 22.11.2026

## Warum interessant

Der Exzellenzcluster Machine Learning betreibt mit dem ML Cloud Team HPC-Infrastruktur für ML-Workloads über vier Rechenzentren: Tübingen AI Center, Cluster of Excellence und Hertie-Institut. Täglich laufen Tausende Jobs, frontier-scale Trainings. Die Stelle ist unbefristet, E 13 TV-L, 100 Prozent, und deckt die ganze Kette ab: Bare-Metal-Compute, Slurm, Virtualisierungsschicht, Storage-Backends und die Automatisierung darüber. Das ist wissenschaftliches Rechnen mit echtem Betriebsdruck, nicht Clusterverwaltung im Nebensatz.

Das ist die einzige der geprüften Stellen, die HPC-Clusterbetrieb wirklich als Kern hat. Freiburg (Future Forests, 50 Prozent Teilzeit) und Heidelberg (Fristen 27.10. und 01.11.2026, abgelaufen) fallen dahinter zurück.

## Was passt

- Linux-Betrieb über dreizehn Hosts und drei Hardware-Generationen, inklusive Bare-Metal-Beschaffung, Installation und Inbetriebnahme.
- Automatisierung: die ganze Flotte als Code in Git, jeder Host eine Feature-Liste, jeder Dienst ein Modul, jede Änderung mit Gate und Rückrollung.
- Telemetrie: Sentinel-Ledger alle 15 Minuten mit Jobstatus, Generation-Alter, Disk- und PSI-Druck, Gatus-Prüfungen, Go-Bridge mit Zustellbestätigung.
- Storage und Sicherung: restic auf NAS, Wiederherstellungen geprüft; Kapazität und Druck im Blick statt im Glauben.
- Ressourcenlimits je Dienst, systemd-Härtung, keine öffentliche Schnittstelle.
- Wissenschaftliche Umgebung aus eigener Zeit: 2012 am Fraunhofer ISE, Laborgeräte, Messdaten, C++ und Python.
- Deutsch C1, Englisch Muttersprache.

## Was fehlt

- Slurm: kein Scheduler-Betrieb, keine Partitionierung, keine Job-Policies.
- Parallele Dateisysteme: kein Lustre, Weka oder Ceph; NAS und restic sind kein Cluster-Storage.
- GPU-Betrieb: keine Treiber-, CUDA-, DCGM-, MIG- oder NVLink-Praxis.
- Hochgeschwindigkeitsnetze: kein InfiniBand, kein 400G-Ethernet, kein Fabric Manager.
- RHEL und Rocky im Produktivbetrieb; die eigene Flotte ist NixOS und Debian-nah.
- Der Abschluss ist M.Sc. Erneuerbare-Energien-Management, nicht Informatik. Die Anzeige verlangt einen Master in Informatik oder verwandt; das ist über die Praxis zu begründen, nicht über das Zeugnis.
- Tübingen ist rund 130 km von Gutach entfernt, also kein Tagespendeln wie Freiburg. Ein Umzug ist die realistische Annahme.

## Weg

Bewerbung über careers.tuebingen.ai bis 06.12.2026, mit Lebenslauf und Zeugnissen. Kontakt für Fragen: Simon Kreuzer, simon.kreuzer@uni-tuebingen.de. Die Stelle ist unbefristet und teilbar.

## Gehalt

E 13 TV-L, 100 Prozent, unbefristet. Die eigene Erwartung von 85.000 bis 95.000 EUR liegt bei E 13 in Reichweite, abhängig von der Stufe. Im Anschreiben steht keine Zahl; die Stufe ist das Gesprächsthema, nicht die Gruppe.
