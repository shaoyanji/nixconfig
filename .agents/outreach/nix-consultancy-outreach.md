# Nix consultancy outreach

**Status:** ready to send (verified 2026-11-22) · **Prepared:** 2026-11-21 · **Sender:** [SENDER]
**Offer:** B2B NixOS, reproducible-build and platform engineering
**Availability:** from 01.12.2026 · 3–5 days/week · remote from Germany

Each target gets one reason for the conversation, one proof point, one concrete
piece of work [SENDER] can take, and one cheap ask. **Only published work
addresses are recorded here**, read from the target's own site on 2026-11-22; a
person's name and direct line stay `[NAME]` and `[PHONE]`, resolved at send time.

## The position in one paragraph

I make NixOS fleets reproducible enough to hand over: one flake pins every
input, hosts compose from feature lists instead of hand edits, builds run
hermetically, secrets are SOPS/age-encrypted at rest, SSH access uses
short-lived certificates rather than standing host keys, and CI runs the same
module gate the machines run. A change is a generation that can be rolled back,
not a shell history that has to be reconstructed.

That is the work one commercial Nix provider sells, the property a binary-cache
vendor makes economical, and the operations layer a regulated-platform vendor
needs behind a reproducible product.

## Proof bank

| Proof | What it actually demonstrates | Best target |
| :--- | :--- | :--- |
| **13-host NixOS fleet, one flake** | A fleet is declared, not assembled; hosts are functions of feature lists and modules. | [TARGET-A], [TARGET-C] |
| **Pinned inputs and pinned host submodules** | A rebuild is a function of the repository, not of the machine or the day. | [TARGET-A], [TARGET-B] |
| **Hermetic builds with no network** | Build outputs do not depend on ambient state; the store is content-addressed. | [TARGET-B], [TARGET-C] |
| **SOPS/age secrets plus a short-lived SSH CA** | Zero-standing-secret access: secrets are encrypted at rest and host access is issued, not shared. | [TARGET-B], [TARGET-C] |
| **PXE/iVentoy netboot and bare-metal installs** | A machine can arrive, boot an installer over the network, join the declared fleet and be rebuilt. | [TARGET-A], [TARGET-C] |
| **CI module gate and generation rollback** | The check that guards a change is the check the host runs; recovery is a known generation. | [TARGET-A], [TARGET-C] |
| **Go CLI/TUI with PostgreSQL and REST** | Developer tooling with one binary, append-only events and a backend service behind the same interface. | [TARGET-B], [TARGET-A] |
| **Public `nixconfig` repository** | The claims are inspectable, not a slide. | All three |

**Deliberate limits.** No BSI/VS-NfD work, KVM or Rust depth, a managed-cache
customer relationship, a subcontract with a Nix delivery shop, or production
Terraform/AWS ownership.

## Commercial shape

- **Polish entity, hourly:** 150–250 PLN/h, scope-dependent.
- **EU annual contract:** EUR 85,000–120,000, 3–5 days/week.

Rates exclude VAT and expenses; travel is by agreement. Start with a paid
2–3 day discovery, then either a fixed-scope statement of work or a monthly
retainer. Do not put a number in the first message; anchor after the scope is
known.

[SENDER] is a US citizen with permanent German residence (Niederlassungserlaubnis),
works from Germany, and needs no sponsorship. English is native; German is C1.
For a German client, lead in German and attach the English one-page profile only
if asked.

---

## 1. [TARGET-A]

**Role to verify:** Founder and Director.
**Public contact:** contact form on the company site (read 2026-11-22); no personal address used.
**Company:** small independent Nix consultancy, public site verified 2026-11-22.

### Why them

The company is a small team of independent principal engineers selling senior Nix and DevOps delivery, including NixOS commercial support, migrations and custom tooling. Its public project list — a server-profile set, a disk-declaration tool,
an installer that turns any machine into a declared host, a CI builder, a
formatter runner, an environment loader — is the exact problem space [SENDER]
works in: a fleet that has to be installed, declared, checked and handed over. It does not need another Nix tutorial; it needs delivery capacity that can join a
client workstream and make a half-migrated fleet reproducible without a ramp.
[SENDER] has run that state on [SENDER]'s own fleet: thirteen hosts, one flake,
feature-list modules, pinned submodules, PXE installs, CI gate, rollback, SOPS/age
and an SSH CA.

### What [SENDER] can take

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
> builds, SOPS/age secrets, SSH CA, PXE installs. Your team sells exactly that
> senior delivery. I'm looking for B2B subcontract work from December. Open to a
> 20-minute call?

### Email

**Subject:** NixOS fleet delivery — subcontract capacity

```text
Hi [NAME],

You sell senior Nix capacity to teams that need a working fleet, not a proof of
concept. I run one: thirteen NixOS hosts from a single flake, feature-list
modules, pinned inputs and submodules, PXE/iVentoy bare-metal installs, hermetic
builds, SOPS/age secrets and a short-lived SSH CA. CI runs the same module gate
the machines run; every change is a generation that can be rolled back.

If a client workstream needs an extra principal engineer for 3–5 days a week, I
can take delivery without a Nix ramp. I am available on a B2B contract from
01.12.2026, remote from Germany.

Would a 30-minute call in the next two weeks be useful? If the bench is full,
one line is enough.

Best regards,
[SENDER]
B2B NixOS & platform engineering
[EMAIL]
```

**Follow-up, seven days later:**

```text
Hi [NAME],

One short follow-up to my note of {{DATE}}. The concrete offer is unchanged: a
13-host NixOS fleet from one flake, hermetic builds, PXE installs and a CI gate,
available as subcontract capacity from December.

If the timing is wrong, a single line is enough and I will leave it there.

Best,
[SENDER]
```

**Do not say:** [SENDER] has used every tool in that project list, is available
full-time, or knows the company's client bench.

---

## 2. [TARGET-B]

**Role to verify:** Founder.
**Public contact:** about page carries a form; no address published, none used.
**Company:** binary-cache and developer-environment vendor, public site verified 2026-11-22.

### Why them

The company sells the consequence of hermetic builds: never build the same thing twice. Its product surface now spans binary caches, developer environments and a
deployment product that reached general availability in January 2026, letting
agents pull profiles from a cache without evaluating or building on the target.
Its founder's public work also includes a declarative interface for secret
providers — adjacent to the secrets problem [SENDER] solves with SOPS/age and a
short-lived SSH CA. The first cache push is easy; the hard part is making cache
hits trustworthy across CI, development and deployment, keeping secrets out of
the closure, and giving a customer a rollout path that does not depend on a local
evaluator. [SENDER]'s fleet runs the pattern by hand: pinned inputs, a CI gate,
content-addressed outputs, generations and rollback.

### What [SENDER] can take

- A cache and CI audit for a team adopting Nix: what is rebuilt, what is
  substituted, where the closure leaks, and which cache key is actually stable.
- An adoption path for the deployment product on a NixOS or nix-darwin fleet:
  profile promotion, agent rollout, rollback and the boundary between cache and
  target.
- A developer-environment migration: flake outputs, pinned toolchains, a
  taskfile entry point, and documentation that survives the first week.
- Customer-facing integration work where the customer needs an engineer who has
  operated the fleet, not only configured the cache.

### The ask

A 20-minute call about professional-services or partner capacity. If the company
handles this entirely in-house, ask for a pointer to the right person and stop.

### LinkedIn connection note

> Hi [NAME] — I run a 13-host NixOS fleet with pinned flakes, hermetic builds and
> a CI gate; your cache is the economic layer for that. I'd like to compare notes
> on cache and rollout adoption and whether you use contract capacity. Open to
> 20 minutes?

### Email

**Subject:** Cache and rollout adoption — contract capacity?

```text
Hi [NAME],

You sell the consequence of hermetic builds: never build the same thing twice.
The hard part for a customer is not the first cache push; it is trusting cache
hits across CI, development and deployment, and keeping secrets out of the
closure.

I run a 13-host NixOS fleet from one flake with pinned inputs, hermetic builds,
SOPS/age secrets and short-lived SSH certificates. I have the operational scars
that make a cache or deployment rollout stick, and I can help customers with
cache strategy, CI hit rates and fleet migration.

Is there a professional-services or partner bench where a B2B contract would
fit? I am available from 01.12.2026. A 20-minute call would be enough to see if
there is a match.

Best regards,
[SENDER]
B2B NixOS & platform engineering
[EMAIL]
```

**Follow-up, seven days later:**

```text
Hi [NAME],

One short follow-up to my note of {{DATE}}. Your pull-from-cache model is the
pattern I already run by hand on a 13-host NixOS fleet; the offer is to help
customers adopt it without losing rollback or secret hygiene.

If this is handled in-house, a pointer to the right person is enough.

Best,
[SENDER]
```

**Do not say:** [SENDER] is a paying customer, the product is broken, or the
company needs a consultant.

---

## 3. [TARGET-C]

**Primary contact:** [NAME], Co-Founder; engineering/cloud
leadership. Contact form on the company site (read 2026-11-22).
**Secondary:** [NAME], CTO (verify current title before sending).
**Company:** regulated-platform and hypervisor vendor, public site verified 2026-11-22.

Use LinkedIn or the published contact form. Do not guess a personal email
address. If a German message is appropriate, use the variant below; [SENDER]'s
German is C1.

### Why them

The company builds open-source infrastructure for digital sovereignty: a
BSI-accredited hypervisor for VS-NfD and NATO RESTRICTED, a hardened Linux
distribution, and automated testing for regulated environments. Its own
description is "modular, transparent and reproducible software," and it
advertises long-term NixOS platform support, which makes the build-and-operations layer part of the product. A reproducible product needs a reproducible way to
build, provision and operate it, and [SENDER]'s fleet is a small working example:
thirteen NixOS hosts from one flake, pinned inputs, hermetic builds, PXE installs,
SOPS/age secrets, short-lived SSH certificates, CI gates and rollback. The gap is scale and accreditation, not the operating model.

### What [SENDER] can take

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

> Hi [NAME] — your reproducible, NixOS-supported stack is the layer I work in: 13
> NixOS hosts, one flake, hermetic builds, SOPS/age, SSH CA. I'm Germany-based and
> available for B2B platform work. Open to 30 minutes?

### English email

**Subject:** NixOS platform and reproducible builds for regulated environments

```text
Dear [NAME],

You describe modular, transparent and reproducible software, and offer long-term
NixOS support. That is the layer I work in: thirteen NixOS hosts from one flake,
pinned inputs, hermetic builds, SOPS/age secrets and a short-lived SSH CA, with CI
gates and rollback.

I could take on the platform and build side of your Linux distribution or your
internal infrastructure: reproducible artifacts, cache and CI, secrets and
access, and documentation that survives an audit. I am Germany-based, German is
C1, and I am available on a B2B contract from 01.12.2026.

I have not worked under BSI accreditation, and my KVM and Rust depth is not your
engineering team's. I would learn the constraints rather than pretend otherwise.

Would 30 minutes in the next two weeks be useful? If this is already covered
internally, a short note is enough.

Kind regards,
[SENDER]
B2B NixOS & platform engineering
[EMAIL]
```

### German email variant

**Betreff:** NixOS-Plattform für regulierte Umgebungen — kurze Frage

```text
Guten Tag [NAME],

Ihre Seite nennt modulare, transparente und reproduzierbare Software sowie
langfristigen NixOS-Support. Genau dort arbeite ich: eine Flotte von 13
NixOS-Hosts aus einem Flake, gepinnte Inputs, hermetische Builds,
SOPS/age-verschlüsselte Secrets und eine SSH-CA mit kurzlebigen Zertifikaten.

Für Ihre Plattform könnte ich die Betriebs- und Build-Seite übernehmen:
reproduzierbare Artefakte, CI-Gates, Rollbacks und dokumentierte Übergaben für
regulierte Kunden. Ich bin in Deutschland ansässig, arbeite auf B2B-Basis und
spreche Deutsch auf C1-Niveau.

Hätten Sie in den nächsten zwei Wochen 30 Minuten für ein technisches Gespräch?
Falls das Thema intern schon abgedeckt ist, reicht ein kurzer Hinweis.

Freundliche Grüße
[SENDER]
B2B NixOS & Plattform-Engineering
[EMAIL]
```

**Follow-up, seven days later (DE):**

```text
Guten Tag [NAME],

kurze Nachfrage zu meiner Mail vom {{DATUM}}: Der Punkt ist unverändert — eine
NixOS-Flotte aus einem Flake, hermetische Builds und ein nachvollziehbarer
Rollback-Pfad, verfügbar als B2B-Kapazität ab Dezember.

Passt es gerade nicht, reicht ein Wort — dann lasse ich es dabei.

Freundliche Grüße
[SENDER]
```

**Do not say:** [SENDER] has BSI/VS-NfD experience or deep KVM/Rust work, or that
the company needs a consultant.

---

## Send sequence

Stagger the sends; do not blast all three on the same morning.

| Order | Target | Channel | Subject / note | Timing |
| :--- | :--- | :--- | :--- | :--- |
| 1 | [TARGET-A] | Email, then LinkedIn | "NixOS fleet delivery — subcontract capacity" | Tue or Wed, 08:00–09:00 CET |
| 2 | [TARGET-B] | Email, then LinkedIn | "Cache and rollout adoption — contract capacity?" | Two days later, same window |
| 3 | [TARGET-C] | LinkedIn or contact form; German email if address is published | "NixOS-Plattform für regulierte Umgebungen — kurze Frage" | Two days later, same window |

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

- **No customer or partner status.** [SENDER] is not a subcontractor of
  [TARGET-A], a paying customer of [TARGET-B], or a vendor to [TARGET-C]. These
  are opening conversations.
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
