---
name: envs
description: "Envs.net Debian hosting: SSH, web, Gemini, Gopher."
version: 0.1.1
author: Shaoyan Ji (shaoyanji), Hermes Agent
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: ['envs', 'debian']
    related_skills: []
---

# envs — the pubnix, and the pipeline its site needs

| | |
| :--- | :--- |
| Host | `envs.net`, Debian 13 trixie, alias `envs` |
| Web | `https://jisifu.envs.net` → `~/public_html` (nginx + PHP 8.4; also `https://envs.net/~jisifu`) |
| Gemini | `gemini://envs.net/~jisifu` → `~/public_gemini` |
| Gopher | `gopher://envs.net/1/~jisifu` → `~/public_gopher` |

The capsule and the gopher hole are served by path, not by vhost: `gemini://jisifu.envs.net`
answers `53 This server does not allow proxy requests`, and `jisifu.envs.net:70`
returns the shared envs.net banner instead of your gophermap. Use the `~jisifu`
forms (measured 2026-11-02).

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

## Known issues

The per-user PHP-FPM pool does not answer (measured 2026-11-02):
`https://jisifu.envs.net/index.php` hangs for 15 s and returns 0 bytes even
though `/run/php/php8.4-fpm.sock` exists. nginx therefore serves only what
`make static` wrote, and every route is a pre-rendered `index.html`. A page that
"does not update" is usually this, not the generator — restart
`envs-php-user@jisifu.socket` and `.service` (needs `#envs`), then rebuild.

Truth: `taskfiles/envs.yml` — the executable contract; this page is the procedure.
