# gemini-mail — the email archive as a Gemini capsule

`gemini://delphi.cloudforest-kardashev.ts.net:1966/mail/` is the archive as a
capsule: search, the newest messages, and one message at a time, from a Gemini
client. It reads the same PostgreSQL rows the tailnet HTTP API on 8450 publishes,
so it is the first capsule here that answers from a live database rather than
serving files — frieren's docs capsule has a CGI too, but `hello` only proves the
wiring.

| | |
| :--- | :--- |
| Landing page | `/mail/` — what the archive holds, how the search works |
| Search | `/cgi-bin/email` with no query answers `10`, so the client asks for one; `?words` answers up to 30 hits with a snippet |
| Newest | `/cgi-bin/latest` — the newest 30 |
| One message | `/cgi-bin/read?<id>` — envelope, attachment name, body in a preformatted block (48 KiB cap); `51` when the archive has no such id |
| Program | `lib/gemini-mail/mail.py` (three modes, one program) |
| Capsule fragment | `lib/gemini-mail.nix` — `/mail/` and `cgi-bin/{email,latest,read}` |
| Mount | `hosts/delphi/gemini.nix` — the 1966 instance only |

**Not a generated page.** Mail arrives hourly, so a capsule compiled at deploy
time would answer yesterday's archive. The scripts query
`EMAIL_ARCHIVE_API` (default `http://127.0.0.1:8080/api`) on request, which is
why the reader is CGI and why the fragment exists only to carry `cgi-bin/`. The
turn log is the second reader on the same capsule: [`gemini-turns.md`](gemini-turns.md).

## Two traps that decide whether it runs

**`CGIPaths` must be relative, and it is set on the tailnet config alone.**
molly-brown's `config.go` joins a relative entry to `DocBase` and leaves an
absolute one alone, then compares the result with the resolved filesystem path;
an absolute `/cgi-bin` never matches a path under `DocBase`. The public 1965
instance names no CGI path at all, so nothing there is executable.

**The fragment is copied onto the capsule, never symlinked.** The server
resolves a CGI's filesystem path *before* matching `CGIPaths`, so a
symlink-joined fragment resolves outside `DocBase` and the script is never
executed. `lib/gemini-mail.nix` therefore `cp -r`s onto the base capsule, and
`lib/gemini-portal.nix` takes an `extra` list so the index links `/mail/` instead
of leaving it a URL you had to know.

## The boundary

The archive is tailnet-only, and so is this reader: 1966 is reached through a
`tailscale0` firewall rule, and the CGI can only talk to loopback. Measured
2026-11-08 after the switch — on the public 1965, `/` answers `20` while `/mail/`
and every `/cgi-bin/*` path answer `51`.

## Verify

`openssl s_client -quiet` prints nothing for a request this server answers on the
OpenSSL 3.5 the host ships (measured 2026-11-08), so probe with Python:

```bash
probe() {
  python3 -c 'import socket,ssl,sys;h,p,x=sys.argv[1],int(sys.argv[2]),sys.argv[3];c=ssl.create_default_context();c.check_hostname=False;c.verify_mode=ssl.CERT_NONE;s=c.wrap_socket(socket.create_connection(("127.0.0.1",p)),server_hostname=h);s.sendall(f"gemini://{h}:{p}{x}\r\n".encode());sys.stdout.write(s.recv(65536).decode())' "$@"
}
H=delphi.cloudforest-kardashev.ts.net
probe $H 1966 /mail/ | head -3                 # 20 text/gemini + the landing page
probe $H 1966 /cgi-bin/email | head -1         # 10 — the client's query prompt
probe $H 1966 '/cgi-bin/email?invoice' | head -1   # 20 + hits
probe $H 1966 /cgi-bin/latest | grep -c '^=> /cgi-bin/read?'   # 30
probe delphi.bountystash.com 1965 /cgi-bin/email | head -1     # 51 — not there
```

The prompt, a hit list, a body inside a preformatted block, `51` for an unknown
id and `40` when the API is down are the six answers worth checking after a
rebuild; each was exercised against the live archive before the first deploy.

## What it is not

- **Not an attachment mirror, by decision.** An attachment is named on the
  message that carried it and never served: the archive holds the file, and a
  capsule copy would be a second home for storage that does not belong in a
  store path. Opening mail here cannot grow the capsule.
- **Not the whole mailbox.** The importer walks the inbox; sent mail and other
  folders are absent until something posts them, and a message stored as an
  envelope says so when opened.
- **Not authenticated.** Tailnet membership is the gate, as it is for 8450.
