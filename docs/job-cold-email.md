# Cold applications by mail (Initiativbewerbung)

A cold mail is read for eleven seconds. Everything here is arranged around that:
one specific reason to write, one piece of verifiable evidence, one question that
is cheap to answer.

The sender is `Matt Ji <matt@bountystash.com>`. That account now sends through
Resend, which signs with bountystash.com's own DKIM key, so the mail arrives
authenticated rather than as an unsigned alias
(`modules/himalaya.nix`, `docs/job-cold-email.md` sits beside `docs/sops-rekey.md`).

Placeholders are `{{UPPER_CASE}}`. Fill every one; a mail that still says
`{{FIRMA}}` is worse than no mail.

## Sending rules

- Plain text only. No HTML, no signature image, no first-contact PDF. ATS and
  recruiter inboxes strip the first and quarantine the last.
- 120 to 180 words. Five paragraphs at most. The ask fits in one sentence.
- First two lines carry one concrete thing about the company: a launch, a
  technology choice, a regulatory deadline, an incident, a job ad that closed.
  Not "I am impressed by your innovative solutions".
- Subject: sentence case, no exclamation mark, no emoji, no "Bewerbung" alone.
- Send Tuesday to Thursday, 07:30 to 09:30 CET. Avoid Monday morning and Friday.
- One follow-up, in the same thread, seven days later. Then stop.
- Log it in the pipeline:
  `task apps:update -- <id> --status "Lead (cold mail {{DATE}})"`.
- Keep the address real: a company that answers gets an answer within a day.

## Betreff / subject lines

| Use | Do not use |
| :--- | :--- |
| `Initiativbewerbung: Systems Engineer — Bezug: {{BEZUG_KURZ}}` | `Bewerbung` |
| `{{ROLLE}} für {{FIRMA}}? Eine kurze Frage` | `Initiativbewerbung` |
| `Go und NixOS bei {{FIRMA}} — 20 Minuten?` | `Anfrage` |
| `Speculative application: {{ROLE}} — {{HOOK}}` | `Hello` / `Quick question` |

## Vorlage A — Infrastruktur und Plattform (DE)

```
Betreff: Initiativbewerbung: Systems Engineer — Bezug: {{BEZUG_KURZ}}

Guten Tag {{ANSPRECHPERSON}},

{{BEZUG}} ist der Grund für diese Mail: {{KONKRETER_SATZ_ZUM_BEZUG}}.

Ich baue Infrastruktur, die sich aus einem Commit wiederherstellen lässt: eine
NixOS-Flotte für NAS, Workstations und Cloud-Hosts, deklariert in Flakes, mit
eigener SSH-CA und verschlüsselten Secrets, bedient über ein Taskfile. Dazu
Go-Dienste mit append-only Event-Log und eine Bewertungsschicht für
Erneuerbare-Energien-Anlagen im dreistelligen Millionenbereich, die Bankprüfungen
standgehalten hat.

Bei {{FIRMA}} würde ich {{KONKRETER_BEITRAG}} übernehmen.

Hätten Sie in den nächsten zwei Wochen 20 Minuten für ein Gespräch? Wenn das
thematisch nicht passt, reicht ein kurzer Hinweis — dann melde ich mich nicht
erneut.

Freundliche Grüße
Matt Ji
Systems & Infrastructure Engineer
matt@bountystash.com · +49 1733281570
https://matt.bountystash.com · https://github.com/shaoyanji
```

## Vorlage B — Security und Vulnerability-Daten (DE)

```
Betreff: Initiativbewerbung: Security Engineering — Bezug: {{BEZUG_KURZ}}

Guten Tag {{ANSPRECHPERSON}},

{{BEZUG}} hat mich auf {{FIRMA}} aufmerksam gemacht: {{KONKRETER_SATZ_ZUM_BEZUG}}.

Ich übersetze Schwachstellendaten in Arbeitsreihenfolgen. Zwei öffentliche
Werkzeuge zeigen die Richtung: kev-time stellt den CISA-KEV-Katalog als Zeitreihe
dar, kelly-svg fasst Einträge zu Clustern zusammen, die ein Team abarbeiten kann.
Dazu kommt die zweite Hälfte, an der solche Programme scheitern: eine deklarative
Flotte, in der jede Änderung nachvollziehbar ist, damit ein Finding auch
geschlossen wird.

Konkret könnte ich bei {{FIRMA}} {{KONKRETER_BEITRAG}}.

Sind 20 Minuten in den nächsten zwei Wochen möglich? Falls nicht, sagen Sie es
bitte kurz — ich frage kein zweites Mal.

Freundliche Grüße
Matt Ji
matt@bountystash.com · +49 1733281570
https://matt.bountystash.com · https://github.com/shaoyanji
```

## Template C — engineering and platform (EN)

```
Subject: Speculative application: {{ROLE}} — {{HOOK}}

Hi {{NAME}},

{{HOOK_SENTENCE}} is why I am writing.

I build infrastructure that can be rebuilt from one commit: a NixOS fleet for
NAS, workstations and cloud hosts, declared in flakes with its own certificate
authority and encrypted secrets, driven by a taskfile. Alongside it, Go services
with append-only event logs, and a valuation layer for renewable assets above
$100M that survived bank audits.

At {{COMPANY}} I would take on {{CONCRETE_CONTRIBUTION}}.

Do you have 20 minutes in the next two weeks? If this is not the right moment,
one line is enough and I will not write again.

Best regards
Matt Ji
Systems & Infrastructure Engineer
matt@bountystash.com · +49 1733281570
https://matt.bountystash.com · https://github.com/shaoyanji
```

## Follow-up, seven days later (same thread)

DE:

```
Guten Tag {{ANSPRECHPERSON}},

kurze Nachfrage zu meiner Mail vom {{DATUM}}: {{EIN_SATZ_NEUER_BEZUG}}.

Passt es bei {{FIRMA}} gerade nicht, reicht ein Wort — dann lasse ich es dabei.

Freundliche Grüße
Matt
```

EN:

```
Hi {{NAME}},

one short follow-up to my mail of {{DATE}}: {{ONE_NEW_FACT}}.

If the timing is wrong at {{COMPANY}}, a single line is enough and I will leave it
there.

Best regards
Matt
```

## Two-line variants

LinkedIn or Xing, to a person rather than a mailbox:

```
Ihre {{BEZUG}} war für mich der Anlass: ich baue NixOS-Flotten und KEV-Werkzeuge
(https://matt.bountystash.com). Ist bei {{FIRMA}} gerade jemand für Plattform
oder Vulnerability-Operations gesucht?
```

Referral, to someone who already works there:

```
Sie arbeiten bei {{FIRMA}} an {{BEZUG}} — ich bewerbe mich dort initiativ für
{{ROLLE}} (NixOS-Flotte, Go, KEV-Daten: https://matt.bountystash.com). Würden Sie
meine Mail an die richtige Person weiterleiten?
```

## What not to write

- `hiermit bewerbe ich mich` — the mail already says that.
- `hoch motiviert`, `teamfähig`, `schnelle Auffassungsgabe` — claims without
  evidence.
- `Gibt es offene Stellen?` — a question the careers page answers.
- A three-page PDF on first contact, or a link to a resume that does not exist
  yet. The page and the repositories are the evidence until the resume is ready.
- Praise of the company with no fact in it.

## Before the send key

1. Every placeholder replaced; the hook names something that happened in the last
   six months.
2. Name of the recipient is correct and spelled as they spell it.
3. One ask, one sentence, with a number of minutes in it.
4. Plain text, 180 words or fewer, links that resolve.
5. Logged in the pipeline, with the date and the channel.
