# Nix consultancy outreach

**Status:** ready to send · **Prepared:** 2026-11-21 · **Sender:** Matt Ji
**Offer:** B2B NixOS, reproducible-build and platform engineering
**Availability:** from 01.12.2026 · 3–5 days/week · remote from Germany

Each target gets one reason for the conversation, one proof point, one concrete
piece of work Matt can take, and one cheap ask. **Contacts are not in this file:**
reach a target via their own site; `[NAME]`, `[CONTACT]`, `[PHONE]` in the pipeline.

## The position in one paragraph

I make NixOS fleets reproducible enough to hand over: one flake pins every
input, hosts compose from feature lists instead of hand edits, builds run
hermetically, secrets are SOPS/age-encrypted at rest, SSH access uses
short-lived certificates rather than standing host keys, and CI runs the same
module gate the machines run. A change is a generation that can be rolled back,
not a shell history that has to be reconstructed.

That is the work Numtide sells, the property Cachix makes economical, and the
operations layer Cyberus needs behind a reproducible, regulated platform.

## Proof bank

| Proof | What it actually demonstrates | Best target |
| :--- | :--- | :--- |
| **13-host NixOS fleet, one flake** | A fleet is declared, not assembled; hosts are functions of feature lists and modules. | Numtide, Cyberus |
| **Pinned inputs and pinned host submodules** | A rebuild is a function of the repository, not of the machine or the day. | Numtide, Cachix |
| **Hermetic builds with no network** | Build outputs do not depend on ambient state; the store is content-addressed. | Cachix, Cyberus |
| **SOPS/age secrets plus a short-lived SSH CA** | Zero-standing-secret access: secrets are encrypted at rest and host access is issued, not shared. | Cachix, Cyberus |
| **PXE/iVentoy netboot and bare-metal installs** | A machine can arrive, boot an installer over the network, join the declared fleet and be rebuilt. | Numtide, Cyberus |
| **CI module gate and generation rollback** | The check that guards a change is the check the host runs; recovery is a known generation. | Numtide, Cyberus |
| **Go CLI/TUI with PostgreSQL and REST** | Developer tooling with one binary, append-only events and a backend service behind the same interface. | Cachix, Numtide |
| **Public `nixconfig` repository** | The claims are inspectable, not a slide. | All three |

**Deliberate limits.** No BSI/VS-NfD work, KVM or Rust depth, a Cachix customer
relationship, a Numtide subcontract, or production Terraform/AWS ownership.

## Commercial shape

- **Polish entity, hourly:** 150–250 PLN/h, scope-dependent.
- **EU annual contract:** EUR 85,000–120,000, 3–5 days/week.

Rates exclude VAT and expenses; travel is by agreement. Start with a paid
2–3 day discovery, then either a fixed-scope statement of work or a monthly
retainer. Do not put a number in the first message; anchor after the scope is
known.

Matt is a US citizen with permanent German residence (Niederlassungserlaubnis),
works from Germany, and needs no sponsorship. English is native; German is C1.
For a German client, lead in German and attach the English one-page profile only
if asked.

---

## 1. [NAME] — Numtide

**Role to verify:** Founder and Director, Numtide.
**Public contact:** [numtide.com/about](https://numtide.com/about) · [CONTACT] · [CONTACT]
**Company:** [numtide.com](https://numtide.com/) · [about](https://numtide.com/about) · [services](https://numtide.com/services/)

### Why him

Numtide is a small team of independent principal engineers selling senior Nix
and DevOps delivery, including NixOS commercial support, migrations and custom
tooling. Its public project list — `srvos`, `disko`, `nixos-anywhere`,
`buildbot-nix`, `treefmt`, `direnv` — is the exact problem space Matt works in:
a fleet that has to be installed, declared, checked and handed over. It does not
need another Nix tutorial; it needs delivery capacity that can join a client
workstream and make a half-migrated fleet reproducible without a ramp. Matt has
run that state on his own fleet: thirteen hosts, one flake, feature-list modules,
pinned submodules, PXE installs, CI gate, rollback, SOPS/age and an SSH CA.

### What Matt can take

- A client fleet migration from hand-managed hosts to a flake with feature-list
  modules and pinned inputs.
- Bare-metal provisioning: PXE/iVentoy, ISO library, installer boot, first-boot
  join, rebuild path.
- CI and delivery: a module gate that runs where the machines run, generation
  rollback, and documentation a client engineer can follow.
- Secrets and access: SOPS/age, short-lived SSH certificates, no standing host
  keys.
- Developer tooling around the fleet: taskfile control plane, Go/Python/Bash
  automation, runbooks.

### The ask

A 30-minute call about subcontract or associate capacity for a client
workstream. If the bench is full, one line is enough.

### LinkedIn connection note

> Hi [NAME] — I run a 13-host NixOS fleet from one flake: pinned inputs, hermetic
> builds, SOPS/age secrets, SSH CA, PXE installs. Numtide sells exactly that
> senior delivery. I'm looking for B2B subcontract work from December. Open to a
> 20-minute call?

### Email

**Subject:** NixOS fleet delivery — subcontract capacity for Numtide

```text
Hi [NAME],

Numtide sells senior Nix capacity to teams that need a working fleet, not a
proof of concept. I run one: thirteen NixOS hosts from a single flake,
feature-list modules, pinned inputs and submodules, PXE/iVentoy bare-metal
installs, hermetic builds, SOPS/age secrets and a short-lived SSH CA. CI runs
the same module gate the machines run; every change is a generation that can be
rolled back.

If a client workstream needs an extra principal engineer for 3–5 days a week, I
can take delivery without a Nix ramp. I am available on a B2B contract from
01.12.2026, remote from Germany.

Would a 30-minute call in the next two weeks be useful? If the bench is full,
one line is enough.

Best regards,
Matt Ji
B2B NixOS & platform engineering
matt@bountystash.com
https://github.com/shaoyanji/nixconfig · https://linkedin.com/in/mattji
```

**Follow-up, seven days later:**

```text
Hi [NAME],

One short follow-up to my note of {{DATE}}. The concrete offer is unchanged: a
13-host NixOS fleet from one flake, hermetic builds, PXE installs and a CI gate,
available as subcontract capacity from December.

If the timing is wrong, a single line is enough and I will leave it there.

Best,
Matt
```

**Do not say:** Matt has used every Numtide tool, is available full-time, or knows its client bench.

---

## 2. [NAME] — Cachix

**Role to verify:** Founder, Cachix.
**Public contact:** [cachix.org/about](https://www.cachix.org/about) · [CONTACT] · [CONTACT]
**Company:** [cachix.org](https://cachix.org/) · [about](https://www.cachix.org/about) · [Cachix Deploy GA](https://blog.cachix.org/)

### Why him

Cachix sells the consequence of hermetic builds: never build the same thing
twice. The product surface now spans binary caches, Devenv developer
environments and Cachix Deploy, which reached general availability in January
2026 and lets agents pull profiles from a cache without evaluating or building
on the target. [NAME]'s public work also includes `secretspec`, a declarative
interface for secret providers — adjacent to the secrets problem Matt solves
with SOPS/age and a short-lived SSH CA. The first cache push is easy; the hard
part is making cache hits trustworthy across CI, development and deployment,
keeping secrets out of the closure, and giving a customer a rollout path that
does not depend on a local evaluator. Matt's fleet runs the pattern by hand:
pinned inputs, a CI gate, content-addressed outputs, generations and rollback.

### What Matt can take

- A cache and CI audit for a team adopting Nix: what is rebuilt, what is
  substituted, where the closure leaks, and which cache key is actually stable.
- A Cachix Deploy adoption path for a NixOS or nix-darwin fleet: profile
  promotion, agent rollout, rollback and the boundary between cache and target.
- A developer-environment migration: flake outputs, pinned toolchains, a
  taskfile entry point, and documentation that survives the first week.
- Customer-facing integration work where the customer needs an engineer who has
  operated the fleet, not only configured the cache.

### The ask

A 20-minute call about professional-services or partner capacity. If Cachix
handles this entirely in-house, ask for a pointer to the right person and stop.

### LinkedIn connection note

> Hi [NAME] — I run a 13-host NixOS fleet with pinned flakes, hermetic builds and
> a CI gate; Cachix is the economic layer for that. I'd like to compare notes on
> cache/Deploy adoption and whether you use contract capacity. Open to 20
> minutes?

### Email

**Subject:** Cachix Deploy adoption — contract capacity?

```text
Hi [NAME],

Cachix sells the consequence of hermetic builds: never build the same thing
twice. The hard part for a customer is not the first cache push; it is trusting
cache hits across CI, development and deployment, and keeping secrets out of the
closure.

I run a 13-host NixOS fleet from one flake with pinned inputs, hermetic builds,
SOPS/age secrets and short-lived SSH certificates. I have the operational scars
that make a cache or Deploy rollout stick, and I can help customers with cache
strategy, CI hit rates and fleet migration.

Is there a professional-services or partner bench where a B2B contract would
fit? I am available from 01.12.2026. A 20-minute call would be enough to see if
there is a match.

Best regards,
Matt Ji
B2B NixOS & platform engineering
matt@bountystash.com
https://github.com/shaoyanji/nixconfig · https://linkedin.com/in/mattji
```

**Follow-up, seven days later:**

```text
Hi [NAME],

One short follow-up to my note of {{DATE}}. Cachix Deploy's pull-from-cache
model is the pattern I already run by hand on a 13-host NixOS fleet; the offer is
to help customers adopt it without losing rollback or secret hygiene.

If this is handled in-house, a pointer to the right person is enough.

Best,
Matt
```

**Do not say:** Matt is a Cachix customer, Deploy is broken, or Cachix needs a consultant.

---

## 3. Cyberus Technology — engineering leadership

**Primary contact:** [NAME], Co-Founder; engineering/cloud
leadership. [CONTACT]
**Secondary:** [NAME], CTO (verify current title before sending).
**Company:** [cyberus-technology.de](https://www.cyberus-technology.de/) · [about](https://www.cyberus-technology.de/about-cyberus) · [Cyberus Linux](https://www.cyberus-technology.de/cyberus-linux)

Use LinkedIn or the published contact form. Do not guess a personal email
address. If a German message is appropriate, use the variant below; Matt's
German is C1.

### Why them

Cyberus builds open-source infrastructure for digital sovereignty: a
BSI-accredited hypervisor for VS-NfD and NATO RESTRICTED, Cyberus Linux, and
automated testing for regulated environments. Its own description is "modular,
transparent and reproducible software," and it advertises long-term NixOS
platform support, which makes the build-and-operations layer part of the
product. A reproducible product needs a reproducible way to build, provision and
operate it, and Matt's fleet is a small working example: thirteen NixOS hosts
from one flake, pinned inputs, hermetic builds, PXE installs, SOPS/age secrets,
short-lived SSH certificates, CI gates and rollback. The gap is scale and
accreditation, not the operating model.

### What Matt can take

- NixOS platform engineering for an internal or customer-facing Linux platform:
  flake structure, module boundaries, pinned inputs, upgrade and rollback.
- Reproducible build and CI work: hermetic builds, cache policy, artifact
  promotion, and a gate that runs the same check as the target.
- Secrets and access engineering: SOPS/age, short-lived SSH certificates,
  removal of standing host keys, and an auditable access path.
- Bare-metal and edge provisioning: PXE/iVentoy, installer images, first-boot
  configuration, rebuild and recovery.
- Documentation and handover for regulated environments: runbooks, change
  records, and a reproducible path from commit to deployed generation.

### The ask

A 30-minute technical conversation with [NAME] or the appropriate engineering
lead. The offer is a B2B contract, not a job application. If the NixOS platform
is already fully covered, ask for a pointer and stop.

### LinkedIn connection note

> Hi [NAME] — Cyberus's reproducible, NixOS-supported stack is the layer I work
> in: 13 NixOS hosts, one flake, hermetic builds, SOPS/age, SSH CA. I'm
> Germany-based and available for B2B platform work. Open to 30 minutes?

### English email

**Subject:** NixOS platform and reproducible builds for regulated environments

```text
Dear Mr [NAME],

Cyberus describes modular, transparent and reproducible software, and offers
long-term NixOS support. That is the layer I work in: thirteen NixOS hosts from
one flake, pinned inputs, hermetic builds, SOPS/age secrets and a short-lived SSH
CA, with CI gates and rollback.

I could take on the platform and build side of Cyberus Linux or internal
infrastructure: reproducible artifacts, cache and CI, secrets and access, and
documentation that survives an audit. I am Germany-based, German is C1, and I am
available on a B2B contract from 01.12.2026.

I have not worked under BSI accreditation, and my KVM and Rust depth is not your
engineering team's. I would learn the constraints rather than pretend otherwise.

Would 30 minutes in the next two weeks be useful? If this is already covered
internally, a short note is enough.

Kind regards,
Matt Ji
B2B NixOS & platform engineering
matt@bountystash.com
https://github.com/shaoyanji/nixconfig · https://linkedin.com/in/mattji
```

### German email variant

**Betreff:** NixOS-Plattform für regulierte Umgebungen — kurze Frage

```text
Guten Tag Herr [NAME],

Ihre Seite nennt modulare, transparente und reproduzierbare Software sowie
langfristigen NixOS-Support. Genau dort arbeite ich: eine Flotte von 13
NixOS-Hosts aus einem Flake, gepinnte Inputs, hermetische Builds,
SOPS/age-verschlüsselte Secrets und eine SSH-CA mit kurzlebigen Zertifikaten.

Für Cyberus könnte ich die Betriebs- und Build-Seite dieser Plattform übernehmen:
reproduzierbare Artefakte, CI-Gates, Rollbacks und dokumentierte Übergaben für
regulierte Kunden. Ich bin in Deutschland ansässig, arbeite auf B2B-Basis und
spreche Deutsch auf C1-Niveau.

Hätten Sie in den nächsten zwei Wochen 30 Minuten für ein technisches Gespräch?
Falls das Thema intern schon abgedeckt ist, reicht ein kurzer Hinweis.

Freundliche Grüße
Matt Ji
B2B NixOS & Plattform-Engineering
matt@bountystash.com
https://github.com/shaoyanji/nixconfig · https://linkedin.com/in/mattji
```

**Follow-up, seven days later (DE):**

```text
Guten Tag Herr [NAME],

kurze Nachfrage zu meiner Mail vom {{DATUM}}: Der Punkt ist unverändert — eine
NixOS-Flotte aus einem Flake, hermetische Builds und ein nachvollziehbarer
Rollback-Pfad, verfügbar als B2B-Kapazität ab Dezember.

Passt es gerade nicht, reicht ein Wort — dann lasse ich es dabei.

Freundliche Grüße
Matt
```

**Do not say:** Matt has BSI/VS-NfD experience or deep KVM/Rust work, or that Cyberus needs a consultant.

---

## Send sequence

Stagger the sends; do not blast all three on the same morning.

| Order | Target | Channel | Subject / note | Timing |
| :--- | :--- | :--- | :--- | :--- |
| 1 | [NAME], Numtide | Email, then LinkedIn | "NixOS fleet delivery — subcontract capacity for Numtide" | Tue or Wed, 08:00–09:00 CET |
| 2 | [NAME], Cachix | Email, then LinkedIn | "Cachix Deploy adoption — contract capacity?" | Two days later, same window |
| 3 | [NAME], Cyberus | LinkedIn or contact form; German email if address is published | "NixOS-Plattform für regulierte Umgebungen — kurze Frage" | Two days later, same window |

One follow-up only, in the same thread, seven days later. If there is no reply,
stop. Do not add a second channel after the follow-up; the next touch is a
different reason, not a reminder.

## Before the send key

1. Verify the recipient's current title and spelling; the dossier is not a source of truth.
2. Replace `{{DATE}}` in the follow-up with the date of the first mail.
3. Keep the email under 180 words and the LinkedIn note under 300 characters.
4. Send plain text: no first-contact PDF, no HTML signature, no attachment.
5. Put the rate only after scope is on the table.
6. Log the contact and date in the application pipeline; one follow-up, then close.

## What not to claim

- **No customer or partner status.** Matt is not a Numtide subcontractor, a
  Cachix customer, or a Cyberus vendor. These are opening conversations.
- **No accreditation experience.** No BSI VS-NfD, NATO RESTRICTED, or regulated
  certification work.
- **No invented stack depth.** Rust, KVM, Angular, Terraform and AWS platform
  ownership are not production strengths; say so if asked.
- **No fleet inflation.** Use thirteen hosts, the figure in the resume and the
  `nixconfig` description. Do not quote the larger inventory count.
- **No "zero trust" certification.** Say zero-standing-secret access: SOPS/age
  at rest, short-lived SSH certificates, no standing host keys.

## Sources

Fleet figures are the resume's, not the inventory count; this dossier is not a
source of truth for a title or a spelling.
