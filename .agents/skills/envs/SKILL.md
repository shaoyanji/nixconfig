---
name: envs
description: "Envs.net Debian hosting: SSH, web, Gemini, Gopher."
version: 0.1.0
author: Shaoyan Ji (shaoyanji), Hermes Agent
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: ['envs', 'alwaysdata', 'debian']
    related_skills: []
---

# envs — the pubnix, and the pipeline its site needs

| | |
| :--- | :--- |
| Host | `envs.net`, Debian 13 trixie, alias `envs` |
| Web | `https://jisifu.envs.net` → `~/public_html` (nginx + PHP 8.4) |
| Gemini | `gemini://jisifu.envs.net` → `~/public_gemini` |
| Gopher | `gopher://jisifu.envs.net` → `~/public_gopher` |

The content is markdown; the site is generated. Three scripts in `public_html`
do the work, and their order is the release:

1. `generate_json.php` — markdown → JSON, tags, SPA routes.
2. `validate_tags.php` and `validate-equations.php` — refuse to publish a page
   with unbalanced HTML or a malformed equation block.
3. `srs-export.php` — flashcard export.

`task envs:build` runs the generator, tag validation, the SRS export and the SPA
routes; `envs:validate` is the equation/HTML gate on its own; `envs:test` is the
PHP suite. A markdown edit on its own does not touch the JSON index or the
routes, so a new page stays unreachable until `envs:build` runs again.

`task envs:exec -- "<cmd>"` is the agent entry point; `envs:ssh` is interactive.
Permissions matter here (pubnix): `envs:harden` enforces SSH 700/600 and
`public_html` 750.

Truth: `taskfiles/envs.yml` — the executable contract; this page is the procedure.
