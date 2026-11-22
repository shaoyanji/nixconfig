// CYCAP Asset Management — PPA Originator (m/w/d), Hamburg.
// Deutsche Typst-Quelle anstelle des Nix-PDFs. PPA, Solarportfolio, Energiehandel.
#set page(paper: "a4", margin: (x: 1.5cm, y: 1.15cm))
#set text(font: "DejaVu Sans", size: 9.2pt, fill: rgb("#191919"), lang: "de")
#set par(justify: true, leading: 0.55em)
#set list(marker: text(fill: rgb("#3d3320"))[•], indent: 0.85em, spacing: 0.3em)
#let accent = rgb("#3d3320")
#let muted = rgb("#5c6b7a")
#let section(t) = block(above: 8pt, below: 2pt)[
  #text(size: 9.8pt, weight: "bold", fill: accent, tracking: 0.07em)[#upper(t)]
  #v(-3pt)
  #line(length: 100%, stroke: 0.5pt + rgb("#c3ced8"))
]
#let job(title, org, when, where) = block(above: 4pt, below: 1pt)[
  #grid(columns: (1fr, auto),
    [#text(weight: "bold")[#title] #text(fill: muted)[— #org]],
    [#text(size: 8pt, fill: muted)[#when]])
  #v(-2pt)
  #text(size: 8pt, fill: muted)[#where]
]

#grid(columns: (1fr, auto),
  [
    #text(size: 19pt, weight: "bold", fill: accent)[Matt Ji]
    #v(-2pt)
    #text(size: 9.8pt)[PPA-Strukturierung und Risikoanalyse · Solarportfolios · Energiehandel]
  ],
  [
    #align(right)[
      #text(size: 8.4pt)[Am Burgerhof 4 · 79261 Gutach im Breisgau]
      #linebreak()
      #text(size: 8.4pt)[matt\@bountystash.com · +49 1733281570]
      #linebreak()
      #text(size: 8.4pt)[linkedin.com/in/mattji · github.com/shaoyanji]
    ]
  ])
#v(-4pt)
#line(length: 100%, stroke: 0.9pt + accent)

#section("Profil")
Zehn Jahre zwischen erneuerbaren Energien und kaufmännischer Steuerung, davon vier Jahre als Asset Manager eines Solarportfolios und drei Jahre mit
PPA- und Hedging-Modellen für Energieunternehmen. Was ich mitbringe, ist die Rechnung hinter dem Angebot: Wie viel ist eine Kilowattstunde unter
welchen Marktannahmen wert, welche Risiken trägt sie, und welcher Preis deckt die Struktur. Was ich nicht mitbringe, ist eine eigene Abschlussliste
im PPA-Vertrieb — dazu unten mehr, offen statt versteckt.

Bei O3 Energy verantwortete ich das Asset Management von Solarkraftwerken mit 10 MW installierter Leistung in einem Portfolio von über 100 Mio. USD.
Das hieß Ertrags- und Finanzmodelle, kaufmännische Steuerung des Betriebs, Due-Diligence-Prüfungen für O&M-Projekte und die Zusammenarbeit mit Kunden,
Banken und Deal-Brokern an einem Dutzend Projekten von je 4 bis 5 Mio. USD. Wer Zahlen dieser Art gegenüber einer Bank vertritt, lernt, wie PPA-Terme
den Wert einer Anlage verändern.

2023 kam das dreimonatige PPA-Mandat für die EWE Trading dazu: Preis- und Mengenrisiken über Gas- und Energieportfolios, Hedging- und Swing-Modelle,
Risikopositionen bis auf Handels- und Treasury-Ebene. Die Mandatsform ist ehrlich benannt — drei Monate als interner Risk Manager, keine Anstellung
über Jahre. Aus der Zeit stammen die Modelle, mit denen ich PPA-, Corporate- und Utility-Strukturen bewerte.

Technisch komme ich aus der Messseite: Heliostat-Messtechnik mit Interferometrie am Fraunhofer ISE, eine Masterarbeit zu Wetter und Volatilität am
Meteorologischen Institut Freiburg, in der ein neuartiges Verfahren zur zeitlichen Kreuzkorrelation von Winddaten über 70 Prozent genauer war als der
bisherige Ansatz. Wer Erträge prognostiziert, sollte wissen, woher die Zeitreihe kommt.

#section("Schwerpunkte")
#grid(columns: (1fr, 1fr), column-gutter: 14pt, row-gutter: 2pt,
  [*PPA-Modellierung* — Preis- und Ertragsstrukturen, Szenarien, Deckungsbeiträge],
  [*Risiko* — Preis-, Mengen- und Marktrisiken, Hedging- und Swing-Modelle],
  [*Solar-Asset-Management* — Ertragssteuerung, Betrieb, Verträge, Banken],
  [*Due Diligence* — O&M-Prüfungen, Projektbewertung, Datenqualität],
  [*Bewertung* — Finanzmodelle, Barwert, Sensitivitäten, Marktannahmen],
  [*Technik* — Anlagenperformance, Messtechnik, Speicherfragen],
  [*Schnittstellen* — Handel, Treasury, Management, externe Berater],
  [*Sprachen* — Deutsch C1, Englisch Muttersprache])

#section("Berufserfahrung")

#block(breakable: false)[
#job("Gründer und Berater", "Bountystash", "06/2020 – 08/2025", "Freiburg")
- PPA-Mandat für die EWE Trading (2023, drei Monate): Preis-, Mengen- und Marktrisiken über Gas- und Energieportfolios, Hedging- und Swing-Modelle, Risikoberichte für Handel, Treasury und Management.
- Risikoadjustierte PPA- und Handelsmodelle für Energieunternehmen: Options- und Absicherungsstrukturen, Sensitivitätsrechnungen, belastbare Entscheidungsgrundlagen statt Bauchgefühl.
- Beratung von Mandanten an der Schnittstelle von Energiemarkt und IT, inklusive der Frage, welche Daten eine Bewertung überhaupt tragen.
]

#block(breakable: false)[
#job("Asset Manager", "O3 Energy", "08/2016 – 06/2020", "Dallas, TX, USA")
- Asset Management von 10 MW PV-Leistung in einem Solarportfolio über 100 Mio. USD: Ertragsüberwachung, kaufmännische Steuerung, Vertrags- und Berichtswesen.
- Finanzmodelle und Ertragsprognosen für den Bestand, inklusive Abgleich von Messdaten und Modellannahmen.
- Due Diligence für O&M-Projekte als Vertretung der Projektleitung; Zusammenarbeit mit Kunden, Banken und Deal-Brokern an einem Dutzend Projekten von je 4 bis 5 Mio. USD.
- Aufbau der internen Software- und IT-Administration für das Unternehmen und seine Tochtergesellschaften.
]

#block(breakable: false)[
#job("Director of Sustainability", "Smart Energy 360", "08/2015 – 08/2016", "Dallas, TX, USA")
- Vertriebs- und Nachhaltigkeitsstrategien für gewerbliche Kunden, Beratung zu Energiestrategie, Cybersicherheitssoftware und Risikomanagement.
]

#block(breakable: false)[
#job("Wissenschaftliche Hilfskraft", "Fraunhofer ISE", "03/2012 – 09/2012", "Freiburg")
- Forschung zu Heliostat-Ungenauigkeiten mit Interferometrie; C++-Anwendung zur Ansteuerung des Messaufbaus, Python-Werkzeuge für Analyse und 3D-Geometrie.
]

#block(breakable: false)[
#job("Associate Technical Professional", "Halliburton", "06/2010 – 09/2011", "Williston, ND, USA")
- Leitung von zwei Frac-Crews mit über 3 Mio. USD Auftragsvolumen pro Woche; Fehlerdiagnose im Feld unter Zeitdruck.
]

#section("Studium und Forschung")

#block(breakable: false)[
#job("Masterarbeit: Wetter und Volatilität", "Meteorologisches Institut, Universität Freiburg", "2013 – 2014", "Freiburg")
- Neuartiges Verfahren zur zeitlichen Kreuzkorrelation von Windgeschwindigkeitsdaten, über 70 Prozent genauer als der bisherige Ansatz.
- Neuronale Netze auf Langzeit-Wetterdaten, um die Netzwirtschaftlichkeit fluktuierender Solar- und Windanlagen zu bewerten.
]

#section("Ausbildung")
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[M.Sc. Renewable Energy Management] #text(fill: muted)[— Albert-Ludwigs-Universität Freiburg]],
  [#text(size: 8pt, fill: muted)[2011 – 2014 · Note 1,8]])
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[B.Sc. Petroleum Engineering] #text(fill: muted)[— Colorado School of Mines, McBride Honors Program]],
  [#text(size: 8pt, fill: muted)[2006 – 2010 · GPA 3,2]])

#v(4pt)
#text(size: 7.8pt, fill: muted)[US-amerikanischer Staatsbürger mit unbefristeter deutscher Niederlassungserlaubnis, kein Sponsoring nötig · Deutsch C1, Englisch Muttersprache · Wohnsitz Gutach im Breisgau, Hamburg-Präsenz nach Vereinbarung · verfügbar ab 01.12.2026]
