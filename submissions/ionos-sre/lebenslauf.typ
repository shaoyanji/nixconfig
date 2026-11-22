// IONOS SE — Site Reliability Engineer (f/m/d), Application Hosting, Karlsruhe.
// Native German source replacing the Nix-built PDF. Nur belegbare Fakten.
#set page(paper: "a4", margin: (x: 1.5cm, y: 1.15cm))
#set text(font: "DejaVu Sans", size: 9.2pt, fill: rgb("#191919"), lang: "de")
#set par(justify: true, leading: 0.55em)
#set list(marker: text(fill: rgb("#2f3350"))[•], indent: 0.85em, spacing: 0.3em)
#let accent = rgb("#2f3350")
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
    #text(size: 9.8pt)[System- und Sicherheitsingenieur · deklarativer Betrieb · Linux]
  ],
  [
    #align(right)[
      #text(size: 8.4pt)[Am Burgerhof 4 · 79261 Gutach im Breisgau]
      #linebreak()
      #text(size: 8.4pt)[matt\@bountystash.com · +49 1733281570]
      #linebreak()
      #text(size: 8.4pt)[github.com/shaoyanji · linkedin.com/in/mattji]
    ]
  ])
#v(-4pt)
#line(length: 100%, stroke: 0.9pt + accent)

#section("Profil")
Betrieb ist entweder ein Repository oder ein Gerücht. Vier Jahre lang habe ich eine Flotte nach dem ersten Weg gefahren: ein
Flake deklariert dreizehn Hosts, jeder Host ist eine Feature-Liste, jeder Dienst ein Modul mit systemd-Unit und definiertem
Fehlerverhalten, Secrets liegen mit sops hinter einer Zertifizierungsstelle, die die Hostschlüssel ausstellt, und jede Generation
lässt sich per Zeiger zurückrollen statt aus dem Gedächtnis. Builds kommen aus einem geteilten Binary-Cache und von Remote-Buildern;
ein Host ist damit eine Funktion des Repositories und nichts Lokales.

Dieselben Maschinen bauen und bedienen die Dienste, die ich schreibe: Go-Dienste hinter einem Append-only-Eventlog, eine
Task-Schnittstelle mit typisierten Argumenten und Trockenläufen, ein E-Mail-Archiv, das seine Post selbst klassifiziert, und ein
Sentinel, der alle fünfzehn Minuten Jobstatus, Generation Age, Disk-Druck und Pressure Stall in ein Ledger schreibt und sowohl bei
einem schlechten Zustand als auch bei Stille alarmiert. Diese zweite Bedingung ist Absicht: Ein Monitor, der still stirbt, sieht
genau aus wie ein System ohne Befund.

Vor der Software war ich Risikoanalytiker: Covered-Call-Hedging für Kundenportfolios, Ertragsmodelle für ein Solarportfolio über
100 Mio. USD, Haftungsrahmen für ein Unternehmen mit Tochtergesellschaften, Heliostat-Messtechnik am Fraunhofer ISE. Daher kommt die
Incident-Haltung. Ein Postmortem ist nicht beendet, wenn die Unit wieder startet, sondern wenn die Ursache der Ursache ein Gate vor
sich hat und der Check, der den Fehler gefunden hat, Teil des Gates geworden ist statt einer Notiz.

Was ich nicht habe, ist die Skalierungshälfte dieser Rolle: dreizehn Hosts und ein Postgres-Archiv sind kein Application Hosting für
Millionen Kundinnen und Kunden, Kubernetes habe ich nicht produktiv betrieben, und Nextcloud nicht administriert. Das steht hier,
bevor es im ersten Gespräch steht.

#section("Schwerpunkte")
#grid(columns: (1fr, 1fr), column-gutter: 14pt, row-gutter: 2pt,
  [*Deklarativer Betrieb* — ein Flake, Hosts als Feature-Listen, Dienste als Module],
  [*Linux* — systemd-Units, nftables, Secrets, Zertifizierungsstelle, Binary-Cache],
  [*Incidents* — Ledger und Alarmierung, Postmortem mit strukturellem Check],
  [*Auslieferung* — Canary zuerst, Rollback als Zeiger, ein Gate für CI und Maschine],
  [*Automatisierung* — Go und Python hinter einer validierten Task-Oberfläche],
  [*Sicherheit* — sops, SSH-CA, Schwachstellen-Triage, Bedrohungsmodellierung],
  [*Telemetrie* — Jobstatus, Generation Age, Disk und PSI alle fünfzehn Minuten],
  [*Dokumentation* — erzeugt aus derselben Quelle wie die Konfiguration])

#section("Berufserfahrung")

#block(breakable: false)[
#job("Gründer", "Bountystash", "Jun 2020 – Aug 2025", "Freiburg, DE")
- Deklarierte eine ganze Flotte als ein Flake: dreizehn Hosts, jeder eine in Reihenfolge verkettete Feature-Liste, jeder Dienst ein Modul, damit die Optionsfläche ein Preis bleibt, den ein Gate zahlt, statt einer Kopie, die auseinanderläuft.
- Verschlüsselte jedes Secret mit sops und stellte Hostschlüssel über eine eigene SSH-Zertifizierungsstelle aus, sodass Zugriff ein kurzlebiges Zertifikat ist und kein Schlüssel, den jemand weitergegeben hat.
- Bediente Rebuilds aus einem geteilten Binary-Cache und von Remote-Buildern und machte Rollback zu einem Zeiger: jede Servergeneration kehrt mit einem Befehl zur vorigen zurück.
- Ließ in der CI dasselbe Modul-Gate laufen, das eine Maschine vor dem Umschalten besteht, angetrieben von einer Inventardatei, sodass eine kaputte Hostdefinition scheitert, bevor sie Hardware erreicht.
- Schrieb die Dienste, die die Flotte betreibt: Go hinter einem Append-only-Eventlog, Python für Analyse und Werkzeuge, PostgreSQL für Zustand, eine Task-Oberfläche mit typisierten Argumenten, Trockenläufen und JSON-Ausgabe für Aufrufer, die Programme sind.
- Führte Monitoring als geschlossenen Kreis: ein Ledger alle fünfzehn Minuten mit Jobstatus, Generation Age, Disk und PSI, gatus alarmiert bei jedem Zustand außer ok und bei Stille.
- Entwickelte eine Covered-Call-Hedging-Strategie für Kundenportfolios und prüfte Bug-Bounty-Programme, mit Triage gegen Listen bekannter ausgenutzter Schwachstellen statt gegen Eindrücke.
]

#block(breakable: false)[
#job("Asset Manager", "O3 Energy", "Aug 2016 – Jun 2020", "Dallas, TX")
- Verantwortete Datenqualität und Ertragsmodelle für ein Solarportfolio über 100 Mio. USD und führte drei Messreihen zu einer prüfbaren Zeitreihe zusammen.
- Administrierte Software und IT für das Unternehmen und seine Tochtergesellschaften, einschließlich Rollout, Zugriffen und der Dokumentation, die das wiederholbar machte.
- Analysierte Haftungsrisiken des Unternehmens und baute den internen Risikomanagementrahmen, an dem die Töchter danach gemessen wurden.
- Leitete ein internationales Team und baute eine Anreizstruktur an einem live gerechneten Finanzmodell — dort habe ich gelernt, dass Akzeptanz zuerst ein Designproblem ist und erst danach ein Kommunikationsproblem.
]

#block(breakable: false)[
#job("Director of Sustainability", "Smart Energy 360", "Aug 2015 – Aug 2016", "Dallas, TX")
- Beriet Geschäftskunden zu Energiestrategie, Sicherheitssoftware und Risiko und übersetzte in beide Richtungen zwischen technischen und kaufmännischen Lesern.
- Verantwortete Kundenservice und Betreuung und entwickelte Vertriebs- und Marketingstrategie für die Nachhaltigkeitspraxis.
]

#block(breakable: false)[
#job("Wissenschaftliche Hilfskraft", "Fraunhofer ISE", "Mär 2012 – Sep 2012", "Freiburg, DE")
- Schrieb die C++-Anwendung für ein Heliostat-Interferometer und die Python-Analyse daneben und prüfte die Geometrie anschließend unabhängig in Mathematica, statt der ersten Implementierung zu glauben.
]

#block(breakable: false)[
#job("Associate Technical Professional", "Halliburton", "Jun 2010 – Sep 2011", "Williston, ND, US")
- Leitete zwei Frac-Crews mit über 3 Mio. USD Arbeit pro Woche und diagnostizierte Geräte- und Prozessfehler unter Zeitdruck, während ein Terminplan von der Antwort abhing.
]

#section("Ausgewählte Arbeiten")
#grid(columns: (1fr, 1fr), column-gutter: 10pt, row-gutter: 5pt,
  [
    #text(weight: "bold")[nixconfig] #text(size: 8pt, fill: muted)[— deklarative Flotte]
    #linebreak()
    Dreizehn Hosts aus einem Flake, gepinnte Eingaben, hermetische Builds, sops-Secrets, SSH-CA, ein Gate pro Host. https://github.com/shaoyanji/nixconfig
  ],
  [
    #text(weight: "bold")[fleet-sentinel] #text(size: 8pt, fill: muted)[— Zuverlässigkeit]
    #linebreak()
    Jobstatus, Generation Age, Disk und PSI alle fünfzehn Minuten, Alarm bei schlechtem Zustand und bei Stille.
  ],
  [
    #text(weight: "bold")[Task-Control-Plane] #text(size: 8pt, fill: muted)[— Betrieb]
    #linebreak()
    Eine validierte Oberfläche mit typisierten Argumenten, Trockenlauf und JSON, von Menschen und von Agenten aufgerufen.
  ],
  [
    #text(weight: "bold")[E-Mail-Archiv] #text(size: 8pt, fill: muted)[— Klassifikation]
    #linebreak()
    Ein Archiv, das seine Post selbst klassifiziert, mit einem Urteil, das geschrieben und geschlossen wird.
  ],
  [
    #text(weight: "bold")[Swirl Engine] #text(size: 8pt, fill: muted)[— Go und Geometrie]
    #linebreak()
    Polygonflächen aus stochastischen Daten über den Satz von Green, mit einem Go-Fuzzer für die Formen, die es brechen.
  ],
  [
    #text(weight: "bold")[Schwachstellenbetrieb] #text(size: 8pt, fill: muted)[— Sicherheit]
    #linebreak()
    Triage offengelegter Schwachstellen nach Ausnutzung, Patchlage und tatsächlicher Betroffenheit der Flotte.
  ])

#section("Ausbildung")
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[M.Sc. Erneuerbare-Energien-Management] #text(fill: muted)[— Albert-Ludwigs-Universität Freiburg]],
  [#text(size: 8pt, fill: muted)[2011 – 2014 · Note 1,8]])
#text(size: 8.4pt)[Masterarbeit: fluktuierende erneuerbare Energien und Wettermuster, analysiert mit künstlichen neuronalen Netzen — ein Verfahren zur zeitlichen Kreuzkorrelation von Windgeschwindigkeiten.]
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[B.Sc. Erdöltechnik] #text(fill: muted)[— Colorado School of Mines, McBride Honors Program]],
  [#text(size: 8pt, fill: muted)[2006 – 2010 · 3,2 GPA]])

#v(4pt)
#text(size: 7.8pt, fill: muted)[Deutsch C1 · Englisch Muttersprache · US-Staatsbürger mit deutscher Niederlassungserlaubnis, keine Unterstützung nötig · Gutach im Breisgau · verfügbar ab 01.12.2026]
