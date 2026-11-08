# gemini-turns — the agent turn log as a Gemini capsule

`gemini://delphi.cloudforest-kardashev.ts.net:1966/turns/` is the fleet's turn
log as a capsule: the newest turns, a word search, and the claims that are open
right now, from a Gemini client. It reads the same shim the agents write through
(`docs/agent-turns.md`), on loopback, so nothing is a copy that can drift.

| | |
| :--- | :--- |
| Landing page | `/turns/` — what a turn holds, and what this page cannot do |
| Search | `/cgi-bin/turns` with no query answers `10`, so the client asks; `?words` answers up to 30 ranked hits |
| Newest | `/cgi-bin/turns-latest` — the newest 30 turns |
| Open claims | `/cgi-bin/turns-live` — one row per subject still `in_progress` |
| One turn | `/cgi-bin/turn?<id>` — frame id or client UUID, a prefix is enough; `51` when the page holds no such turn |
| Program | `lib/gemini-turns/turns.py` (four modes, one program) |
| Capsule fragment | `lib/gemini-turns.nix` — `/turns/` and `cgi-bin/{turns,turns-latest,turns-live,turn}` |
| Mount | `hosts/delphi/gemini.nix` — the 1966 instance only |

Turns arrive all day, so this is a CGI like the mail reader and for the same
reason: a page compiled at deploy time would answer yesterday's claims.

## The token is a file, because a CGI gets no environment

`molly-brown` starts a CGI with an empty environment (`dynamic.go`:
`cmd.Env = []string{}`), so a unit's `EnvironmentFile` never reaches the script —
a detail worth knowing before reaching for the obvious answer. The token is
therefore read from a file whose **path** the wrapper passes:

```nix
sops.templates."gemini-turns-token" = {
  content = config.sops.placeholder."agent-turns-token";
  mode = "0440";
  group = "gemini";
};
```

`/run/secrets/rendered` is `0751`, so the capsule's service group can traverse it
and read the file; the capsule store path itself never holds a value, which
matters because a store path is world-readable. Rendered from
`sops.placeholder`, so there is one credential rather than a second copy of it —
which also means the capsule holds a token that can append, because the shim has
no read-only scope. The reader never uses that side; if it ever needs to be
separated, the shim needs a scopes field, not a new secret.

The shim reads its tokens once at start and the template replaces the file's
inode on rotation, so `sops.secrets."agent-turns-token".restartUnits` carries
both `agent-turns-shim.service` and `molly-brown-tailnet.service`.

## Limits worth knowing

- **One page of 200.** The shim's `maxLimit` is 200 and a CGI can ask once, so a
  word that appears only in an older turn is not found here. `agents:xs:list`
  scans 2000 frames and is the full answer.
- **Ranking follows the task's read model, not recency**: a subject hit outranks
  an action hit, which outranks a rationale hit.
- **Live** is the newest turn per subject when its outcome is `in_progress`.
  Past 7 days it is printed as *stale* and the row says so — the gate does not
  fail on a claim whose agent died, and neither does this page.
- **Read-only.** There is no write route: appending needs the shim's schema
  validation and an agent's token, and the store refuses update and delete.

## Cross-links

The portfolio index on 1966 links both readers (`## Mail`, `## Agent turns`);
`/mail/` and `/turns/` link each other and `/`. On the mail page the frieren docs
capsule is labelled *LAN*: `gemini.frieren.lan` does not resolve off the LAN, and
1966 is a tailnet name.

## Verify

`openssl s_client -quiet` prints nothing for a request this host answers (OpenSSL
3.5, measured 2026-11-08), so probe with the Python one-liner in
[`gemini-mail.md`](gemini-mail.md#verify):

```bash
H=delphi.cloudforest-kardashev.ts.net
probe $H 1966 /turns/ | head -3                      # 20 text/gemini + the landing page
probe $H 1966 /cgi-bin/turns | head -1               # 10 — the client's query prompt
probe $H 1966 '/cgi-bin/turns?gemini' | head -1      # 20 + hits
probe $H 1966 /cgi-bin/turns-live | head -5          # the open claims
probe $H 1966 '/cgi-bin/turn?zzzzzz' | head -1       # 51 — no such turn
probe delphi.bountystash.com 1965 /turns/ | head -1  # 51 — not on the public capsule
```

`40` when the shim is down or the token file is unreadable is the sixth answer:
the status line names which, without printing the token.

## What it is not

- **Not a second ledger.** The rows are the shim's fields; the markdown ledgers
  were retired, and this page is not a place for one to grow back.
- **Not writable, not authenticated beyond the tailnet.** Membership is the gate,
  as it is for 8449.
