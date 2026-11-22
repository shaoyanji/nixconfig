// ENVIRIA — Commercial Asset Manager Solar PV. Eigenständige deutsche Quelle.
#set page(paper: "a4", margin: (x: 1.5cm, y: 1.2cm))
#set text(font: "DejaVu Sans", size: 9.2pt, fill: rgb("#191919"), lang: "de")
#set par(justify: true, leading: 0.55em)
#set list(marker: text(fill: rgb("#1d4d3a"))[•], indent: 0.85em, spacing: 0.32em)
#let accent = rgb("#1d4d3a")
#let muted = rgb("#5c6b7a")
#let section(t) = block(above: 8pt, below: 2pt)[
  #text(size: 9.8pt, weight: "bold", fill: accent, tracking: 0.07em)[#upper(t)]
  #v(-3pt)
  #line(length: 100%, stroke: 0.5pt + rgb("#c3ced8"))
]
#let job(title, org, when) = block(above: 4pt, below: 1pt)[
  #grid(columns: (1fr, auto),
    [#text(weight: "bold")[#title] #text(fill: muted)[— #org]],
    [#text(size: 8pt, fill: muted)[#when]])
]

#grid(columns: (1fr, auto),
  [
    #text(size: 19pt, weight: "bold", fill: accent)[Matt Ji]
    #v(-2pt)
    #text(size: 9.8pt)[Commercial Asset Management · Solar PV · Energiewirtschaft]
  ],
  [
    #align(right)[
      #text(size: 8.4pt)[Am Burgerhof 4 · 79261 Gutach im Breisgau]
      #linebreak()
      #text(size: 8.4pt)[matt\@bountystash.com · +49 1733281570]
      #linebreak()
      #text(size: 8.4pt)[linkedin.com/in/mattji]
    ]
  ])
#v(-4pt)
#line(length: 100%, stroke: 0.9pt + accent)

#section("Profil")
Zehn Jahre kaufmännische Betreuung von Erneuerbare-Energien-Portfolios, davon vier als Asset Manager eines
Solarportfolios über 100 Mio. USD: Ertrags- und Bewertungsmodelle, die einer Bankenprüfung standhielten,
Due-Diligence-Prüfungen für O\&M-Projekte, Vertrags- und Dienstleistersteuerung sowie die Schnittstelle zu
Kunden, Banken und Deal-Brokern. Dazu PPA- und Handelsmodelle für Energieunternehmen, Risikosteuerung von
Gasspeicher- und Swing-Geschäften für die EWE Trading sowie ein MSc in Erneuerbare-Energien-Management. Ich
denke in Vollkosten pro kWh und in der Frage, was ein Vertrag in Jahr zehn kostet. Deutsch C1, Englisch
muttersprachlich, US-Staatsbürger mit unbefristeter Niederlassungserlaubnis.

#section("Schwerpunkte")
#grid(columns: (1fr, 1fr), column-gutter: 14pt, row-gutter: 2pt,
  [*Asset Management* — Betriebsphase, Dienstleistersteuerung, Reporting],
  [*Finanzmodellierung* — Ertrags-, Bewertungs- und PPA-Modelle, Bank-Audit],
  [*Energiewirtschaft* — PPA, Hedging, Gasspeicher, Swing, Wetterderivate],
  [*Risikomanagement* — Rahmenwerk, Haftungsrisiken, Limitsteuerung],
  [*Verträge & Due Diligence* — O\&M-Prüfung, kaufmännische Prüfung von Angeboten],
  [*Daten & Anlagenperformance* — Telemetrie-Abgleich, Kennzahlen, SQL, Python],
  [*Reporting* — Investoren- und Bankreporting, Abweichungsanalyse],
  [*Sprachen* — Deutsch C1, Englisch muttersprachlich])

#section("Berufserfahrung")

#job("Asset Manager", "O3 Energy, Dallas (TX)", "08/2016 – 06/2020")
- Leitung des Asset Managements eines Solarportfolios über 100 Mio. USD sowie Betrieb von 10 MW Solar-PV-Anlagen.
- Erstellung von Finanzmodellen und Ertragsprognosen, die als Grundlage für Bankenprüfungen und Investorenreporting dienten.
- Due-Diligence-Prüfungen für O\&M-Projekte eigenständig abgegrenzt und durchgeführt, als Vertretung der Projektleitung.
- Betreuung von Kunden, Banken und Deal-Brokern über ein Dutzend Projekte mit einem Volumen von je 4–5 Mio. USD.
- Abgleich von Zähler-, Wechselrichter- und Wetterdaten; fehlende Messwerte wurden zu einem expliziten Fehlerbudget statt zu einem guten Monat.
- Aufbau eines internen Risikomanagement-Rahmenwerks inklusive Analyse der Haftungsrisiken des Unternehmens.
- Mobile Erfassung für Außendiensttechniker, damit eine Inspektion denselben strukturierten Datensatz erzeugt wie eine Zählerablesung.
- Softwareeinführung und IT-Administration für das Unternehmen und seine Tochtergesellschaften.

#job("Gründer · Beratung für Energie- und Datenmodelle", "Bountystash", "06/2020 – 08/2025")
- Anpassung von PPA-Handelsmodellen für Energieversorgungsunternehmen an deren Beschaffungs- und Vermarktungslogik.
- Risikosteuerung von Gasspeicher- und Gas-Swing-Handelsmodellen als Risk Manager für die EWE Trading.
- Bewertungs- und Datenanwendungen für Kunden mit Landportfolios über 300 Mio. USD.
- Algorithmus für Optionsgeschäfte und Hedging auf Wetterderivate, inklusive Bewertung und Szenariorechnung.
- Aufbau eines Monitorings, das Anlagen- und Systemkennzahlen im Viertelstundentakt erfasst und jede Abweichung von „ok" meldet.

#job("Director of Sustainability", "Smart Energy 360, Dallas (TX)", "08/2015 – 08/2016")
- Verantwortung für eine Projektpipeline über 100 Mio. USD im Segment gewerblicher Kunden.
- Beratung zu Nachhaltigkeitsstrategie, Risikomanagement und Energiebeschaffung.
- Übersetzung technischer und regulatorischer Randbedingungen in entscheidungsfähige Empfehlungen für das Management.

#job("Wissenschaftlicher Mitarbeiter", "Fraunhofer ISE, Freiburg", "03/2012 – 09/2012")
- Vermessung von Heliostaten-Ungenauigkeiten mittels Interferometrie, inklusive der C++-Anwendung für das Messgerät.
- Umsetzung der Auswertung aus einer veröffentlichten Paraboloid-Arbeit in Python, samt 3D-Geometrie und statistischer Auswertung.
- Arbeit in festen Messkampagnen, in denen ein Ergebnis reproduzierbar sein musste und nicht nur plausibel.

#job("Associate Technical Professional", "Halliburton", "06/2010 – 09/2011")
- Behebung von Equipment- und Prozessproblemen im Feld, unter Zeitdruck und ohne zweiten Versuch.
- Verantwortung für die Sicherheitsschulung der Crew und Arbeit nach Verfahren ohne Abweichungstoleranz.

#section("Ausgewählte Projekte")
#grid(columns: (1fr, 1fr), column-gutter: 10pt, row-gutter: 5pt,
  [
    #text(weight: "bold")[Energie-Telemetrie und Bewertung] #text(size: 8pt, fill: muted)[— O3 Energy]
    #linebreak()
    Ertrags- und Bewertungsmodelle für ein Portfolio über 100 Mio. USD, die einer Bankenprüfung standhielten, plus
    ein Abgleich, der einen toten Sensor in einen bekannten Fehler verwandelte.
  ],
  [
    #text(weight: "bold")[Risk Calculation Engine] #text(size: 8pt, fill: muted)[— Swirl Engine]
    #linebreak()
    Berechnungsmotor für Risiko- und Bewertungsfragen mit nachvollziehbaren Eingaben, damit eine Zahl aus einem
    Modell prüfbar bleibt und nicht nur plausibel aussieht.
  ],
  [
    #text(weight: "bold")[PPA- und Hedging-Modelle] #text(size: 8pt, fill: muted)[— Beratung]
    #linebreak()
    Anpassung von Handelsmodellen für Energieunternehmen und Risikosteuerung von Gasspeicher- und Swing-Positionen
    für die EWE Trading.
  ],
  [
    #text(weight: "bold")[Flotten-Monitoring] #text(size: 8pt, fill: muted)[— nixconfig]
    #linebreak()
    Kennzahlen zu Jobstatus, Alter der Konfiguration, Speicherdruck und Systemlast im Viertelstundentakt, mit
    Meldung bei jeder Abweichung und Nachweis, wann was gemessen wurde.
  ])

#section("Ausbildung")
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[M.Sc. Renewable Energy Management] #text(fill: muted)[— Albert-Ludwigs-Universität Freiburg]],
  [#text(size: 8pt, fill: muted)[2011 – 2014 · Note 1,8]])
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[B.Sc. Petroleum Engineering] #text(fill: muted)[— Colorado School of Mines, McBride Honors Program]],
  [#text(size: 8pt, fill: muted)[2006 – 2010 · 3,2 GPA]])

#v(5pt)
#text(size: 7.8pt, fill: muted)[Deutsch C1 · Englisch muttersprachlich · US-Staatsbürger mit unbefristeter Niederlassungserlaubnis, arbeitsberechtigt ohne Visumssponsoring · Wechsel bereit, hybrid in Frankfurt nach Vereinbarung]
