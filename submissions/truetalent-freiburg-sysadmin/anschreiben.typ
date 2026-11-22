// True Talent Solutions Partners — Senior System Administrator, Freiburg. Deutsches Anschreiben.
#set page(paper: "a4", margin: (x: 2.3cm, y: 1.9cm))
#set text(font: "DejaVu Sans", size: 9.9pt, fill: rgb("#191919"), lang: "de")
#set par(justify: true, leading: 0.62em)
#let muted = rgb("#5c6b7a")

#align(right)[
  #text(weight: "bold", size: 10.6pt)[Matt Ji]
  #linebreak()
  #text(size: 9.2pt)[Am Burgerhof 4 · 79261 Gutach im Breisgau]
  #linebreak()
  #text(size: 9.2pt)[matt\@bountystash.com]
]

#v(0.45cm)
#text(size: 8.8pt, fill: muted)[22. November 2026]
#v(0.4cm)
True Talent Solutions Partners\\
Freiburg im Breisgau

#v(0.55cm)
#text(weight: "bold", size: 10.3pt)[Bewerbung als Senior System Administrator — Freiburg im Breisgau]
#v(0.45cm)

Sehr geehrte Damen und Herren,

die Stelle ist für mich keine Bewerbung unter vielen: Ich wohne 20 Kilometer von Freiburg entfernt und suche
bewusst eine Rolle, in der ich vor Ort an den Systemen arbeite statt sie aus der Ferne zu betrachten. Genau
das habe ich fünf Jahre lang getan — Server in Betrieb nehmen, patchen, überwachen, reparieren — und dabei
gelernt, dass ein heterogenes Netz vor allem von Dokumentation und Nachvollziehbarkeit lebt.

Meine Systeme administriere ich deklarativ: dreizehn Linux-Hosts aus einem Repository, Provisionierung über
PXE und iVentoy, jede Änderung durch ein Gate, das in der CI und auf dem Host identisch läuft, jeder
Rückweg ein Zeiger auf die vorige Generation. Überwacht wird mit einem Ledger alle fünfzehn Minuten —
Jobstatus, Disk-Druck, PSI — mit Meldung auf jeden Zustand ungleich ok. Sicherheit ist Voreinstellung:
nftables als Default-Deny, Secrets pro Host mit SOPS und age verschlüsselt, Zugang über kurzlebige
Zertifikate, Rechte nach dem Minimum. Ich habe Anwender direkt betreut — Feldtechniker und Büro — und
Software-Rollouts geplant und dokumentiert.

Was ich nicht mitbringe, sage ich vorab: Proxmox und Ceph habe ich nicht administriert; meine
Virtualisierungserfahrung sind MicroVMs und systemd-Slices, meine Speichererfahrung ist lokaler und
netzbasierter Speicher, kein Ceph-Cluster. Windows Server und Microsoft 365 habe ich nicht betreut, Azure
nicht betrieben. Eine ISO-27001- oder C5-Zertifizierung habe ich nicht begleitet — ich habe die Praktiken,
die dahinterstehen: Default-Deny, Minimalrechte, Patch-Tests vor dem Rollout, prüfbare Dokumentation. Für
eine Rolle, in der Windows und Compliance-Projekte einen großen Teil ausmachen, ist das der ehrliche
Ausgangspunkt.

Zum Rahmen: Präsenz vor Ort ist für mich kein Problem, sondern der Grund für diese Bewerbung; Arbeitsweg
rund 25 Minuten. Meine Gehaltsvorstellung bespreche ich gern im ersten Gespräch anhand der Bandbreite, die
Sie für die Rolle vorgesehen haben. Deutsch ist C1, Englisch Muttersprache, ich bin US-Staatsbürger mit
deutscher Niederlassungserlaubnis und brauche kein Sponsoring.

Mit freundlichen Grüßen,
#v(0.5cm)
Matt Ji
