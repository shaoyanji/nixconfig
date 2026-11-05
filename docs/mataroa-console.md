# Mataroa console

A blog on [mataroa.blog](https://mataroa.blog) gives you a form in a browser and
an API. Neither gives you a directory of files you can grep, diff, edit in vim and
commit — and with the API alone, "what is on my blog?" is a question you answer by
reading HTTP.

So the console inverts it: **the files are the source, the blog is a deployment
target.** `posts/<slug>.md` on delphi is the writing; publishing is a POST or a
PATCH against mataroa, and the console keeps a ledger of which files differ from
what the blog holds.

- module: `modules/services/mataroa-console.nix` (`services.mataroaConsole`)
- program: `modules/scripts/mataroa-console.py` (stdlib only, no dependencies)
- host: `hosts/delphi/mataroa-console.nix` · unit `mataroa-console.service`
- loopback **:8095**, tailnet mount **:8454** (`tailscale-serve-mataroa`), card on
  the tailnet service portal
- state: `/var/lib/mataroa-console/posts/`, a git repository the service commits to

## The model

| | where | who owns it |
| --- | --- | --- |
| the text | `posts/<slug>.md` with `title`, `published_at` frontmatter | you, in vim or the editor page |
| the history | `git log` in the state directory | the service, one commit per write |
| the publication | mataroa's database, via `POST`/`PATCH /api/posts/` | the ledger says when it differs |

A post that exists only on the blog is `remote-only`; a file never published is
`local-only`; both present with different bodies or dates is `differs`. That is
the whole state machine, and it is displayed rather than resolved automatically,
because a `differs` row is a decision about which copy is right.

## Endpoints

| Route | What |
| --- | --- |
| `GET /` | the ledger: every post with its state |
| `GET /p/<slug>` | one post, rendered through comrak |
| `GET /e/<slug>`, `GET /e/new` | the editor |
| `POST /save`, `/publish`, `/unpublish`, `/pull` | the editor's forms |
| `GET /api/state` | the ledger as JSON |
| `GET /api/post/<slug>` | one post as JSON |
| `PUT /api/post/<slug>` | write the file (title, body, published_at) |
| `POST /api/publish/<slug>`, `/api/unpublish/<slug>`, `/api/pull` | against the blog |
| `DELETE /api/post/<slug>` | remove the local file |

Publishing decides `POST` against `PATCH` by asking the blog's post list first: a
slug mataroa already has is updated in place, so a re-publish cannot mint a
duplicate. Unpublish is `published_at: ""`, which is mataroa's own draft marker.

## Two guards, one fence

The listener is loopback and the only route in is the tailnet mount, so "on the
tailnet" is the fence. On top of that:

- **API writes** need `X-Mataroa-Write: 1`, and the `Origin` when one is sent.
  A cross-site request cannot set a custom header without a preflight, which the
  console never grants.
- **Form writes** require `Origin` to be exactly `https://<tailnetHost>:<tailnetPort>`,
  because a form cannot set a header. Browsers send `Origin` on every form POST;
  a request with no `Origin` is not a browser form, and the scriptable path is the
  JSON API next to it.

The origin is a module option (`tailnetHost` + `tailnetPort`) and the mount reads
the same options, so the check cannot disagree with the address the page is open
at.

## The token

The bearer token lives in `modules/secrets.yaml` under `mataroa/api/key` — the
tracked fleet file, not `modules/secrets/apikeys.yaml`, whose directory is a
submodule outside the flake and therefore absent from a `github:` build. It
reaches the process through `LoadCredential`, is read from
`$CREDENTIALS_DIRECTORY/mataroa-token`, and is never rendered, logged, or written
into a post file. Rotation is an edit of that key plus a restart.

The console reports a rejected token on the ledger page rather than inventing an
empty blog: `Not authorized.` in the header is mataroa answering 403, and the fix
is a fresh key from the blog's settings.

## Operator recipes

```bash
task dev:blog:mataroa                     # the ledger from any tailnet host (TOON)
task dev:blog:mataroa FORMAT=text         # state, date, slug

# write from a shell, without a browser
curl -fsS -X PUT -H 'X-Mataroa-Write: 1' -H 'Content-Type: application/json' \
  -d '{"title":"…","body":"…","published_at":""}' \
  https://delphi.cloudforest-kardashev.ts.net:8454/api/post/my-slug

curl -fsS -X POST -H 'X-Mataroa-Write: 1' \
  https://delphi.cloudforest-kardashev.ts.net:8454/api/publish/my-slug

curl -fsS -X POST -H 'X-Mataroa-Write: 1' \
  https://delphi.cloudforest-kardashev.ts.net:8454/api/pull
```

## What is not done

- The API also has comments (list, pending, approve, delete) and pages
  (create, get, update, delete, list). The console does neither yet.
- The ledger trusts mataroa's post list for existence and its `body` for the
  comparison; there is no three-way merge, so a `differs` row is resolved by
  publishing or by pulling, never both at once.
- Backups are the state directory's git history on delphi, which is a second copy
  on the same disk: worth a restic target before the posts matter.
