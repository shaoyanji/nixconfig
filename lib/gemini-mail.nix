# lib/gemini-mail.nix — the mail archive as a Gemini capsule fragment: a landing
# page plus CGI wrappers over ./gemini-mail/mail.py. Mounting rule and the query
# contract: docs/gemini-mail.md.
{
  pkgs,
  lib ? pkgs.lib,
  api ? "http://127.0.0.1:8080/api",
}: let
  script = ./gemini-mail/mail.py;

  # One wrapper per mode. The URL is the interface, so `/cgi-bin/email?words`
  # and `/cgi-bin/read?<id>` are separate scripts rather than a query-key
  # convention a reader would have to be told about.
  cgi = name: mode:
    pkgs.writeTextFile {
      name = "gemini-mail-${name}";
      executable = true;
      text = ''
        #!${pkgs.runtimeShell}
        EMAIL_ARCHIVE_API=${lib.escapeShellArg api} \
          exec ${pkgs.python3}/bin/python3 ${script} ${mode}
      '';
    };

  landing = pkgs.writeText "gemini-mail-index.gmi" ''
    # Mail archive

    The archive on this host: every message the importer has stored, searchable
    and readable without a browser.

    => /cgi-bin/email search — words, "a phrase", OR, -excluded
    => /cgi-bin/latest the newest 30 messages
    => /cgi-bin/attention what needs a person

    ## What is in here

    The inbox, as the importer walks it: plain text, one mailbox. Sent mail and
    other folders are not served yet, and a message the importer saw only as an
    envelope says so when you open it.

    An attachment is a link to a notice saying where the file lives, never the
    file: the capsule mirrors no bytes, so reading mail here cannot grow the
    store.

    ## What needs a person

    The attention queue is the other reading order: every message still open in
    the person, review or action tier, a person's mail first, each with the
    classifier's reason. A message an agent already owns is in that agent's
    queue instead, so this page stays about people. Resolving is a write, and a
    capsule read does not write; `task agents:mail:resolve` and
    `agents:mail:sweep` do that on the host.

    ## How the search works

    Full text over sender, subject and body, newest first, 30 results. The
    syntax is PostgreSQL's web search form: quote a phrase, join alternatives
    with OR, exclude a word with a leading minus. The search link asks your
    client for a query, so the same page works from any Gemini client.

    ## Elsewhere

    => / the portfolio
    => /turns/ the agent turn log
    => gemini://gemini.frieren.lan/ the fleet's documentation over Gemini (LAN)
  '';
in {
  # The gemtext a capsule's index appends to reach the reader. Passed to
  # lib/gemini-portal.nix's `extra`, so the link sits in the index rather than
  # after its footer.
  indexSection = [
    ""
    "## Mail"
    ""
    "=> /mail/ the mail archive — search every message the importer stored"
  ];

  fragment =
    pkgs.runCommand "gemini-mail" {
      meta.description = "The mail archive as a Gemini capsule fragment: /mail/ and /cgi-bin/{email,latest,read,attention,attachment}";
    } ''
      install -Dm644 ${landing} $out/mail/index.gmi
      install -Dm755 ${cgi "email" "search"} $out/cgi-bin/email
      install -Dm755 ${cgi "latest" "latest"} $out/cgi-bin/latest
      install -Dm755 ${cgi "read" "read"} $out/cgi-bin/read
      install -Dm755 ${cgi "attention" "attention"} $out/cgi-bin/attention
      install -Dm755 ${cgi "attachment" "attachment"} $out/cgi-bin/attachment
    '';

  # The fragment copied onto an existing capsule. `cp`, not a symlink join:
  # molly-brown resolves a CGI's path before matching `CGIPaths`, so a symlinked
  # fragment would resolve outside DocBase and never match — the same trap as an
  # absolute CGIPaths entry.
  capsule = base:
    pkgs.runCommand "gemini-mail-capsule" {
      meta.description = "A capsule plus the mail archive reader under /mail and /cgi-bin";
    } ''
      cp -r ${base} $out
      chmod -R u+w $out
      install -Dm644 ${landing} $out/mail/index.gmi
      install -Dm755 ${cgi "email" "search"} $out/cgi-bin/email
      install -Dm755 ${cgi "latest" "latest"} $out/cgi-bin/latest
      install -Dm755 ${cgi "read" "read"} $out/cgi-bin/read
      install -Dm755 ${cgi "attention" "attention"} $out/cgi-bin/attention
      install -Dm755 ${cgi "attachment" "attachment"} $out/cgi-bin/attachment
    '';
}
