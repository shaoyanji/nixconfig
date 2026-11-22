#set document(title: "Bewerbung — Deutsche Telekom IT, Senior SRE Observability", author: "Matt Ji")
#set page(paper: "a4", margin: (top: 2cm, bottom: 2cm, left: 2.2cm, right: 2.2cm))
#set text(font: ("Libertinus Serif", "DejaVu Sans"), size: 10pt, fill: rgb("#111827"), lang: "de")
#set par(leading: 0.58em, justify: true, spacing: 1.1em)

#text(size: 9pt, fill: rgb("#374151"))[
  #text(weight: "bold", size: 10pt, fill: rgb("#111827"))[Matt Ji] \
  Am Burgerhof 4, 79261 Gutach im Breisgau \
  matt\@bountystash.com • +49 1733281570 • github.com/shaoyanji/nixconfig
]

#v(14pt)

#text(size: 9pt)[
  Deutsche Telekom IT GmbH \
  Senior Site Reliability Engineer — Observability
]

#v(14pt)
#align(right)[#text(size: 8.5pt, fill: rgb("#4b5563"))[22. November 2026]]

#v(6pt)
#text(weight: "bold")[Bewerbung als Senior Site Reliability Engineer, Schwerpunkt Observability]

#v(4pt)
Sehr geehrte Damen und Herren,

#v(2pt)
Beobachtung ist für mich keine Sammlung von Dashboards, sondern die Frage, ob ein Ausfall bemerkt wird, bevor ein Nutzer anruft. In meinem Bestand hängt daran eine Schleife: ein Ledger, das alle fünfzehn Minuten einen Datensatz mit Zeitstempel schreibt, Prüfungen von außen, die Erreichbarkeit und Antwortzeit messen, und ein Alarmkanal in Go, der eine Störung erst als gemeldet führt, wenn die Zustellung bestätigt ist. Ein Alarm, der ausgelöst und nie zugestellt wird, ist schlimmer als kein Alarm, weil er einen falschen Glauben erzeugt. Dieselbe Schleife prüft Speicher- und Prozessdruck, das Alter der laufenden Generation und den Platz auf den Datenträgern — die Größen, die einem Ausfall vorausgehen.

#v(2pt)
Dreizehn Linux-Hosts über drei Hardware-Generationen, fünf Jahre, eine Flake: ein Modul je Dienst, eine Feature-Liste je Host, gepinnte Eingaben, ein Gate über das ausgewertete System vor jedem Rollout, Rückrollung über die vorige Generation. Dazu systemd und seine Fehlerbilder, cgroups und Namespaces, PSI-Werte, Boot und initrd auf echter Hardware, nftables und ein WireGuard-Netz ohne öffentlichen Listener. Werkzeuge schreibe ich in Python und Go; die Dokumentation entsteht aus demselben Graphen wie das Aufgabenmenü, weil eine Dokumentation, die auseinanderläuft, schlechter ist als keine.

#v(2pt)
Was ich nicht mitbringe, sage ich im ersten Absatz offen: Ich habe keinen regulierten KRITIS-Betrieb verantwortet, also keine Auditierung nach BSIG und IT-Grundschutz, keine Nachweispflichten gegenüber einer Aufsicht. Prometheus, Thanos oder Loki habe ich nicht im Maßstab von Telekom betrieben; meine Metriken stammen aus einem eigenen Ledger, aus Gatus-Prüfungen und auf einzelnen Hosts aus node_exporter. OpenTelemetry und Kubernetes kenne ich nicht aus dem Betrieb. Was ich mitbringe, ist die Fähigkeit, eine Beobachtungsschleife zu bauen, die man einem Publikum von Millionen zumuten kann — und die Bereitschaft, die Werkzeuge zu übernehmen, die hier Standard sind, statt meine eigenen durchzusetzen.

#v(2pt)
Ich lebe in Deutschland, arbeite fern ohne Einschränkung, Deutsch ist C1, Englisch Muttersprache, Niederlassungserlaubnis liegt vor. Das Repository ist öffentlich: github.com/shaoyanji/nixconfig

#v(4pt)
Mit freundlichen Grüßen

#v(18pt)
Matt Ji
