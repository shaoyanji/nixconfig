# lib/gemini-turns.nix — the agent turn log as a Gemini capsule fragment: a
# landing page plus four CGI wrappers over ./gemini-turns/turns.py. Mounting rule
# and the token's path-never-value rule: docs/gemini-turns.md.
{
  pkgs,
  lib ? pkgs.lib,
  api ? "http://127.0.0.1:8093/v1/events",
  tokenFile ? "/run/secrets/rendered/gemini-turns-token",
}: let
  script = ./gemini-turns/turns.py;

  # One wrapper per mode, for the same reason as the mail reader: the URL is the
  # interface, so `/cgi-bin/turns-live` needs no query key a reader must be told.
  cgi = name: mode:
    pkgs.writeTextFile {
      name = "gemini-turns-${name}";
      executable = true;
      text = ''
        #!${pkgs.runtimeShell}
        AGENT_TURNS_API=${lib.escapeShellArg api} \
          AGENT_TURNS_TOKEN_FILE=${lib.escapeShellArg tokenFile} \
          exec ${pkgs.python3}/bin/python3 ${script} ${mode}
      '';
    };

  landing = pkgs.writeText "gemini-turns-index.gmi" ''
    # Agent turns

    Every agent turn in the fleet, one summary per turn: who worked, on what
    subject, what changed, and whether it is done, still open, or blocked. This
    is the coordination log an agent reads before it starts and writes when it
    finishes.

    => /cgi-bin/turns search — words across subject, action, rationale, claims, files
    => /cgi-bin/turns-latest the newest 30 turns
    => /cgi-bin/turns-live what is claimed right now

    ## What a turn holds

    The summary: a timestamp, the agent, a subject of the form `repo:task-id`,
    one line of action, an outcome. Opening a turn adds its rationale, the areas
    it claims, the files it lists, the commits it made, and the branch it ran
    from. The full record is what the coordination contract carries — this page
    shows the same fields, not a different account of them.

    ## What this page is not

    Read-only. Appending a turn needs the bearer token an agent already holds
    and the shim that validates the schema; there is no write route here, and the
    store behind it refuses updates and deletes.

    ## Elsewhere

    => / the portfolio
    => /mail/ the mail archive
  '';
in {
  # The gemtext a capsule's index appends so the log is reachable from the front
  # page. Passed to lib/gemini-portal.nix's `extra`.
  indexSection = [
    ""
    "## Agent turns"
    ""
    "=> /turns/ the turn log — what each agent changed, and what is claimed now"
  ];

  fragment =
    pkgs.runCommand "gemini-turns" {
      meta.description = "The agent turn log as a Gemini capsule fragment: /turns/ and /cgi-bin/{turns,turns-latest,turns-live,turn}";
    } ''
      install -Dm644 ${landing} $out/turns/index.gmi
      install -Dm755 ${cgi "turns" "search"} $out/cgi-bin/turns
      install -Dm755 ${cgi "turns-latest" "latest"} $out/cgi-bin/turns-latest
      install -Dm755 ${cgi "turns-live" "live"} $out/cgi-bin/turns-live
      install -Dm755 ${cgi "turn" "read"} $out/cgi-bin/turn
    '';

  # Copied onto an existing capsule — `cp`, never a symlink join: molly-brown
  # resolves a CGI's path before matching `CGIPaths`, so a symlinked fragment
  # resolves outside DocBase and never runs (lib/gemini-mail.nix carries the
  # measurement).
  capsule = base:
    pkgs.runCommand "gemini-turns-capsule" {
      meta.description = "A capsule plus the agent turn log under /turns and /cgi-bin";
    } ''
      cp -r ${base} $out
      chmod -R u+w $out
      install -Dm644 ${landing} $out/turns/index.gmi
      install -Dm755 ${cgi "turns" "search"} $out/cgi-bin/turns
      install -Dm755 ${cgi "turns-latest" "latest"} $out/cgi-bin/turns-latest
      install -Dm755 ${cgi "turns-live" "live"} $out/cgi-bin/turns-live
      install -Dm755 ${cgi "turn" "read"} $out/cgi-bin/turn
    '';
}
