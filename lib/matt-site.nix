# lib/matt-site.nix — matt.bountystash.com, two locales over one shell: JSON in,
# shell.html plus style.css out, the one CSS vocabulary lib/bountystash-site.nix
# already owns. Colour is one `light-dark()` pair per token, one scheme switch.
{
  pkgs,
  lib ? pkgs.lib,
  data ? builtins.fromJSON (builtins.readFile ./matt/profile.json),
  dataDe ? builtins.fromJSON (builtins.readFile ./matt/profile.de.json),
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

  css = builtins.readFile ./matt/style.css;

  # Both locales share one origin, so the sitemap and robots.txt are built from
  # the profile rather than from either locale's page URL.
  siteUrl = data.profile.url;

  sections = [
    {
      id = "focus";
      n = "00";
    }
    {
      id = "work";
      n = "01";
    }
    {
      id = "lab";
      n = "02";
    }
    {
      id = "stack";
      n = "03";
    }
    {
      id = "hire";
      n = "04";
    }
  ];

  mkLocale = lang: let
    d =
      if lang == "de"
      then dataDe
      else data;
    p = d.profile;
    ui = d.ui;
    root =
      if lang == "de"
      then "../"
      else "";
    pageUrl =
      if lang == "de"
      then "${siteUrl}/de/"
      else "${siteUrl}/";

    nav = lib.concatMapStringsSep "" (s: ''<a href="#${s.id}">${s.n} ${esc ui.nav.${s.id}}</a>'') sections;

    contacts = lib.concatMapStringsSep "" (c: ''<a href="${c.href}">${esc c.label}</a>'') p.contacts;

    focusCards =
      lib.concatMapStringsSep "" (f: ''
        <article class="card">
          <h3>${esc f.title}</h3>
          <p>${esc f.body}</p>
        </article>
      '')
      d.focus;

    # The whole card is folded into one lowercase `data-search` attribute, so the
    # filter script never has to walk the DOM or normalise text at runtime.
    searchText = w:
      lib.toLower (lib.concatStringsSep " " ([w.title w.role w.period w.description] ++ w.highlights));

    workRows =
      lib.concatMapStringsSep "" (w: ''
        <li data-search="${esc (searchText w)}">
          <span class="yr">${esc w.period}</span>
          <div>
            <strong>${
          if w.link == ""
          then esc w.title
          else ''<a href="${w.link}">${esc w.title}</a>''
        }</strong>
            <span class="org">${esc w.role}</span>
            <p>${esc w.description}</p>
            <ul class="bullets">${lib.concatMapStringsSep "" (h: "<li>${esc h}</li>") w.highlights}</ul>
          </div>
        </li>
      '')
      d.work;

    labLinks =
      lib.concatMapStringsSep " · " (l: ''<a href="${l.href}">${esc l.label}</a>'') d.lab.links;

    stackGroups =
      lib.concatMapStringsSep "" (g: ''
        <details>
          <summary><span>${esc g.category}</span><span>${toString (builtins.length g.items)}</span></summary>
          <ul class="tags">${lib.concatMapStringsSep "" (i: "<li>${esc i}</li>") g.items}</ul>
        </details>
      '')
      d.stack;

    wants = lib.concatMapStringsSep "" (w: "<li>${esc w}</li>") d.hire.wants;

    # Contact links are looked up by label rather than by position, so reordering
    # profile.json cannot point the structured data at the wrong site.
    contactHref = label: (builtins.head (builtins.filter (c: c.label == label) p.contacts)).href;

    jsonld =
      builtins.replaceStrings ["<"] ["\\u003c"]
      (builtins.toJSON {
        "@context" = "https://schema.org";
        "@type" = "Person";
        name = p.name;
        jobTitle = p.title;
        description = p.bio;
        url = pageUrl;
        email = contactHref "email";
        inLanguage = lang;
        sameAs = [
          (contactHref "github")
          (contactHref "linkedin")
        ];
        address = {
          "@type" = "PostalAddress";
          addressLocality = "Gutach im Breisgau";
          addressCountry = "DE";
        };
      });

    body = ''
      <section id="focus">
        <h2><span>00</span> ${esc ui.headings.focus}</h2>
        <div class="cards">${focusCards}</div>
      </section>

      <section id="work">
        <h2><span>01</span> ${esc ui.headings.work}</h2>
        <div class="filterbar" data-filter-bar data-of="${esc ui.filterOf}" hidden>
          <label for="work-filter">${esc ui.filterLabel}</label>
          <input id="work-filter" type="search" data-filter-input placeholder="${esc ui.filterPlaceholder}" autocomplete="off" spellcheck="false">
          <p class="fcount" data-filter-count aria-live="polite"></p>
        </div>
        <p class="fempty" data-filter-none hidden>${esc ui.filterNone}</p>
        <ol class="work" data-filter-list>${workRows}</ol>
      </section>

      <section id="lab">
        <h2><span>02</span> ${esc d.lab.title}</h2>
        <div class="lab">
          <p>${esc d.lab.body}</p>
          <p class="tools">${labLinks}</p>
        </div>
      </section>

      <section id="stack">
        <h2><span>03</span> ${esc ui.headings.stack}</h2>
        ${stackGroups}
      </section>

      <section id="hire">
        <h2><span>04</span> ${esc d.hire.title}</h2>
        <div class="hire">
          <p>${esc d.hire.body}</p>
          <ul>${wants}</ul>
          <a class="cta" href="${d.hire.cta.href}">${esc d.hire.cta.label}</a>
        </div>
      </section>
    '';

    langSwitch =
      if lang == "de"
      then ''<a href="${root}index.html" hreflang="en" lang="en">EN</a><span class="sep" aria-hidden="true">/</span><span aria-current="page">DE</span>''
      else ''<span aria-current="page">EN</span><span class="sep" aria-hidden="true">/</span><a href="${root}de/index.html" hreflang="de" lang="de">DE</a>'';
  in
    render ./matt/shell.html {
      inherit lang nav contacts jsonld body langSwitch;
      title = "${p.name} — ${p.title}";
      description = "${p.title}. ${p.subtitle}.";
      url = pageUrl;
      altEn = "${siteUrl}/";
      altDe = "${siteUrl}/de/";
      locale =
        if lang == "de"
        then "de_DE"
        else "en_US";
      inherit (p) handle;
      inherit (p) status;
      inherit (p) location;
      inherit (p) name;
      role = p.title;
      inherit (p) subtitle;
      inherit (p) bio;
      inherit (ui) skip;
      inherit (ui) navLabel;
      inherit (ui) theme;
      inherit (ui) themeAria;
      inherit (ui) langLabel;
      inherit (ui) footer;
      ogImage = "${siteUrl}/${
        if lang == "de"
        then "og-de.png"
        else "og.png"
      }";
      ogImageAlt =
        if lang == "de"
        then "Matt Ji, Systemingenieur für Infrastruktur und Sicherheit: Go, NixOS-Flotten, Schwachstellendaten. Auf der Suche nach einer Senior-Rolle."
        else "Matt Ji, systems and security engineer: Go, NixOS fleets, vulnerability data. Looking for a senior role.";
      cssHref = "${root}style.css";
    };

  en = mkLocale "en";
  de = mkLocale "de";

  page = name: content: pkgs.writeText name content;
  cssFile = pkgs.writeText "matt-style.css" css;

  # Share cards, rendered at build time: Slack and LinkedIn ignore an SVG
  # og:image, and the persona page needs its own card rather than the mockup's.
  fontMono = "${pkgs.dejavu_fonts}/share/fonts/truetype/DejaVuSansMono.ttf";
  fontMonoBold = "${pkgs.dejavu_fonts}/share/fonts/truetype/DejaVuSansMono-Bold.ttf";
  card = pkgs.runCommand "matt-og" {nativeBuildInputs = [pkgs.imagemagick];} ''
    mkdir -p $out
    card() {
      dest=$1; kicker=$2; headline=$3; sub=$4; avail=$5
      magick -size 1200x630 xc:'#f6f2e9' \
        -fill '#1c5f4d' -draw 'rectangle 0,0 10,630' \
        -font ${fontMonoBold} -pointsize 24 -kerning 6 -fill '#1c5f4d' -annotate +80+120 "$kicker" \
        -font ${fontMonoBold} -kerning 0 -pointsize 50 -fill '#14120e' -annotate +80+256 "$headline" \
        -font ${fontMono} -pointsize 28 -fill '#6a6355' -annotate +80+344 "$sub" \
        -pointsize 26 -fill '#1c5f4d' -annotate +80+398 "$avail" \
        -fill '#d8d1c1' -draw 'rectangle 80,486 1120,487' \
        -pointsize 28 -fill '#1c5f4d' -annotate +80+566 'matt.bountystash.com' \
        "$dest"
    }
    card $out/og.png 'MATT JI' 'Systems and security engineer' 'Go · NixOS fleets · vulnerability data' 'Looking for a senior or lead role — remote, CET'
    card $out/og-de.png 'MATT JI' 'Systemingenieur, Infrastruktur' 'Go · NixOS-Flotten · Schwachstellendaten' 'Auf der Suche nach einer Senior-Rolle — remote, MEZ'
  '';
in
  pkgs.runCommand "matt-site" {} ''
    mkdir -p $out/de
    install -m 0644 ${cssFile} $out/style.css
    install -m 0644 ${card}/og.png $out/og.png
    install -m 0644 ${card}/og-de.png $out/og-de.png
    install -m 0644 ${page "index.html" en} $out/index.html
    install -m 0644 ${page "de-index.html" de} $out/de/index.html
    cat > $out/robots.txt <<'EOF'
    User-agent: *
    Allow: /

    Sitemap: ${siteUrl}/sitemap.xml
    EOF
    cat > $out/sitemap.xml <<'EOF'
    <?xml version="1.0" encoding="UTF-8"?>
    <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml">
      <url>
        <loc>${siteUrl}/</loc>
        <xhtml:link rel="alternate" hreflang="en" href="${siteUrl}/"/>
        <xhtml:link rel="alternate" hreflang="de" href="${siteUrl}/de/"/>
        <xhtml:link rel="alternate" hreflang="x-default" href="${siteUrl}/"/>
        <changefreq>monthly</changefreq>
      </url>
      <url>
        <loc>${siteUrl}/de/</loc>
        <xhtml:link rel="alternate" hreflang="en" href="${siteUrl}/"/>
        <xhtml:link rel="alternate" hreflang="de" href="${siteUrl}/de/"/>
        <xhtml:link rel="alternate" hreflang="x-default" href="${siteUrl}/"/>
        <changefreq>monthly</changefreq>
      </url>
    </urlset>
    EOF
    cat > $out/404.html <<'EOF'
    <!doctype html><html lang="en"><meta charset="utf-8"><title>Not found</title>
    <body style="font:16px ui-monospace,monospace;padding:4rem;max-width:40rem">
    <h1>404</h1><p>No such page.</p><p><a href="/">matt.bountystash.com</a></p>
    EOF
    echo "matt-site: $(find $out -type f | wc -l) files, $(du -sb $out | cut -f1) bytes"
  ''
