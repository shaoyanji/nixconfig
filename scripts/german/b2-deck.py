#!/usr/bin/env python3
"""Build the telc-B2 study deck and merge it into an existing Anki collection.

The B1 deck on the sync server came from a 2018 `.apkg` (schema 11). Uploading a
collection replaces the server's, so this does not build a fresh file: it opens
the B1 collection, adds one notetype, two decks and the B2 notes, and writes the
merged collection out. That keeps the 5,264 B1 cards and their media references
exactly as they are.

Usage:
  b2-deck.py --b1 collection.anki2 --out collection-b2.anki2
"""

import argparse
import hashlib
import json
import random
import sqlite3
import string
import time

DECK_KONNEKTOREN = 1700000001
DECK_UEBEN = 1700000002
DECK_SCHREIBEN = 1700000003
MODEL_B2 = 1700000000
FIRST_NOTE_ID = 1700000000000

NEW_THIS_SESSION = 20


def back(*lines):
    return "<br>".join(lines)


def konnektor(funktion, stellung, beispiel, tipp):
    return back(
        f"<b>Funktion:</b> {funktion}",
        f"<b>Satzstellung:</b> {stellung}",
        f"<b>Beispiel:</b> <i>{beispiel}</i>",
        f"<b>Tipp:</b> {tipp}",
    )


# (front, back, tags)
KONNEKTOREN = [
    (
        "obwohl",
        konnektor(
            "Einräumung / Gegensatz: der Gegensatz besteht trotzdem.",
            "Subjunktion → Nebensatz, konjugiertes Verb am Ende. Der Hauptsatz kann davor oder dahinter stehen.",
            "Obwohl der Kurs teuer war, hat er sich gelohnt.",
            "Nach dem Nebensatz muss der Hauptsatz vollständig folgen: „Obwohl es regnete, gingen wir …“, nicht „…, wir gingen“.",
        ),
        "konnektoren gegensatz subjunktion",
    ),
    (
        "trotzdem",
        konnektor(
            "Gegensatz zur vorherigen Aussage (Folge eines Zugeständnisses).",
            "Adverb → Position 1 oder mitten im Satz; das Verb bleibt an Position 2.",
            "Es regnete stark. Trotzdem machten wir einen Ausflug.",
            "Nicht mit „trotz“ verwechseln: „trotz“ steht vor einem Nomen mit Genitiv (trotz des Regens).",
        ),
        "konnektoren gegensatz adverb",
    ),
    (
        "dennoch",
        konnektor(
            "wie „trotzdem“, aber schriftlich und gehoben.",
            "Adverb → Position 1 oder nach dem Verb; Verb an Position 2.",
            "Das Angebot war günstig. Dennoch habe ich abgelehnt.",
            "In Beschwerdebriefen sehr passend; im Gespräch klingt „trotzdem“ natürlicher.",
        ),
        "konnektoren gegensatz adverb schreiben",
    ),
    (
        "zwar … aber",
        konnektor(
            "Einräumung mit Gegensatz: erst zustimmen, dann einschränken.",
            "„zwar“ eröffnet einen Hauptsatz (Verb an Position 2), „aber“ den zweiten.",
            "Zwar ist die Wohnung klein, aber sie liegt sehr zentral.",
            "Steht „zwar“ auf Position 1, rutscht das Verb direkt dahinter: „Zwar ist die Wohnung …“, nicht „Zwar die Wohnung ist …“.",
        ),
        "konnektoren gegensatz zweiteilig",
    ),
    (
        "zwar … dennoch",
        konnektor(
            "Einräumung, im zweiten Teil formeller als „aber“.",
            "zwar + Hauptsatz, dann dennoch + Hauptsatz (Verb an Position 2).",
            "Zwar war die Prüfung schwer, dennoch haben alle bestanden.",
            "Zwei Sätze statt einer Konstruktion — im Brief wirkt das ruhiger als ein langer Satz mit „aber“.",
        ),
        "konnektoren gegensatz zweiteilig schreiben",
    ),
    (
        "allerdings",
        konnektor(
            "Einschränkung: „aber“ im Ton freundlicher, oft nach einer Zustimmung.",
            "Adverb → meist nach dem Verb oder auf Position 1.",
            "Das Hotel war sauber. Allerdings war das Zimmer sehr laut.",
            "„allerdings“ allein heißt schon „aber“ — kein zusätzliches „aber“ im selben Satz.",
        ),
        "konnektoren gegensatz adverb",
    ),
    (
        "jedoch",
        konnektor(
            "Gegensatz, schriftlich; steht oft mitten im Satz.",
            "Adverb → Position 1 oder nach dem Bezugswort; Wortstellung bleibt sonst unverändert.",
            "Die Lieferung kam pünktlich, die Verpackung jedoch war beschädigt.",
            "Mitten im Satz ist „jedoch“ die eleganteste Variante im Brief.",
        ),
        "konnektoren gegensatz adverb schreiben",
    ),
    (
        "hingegen",
        konnektor(
            "Gegenüberstellung zweier Aussagen oder Personen.",
            "Adverb → Position 1 oder nach dem Bezugswort.",
            "Im Sommer ist es hier heiß, im Winter hingegen sehr kalt.",
            "Für Vergleiche; „dagegen“ ist die mündlichere Variante.",
        ),
        "konnektoren gegensatz adverb",
    ),
    (
        "dagegen",
        konnektor(
            "Gegensatz (Adverb); als Präposition „gegen“ + Akkusativ.",
            "Adverb → Position 1 oder nach dem Verb.",
            "Ich trinke lieber Tee, mein Bruder trinkt dagegen Kaffee.",
            "Präposition: „Ich habe nichts gegen den Plan.“",
        ),
        "konnektoren gegensatz adverb",
    ),
    (
        "deshalb",
        konnektor(
            "Folge: die zweite Aussage ist die Konsequenz der ersten.",
            "Adverb → Position 1, Verb an Position 2.",
            "Ich hatte keine Zeit, deshalb habe ich nicht geantwortet.",
            "„deshalb“ nennt die FOLGE, nicht den Grund. Der Grund kommt mit „weil“ oder „denn“.",
        ),
        "konnektoren folge adverb",
    ),
    (
        "deswegen",
        konnektor(
            "= deshalb (gleiche Bedeutung und Stellung).",
            "Adverb → Position 1, Verb an Position 2.",
            "Der Zug fiel aus, deswegen kam ich zu spät.",
            "Austauschbar mit „deshalb“; im Brief „deshalb“ oder „daher“ bevorzugen.",
        ),
        "konnektoren folge adverb",
    ),
    (
        "daher",
        konnektor(
            "Folge, schriftlicher als „deshalb“.",
            "Adverb → Position 1, Verb an Position 2.",
            "Die Preise sind gestiegen; daher bleiben viele Kunden aus.",
            "Sehr passend in der Argumentation eines Briefes oder Aufsatzes.",
        ),
        "konnektoren folge adverb schreiben",
    ),
    (
        "folglich",
        konnektor(
            "logische Folge, formell.",
            "Adverb → Position 1, Verb an Position 2.",
            "Die Frist ist abgelaufen. Folglich ist die Bewerbung nicht mehr gültig.",
            "Nur wenn die Folge wirklich zwingend ist; sonst klingt es übertrieben.",
        ),
        "konnektoren folge adverb schreiben",
    ),
    (
        "infolgedessen",
        konnektor(
            "Folge im Amts- und Geschäftsstil.",
            "Adverb → Position 1, Verb an Position 2.",
            "Es gab keine Einwände; infolgedessen wurde der Plan angenommen.",
            "Sehr formell — in einer Prüfung ein Plus, im Alltag selten.",
        ),
        "konnektoren folge adverb schreiben",
    ),
    (
        "weil",
        konnektor(
            "Grund / Ursache.",
            "Subjunktion → Nebensatz, Verb am Ende.",
            "Ich bleibe zu Hause, weil ich krank bin.",
            "Vergleiche: „denn“ (Hauptsatz, Position 0) und „wegen“ (Präposition + Genitiv).",
        ),
        "konnektoren grund subjunktion",
    ),
    (
        "denn",
        konnektor(
            "Grund, aber als Hauptsatzkonjunktion.",
            "Position 0: die Wortstellung bleibt wie im Hauptsatz (Subjekt + Verb).",
            "Ich bleibe zu Hause, denn ich bin krank.",
            "Nach „denn“ folgt keine Verbletztstellung — der häufigste Fehler bei diesem Wort.",
        ),
        "konnektoren grund konjunktion",
    ),
    (
        "wegen",
        konnektor(
            "Grund, als Präposition vor einem Nomen.",
            "Präposition mit Genitiv: wegen des schlechten Wetters.",
            "Wegen des Streiks kam der Bus nicht.",
            "„wegen dem Wetter“ hört man, ist aber umgangssprachlich — im Brief „wegen des Wetters“.",
        ),
        "konnektoren grund präposition genitiv",
    ),
    (
        "aufgrund",
        konnektor(
            "Grund, formeller als „wegen“.",
            "Präposition mit Genitiv: aufgrund der vielen Anfragen.",
            "Aufgrund der vielen Anfragen müssen wir den Termin verschieben.",
            "Feststehend: „aufgrund“ (ein Wort), nicht „auf Grund“.",
        ),
        "konnektoren grund präposition genitiv schreiben",
    ),
    (
        "trotz",
        konnektor(
            "Gegensatz, als Präposition vor einem Nomen.",
            "Präposition mit Genitiv: trotz des Regens.",
            "Trotz des Regens fand das Fest im Garten statt.",
            "Der Satz mit „trotz“ hat keinen Nebensatz — deshalb braucht er ein normales Hauptsatz-Verb.",
        ),
        "konnektoren gegensatz präposition genitiv",
    ),
    (
        "zumal",
        konnektor(
            "zusätzlicher, verstärkender Grund (gehoben).",
            "Subjunktion → Nebensatz, Verb am Ende.",
            "Ich nehme den Zug, zumal ich dann während der Fahrt arbeiten kann.",
            "Signalisiert: der Grund kommt obendrauf, es gibt schon einen anderen.",
        ),
        "konnektoren grund subjunktion",
    ),
    (
        "während (temporal)",
        konnektor(
            "zwei Handlungen laufen gleichzeitig.",
            "Subjunktion → Nebensatz, Verb am Ende.",
            "Während ich koche, hört er Musik.",
            "Gleichzeitigkeit: beide Teile stehen normalerweise im gleichen Tempus.",
        ),
        "konnektoren temporal subjunktion",
    ),
    (
        "während (kontrastiv)",
        konnektor(
            "Gegensatz zwischen zwei Aussagen (schriftlich).",
            "Subjunktion → Nebensatz, Verb am Ende.",
            "Während die einen sparen, geben die anderen immer mehr Geld aus.",
            "In Aufsätzen die schönste Form des Gegensatzes; im Brief eher „hingegen“.",
        ),
        "konnektoren gegensatz subjunktion schreiben",
    ),
    (
        "nachdem",
        konnektor(
            "Vorzeitigkeit: eine Handlung ist abgeschlossen, bevor die nächste beginnt.",
            "Subjunktion → Nebensatz; Zeitfolge: Plusquamperfekt im Nebensatz, Präteritum/Perfekt im Hauptsatz.",
            "Nachdem ich gegessen hatte, ging ich spazieren.",
            "„Nachdem ich gegessen habe, ging ich“ ist falsch — die Zeiten müssen die Reihenfolge zeigen.",
        ),
        "konnektoren temporal subjunktion",
    ),
    (
        "bevor",
        konnektor(
            "Nachzeitigkeit: die Handlung im Hauptsatz kommt zuerst.",
            "Subjunktion → Nebensatz, Verb am Ende.",
            "Bevor ich gehe, räume ich die Küche auf.",
            "Gleiche Zeitform in beiden Teilen ist normal (Gegenteil von „nachdem“).",
        ),
        "konnektoren temporal subjunktion",
    ),
    (
        "seitdem",
        konnektor(
            "Beginn in der Vergangenheit, Wirkung bis jetzt.",
            "Subjunktion → Nebensatz, Verb am Ende.",
            "Seitdem ich in Berlin wohne, fahre ich fast täglich Rad.",
            "Hauptsatz im Präsens, wenn die Wirkung bis heute gilt.",
        ),
        "konnektoren temporal subjunktion",
    ),
    (
        "solange",
        konnektor(
            "Zeitraum, in dem etwas gilt.",
            "Subjunktion → Nebensatz, Verb am Ende.",
            "Solange die Heizung nicht repariert ist, bleibt die Wohnung kalt.",
            "Nicht mit „so lange“ (Dauer als Angabe) verwechseln.",
        ),
        "konnektoren temporal subjunktion",
    ),
    (
        "bis",
        konnektor(
            "Endpunkt einer Handlung.",
            "Subjunktion → Nebensatz, Verb am Ende.",
            "Warte bitte, bis ich fertig bin.",
            "Nach „bis“ kein „dass“ und kein „wenn“.",
        ),
        "konnektoren temporal subjunktion",
    ),
    (
        "sobald",
        konnektor(
            "unmittelbar nach einem Zeitpunkt; „so früh wie möglich“.",
            "Subjunktion → Nebensatz, Verb am Ende.",
            "Sobald ich die Ergebnisse habe, schreibe ich Ihnen.",
            "Im Brief die höfliche Alternative zu „wenn … dann“.",
        ),
        "konnektoren temporal subjunktion schreiben",
    ),
    (
        "als (einmalig)",
        konnektor(
            "einmaliges Ereignis in der Vergangenheit.",
            "Subjunktion → Nebensatz, Verb am Ende; Vergangenheit.",
            "Als ich in Hamburg ankam, regnete es.",
            "Einmalig → „als“; wiederholt oder Gegenwart → „wenn“.",
        ),
        "konnektoren temporal subjunktion",
    ),
    (
        "wenn (wiederholt / Gegenwart)",
        konnektor(
            "wiederholtes Ereignis oder Bedingung in Gegenwart und Zukunft.",
            "Subjunktion → Nebensatz, Verb am Ende.",
            "Wenn ich Zeit habe, komme ich vorbei.",
            "Auch Bedingung: „Wenn die Ware morgen kommt, ist alles in Ordnung.“",
        ),
        "konnektoren temporal subjunktion bedingung",
    ),
    (
        "falls",
        konnektor(
            "Bedingung, deren Eintreten unsicher ist.",
            "Subjunktion → Nebensatz, Verb am Ende.",
            "Falls Sie Fragen haben, rufen Sie mich bitte an.",
            "Höflicher und vorsichtiger als „wenn“; im Brief sehr üblich.",
        ),
        "konnektoren bedingung subjunktion schreiben",
    ),
    (
        "sofern",
        konnektor(
            "Bedingung, formell und geschäftlich.",
            "Subjunktion → Nebensatz, Verb am Ende.",
            "Sofern die Ware bis Freitag eintrifft, halten wir den Termin.",
            "Nur in formellen Texten; „falls“ ist die allgemeinere Wahl.",
        ),
        "konnektoren bedingung subjunktion schreiben",
    ),
    (
        "wenn … dann",
        konnektor(
            "Bedingung mit Nachdruck auf der Folge.",
            "Nebensatz mit „wenn“, danach „dann“ auf Position 1 des Hauptsatzes (Verb an Position 2).",
            "Wenn die Lieferung nicht kommt, dann storniere ich die Bestellung.",
            "„dann“ ist optional, macht die Folge aber klar — gut in Beschwerden.",
        ),
        "konnektoren bedingung zweiteilig",
    ),
    (
        "damit",
        konnektor(
            "Ziel / Absicht, wenn die Subjekte verschieden sind.",
            "Subjunktion → Nebensatz, Verb am Ende.",
            "Ich spreche langsam, damit du mich verstehst.",
            "Gleiches Subjekt in beiden Teilen → besser „um … zu“.",
        ),
        "konnektoren ziel subjunktion",
    ),
    (
        "um … zu",
        konnektor(
            "Ziel / Absicht bei gleichem Subjekt.",
            "Infinitivkonstruktion: um + … + zu + Infinitiv am Satzende.",
            "Ich lerne jeden Tag, um die Prüfung zu bestehen.",
            "Kein eigenes Subjekt möglich: „um die Prüfung zu bestehen“ hat kein „ich“.",
        ),
        "konnektoren ziel infinitiv",
    ),
    (
        "sodass",
        konnektor(
            "Folge einer Handlung oder eines Umstands.",
            "Subjunktion → Nebensatz, Verb am Ende.",
            "Es regnete in Strömen, sodass das Fest ausfiel.",
            "Wenn ein Adjektiv die Folge auslöst: „so … dass“ (so kalt, dass …).",
        ),
        "konnektoren folge subjunktion",
    ),
    (
        "so … dass",
        konnektor(
            "Folge mit Gradangabe (Adjektiv oder Adverb).",
            "„so“ steht beim Adjektiv im Hauptsatz, „dass“ leitet den Nebensatz ein (Verb am Ende).",
            "Es war so kalt, dass die Heizung ausfiel.",
            "Nicht „so … sodass“ — entweder „so … dass“ oder „sodass“.",
        ),
        "konnektoren folge subjunktion zweiteilig",
    ),
    (
        "indem",
        konnektor(
            "Mittel / Methode: auf welche Weise etwas geschieht.",
            "Subjunktion → Nebensatz, Verb am Ende.",
            "Man lernt eine Sprache, indem man sie täglich benutzt.",
            "Nicht für Ziele („damit“/„um zu“), sondern für das Wie.",
        ),
        "konnektoren mittel subjunktion",
    ),
    (
        "ohne dass / ohne … zu",
        konnektor(
            "fehlende Begleitumstände.",
            "„ohne dass“ + Nebensatz (Verb Ende) bei verschiedenem Subjekt; „ohne … zu“ + Infinitiv bei gleichem.",
            "Er ging, ohne dass sie es merkte. / Er ging, ohne ein Wort zu sagen.",
            "Häufiger Fehler: „ohne dass ich sage“ statt „ohne zu sagen“ bei gleichem Subjekt.",
        ),
        "konnektoren infinitiv subjunktion",
    ),
    (
        "anstatt dass / anstatt … zu",
        konnektor(
            "Ersatz: das eine geschieht statt des anderen.",
            "„anstatt dass“ + Nebensatz; „anstatt … zu“ + Infinitiv (gleiches Subjekt).",
            "Er spielt, anstatt zu lernen.",
            "Auch „statt“ möglich; im Schriftlichen „anstatt“.",
        ),
        "konnektoren infinitiv subjunktion",
    ),
    (
        "je … desto",
        konnektor(
            "proportionale Steigerung: eins wächst mit dem anderen.",
            "„je“ + Komparativ am Anfang des Nebensatzes (Verb am Ende), „desto“ + Komparativ auf Position 1 des Hauptsatzes (Verb an Position 2).",
            "Je mehr ich übe, desto sicherer werde ich.",
            "„desto“ und „umso“ sind austauschbar; nie „je … je“.",
        ),
        "konnektoren steigerung zweiteilig",
    ),
    (
        "einerseits … andererseits",
        konnektor(
            "zwei Seiten einer Sache.",
            "Zwei Hauptsätze; nach „einerseits“ und „andererseits“ steht das Verb an Position 2.",
            "Einerseits ist der Job gut bezahlt, andererseits ist er sehr stressig.",
            "Perfekt für die Argumentation im Aufsatz; im Brief eher „zum einen … zum anderen“.",
        ),
        "konnektoren zweiteilig argumentation",
    ),
    (
        "zum einen … zum anderen",
        konnektor(
            "zwei Gesichtspunkte aufzählen.",
            "Zwei Hauptsätze, Verb jeweils an Position 2.",
            "Zum einen fehlt das Zertifikat, zum anderen war die Gruppe zu groß.",
            "Im Brief die elegantere Variante von „einerseits … andererseits“.",
        ),
        "konnektoren zweiteilig schreiben",
    ),
    (
        "nicht nur … sondern auch",
        konnektor(
            "Steigerung / Zusatz.",
            "Zwei Hauptsätze oder zwei Satzteile; nach „sondern auch“ normale Wortstellung.",
            "Ich brauche nicht nur das Zertifikat, sondern auch mehr Sicherheit beim Sprechen.",
            "„sondern“ nur nach einer Verneinung oder Einschränkung (nicht nur …).",
        ),
        "konnektoren zweiteilig",
    ),
    (
        "sowohl … als auch",
        konnektor(
            "beides zusammen, ohne Steigerung.",
            "Verbindet zwei gleichrangige Satzteile.",
            "Sowohl die Lehrerin als auch die Gruppe waren gut.",
            "Achtung Wortstellung: das Verb richtet sich nach dem zweiten Teil.",
        ),
        "konnektoren zweiteilig",
    ),
    (
        "entweder … oder",
        konnektor(
            "Alternative: nur eins von beiden.",
            "Zwei Hauptsätze oder Satzteile; Verb an Position 2.",
            "Entweder wir treffen uns um acht, oder wir verschieben den Termin.",
            "Nicht „entweder … oder aber“ — eins reicht.",
        ),
        "konnektoren zweiteilig",
    ),
    (
        "weder … noch",
        konnektor(
            "beides verneint.",
            "Verbindet zwei Satzteile; das Verb bleibt im Singular oder richtet sich nach dem letzten Teil.",
            "Ich habe weder Zeit noch Geld.",
            "Kein zusätzliches „nicht“ im Satz — „weder“ verneint schon.",
        ),
        "konnektoren zweiteilig negation",
    ),
    (
        "also (Folgerung)",
        konnektor(
            "Folgerung / Zusammenfassung aus dem Gesagten.",
            "Adverb → Position 1 oder mitten im Satz, Verb an Position 2.",
            "Die Frist ist abgelaufen, also ist die Bewerbung nicht mehr gültig.",
            "Nicht mit „also“ als Füllwort („also, ich meine …“) verwechseln — das gehört nicht in einen Brief.",
        ),
        "konnektoren folge adverb",
    ),
    (
        "außerdem",
        konnektor(
            "Zusatz: noch ein Punkt kommt dazu.",
            "Adverb → Position 1, Verb an Position 2.",
            "Außerdem benötige ich eine Bestätigung für meinen Arbeitgeber.",
            "Der Standard für den zweiten Punkt im Brief; nicht zweimal hintereinander verwenden.",
        ),
        "konnektoren zusatz adverb schreiben",
    ),
    (
        "darüber hinaus",
        konnektor(
            "Zusatz, formeller als „außerdem“.",
            "Adverb → Position 1, Verb an Position 2.",
            "Darüber hinaus bitte ich um eine Bestätigung der Buchung.",
            "Gut, um zwei formelle Punkte zu trennen.",
        ),
        "konnektoren zusatz adverb schreiben",
    ),
    (
        "des Weiteren",
        konnektor(
            "Zusatz im Geschäftsstil.",
            "Adverb → Position 1, Verb an Position 2.",
            "Des Weiteren möchte ich wissen, ob die Kursgebühr das Material enthält.",
            "Sehr formell; „des Weiteren“ wird getrennt geschrieben.",
        ),
        "konnektoren zusatz adverb schreiben",
    ),
    (
        "zunächst",
        konnektor(
            "erster Punkt einer Aufzählung.",
            "Adverb → Position 1, Verb an Position 2.",
            "Zunächst möchte ich mich für Ihre schnelle Antwort bedanken.",
            "Danach: „außerdem“, „darüber hinaus“, „schließlich“.",
        ),
        "konnektoren reihenfolge adverb schreiben",
    ),
    (
        "schließlich",
        konnektor(
            "letzter Punkt oder abschließendes Argument.",
            "Adverb → Position 1, Verb an Position 2.",
            "Schließlich möchte ich Sie bitten, mir die Bestätigung zuzusenden.",
            "Nicht „zum Schluss“ mit „schließlich“ (Bedeutung: am Ende / immerhin) verwechseln.",
        ),
        "konnektoren reihenfolge adverb schreiben",
    ),
    (
        "übrigens",
        konnektor(
            "Nebenbemerkung, die nicht zum Hauptpunkt gehört.",
            "Adverb → Position 1, Verb an Position 2.",
            "Übrigens hat mir Ihre Kollegin bereits geholfen.",
            "Im formellen Brief sparsam einsetzen — eher mündlich.",
        ),
        "konnektoren zusatz adverb",
    ),
    (
        "meiner Meinung nach",
        konnektor(
            "eigene Meinung einleiten.",
            "Position 1 → Verb an Position 2 (meiner Meinung nach IST das falsch).",
            "Meiner Meinung nach ist die Kursgebühr zu hoch.",
            "Nicht „meiner Meinung nach, dass …“ — danach folgt ein normaler Hauptsatz.",
        ),
        "konnektoren meinung schreiben",
    ),
    (
        "obgleich / obschon",
        konnektor(
            "= obwohl, gehoben und schriftlich.",
            "Subjunktion → Nebensatz, Verb am Ende.",
            "Obgleich die Zeit knapp war, hat sie alle Punkte bearbeitet.",
            "In Prüfungen ein Zeichen für Wortschatzbreite; Bedeutung identisch mit „obwohl“.",
        ),
        "konnektoren gegensatz subjunktion schreiben",
    ),
]

UEBEN = [
    (
        "____ ich seit drei Jahren Deutsch lerne, mache ich noch Fehler bei den Konnektoren.",
        "Obwohl<br><i>Obwohl ich seit drei Jahren Deutsch lerne, mache ich noch Fehler.</i><br>Einräumung → Subjunktion, Verb am Ende (lerne).",
        "ueben luecke gegensatz",
    ),
    (
        "Es regnete in Strömen. ____ beschlossen wir, zu Fuß zu gehen.",
        "Trotzdem<br><i>Trotzdem beschlossen wir, zu Fuß zu gehen.</i><br>Adverb auf Position 1, Verb (beschlossen) an Position 2.",
        "ueben luecke gegensatz",
    ),
    (
        "Ich habe den Vertrag nicht unterschrieben, ____ ich einige Punkte nicht verstanden habe.",
        "weil<br><i>…, weil ich einige Punkte nicht verstanden habe.</i><br>Grund im Nebensatz → Verb am Ende.",
        "ueben luecke grund",
    ),
    (
        "Ich habe einige Punkte nicht verstanden, ____ habe ich den Vertrag nicht unterschrieben.",
        "deshalb<br><i>…, deshalb habe ich den Vertrag nicht unterschrieben.</i><br>Folge auf Position 1, Verb an Position 2.",
        "ueben luecke folge",
    ),
    (
        "____ der hohen Kosten hat die Firma das Projekt fortgesetzt.",
        "Trotz<br><i>Trotz der hohen Kosten hat die Firma das Projekt fortgesetzt.</i><br>Präposition mit Genitiv — kein Nebensatz, deshalb „hat“ an Position 2.",
        "ueben luecke gegensatz genitiv",
    ),
    (
        "____ des schlechten Wetters fand das Fest im Garten statt.",
        "Trotz<br><i>Trotz des schlechten Wetters fand das Fest im Garten statt.</i><br>„Wegen“ würde einen Grund nennen; hier ist es ein Gegensatz.",
        "ueben luecke gegensatz genitiv",
    ),
    (
        "Ich spreche langsam, ____ Sie mich besser verstehen.",
        "damit<br><i>…, damit Sie mich besser verstehen.</i><br>Verschiedene Subjekte (ich / Sie) → „damit“, nicht „um … zu“.",
        "ueben luecke ziel",
    ),
    (
        "Ich lerne jeden Tag, ____ die Prüfung zu bestehen.",
        "um<br><i>…, um die Prüfung zu bestehen.</i><br>Gleiches Subjekt → Infinitivkonstruktion.",
        "ueben luecke ziel infinitiv",
    ),
    (
        "Er hat mir geholfen, ____ ich ihn nicht darum gebeten hatte.",
        "obwohl<br><i>…, obwohl ich ihn nicht darum gebeten hatte.</i><br>Einräumung im Nebensatz.",
        "ueben luecke gegensatz",
    ),
    (
        "Die Prüfung war schwer, ____ haben fast alle Teilnehmer bestanden.",
        "dennoch<br><i>…, dennoch haben fast alle Teilnehmer bestanden.</i><br>Gegensatz als Adverb; „trotzdem“ passt hier ebenso.",
        "ueben luecke gegensatz",
    ),
    (
        "Ich weiß noch nicht, ____ ich am Kurs teilnehmen kann.",
        "ob<br><i>…, ob ich am Kurs teilnehmen kann.</i><br>Indirekte Frage → „ob“, nicht „wenn“.",
        "ueben luecke nebensatz",
    ),
    (
        "____ Sie Fragen haben, können Sie mich jederzeit anrufen.",
        "Falls<br><i>Falls Sie Fragen haben, können Sie mich jederzeit anrufen.</i><br>Unsichere Bedingung; „Wenn“ wäre auch korrekt, „Falls“ ist vorsichtiger.",
        "ueben luecke bedingung",
    ),
    (
        "____ die Ware bis Freitag eintrifft, halten wir den Termin.",
        "Sofern<br><i>Sofern die Ware bis Freitag eintrifft, halten wir den Termin.</i><br>Formelle Bedingung, Verb im Nebensatz am Ende (eintrifft).",
        "ueben luecke bedingung",
    ),
    (
        "Es war so kalt, ____ wir die Heizung den ganzen Tag laufen ließen.",
        "dass<br><i>Es war so kalt, dass wir die Heizung … laufen ließen.</i><br>„so“ + Adjektiv im Hauptsatz, „dass“ im Nebensatz.",
        "ueben luecke folge",
    ),
    (
        "Sie sprach sehr leise, ____ ich sie kaum verstand.",
        "sodass<br><i>…, sodass ich sie kaum verstand.</i><br>Folge ohne Gradangabe → „sodass“ (ein Wort).",
        "ueben luecke folge",
    ),
    (
        "____ ich die Ergebnisse habe, schreibe ich Ihnen.",
        "Sobald<br><i>Sobald ich die Ergebnisse habe, schreibe ich Ihnen.</i><br>Unmittelbar nach dem Zeitpunkt; im Brief sehr üblich.",
        "ueben luecke temporal schreiben",
    ),
    (
        "____ ich in Berlin wohne, fahre ich fast täglich Rad.",
        "Seitdem<br><i>Seitdem ich in Berlin wohne, fahre ich fast täglich Rad.</i><br>Beginn in der Vergangenheit, Wirkung bis jetzt.",
        "ueben luecke temporal",
    ),
    (
        "Je mehr ich lese, ____ besser verstehe ich die Texte.",
        "desto<br><i>Je mehr ich lese, desto besser verstehe ich die Texte.</i><br>„desto“ + Komparativ auf Position 1, Verb danach.",
        "ueben luecke steigerung",
    ),
    (
        "Ich habe ____ Zeit ____ Geld für einen zweiten Kurs.",
        "weder … noch<br><i>Ich habe weder Zeit noch Geld für einen zweiten Kurs.</i><br>Doppelte Verneinung; kein zusätzliches „nicht“.",
        "ueben luecke zweiteilig",
    ),
    (
        "____ die Lehrerin ____ die Gruppe waren sehr geduldig.",
        "Sowohl … als auch<br><i>Sowohl die Lehrerin als auch die Gruppe waren sehr geduldig.</i><br>Beides zusammen; das Verb richtet sich nach dem zweiten Teil (waren).",
        "ueben luecke zweiteilig",
    ),
]

UMSCHREIBEN = [
    (
        "Schreibe mit „obwohl“: Es regnete stark. Wir machten einen Ausflug.",
        "Obwohl es stark regnete, machten wir einen Ausflug.<br>Nebensatz zuerst, dann Verb des Hauptsatzes direkt nach dem Komma.",
        "ueben umschreiben gegensatz",
    ),
    (
        "Schreibe mit „trotzdem“: Obwohl es stark regnete, machten wir einen Ausflug.",
        "Es regnete stark. Trotzdem machten wir einen Ausflug.<br>Zwei Hauptsätze; „trotzdem“ auf Position 1, Verb an Position 2.",
        "ueben umschreiben gegensatz",
    ),
    (
        "Schreibe mit „trotz“: Obwohl das Wetter schlecht war, fand das Fest statt.",
        "Trotz des schlechten Wetters fand das Fest statt.<br>Nomen statt Nebensatz: „trotz“ + Genitiv.",
        "ueben umschreiben gegensatz genitiv",
    ),
    (
        "Schreibe mit „deshalb“: Ich konnte nicht kommen, weil ich krank war.",
        "Ich war krank, deshalb konnte ich nicht kommen.<br>Grund → Folge; Verb bleibt an Position 2.",
        "ueben umschreiben folge",
    ),
    (
        "Schreibe mit „weil“: Wegen des Streiks kam der Bus nicht.",
        "Der Bus kam nicht, weil es einen Streik gab.<br>Die Präposition wird zum Nebensatz mit Verb am Ende.",
        "ueben umschreiben grund",
    ),
    (
        "Schreibe mit „um … zu“: Ich lerne Deutsch, damit ich in Deutschland studieren kann.",
        "Ich lerne Deutsch, um in Deutschland studieren zu können.<br>Gleiches Subjekt → Infinitivkonstruktion, „zu“ vor dem Infinitiv am Ende.",
        "ueben umschreiben ziel infinitiv",
    ),
    (
        "Schreibe mit „obwohl“: Er hatte wenig Zeit. Er half mir trotzdem.",
        "Obwohl er wenig Zeit hatte, half er mir.<br>„trotzdem“ fällt weg, weil „obwohl“ den Gegensatz schon trägt.",
        "ueben umschreiben gegensatz",
    ),
    (
        "Schreibe mit „dennoch“: Zwar war der Kurs teuer, aber er hat sich gelohnt.",
        "Der Kurs war teuer. Dennoch hat er sich gelohnt.<br>Formeller als „aber“; zwei Hauptsätze.",
        "ueben umschreiben gegensatz schreiben",
    ),
    (
        "Schreibe mit „während“: Die einen sparen. Die anderen geben viel Geld aus.",
        "Während die einen sparen, geben die anderen viel Geld aus.<br>Kontrastiver Gebrauch; Verb im Nebensatz am Ende (sparen).",
        "ueben umschreiben gegensatz",
    ),
    (
        "Schreibe mit „falls“: Wenn Sie Fragen haben, rufen Sie mich an.",
        "Falls Sie Fragen haben, rufen Sie mich bitte an.<br>„falls“ für eine unsichere Bedingung; höflicher im Brief.",
        "ueben umschreiben bedingung schreiben",
    ),
]

SCHREIBEN = [
    (
        "Wie ist ein telc-B2-Brief aufgebaut? (5 Teile)",
        back(
            "<b>1. Anrede:</b> Sehr geehrte Damen und Herren, / Sehr geehrte Frau …, / Sehr geehrter Herr …, (Komma, danach klein weiter)",
            "<b>2. Einleitung:</b> Bezug herstellen — Grund des Schreibens in einem Satz.",
            "<b>3. Hauptteil:</b> alle Punkte der Aufgabe, jeder in einem eigenen Absatz, mit Konnektoren verbunden.",
            "<b>4. Schluss:</b> Forderung, Bitte oder Ergebnis + Frist.",
            "<b>5. Grußformel:</b> Mit freundlichen Grüßen + Name (kein Komma nach der Grußformel).",
            "<br>Zeit im Examen: etwa 30 Minuten für 150–180 Wörter. Erst die fünf Punkte der Aufgabe als Stichworte notieren, dann schreiben.",
        ),
        "schreiben aufbau pruefung",
    ),
    (
        "Formelle Anrede und Grußformel — was ist richtig?",
        back(
            "<b>Anrede:</b> „Sehr geehrte Damen und Herren,“ — wenn der Name unbekannt ist.",
            "„Sehr geehrte Frau Berger,“ / „Sehr geehrter Herr Berger,“ — wenn der Name bekannt ist.",
            "Nach der Anrede klein weiterschreiben, weil das Komma den Satz fortsetzt.",
            "<b>Gruß:</b> „Mit freundlichen Grüßen“ — danach kein Komma, dann der Name in der nächsten Zeile.",
            "Nicht: „Hallo“, „Liebe Grüße“, „Bis bald“ — das ist privat, nicht formell.",
            "<b>Nie:</b> „Sehr geehrte Damen und Herren!“ mit Ausrufezeichen.",
        ),
        "schreiben anrede redemittel",
    ),
    (
        "Einleitung: Wie stellst du den Bezug her? (Redemittel)",
        back(
            "„ich schreibe Ihnen bezüglich …“",
            "„ich beziehe mich auf Ihre Anzeige / Ihre E-Mail vom …“",
            "„vielen Dank für Ihre schnelle Antwort vom …“",
            "„ich habe auf Ihrer Website gelesen, dass …“",
            "„leider muss ich Ihnen mitteilen, dass …“ (Beschwerde)",
            "„ich interessiere mich für … und hätte dazu einige Fragen.“ (Anfrage)",
        ),
        "schreiben redemittel einleitung",
    ),
    (
        "Beschwerde: Redemittel für den Hauptteil",
        back(
            "„Leider muss ich Ihnen mitteilen, dass …“",
            "„Ich bin mit … nicht zufrieden.“",
            "„Das entspricht nicht der Beschreibung / der Absprache.“",
            "„Obwohl Sie … zugesagt hatten, …“",
            "„Hinzu kommt, dass …“",
            "„Außerdem war / fehlte / wurde …“",
            "„Ich habe Sie bereits am … darauf hingewiesen.“",
        ),
        "schreiben redemittel beschwerde",
    ),
    (
        "Anfrage: Redemittel für den Hauptteil",
        back(
            "„Ich würde gern wissen, ob …“",
            "„Könnten Sie mir bitte mitteilen, wie / wann / ob …“",
            "„Außerdem interessiert mich, ob …“",
            "„Darüber hinaus wäre wichtig zu wissen, ob …“",
            "„Bitte senden Sie mir …“",
            "„Für eine kurze Rückmeldung wäre ich dankbar.“",
        ),
        "schreiben redemittel anfrage",
    ),
    (
        "Schluss: Forderung und Frist formulieren",
        back(
            "„Ich erwarte daher, dass …“",
            "„Ich bitte Sie, mir … zu erstatten / zuzusenden.“",
            "„Ich bitte um eine Antwort bis zum …“",
            "„Sollte ich bis dahin nichts hören, werde ich …“ (nur androhen, wenn es zur Situation passt)",
            "„Ich hoffe, dass sich die Angelegenheit unkompliziert lösen lässt.“",
            "<br>Immer höflich bleiben: Konjunktiv II („ich würde“, „könnten Sie“) nimmt die Schärfe heraus.",
        ),
        "schreiben redemittel schluss",
    ),
    (
        "Höflichkeit: Konjunktiv II im Brief (Beispiele)",
        back(
            "„Könnten Sie mir bitte … mitteilen?“ (nicht: „Können Sie …“)",
            "„Ich würde mich über eine Antwort freuen.“",
            "„Es wäre hilfreich, wenn Sie …“",
            "„Ich hätte noch eine Frage.“",
            "„Wäre es möglich, den Termin zu verschieben?“",
            "<br>Der Konjunktiv II macht aus einer Forderung eine Bitte — im Examen ein Plus.",
        ),
        "schreiben grammatik konjunktiv",
    ),
    (
        "Welche Konnektoren heben einen formellen Brief? (Ersatz für „und“, „aber“, „auch“)",
        back(
            "„und“ → <i>außerdem, darüber hinaus, des Weiteren, zudem</i>",
            "„aber“ → <i>allerdings, jedoch, dennoch, hingegen</i>",
            "„weil“ → <i>da, zumal, aufgrund (des/der)</i>",
            "„deshalb“ → <i>daher, aus diesem Grund, folglich</i>",
            "„wenn“ → <i>falls, sofern</i>",
            "„zum Beispiel“ → <i>beispielsweise, etwa</i>",
            "<br>Zwei bis drei solcher Wörter genügen; wer jedes „und“ ersetzt, schreibt unnatürlich.",
        ),
        "schreiben konnektoren redemittel",
    ),
    (
        "Typische Fehler im B2-Brief (3 Klassiker)",
        back(
            "<b>1. Verbletztstellung nach „denn“/„deshalb“:</b> falsch „…, deshalb ich habe …“ — richtig „…, deshalb habe ich …“.",
            "<b>2. Umgangssprache:</b> „Hallo“, „Ich wollte mal fragen“ → „Sehr geehrte …“, „ich würde gern wissen“.",
            "<b>3. Punkt der Aufgabe vergessen:</b> Die Aufgabe nennt meist vier Inhaltspunkte. Wer einen auslässt, verliert Punkte — erst alle notieren, dann schreiben.",
            "<br>Prüfe am Ende drei Dinge: alle Punkte drin? Anrede und Grußformel formell? Verb an Position 2 nach Konnektoren?",
        ),
        "schreiben fehler pruefung",
    ),
    (
        "Aufgabe (Beschwerde): Deutschkurs\nSie haben einen vierwöchigen Intensivkurs B2 gebucht und im Voraus bezahlt (680 €). Die Gruppe war viel größer als zugesagt, der Raum wurde zweimal gewechselt, die Lehrkraft dreimal, das Zertifikat fehlt. Schreiben Sie eine Beschwerde: nennen Sie die Probleme, sagen Sie, was Sie erwarten, setzen Sie eine Frist.",
        back(
            "Sehr geehrte Damen und Herren,",
            "<br>ich schreibe Ihnen bezüglich des Intensivkurses Deutsch B2, den ich am 5. Oktober bei Ihnen gebucht und vollständig bezahlt habe (Rechnung Nr. 4471, 680 €).",
            "<br>Leider muss ich Ihnen mitteilen, dass der Kurs nicht der Beschreibung entsprach. Obwohl Sie eine Gruppe von höchstens zehn Teilnehmern zugesagt hatten, saßen wir ab der zweiten Woche zu achtzehn im Raum. Außerdem wurde der Unterricht zweimal kurzfristig verlegt, sodass jeweils fast eine Stunde verloren ging. Darüber hinaus wechselte die Lehrkraft dreimal; da jede Person anders unterrichtete, fehlte uns der rote Faden. Hinzu kommt, dass das zugesagte Zertifikat bis heute nicht ausgestellt wurde.",
            "<br>Ich habe den Kurs zwar bis zum Ende besucht, bin mit dem Ergebnis jedoch nicht zufrieden. Ich erwarte daher eine Teilerstattung von mindestens 40 Prozent sowie die Zusendung des Zertifikats bis zum 30. November. Sollte ich bis dahin keine Antwort erhalten, werde ich mich an die Verbraucherzentrale wenden.",
            "<br>Mit freundlichen Grüßen<br>Matt Ji",
            "<br><i>Konnektoren im Text: obwohl, sodass, da, zwar … jedoch, daher, sowie. Alle vier Inhaltspunkte sind abgedeckt, die Frist steht im letzten Absatz.</i>",
        ),
        "schreiben modell beschwerde",
    ),
    (
        "Aufgabe (Anfrage): Intensivkurs\nSie möchten im Januar einen Intensivkurs B2 in Berlin machen und danach die Prüfung telc B2 ablegen. Fragen Sie nach: Kursgebühr und Material, Unterrichtszeiten, Unterkunft, Prüfungsvorbereitung, Einstufungstest.",
        back(
            "Sehr geehrte Damen und Herren,",
            "<br>ich habe Ihre Anzeige für Intensivkurse Deutsch B2 auf Ihrer Website gelesen und interessiere mich für den Kurs im Januar.",
            "<br>Für meine Planung benötige ich noch einige Informationen. Zunächst würde ich gern wissen, wie hoch die Kursgebühr ist und ob die Lehrmaterialien darin enthalten sind. Außerdem interessiert mich, ob der Unterricht vormittags oder nachmittags stattfindet, da ich parallel halbtags arbeite. Darüber hinaus möchte ich erfahren, ob Sie Zimmer in einer Wohngemeinschaft vermitteln und mit welchen Kosten ich dabei rechnen muss. Da ich im März die Prüfung telc B2 ablegen möchte, wäre es wichtig zu wissen, ob der Kurs gezielt darauf vorbereitet. Schließlich bitte ich um Auskunft, ob ein Einstufungstest erforderlich ist und wann dieser stattfindet.",
            "<br>Ich würde mich über eine ausführliche Antwort bis Ende der Woche sehr freuen. Vielen Dank im Voraus.",
            "<br>Mit freundlichen Grüßen<br>Matt Ji",
            "<br><i>Konnektoren im Text: zunächst, außerdem, darüber hinaus, da, schließlich. Fünf Fragen, jede in einem eigenen Satz — so ist keine vergessen.</i>",
        ),
        "schreiben modell anfrage",
    ),
    (
        "Aufgabe (halbformell): Heizung defekt\nSeit einer Woche funktioniert die Heizung in Ihrer Wohnung nicht, Ihr Vermieter reagiert nicht auf Anrufe. Schreiben Sie: das Problem, die Folgen, was Sie verlangen, eine Frist.",
        back(
            "Sehr geehrter Herr Berger,",
            "<br>ich schreibe Ihnen wegen der Heizung in meiner Wohnung (Kaiserstraße 14, 2. OG). Seit dem 28. Oktober bleibt sie kalt, obwohl ich Sie in dieser Woche dreimal angerufen und einmal per E-Mail informiert habe.",
            "<br>Da die Temperaturen nachts bereits unter fünf Grad liegen, ist die Wohnung morgens kaum zu beheizen; inzwischen bin ich erkältet und arbeite von zu Hause, was unter diesen Bedingungen schwierig ist. Ich habe einen Handwerker kommen lassen, der jedoch feststellte, dass der Fehler an der zentralen Anlage liegt und nicht von mir behoben werden kann.",
            "<br>Ich bitte Sie daher, die Reparatur bis zum 8. November zu veranlassen. Sollte bis dahin nichts geschehen, werde ich die Miete mindern und mir gegebenenfalls rechtlichen Rat holen. Ich hoffe jedoch, dass sich die Angelegenheit unkompliziert lösen lässt, und erwarte Ihre Rückmeldung bis Freitag.",
            "<br>Mit freundlichen Grüßen<br>Matt Ji",
            "<br><i>Halbformell: Anrede mit Namen, aber sachlich. „obwohl“, „da“, „jedoch“, „daher“ tragen die Argumentation; die Androhung steht im Konjunktiv-Umfeld („werde … holen“).</i>",
        ),
        "schreiben modell beschwerde",
    ),
    (
        "Schreibübung 1 (Beschwerde): Reise\nSie haben eine Städtereise gebucht: Das Hotel lag außerhalb der Stadt, das Zimmer war nicht das gebuchte, der versprochene Stadtrundgang fiel aus. Schreiben Sie eine Beschwerde mit Forderung und Frist (150–180 Wörter).",
        back(
            "<b>Erwartungshorizont:</b> formelle Anrede · Bezug (Buchungsnummer, Datum) · drei Probleme mit Konnektoren (obwohl, außerdem, hinzu kommt, sodass) · Forderung (Teilerstattung / Gutschein) · Frist · Grußformel.",
            "<b>Redemittel:</b> „Leider entsprach die Reise nicht der Beschreibung.“ / „Obwohl im Katalog ein zentrales Hotel stand, …“ / „Ich erwarte daher …“ / „Ich bitte um eine Antwort bis zum …“",
            "<b>Musteranfang:</b> „Sehr geehrte Damen und Herren, ich schreibe Ihnen bezüglich der Städtereise nach Prag vom 12. bis 15. Oktober (Buchung Nr. 88213). Leider muss ich Ihnen mitteilen, dass die Reise in mehreren Punkten nicht der Beschreibung entsprach.“",
        ),
        "schreiben uebung beschwerde",
    ),
    (
        "Schreibübung 2 (Anfrage): Praktikum\nSie haben eine Anzeige für ein Praktikum im Marketing gelesen. Fragen Sie nach Dauer und Beginn, Aufgaben, Bezahlung, Arbeitszeiten und Bewerbungsunterlagen (150–180 Wörter).",
        back(
            "<b>Erwartungshorizont:</b> Anrede · Bezug auf die Anzeige · fünf konkrete Fragen, jede mit eigenem Konnektor (zunächst, außerdem, darüber hinaus, des Weiteren, schließlich) · höflicher Schluss mit Rückmeldewunsch · Grußformel.",
            "<b>Redemittel:</b> „Ich habe Ihre Anzeige … gelesen und interessiere mich für …“ / „Könnten Sie mir bitte mitteilen, ob …“ / „Für eine kurze Rückmeldung wäre ich dankbar.“",
            "<b>Musteranfang:</b> „Sehr geehrte Frau Weber, ich habe Ihre Anzeige für ein Praktikum im Marketing auf Ihrer Website gelesen und interessiere mich sehr dafür. Da ich mein Studium im März abschließe, suche ich ein Praktikum ab April.“",
        ),
        "schreiben uebung anfrage",
    ),
    (
        "Wie viele Wörter und wie viel Zeit im schriftlichen Teil?",
        back(
            "telc B2, Schriftlicher Ausdruck: eine Aufgabe (Brief oder E-Mail), <b>ca. 150–180 Wörter</b> in <b>etwa 30 Minuten</b>.",
            "Weniger als 120 Wörter wirken dünn; mehr als 200 kostet Zeit, die im Leseverstehen fehlt.",
            "<b>Ablauf:</b> 3 Minuten Stichworte zu jedem Aufgabenpunkt → 20 Minuten schreiben → 5 Minuten prüfen (Punkte, Verbstellung, Anrede/Gruß).",
            "Zählen muss man nicht: 150 Wörter sind ungefähr eine handschriftliche Seite mit vier Absätzen.",
        ),
        "schreiben pruefung plan",
    ),
    (
        "7-Tage-Plan bis zur telc-B2-Prüfung (Schreiben)",
        back(
            "<b>Tag 1–2:</b> Konnektoren-Deck, 20 neue Karten pro Tag. Zusätzlich je 10 Karten „Konnektoren üben“.",
            "<b>Tag 3:</b> Beschwerde-Modell abschreiben (von Hand), danach aus dem Gedächtnis die Struktur aufschreiben.",
            "<b>Tag 4:</b> Anfrage-Modell abschreiben; danach Schreibübung 1 in 30 Minuten ohne Vorlage.",
            "<b>Tag 5:</b> Schreibübung 2 in 30 Minuten; Fehler markieren und die betroffenen Konnektor-Karten wiederholen.",
            "<b>Tag 6:</b> Beide Modelle laut lesen, Konnektoren im Text unterstreichen; Konnektoren-Deck komplett.",
            "<b>Tag 7:</b> Eine neue Aufgabe aus dem Kopf schreiben, nur Stichworte und Redemittel als Hilfe.",
        ),
        "schreiben plan pruefung",
    ),
]

DECKS = {
    DECK_KONNEKTOREN: ("Deutsch::B2::Konnektoren", "B2 Konnektoren", []),
    DECK_UEBEN: ("Deutsch::B2::Konnektoren üben", "B2 Konnektoren üben", []),
    DECK_SCHREIBEN: ("Deutsch::B2::Schreiben (telc)", "B2 Schreiben telc", []),
}


def notetype(now_ms, deck_id):
    def field(name, ord_):
        return {
            "name": name,
            "ord": ord_,
            "sticky": False,
            "rtl": False,
            "font": "Arial",
            "size": 20,
            "media": [],
        }

    return {
        "id": MODEL_B2,
        "name": "B2 (Vorne/Hinten)",
        "type": 0,
        "mod": now_ms // 1000,
        "usn": 0,
        "sortf": 0,
        "did": deck_id,
        "tmpls": [
            {
                "name": "Karte 1",
                "ord": 0,
                "qfmt": "{{Vorne}}",
                "afmt": "{{FrontSide}}<hr id=answer>{{Hinten}}",
                "bqfmt": "",
                "bafmt": "",
                "did": None,
                "bfont": "",
                "bsize": 0,
            }
        ],
        "flds": [field("Vorne", 0), field("Hinten", 1)],
        "css": ".card {\n font-family: arial;\n font-size: 20px;\n text-align: left;\n color: black;\n background-color: white;\n}\n"
        ".nightMode .card { color: white; background-color: black; }\n"
        "i { color: #444; }\n.nightMode i { color: #bbb; }",
        "latexPre": "\\documentclass[12pt]{article}\\special{papersize=3in,5in}\\usepackage[utf8]{inputenc}"
        "\\usepackage{amssymb,amsmath}\\pagestyle{empty}\\setlength{\\parindent}{0in}\\begin{document}",
        "latexPost": "\\end{document}",
        "latexsvg": False,
        "req": [[0, "any", [0, 1]]],
        "tags": ["telc-b2", "deutsch-b2"],
        "vers": [],
    }


def deck_json(deck_id, name, base, now_s):
    d = dict(base)
    d.update({"id": deck_id, "name": name, "mod": now_s, "usn": 0, "desc": "", "dyn": 0})
    return d


def plain(html):
    out, depth = [], 0
    for ch in html:
        if ch == "<":
            depth += 1
        elif ch == ">":
            depth = max(0, depth - 1)
        elif depth == 0:
            out.append(ch)
    return "".join(out).strip()


def csum(sfld):
    return int(hashlib.sha1(sfld.encode("utf-8")).hexdigest()[:8], 16)


def guid(rng, taken):
    while True:
        g = "".join(rng.choice(string.ascii_letters + string.digits) for _ in range(10))
        if g not in taken:
            taken.add(g)
            return g


def add_notes(con, entries, deck_id, start_index, due_start, now_ms, rng, taken):
    """entries: list of (front, back, tags). Returns (next_index, next_due)."""
    rows_n, rows_c = [], []
    for i, (front, backend, tags) in enumerate(entries):
        note_id = FIRST_NOTE_ID + start_index + i
        sfld = plain(front)
        rows_n.append(
            (
                note_id,
                guid(rng, taken),
                MODEL_B2,
                now_ms // 1000,
                0,
                " " + " ".join([t for t in tags.split() if t]) + " ",
                front + "\x1f" + backend,
                sfld,
                csum(sfld),
                0,
                "",
            )
        )
        rows_c.append(
            (
                note_id + 1,  # card ids sit next to their note id; the ranges do not overlap
                note_id,
                deck_id,
                0,
                now_ms // 1000,
                0,
                0,
                0,
                due_start + i,
                0,
                0,
                0,
                0,
                0,
                0,
                0,
                0,
                0,
            )
        )
    con.executemany(
        "insert into notes (id,guid,mid,mod,usn,tags,flds,sfld,csum,flags,data)"
        " values (?,?,?,?,?,?,?,?,?,?,?)",
        rows_n,
    )
    con.executemany(
        "insert into cards (id,nid,did,ord,mod,usn,type,queue,due,ivl,factor,reps,lapses,"
        "left,odue,odid,flags,data) values (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
        rows_c,
    )
    return start_index + len(entries), due_start + len(entries)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--b1", required=True, help="schema-11 collection.anki2 to merge into")
    ap.add_argument("--out", required=True, help="merged collection to write")
    args = ap.parse_args()

    now_ms = int(time.time() * 1000)
    rng = random.Random(20261106)

    import shutil

    shutil.copyfile(args.b1, args.out)
    con = sqlite3.connect(args.out)
    models = json.loads(con.execute("select models from col").fetchone()[0])
    decks = json.loads(con.execute("select decks from col").fetchone()[0])
    default_dconf_id = sorted(json.loads(con.execute("select dconf from col").fetchone()[0]))[0]

    models[str(MODEL_B2)] = notetype(now_ms, DECK_KONNEKTOREN)
    base = decks["1"]
    for deck_id, (name, _, _) in DECKS.items():
        decks[str(deck_id)] = deck_json(deck_id, name, base, now_ms // 1000)
        decks[str(deck_id)]["conf"] = int(default_dconf_id)

    con.execute(
        "update col set models = ?, decks = ?, mod = ?, usn = 1",
        (json.dumps(models, ensure_ascii=False), json.dumps(decks, ensure_ascii=False), now_ms),
    )

    taken = {r[0] for r in con.execute("select guid from notes")}
    max_note = con.execute("select max(id) from notes").fetchone()[0]
    max_due = con.execute("select max(due) from cards").fetchone()[0]
    if FIRST_NOTE_ID + 10000 < max_note:
        raise SystemExit("note id base collides with the existing collection")

    idx, due = 0, max_due + 1
    start = con.execute("select count(*) from notes").fetchone()[0]

    batches = [
        (DECK_KONNEKTOREN, KONNEKTOREN),
        (DECK_UEBEN, UEBEN + UMSCHREIBEN),
        (DECK_SCHREIBEN, SCHREIBEN),
    ]
    for deck_id, entries in batches:
        idx, due = add_notes(con, entries, deck_id, idx, due, now_ms, rng, taken)

    con.commit()
    con.execute("vacuum")
    con.commit()
    con.close()

    print(f"konnektoren={len(KONNEKTOREN)} ueben={len(UEBEN) + len(UMSCHREIBEN)} schreiben={len(SCHREIBEN)}")
    print(f"new notes on top of {start}: {idx}, output={args.out}")


if __name__ == "__main__":
    main()
