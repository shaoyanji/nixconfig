#set document(title: "Matt Ji — Lebenslauf", author: "Matt Ji")
#set page(paper: "a4", margin: (top: 1.4cm, bottom: 1.4cm, left: 1.7cm, right: 1.7cm))
#set text(font: ("Libertinus Serif", "DejaVu Sans"), size: 9.5pt, fill: rgb("#111827"), lang: "de", hyphenate: false)
#set par(leading: 0.5em, justify: true)

#align(center)[
  #text(size: 19pt, weight: "bold")[Matt Ji]
  #v(1pt)
  #text(size: 9pt, fill: rgb("#4b5563"))[Kaufmännisches Asset Management für Solar-PV]
  #v(2pt)
  #text(size: 8.5pt, fill: rgb("#374151"))[Am Burgerhof 4, 79261 Gutach im Breisgau • matt\@bountystash.com • +49 1733281570 • github.com/shaoyanji]
]
#v(6pt)
#line(length: 100%, stroke: 0.5pt + rgb("#d1d5db"))

#v(6pt)
#text(size: 9pt)[Asset Manager mit M.Sc. Erneuerbare-Energien-Management und vier Jahren kaufmännischer Verantwortung für 10 MW Solar-PV-Anlagen, danach fünf Jahre technischer Betrieb von Infrastruktur. Bewertet Anlagen in Finanzmodellen und liest dieselben Anlagen in Ertrags- und Betriebsdaten: Messreihen, Stillstände, Speicher- und Druckwerte. Berichtet aus Zahlen statt aus Eindrücken und dokumentiert jede Entscheidung nachvollziehbar. Wohnhaft in Baden-Württemberg, rund zwei Stunden von Güglingen. BESS-Betrieb, EEG- und Marktstammdatenregister-Abrechnung, Direktvermarktung und die Betreuung institutioneller Investoren sind nicht Teil dieser Erfahrung. US-Staatsangehörigkeit mit Niederlassungserlaubnis, kein Visum nötig. Deutsch C1, Englisch Muttersprache.]

#let section(kind) = block(breakable: false, sticky: true, width: 100%)[
  #v(5pt)
  #text(size: 10.5pt, weight: "bold", fill: rgb("#1f2937"))[#kind]
  #v(1pt)
  #line(length: 100%, stroke: 0.4pt + rgb("#e5e7eb"))
  #v(2pt)
]

#let entry(title, when, bullets) = block(breakable: false, width: 100%)[
  #par[
    #text(weight: "bold")[#title]
    #if when != "" [#text(size: 8.5pt, fill: rgb("#4b5563"))[ — #when]]
  ]
  #if bullets != () [
    #v(1pt)
    #block(inset: (left: 10pt, top: 0pt, bottom: 0pt))[
      #for bullet in bullets [- #bullet]
    ]
  ]
  #v(3pt)
]

#section("Berufserfahrung")
#entry("O3 Energy — Asset Manager", "2016 – 2020", (
  "Betreute 10 MW Solar-PV-Anlagen kaufmännisch und war für das Unternehmen und seine Tochtergesellschaften zuständig",
  "Erstellte Finanzmodelle und rechnete Investitionen, Erträge und Kosten über die Laufzeit durch",
  "Wertete Betriebs- und Ertragsdaten aus und leitete daraus Maßnahmen ab, statt Zahlen nur zu berichten",
  "Betreute Software und IT-Administration des Unternehmens einschließlich der Systeme, in denen die Anlagendaten zusammenliefen",
  "Hielt Ergebnisse in Auswertungen für die Geschäftsführung fest und dokumentierte Annahmen nachvollziehbar",
))
#entry("Bountystash — Gründer und alleiniger Betreiber", "2020 – 2025", (
  "Betrieb dreizehn Server über drei Hardware-Generationen und mehrere Standorte, von der Beschaffung bis zur Inbetriebnahme",
  "Baute die Betriebstelemetrie selbst: alle 15 Minuten Jobstatus, Generation-Alter sowie Disk- und PSI-Druck in ein JSONL-Ledger, dazu Gatus-Prüfungen",
  "Wertete diese Daten in Python und Go aus und band Alarmierung an eine Go-Bridge, die eine Zustellung erst bestätigt, wenn die Nachricht ankommt",
  "Beschrieb Plattform und Dienste deklarativ, prüfte im CI denselben Zustand, der ausgerollt wird, und hielt jeden Stand rückrollbar",
  "Sicherte mit restic auf NAS-Ziele und prüfte Wiederherstellungen statt Sicherungsläufe zu zählen",
  "Dokumentierte jede Prozedur als Runbook und hielt damit Betriebswissen unabhängig von einer Person",
))
#entry("Fraunhofer ISE — Wissenschaftliche Hilfskraft", "2012", (
  "Band Laborgeräte über C++-Anwendungen an und wertete Messreihen mit Python aus",
  "Forschte zu Heliostat-Ungenauigkeiten mit Interferometrie am Institut für Solare Energiesysteme",
))

#section("Ausbildung")
#entry("Albert-Ludwigs-Universität Freiburg — M.Sc. Erneuerbare-Energien-Management", "2011 – 2014", ("Abschluss 1,8; Modellierung mit neuronalen Netzen, Energiewirtschaft und Technikbewertung",))
#entry("Colorado School of Mines — B.Sc. Erdöltechnik", "2006 – 2010", ("GPA 3,2",))

#section("Projekte")
#entry("nixconfig — deklarierte Flotte mit Auswertung", "seit 2023", (
  "Ein Modul je Dienst, eine Feature-Liste je Host; ein Gate prüft Module und Assertions vor jedem Ausrollen",
  "Sentinel-Ledger über Jobstatus, Generation-Alter, Disk- und PSI-Druck mit Auswertung in Python und Go",
  "Dienste hinter einem Tailnet ohne öffentliche Schnittstelle, Zertifikate über die eigene CA",
))

#section("Kenntnisse")
#text(weight: "bold")[Kaufmännisch] — Finanzmodelle, Wirtschaftlichkeitsrechnung, Ertrags- und Kostenanalyse, KPI-Auswertung, Soll-Ist-Vergleich, Reporting \
#text(weight: "bold")[Solar-PV] — kaufmännische Betreuung von 10 MW Freiflächenanlagen, Ertragsdaten, Betriebsauswertung \
#text(weight: "bold")[Daten und IT] — Python, Shell, Go, Auswertung großer Messreihen, Monitoring-Ledger, reproduzierbare Auswertungen \
#text(weight: "bold")[Dokumentation] — Runbooks, nachvollziehbare Annahmen, revisionsfeste Ablage im Repository \
#text(weight: "bold")[Nicht vorhanden] — BESS-Betrieb, EEG-/Marktstammdatenregister-Abrechnung, Direktvermarktung, institutionelle Investoren, DATEV/SAP \
#text(weight: "bold")[Sprachen und Status] — Deutsch C1, Englisch Muttersprache · Wohnsitz Baden-Württemberg · US-Staatsangehörigkeit mit Niederlassungserlaubnis
