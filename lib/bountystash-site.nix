# lib/bountystash-site.nix — the portfolio, as evaluated data
{
  pkgs,
  lib ? pkgs.lib,
  data ? builtins.fromJSON (builtins.readFile ./bountystash/portfolio.json),
  dataDe ? builtins.fromJSON (builtins.readFile ./bountystash/portfolio.de.json),
}: let
  esc = lib.escapeXML;

  render = file: values: let
    text = builtins.readFile file;
    names = builtins.attrNames values;
    out = lib.replaceStrings (map (n: "{{${n}}}") names) (map (n: toString values.${n}) names) text;
    unbound = lib.head (lib.splitString "}}" (lib.last (lib.splitString "{{" out)));
  in
    if lib.hasInfix "{{" out
    then throw "template ${toString file}: unbound placeholder {{${unbound}}}"
    else out;

  # Vocabulary and slugs are shared with the Gemini capsule (lib/gemini-portal.nix),
  # so the two surfaces cannot rename a section or move a case study differently.
  shared = import ./bountystash/shared.nix {inherit lib;};
  inherit (shared) labels slug;

  # The deploy target. Both locales and every case study are pages on this one
  # origin, so a canonical, an og:url and a sitemap entry all derive from it.
  siteUrl = "https://bountystash.com";

  slugs = map (p: slug p.title) data.projects;
  # The file keeps `.html`; every link uses the URL Cloudflare Pages serves,
  # because it 308-redirects the extension away and a canonical that needs a
  # redirect is a canonical that disagrees with the address bar.
  projectAt = i: {
    en = builtins.elemAt data.projects i;
    de = builtins.elemAt dataDe.projects i;
    file = "${builtins.elemAt slugs i}.html";
    href = "/work/${builtins.elemAt slugs i}";
  };

  css = builtins.readFile ./bountystash/style.css;

  # Every internal link on this site is root-relative: the project pages live one
  # directory deeper than the home pages, and a stylesheet href derived from the
  # locale's depth (`style.css` on `/work/x`) is served from `/work/style.css`,
  # which does not exist. The page returns 200 and renders unstyled. Absolute is
  # the one form that cannot be right on one page and wrong on another;
  # `task site:links` resolves all of them against the built artifact.
  asset = path: "/${path}";

  mkLocale = lang: let
    d =
      if lang == "de"
      then dataDe
      else data;
    t = labels.${lang};
    # Where this locale's pages sit on the origin, used only for absolutes:
    # canonical, og:url and the sitemap. Every in-page link is root-relative.
    prefix =
      if lang == "de"
      then "/de"
      else "";
    p = d.profile;
    ogImage = "${siteUrl}/${
      if lang == "de"
      then "og-de.png"
      else "og.png"
    }";

    nav = lib.concatMapStringsSep "" (s: ''<a href="${prefix}/#${s.id}">${s.n} ${esc s.label}</a>'') [
      {
        id = "profile";
        n = "00";
        label = t.profile;
      }
      {
        id = "metrics";
        n = "01";
        label = t.metrics;
      }
      {
        id = "work";
        n = "02";
        label = t.work;
      }
      {
        id = "stack";
        n = "03";
        label = t.stack;
      }
      {
        id = "principles";
        n = "04";
        label = t.principles;
      }
      {
        id = "record";
        n = "05";
        label = t.record;
      }
    ];

    metrics =
      lib.concatMapStringsSep "" (m: ''
        <div><dt>${esc m.label}</dt><dd>${esc m.value}</dd></div>
      '')
      d.metrics;

    workRows = lib.concatMapStringsSep "" (i: let
      pr = projectAt i;
      x = pr.en;
    in ''
      <li><a href="${prefix}${pr.href}">
        <span class="yr">${esc x.period}</span>
        <span><strong>${esc x.title}</strong><span class="org">${esc x.role}</span></span>
        <span class="go" aria-hidden="true">→</span>
      </a></li>
    '') (lib.range 0 (builtins.length data.projects - 1));

    stack =
      lib.concatMapStringsSep "" (c: ''
        <details>
          <summary><span>${esc c.category}</span><span>${toString (builtins.length c.items)} ${t.items}</span></summary>
          <ul class="tags">${lib.concatMapStringsSep "" (i: "<li>${esc i}</li>") c.items}</ul>
        </details>
      '')
      d.skills;

    principles =
      lib.concatMapStringsSep "" (x: ''
        <article><h3>${esc x.title}</h3><p>${esc x.body}</p></article>
      '')
      d.philosophy;

    education = lib.concatMapStringsSep "" (e: "
      <span>${esc e.degree} — ${esc e.school} <span class=\"org\">${esc e.period}</span></span>
    ") p.education;

    contacts = lib.concatMapStringsSep " · " (c: ''<a href="${c.href}">${esc c.label}</a>'') [
      {
        label = "email";
        href = "mailto:${p.contacts.email}";
      }
      {
        label = "github";
        href = p.contacts.github;
      }
      {
        label = "linkedin";
        href = p.contacts.linkedin;
      }
    ];

    body = ''
      <section id="profile">
        <h2><span>00</span> ${t.profile}</h2>
        <p class="lede">${esc p.bio}</p>
      </section>

      <section id="metrics">
        <h2><span>01</span> ${t.metrics}</h2>
        <dl class="metrics">${metrics}</dl>
      </section>

      <section id="work">
        <h2><span>02</span> ${t.work}</h2>
        <ol class="work">${workRows}</ol>
      </section>

      <section id="stack">
        <h2><span>03</span> ${t.stack}</h2>
        ${stack}
      </section>

      <section id="principles">
        <h2><span>04</span> ${t.principles}</h2>
        <div class="principles">${principles}</div>
      </section>

      <section id="record">
        <h2><span>05</span> ${t.record}</h2>
        <dl class="record">
          <dt>${t.education}</dt><dd class="edu">${education}</dd>
          <dt>${t.auth}</dt><dd>${esc p.work_auth.citizenship} · ${esc p.work_auth.residency} · ${esc p.work_auth.languages}</dd>
          <dt>${t.contact}</dt><dd>${contacts}</dd>
        </dl>
      </section>
    '';

    index = render ./bountystash/shell.html {
      inherit lang nav body contacts;
      title = "${p.name} — ${p.title}";
      description = "${p.title} — ${p.subtitle}";
      url = "${siteUrl}${prefix}/";
      ogType = "profile";
      inherit ogImage;
      ogImageAlt =
        if lang == "de"
        then "${esc p.name}, ${esc p.title}: Go, NixOS, verteilte Systeme, Energie-Infrastruktur."
        else "${esc p.name}, ${esc p.title}: Go, NixOS, distributed systems, energy infrastructure.";
      cssHref = asset "style.css";
      locale =
        if lang == "de"
        then "de_DE"
        else "en_US";
      altEn = "/";
      altDe = "/de/";
      langSwitch =
        if lang == "de"
        then ''<a href="/" hreflang="en">EN</a><span aria-hidden="true">/</span><span aria-current="page">DE</span>''
        else ''<span aria-current="page">EN</span><span aria-hidden="true">/</span><a href="/de/" hreflang="de">DE</a>'';
      inherit (p) handle;
      inherit (p) location;
      inherit (p) name;
      role = p.title;
      inherit (p) subtitle;
      status = p.status.text;
      inherit (t) skip;
      inherit (t) navLabel;
      inherit (t) footer;
    };

    projectPage = i: let
      pr = projectAt i;
      x =
        if lang == "de"
        then pr.de
        else pr.en;
      body = render ./bountystash/project.html {
        index = "0${toString (i + 1)}";
        inherit (t) kind;
        inherit (x) title;
        inherit (x) role;
        inherit (x) period;
        inherit (x) description;
        inherit (x) impact;
        impactLabel = t.impact;
        inherit (t) stackLabel;
        stack = lib.concatMapStringsSep "" (s: "<li>${esc s}</li>") x.stack;
        backHref = "${prefix}/#work";
        backLabel = t.back;
        cssHref = asset "style.css";
      };
    in
      render ./bountystash/shell.html {
        inherit lang nav body contacts;
        title = "${esc x.title} — ${p.name}";
        description = "${esc x.role} · ${esc x.period}";
        url = "${siteUrl}${prefix}${pr.href}";
        ogType = "article";
        inherit ogImage;
        ogImageAlt = "${esc x.title} — ${esc x.role} · ${esc p.name}";
        cssHref = asset "style.css";
        locale =
          if lang == "de"
          then "de_DE"
          else "en_US";
        altEn = pr.href;
        altDe = "/de${pr.href}";
        langSwitch =
          if lang == "de"
          then ''<a href="${pr.href}" hreflang="en">EN</a><span aria-hidden="true">/</span><span aria-current="page">DE</span>''
          else ''<span aria-current="page">EN</span><span aria-hidden="true">/</span><a href="/de${pr.href}" hreflang="de">DE</a>'';
        inherit (p) handle;
        inherit (p) location;
        inherit (p) name;
        role = p.title;
        inherit (p) subtitle;
        status = p.status.text;
        inherit (t) skip;
        inherit (t) navLabel;
        inherit (t) footer;
      };
  in {
    inherit index projectPage;
  };

  en = mkLocale "en";
  de = mkLocale "de";

  cssFile = pkgs.writeText "bountystash-style.css" css;
  page = name: html: pkgs.writeText name html;

  # Share cards, rendered at build time: Slack, LinkedIn and X ignore an SVG
  # og:image, and a page that advertises no card renders as a bare link. One card
  # per locale — the case studies share it and carry their own og:title.
  fontMono = "${pkgs.dejavu_fonts}/share/fonts/truetype/DejaVuSansMono.ttf";
  fontMonoBold = "${pkgs.dejavu_fonts}/share/fonts/truetype/DejaVuSansMono-Bold.ttf";
  card = pkgs.runCommand "bountystash-og" {nativeBuildInputs = [pkgs.imagemagick];} ''
    mkdir -p $out
    card() {
      dest=$1; headline=$2; sub=$3; avail=$4
      suby=344; availy=398
      # A two-line headline (the German title does not break at a hyphen) needs
      # the lines below it pushed down rather than drawn over.
      case "$headline" in *$'\n'*) suby=382; availy=436 ;; esac
      magick -size 1200x630 xc:'#f7f3ea' \
        -fill '#a8431b' -draw 'rectangle 0,0 10,630' \
        -font ${fontMonoBold} -pointsize 24 -kerning 6 -fill '#a8431b' -annotate +80+120 'MATT JI' \
        -font ${fontMonoBold} -kerning 0 -pointsize 50 -fill '#17150f' -annotate +80+256 "$headline" \
        -font ${fontMono} -pointsize 28 -fill '#6b6455' -annotate +80+$suby "$sub" \
        -pointsize 26 -fill '#a8431b' -annotate +80+$availy "$avail" \
        -fill '#d9d2c2' -draw 'rectangle 80,512 1120,513' \
        -pointsize 28 -fill '#a8431b' -annotate +80+576 'bountystash.com' \
        "$dest"
    }
    card $out/og.png 'Senior infrastructure engineer' 'Go · NixOS · distributed systems · energy' 'Available for senior and lead roles — remote, CET'
    card $out/og-de.png $'System- und\nSicherheitsingenieur' 'Go · NixOS · verteilte Systeme · Energie' 'Verfügbar für Senior- und Lead-Rollen — remote, MEZ'
  '';

  # One origin, two locales, and every case study on it: the sitemap is built
  # from the same project list the pages are, so a new case study cannot be
  # published outside it.
  sitemapUrls =
    [
      {
        loc = "${siteUrl}/";
        en = "${siteUrl}/";
        de = "${siteUrl}/de/";
      }
      {
        loc = "${siteUrl}/de/";
        en = "${siteUrl}/";
        de = "${siteUrl}/de/";
      }
    ]
    ++ map (
      i: let
        pr = projectAt i;
      in {
        loc = "${siteUrl}${pr.href}";
        en = "${siteUrl}${pr.href}";
        de = "${siteUrl}/de${pr.href}";
      }
    ) (lib.range 0 (builtins.length data.projects - 1));

  sitemapEntries =
    lib.concatMapStringsSep "\n" (u: ''
      <url>
        <loc>${u.loc}</loc>
        <xhtml:link rel="alternate" hreflang="en" href="${u.en}"/>
        <xhtml:link rel="alternate" hreflang="de" href="${u.de}"/>
        <xhtml:link rel="alternate" hreflang="x-default" href="${u.en}"/>
        <changefreq>monthly</changefreq>
      </url>
    '')
    sitemapUrls;
in
  pkgs.runCommand "bountystash-site" {} ''
    mkdir -p $out/work $out/de/work
    install -m 0644 ${cssFile} $out/style.css
    install -m 0644 ${card}/og.png $out/og.png
    install -m 0644 ${card}/og-de.png $out/og-de.png
    install -m 0644 ${page "index.html" en.index} $out/index.html
    install -m 0644 ${page "de-index.html" de.index} $out/de/index.html
    ${lib.concatMapStringsSep "\n" (i: let
      pr = projectAt i;
    in ''
      install -m 0644 ${page "en-${pr.file}" (en.projectPage i)} $out/work/${pr.file}
      install -m 0644 ${page "de-${pr.file}" (de.projectPage i)} $out/de/work/${pr.file}
    '') (lib.range 0 (builtins.length data.projects - 1))}
    cat > $out/robots.txt <<'EOF'
    User-agent: *
    Allow: /

    Sitemap: ${siteUrl}/sitemap.xml
    EOF
    cat > $out/sitemap.xml <<'EOF'
    <?xml version="1.0" encoding="UTF-8"?>
    <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml">
    ${sitemapEntries}
    </urlset>
    EOF
    cat > $out/404.html <<'EOF'
    <!doctype html><html lang="en"><meta charset="utf-8"><title>Not found</title>
    <body style="font:16px ui-monospace,monospace;padding:4rem;max-width:40rem">
    <h1>404</h1><p>No such page.</p><p><a href="/">bountystash.com</a></p>
    EOF
    echo "site: $(find $out -type f | wc -l) files, $(du -sb $out | cut -f1) bytes"
  ''
