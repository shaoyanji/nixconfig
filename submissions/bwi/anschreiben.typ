#set document(title: "Bewerbung BWI — Senior Infrastructure/Platform Engineer", author: "Matt Ji")
#set page(paper: "a4", margin: (top: 1.9cm, bottom: 1.9cm, left: 2.2cm, right: 2.2cm))
#set text(font: ("Libertinus Serif", "DejaVu Sans"), size: 10pt, fill: rgb("#111827"), lang: "de")
#set par(leading: 0.55em, justify: true, spacing: 1.1em)

#text(size: 9pt, fill: rgb("#374151"))[
  #text(weight: "bold", size: 10pt, fill: rgb("#111827"))[Matt Ji] \
  Am Burgerhof 4, 79261 Gutach im Breisgau \
  matt\@bountystash.com • +49 1733281570 • github.com/shaoyanji
]

#v(13pt)

#text(size: 9pt)[
  BWI GmbH \
  Frau Darina Kache \
  Auf dem Steinbüchel 22 \
  53340 Meckenheim
]

#v(13pt)
#align(right)[#text(size: 8.5pt, fill: rgb("#4b5563"))[22. November 2026]]

#v(5pt)
#text(weight: "bold")[Bewerbung als Senior Infrastructure/Platform Engineer (m/w/d), Stellen-ID 64059]

#v(4pt)
Sehr geehrte Frau Kache,

#v(2pt)
In Ihrem Profil steht Nix/NixOS zwischen Virtualisierung und Network Storage, als gute Kenntnisse neben Kubernetes. Für mich ist es die Betriebsgrundlage: dreizehn Server über drei Hardware-Generationen, jeder Dienst ein Modul, jeder Host eine Feature-Liste, jede Änderung ein Commit mit Gate und Rückrollung. Ich nenne das zuerst, weil es der Punkt ist, an dem ich ohne Einarbeitung arbeite.

#v(2pt)
Zur Aufgabe selbst: Eine Kubernetes-Infrastruktur für air-gapped Rechenzentren zu bauen, heißt, jede Abhängigkeit mitzuliefern und zu prüfen, statt sie zu ziehen. So betreibe ich meine Flotte seit Jahren: kein Dienst mit öffentlicher Schnittstelle, eine eigene SSH-Zertifizierungsstelle mit kurzlebigen Zertifikaten, TLS über eigene CA, Geheimnisse in sops und age, Firewall als Code in nftables, Bare Metal über PXE aus eigenem Archiv. Überwacht wird mit einem Sentinel-Ledger alle 15 Minuten, Alarmzustellungen bestätigt eine in Go geschriebene Bridge erst bei Ankunft. Was fehlt, sage ich vorher: keinen Kubernetes-Betrieb, kein CKA oder CKS, kein Ceph, kein VMware. Ich weiß, dass das der Kern der Stelle ist und nicht ein Nebensatz.

#v(2pt)
Das Gehalt: Ich erwarte 88.000 bis 92.000 EUR brutto im Jahr. Ihr Band beginnt bei 71.000 EUR und endet bei 91.650 EUR; meine Vorstellung liegt am oberen Rand, weil ich Betriebsverantwortung über eine ganze Flotte getragen habe und nicht nur einzelne Systeme. Über die Einordnung spreche ich gern.

#v(2pt)
Zur Person: Ich bin US-Amerikaner mit unbefristetem Niederlassungsrecht in Deutschland, benötige kein Visum und bin bereit, die Sicherheitsüberprüfung SÜ2 zu durchlaufen. Reisebereitschaft ist vorhanden. Gutach im Breisgau liegt rund dreieinhalb Stunden von Meckenheim entfernt; mit mobilem Arbeiten wären Präsenzblöcke für mich die realistische Form, ein Umzug nach erprobter Zeit denkbar. Deutsch C1, Englisch Muttersprache. Mein Repository zeigt die Arbeit ungeschminkt: github.com/shaoyanji/nixconfig

#v(4pt)
Mit freundlichen Grüßen

#v(16pt)
Matt Ji
