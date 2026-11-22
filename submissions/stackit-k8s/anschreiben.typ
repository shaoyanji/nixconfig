#set document(title: "Bewerbung STACKIT — Senior Kubernetes Engineer", author: "Matt Ji")
#set page(paper: "a4", margin: (top: 2cm, bottom: 2cm, left: 2.2cm, right: 2.2cm))
#set text(font: ("Libertinus Serif", "DejaVu Sans"), size: 10pt, fill: rgb("#111827"), lang: "de")
#set par(leading: 0.58em, justify: true, spacing: 1.1em)

#text(size: 9pt, fill: rgb("#374151"))[
  #text(weight: "bold", size: 10pt, fill: rgb("#111827"))[Matt Ji] \
  Am Burgerhof 4, 79261 Gutach im Breisgau \
  matt\@bountystash.com • +49 1733281570 • github.com/shaoyanji
]

#v(14pt)

#text(size: 9pt)[
  STACKIT \
  Schwarz Digits KG \
  Stiftsbergstraße 1 \
  74172 Neckarsulm
]

#v(14pt)
#align(right)[#text(size: 8.5pt, fill: rgb("#4b5563"))[22. November 2026]]

#v(6pt)
#text(weight: "bold")[Bewerbung als Senior Kubernetes Engineer]

#v(4pt)
Sehr geehrte Damen und Herren,

#v(2pt)
Kubernetes habe ich nicht betrieben. Das sage ich zuerst, weil es der Kern der Stelle ist und weil alles Folgende nur dann etwas wert ist, wenn diese Lücke klar benannt wurde: keine Control Plane, kein etcd, keine Operatoren, kein Helm, keine CNI, kein eBPF, kein Terraform. Bei einem Cloud-Anbieter, der Cluster als Produkt verkauft, ist das nicht ein Werkzeug, das man in der Einarbeitung nachzieht.

#v(2pt)
Was ich stattdessen mitbringe, ist die Ebene darunter, und zwar im Betrieb: dreizehn Server über drei Hardware-Generationen als ein deklarativer Zustand. Jeder Dienst ein Modul, jeder Host eine Feature-Liste, jede Änderung ein Commit, den ein Gate prüfen muss, jeder frühere Stand als Generation erhalten und rückrollbar. Kein Host wurde von Hand angefasst; deshalb gibt es keinen Zustand, der nur auf einer Maschine existiert. Wer Cluster-Lebenszyklen baut, macht konzeptionell dasselbe: einen gewünschten Zustand beschreiben, ihn herstellen, Abweichungen erkennen, den Weg zurück offen halten.

#v(2pt)
Dazu die Details, die zählen, wenn es eng wird: cgroup-Limits je Dienst, PSI-Speicherdruck als Messgröße, systemd-Härtung, Namespaces, nftables als Code, DNS, ein WireGuard-Tailnet ohne öffentliche Schnittstelle, PXE-Installationen aus eigenem Archiv. Werkzeuge schreibe ich in Go, darunter eine Bridge, die eine Alarmzustellung erst bestätigt, wenn die Nachricht ankommt, und den Router einer autarken KI-Plattform. Netzwerk habe ich bis zur Firewall-Regel und zum DNS-Eintrag selbst verantwortet, weil es niemand sonst gab.

#v(2pt)
Ich bin US-Amerikaner mit Niederlassungserlaubnis, brauche also keinen Visa-Sponsor. Neckarsulm ist von Freiburg rund anderthalb bis zwei Stunden entfernt; Präsenzblöcke sind für mich die passende Form, ein Umzug nach der Einarbeitung denkbar. Deutsch C1, Englisch Muttersprache. Mein Repository ist öffentlich und zeigt die Arbeit ungeschminkt: github.com/shaoyanji/nixconfig

#v(4pt)
Mit freundlichen Grüßen

#v(18pt)
Matt Ji
