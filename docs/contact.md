# Contact

One page for the operator's own contact facts, so no other page carries a copy.
Third-party contacts are not kept here at all — see the last section.

## Matt Ji

| Field | Value | Source |
| :--- | :--- | :--- |
| Name | Matt Ji | `lib/matt/profile.json` (`profile.name`) |
| Role | Systems & Infrastructure Engineer | `lib/matt/profile.json` (`profile.title`) |
| E-mail | `<matt@bountystash.com>` | `lib/matt/profile.json` (`profile.handle`) |
| Portfolio | <https://matt.bountystash.com> | `lib/matt/profile.json` (`profile.url`) |
| GitHub | <https://github.com/shaoyanji> | `profile.contacts` |
| LinkedIn | <https://linkedin.com/in/mattji> | `profile.contacts` |
| XING | <https://xing.com/profile/Shaoyan_Ji> | `profile.contacts` |
| Phone | not printed here | `modules/secrets/pii.yaml` |
| Street address | not printed here | `modules/secrets/pii.yaml` |
| Referees | not printed here | `modules/secrets/pii.yaml` |

The three private rows are sops-encrypted in the secrets submodule because a
tracked file is a published file [[flake/policies.nix#private-data-is-not-a-build-input]].
Read one without decrypting the file by hand:

```bash
task apps:pii:sync                     # -> ~/.config/appflow/pii.json (0600, outside the repo)
scripts/task/pii.sh get basics.phone   # one value, straight into a document
```

`lib/matt/profile.json` is the published half: the site renders every value in it,
so keeping it in the tree hides nothing.

## Where a contact block comes from

| Surface | Path |
| :--- | :--- |
| Website header and `hire` block | `lib/matt/profile.json` |
| CV and letter (phone, street address) | `scripts/task/appflow-packet.sh` merges `pii.json` into the corpus at build time |
| Cold-mail signatures | `docs/job-cold-email.md` uses `{{EMAIL}}`, filled from the values above |
| Application packets | `${APPFLOW_PACKETS:-~/.local/state/appflow/submissions}/<slug>/submission-sheet.md`, deliberately outside this public tree |

## Third-party contacts

Nothing here records another person's address, direct line or profile slug. Two
consequences worth knowing:

- The outreach dossier at `.agents/outreach/nix-consultancy-outreach.md` names no
  target either: companies are `[TARGET-A]`, `[TARGET-B]` and `[TARGET-C]`, and
  the person, address and direct line are `[NAME]`, `[EMAIL]` and `[PHONE]`
  slots resolved from the target's own site at send time.
- An advert's own contact block (a hiring manager, a works council address) may
  appear in that application's `submission-sheet.md`, because the portal form is
  where it is used. It stays in that packet and is not copied into `docs/`.
