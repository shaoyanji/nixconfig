# lib/gemini-portal.nix — the bountystash portfolio as a Gemini capsule: gemtext
# pages plus resume.json / lebenslauf.json. Layout and rationale:
# .agents/deploy/hosts/delphi.md § The Gemini capsule.
{
  pkgs,
  lib ? pkgs.lib,
  data ? builtins.fromJSON (builtins.readFile ./bountystash/portfolio.json),
  dataDe ? builtins.fromJSON (builtins.readFile ./bountystash/portfolio.de.json),
}: let
  shared = import ./bountystash/shared.nix {inherit lib;};
  inherit (shared) labels slug;

  locales = {
    en = data;
    de = dataDe;
  };
  d = lang: locales.${lang};
  t = lang: labels.${lang};
  root = lang:
    if lang == "de"
    then "/de/"
    else "/";

  slugs = map (p: slug p.title) data.projects;

  # Gemini-only vocabulary; section labels and slugs come from
  # lib/bountystash/shared.nix so both surfaces stay in step.
  local = {
    en = {
      machine = "Machine-readable";
      resume = "resume.json — this document as JSON";
      lebenslauf = "lebenslauf.json — the German CV as JSON";
      languages = "Languages";
      other = "Deutsch — dasselbe Portal auf Deutsch";
      elsewhere = "Elsewhere";
      https = "the same portfolio over HTTPS";
      project = "project page";
    };
    de = {
      machine = "Maschinenlesbar";
      resume = "resume.json — dieses Dokument als JSON";
      lebenslauf = "lebenslauf.json — der Lebenslauf als JSON";
      languages = "Sprachen";
      other = "English — the same portal in English";
      elsewhere = "Weiter";
      https = "dasselbe Portfolio über HTTPS";
      project = "Projektseite";
    };
  };
  c = lang: local.${lang};

  heading = level: text: "${lib.concatStringsSep "" (lib.genList (_: "#") level)} ${text}";
  # A gemtext link is a line of its own, and needs a label: clients do not
  # auto-link a bare URL.
  link = url: label: "=> ${url} ${label}";
  bullets = xs: map (x: "* ${x}") xs;
  join = lines: lib.concatStringsSep "\n" lines + "\n";

  # The three contacts the HTML page publishes; the phone number in the same
  # JSON is not a capsule decision.
  contacts = p: [
    (link "mailto:${p.contacts.email}" p.contacts.email)
    (link p.contacts.github "github")
    (link p.contacts.linkedin "linkedin")
  ];

  indexDoc = lang: let
    x = d lang;
    p = x.profile;
    v = t lang;
    m = c lang;
    work =
      lib.imap0 (
        i: pr: link "${root lang}work/${builtins.elemAt slugs i}.gmi" "${pr.title} — ${pr.period}"
      )
      x.projects;
    stack = lib.concatMap (cat: ["" (heading 3 cat.category) "" (lib.concatStringsSep " · " cat.items)]) x.skills;
    principles = lib.concatMap (q: ["" (heading 3 q.title) "" q.body]) x.philosophy;
    education = bullets (map (e: "${e.degree} — ${e.school} (${e.period})") p.education);
  in
    join (
      [
        "# ${p.name}"
        ""
        p.title
        ""
        p.subtitle
        ""
        p.location
        p.status.text
        ""
      ]
      ++ contacts p
      ++ ["" (heading 2 v.profile) "" p.bio]
      ++ ["" (heading 2 v.metrics) ""]
      ++ bullets (map (m: "${m.label} — ${m.value}") x.metrics)
      ++ ["" (heading 2 v.work) ""]
      ++ work
      ++ ["" (heading 2 v.stack)]
      ++ stack
      ++ ["" (heading 2 v.principles)]
      ++ principles
      ++ ["" (heading 2 v.record) "" (heading 3 v.education) ""]
      ++ education
      ++ ["" (heading 3 v.auth) "" "${p.work_auth.citizenship} · ${p.work_auth.residency} · ${p.work_auth.languages}"]
      ++ ["" (heading 3 v.contact) ""]
      ++ contacts p
      ++ ["" (heading 2 m.machine) "" (link "/resume.json" m.resume) (link "/lebenslauf.json" m.lebenslauf)]
      ++ [
        ""
        (heading 2 m.languages)
        ""
        (link (root (
            if lang == "de"
            then "en"
            else "de"
          ))
          m.other)
      ]
      ++ ["" (heading 2 m.elsewhere) "" (link "https://www.bountystash.com" m.https)]
      ++ ["" v.footer]
    );

  projectDoc = lang: i: let
    x = d lang;
    v = t lang;
    m = c lang;
    pr = builtins.elemAt x.projects i;
  in
    join (
      ["# ${pr.title}" "" "${pr.role} · ${pr.period}" "" pr.description]
      ++ ["" (heading 2 v.impact) "" pr.impact]
      ++ ["" (heading 2 v.stackLabel) ""]
      ++ bullets pr.stack
      # `link` is "#" for a project with no public page, and a gemtext link to
      # "#" is a dead end.
      ++ lib.optionals (pr.link != "" && pr.link != "#") ["" (link pr.link m.project)]
      ++ ["" (link (root lang) v.back)]
    );

  # The rendered document with its provenance. Field names are the source's:
  # a consumer reads exactly what the capsule displays.
  resume = lang: {
    schemaVersion = 1;
    generatedBy = "lib/gemini-portal.nix";
    locale =
      if lang == "de"
      then "de-DE"
      else "en-US";
    source =
      if lang == "de"
      then "lib/bountystash/portfolio.de.json"
      else "lib/bountystash/portfolio.json";
    inherit (d lang) profile metrics skills projects philosophy notes;
  };

  page = name: text: pkgs.writeText "gemini-${name}" text;
in
  pkgs.runCommand "gemini-portal" {
    nativeBuildInputs = [pkgs.jq];
    meta.description = "bountystash.com as a Gemini capsule: gemtext portal plus resume.json and lebenslauf.json";
  } ''
    mkdir -p $out/work $out/de/work

    install -m 0644 ${page "index.gmi" (indexDoc "en")} $out/index.gmi
    install -m 0644 ${page "de-index.gmi" (indexDoc "de")} $out/de/index.gmi

    ${lib.concatStringsSep "\n" (lib.imap0 (i: _: ''
        install -m 0644 ${page "work-${builtins.elemAt slugs i}.gmi" (projectDoc "en" i)} $out/work/${builtins.elemAt slugs i}.gmi
        install -m 0644 ${page "de-work-${builtins.elemAt slugs i}.gmi" (projectDoc "de" i)} $out/de/work/${builtins.elemAt slugs i}.gmi
      '')
      data.projects)}

    # Pretty-printed: people read these on a gemini client as often as programs do.
    ${pkgs.jq}/bin/jq . ${page "resume.json" (builtins.toJSON (resume "en"))} > $out/resume.json
    ${pkgs.jq}/bin/jq . ${page "lebenslauf.json" (builtins.toJSON (resume "de"))} > $out/lebenslauf.json
  ''
