# lib/matt-site.nix — matt.bountystash.com, two locales over one shell.
#
# JSON in, shell.html and style.css out; the resume is the fact, prose the rest.
# docs: modules/plugins/appflow/README.md
{
  pkgs,
  lib ? pkgs.lib,
  resume ? builtins.fromJSON (builtins.readFile ./matt/resume.json),
  data ? builtins.fromJSON (builtins.readFile ./matt/profile.json),
  dataDe ? builtins.fromJSON (builtins.readFile ./matt/profile.de.json),
  cases ? builtins.fromJSON (builtins.readFile ./matt/cases.json),
  casesDe ? builtins.fromJSON (builtins.readFile ./matt/cases.de.json),
  projects ? builtins.fromJSON (builtins.readFile ./matt/projects.json),
  briefs ? builtins.fromJSON (builtins.readFile ./matt/briefs.json),
  briefsDe ? builtins.fromJSON (builtins.readFile ./matt/briefs.de.json),
}: let
  # The page budgets below are asserted by this, not by eye: a CV that spills a
  # line onto a second page fails its build.
  typeset = import ./typeset.nix {inherit pkgs;};

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

  siteUrl = data.profile.url;

  resumeWork = resume.work or [];
  resumeProjects = resume.projects or [];
  resumeEducation = resume.education or [];
  resumeLanguages = resume.languages or [];

  # The German corpus: the same resume, translated bullet for bullet. A German
  # variant projects from it, so its bullets are checked against German strings
  # rather than against their English originals.
  lebenslauf = builtins.fromJSON (builtins.readFile ./matt/lebenslauf.json);
  lebenslaufWork = lebenslauf.work or [];
  lebenslaufProjects = lebenslauf.projects or [];

  yearPeriod = nowLabel: start: end: let
    ys = builtins.substring 0 4 start;
    ye =
      if end == ""
      then ""
      else builtins.substring 0 4 end;
  in
    if start == ""
    then ""
    else if end == ""
    then "${ys} — ${nowLabel}"
    else if ys == ye
    then ys
    else "${ys} — ${ye}";

  # One role, one prose entry, matched on the organisation the resume names.
  joinWork = d: nowLabel: let
    prose = lib.listToAttrs (map (w: lib.nameValuePair w.org w) (builtins.filter (w: (w.org or "") != "") d.work));
    missing = builtins.filter (n: !(builtins.hasAttr n prose)) (map (w: w.name) resumeWork);
  in
    if missing != []
    then throw "matt-site: no prose for resume role(s): ${lib.concatStringsSep ", " missing}"
    else
      lib.sort (a: b: a.sortKey > b.sortKey) (
        map (
          w: let
            pr = prose.${w.name};
          in
            pr
            // {
              period = yearPeriod nowLabel (w.startDate or "") (w.endDate or "");
              sortKey = w.startDate or "";
              link =
                if (pr.link or "") != ""
                then pr.link
                else w.url or "";
            }
        )
        resumeWork
        ++ builtins.map (w: w // {sortKey = w.sortStart;}) (builtins.filter (w: (w.org or "") == "") d.work)
      );

  # Closed in both directions: a resume project without prose fails the build, and
  # so does a prose entry that claims no resume project. The archive is therefore
  # the resume, projected — not a list that can grow by editing a second file.
  joinProjects = let
    claimed = lib.listToAttrs (map (p: lib.nameValuePair p.resumeName p) (builtins.filter (p: (p.resumeName or "") != "") projects.entries));
    missing = builtins.filter (n: !(builtins.hasAttr n claimed)) (map (p: p.name) resumeProjects);
    invented = map (p: p.name) (builtins.filter (p: (p.resumeName or "") == "") projects.entries);
  in
    if missing != []
    then throw "matt-site: no project entry for resume project(s): ${lib.concatStringsSep ", " missing}"
    else if invented != []
    then throw "matt-site: no resume project for archive entry(ies): ${lib.concatStringsSep ", " invented}"
    else
      lib.sort (a: b: a.start > b.start) (
        map (
          p: let
            e = claimed.${p.name};
          in
            e
            // {
              start = p.startDate or e.start;
              end = p.endDate or e.end;
              entity = p.entity or e.entity;
              type = p.type or e.type;
              url =
                if (p.url or "") == ""
                then (e.url or "")
                else p.url;
            }
        )
        resumeProjects
        ++ builtins.filter (p: (p.resumeName or "") == "") projects.entries
      );

  education =
    map (e: {
      degree = "${e.studyType}, ${e.area}";
      school = e.institution;
      period = yearPeriod "now" (e.startDate or "") (e.endDate or "");
    })
    resumeEducation;

  # Education is a fact from the resume, so the German CV translates it rather
  # than keeping a second list. The map is keyed by the resume's own strings and
  # an unknown one fails the German build instead of shipping a half-English CV.
  deTerm = {
    "University of Freiburg" = "Albert-Ludwigs-Universität Freiburg";
    "Colorado School of Mines" = "Colorado School of Mines";
    "Renewable Energy Management" = "Erneuerbare-Energien-Management";
    "Petroleum Engineering" = "Erdöltechnik";
    "Master of Science" = "Master of Science";
    "Bachelor of Science" = "Bachelor of Science";
  };
  deEducation =
    map (e: {
      degree = "${deTerm.${e.studyType}}, ${deTerm.${e.area}}";
      school = deTerm.${e.institution};
      period = yearPeriod "heute" (e.startDate or "") (e.endDate or "");
    })
    resumeEducation;

  # The level is a fact, so it lives in the resume (`languages[].fluency`) and
  # nowhere else. A CEFR level typed a second time into a profile is exactly the
  # drift that put "German C1" on a page while the runner said otherwise.
  languageLine = ui:
    lib.concatMapStringsSep ", " (
      l: "${ui.langNames.${l.language}} (${
        if builtins.hasAttr l.fluency ui.fluency
        then ui.fluency.${l.fluency}
        else l.fluency
      })"
    )
    resumeLanguages;

  # Both locales share one origin, so the sitemap and robots.txt are built from
  # the profile rather than from either locale's page URL.
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
      id = "projects";
      n = "02";
    }
    {
      id = "lab";
      n = "03";
    }
    {
      id = "stack";
      n = "04";
    }
    {
      id = "hire";
      n = "05";
    }
  ];

  caseSlugs = builtins.attrNames cases;
  briefSlugs = builtins.attrNames briefs;

  # Measurement, off until an endpoint exists. Cloudflare Pages counts pageviews
  # from its dashboard without a script; this hook is for outbound clicks.
  mkAnalytics = a:
    if a.endpoint == ""
    then ""
    else ''
      <script>
        (function () {
          var endpoint = "${a.endpoint}";
          var site = "${a.site}";
          function send(payload) {
            if (!navigator.sendBeacon) return;
            navigator.sendBeacon(endpoint, new Blob([JSON.stringify(payload)], { type: "application/json" }));
          }
          send({ site: site, event: "pageview", path: location.pathname });
          document.addEventListener("click", function (event) {
            var link = event.target.closest ? event.target.closest("a[data-event]") : null;
            if (!link) return;
            send({ site: site, event: link.getAttribute("data-event"), path: location.pathname, href: link.href });
          });
        })();
      </script>
    '';

  privacy = ui: a:
    if a.endpoint == ""
    then ui.footerPrivacy
    else ui.footerPrivacyAnalytics;

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
    nowLabel =
      if lang == "de"
      then "heute"
      else "now";

    work = joinWork d nowLabel;

    projectRowsData =
      map (
        e:
          e
          // {
            summary =
              if lang == "de"
              then e.summaryDe or e.summary
              else e.summary;
          }
      )
      joinProjects;

    nav = lib.concatMapStringsSep "" (s: ''<a href="#${s.id}">${s.n} ${esc ui.nav.${s.id}}</a>'') sections;

    contacts = lib.concatMapStringsSep "" (c: ''<a href="${c.href}" data-event="out:${c.label}">${esc c.label}</a>'') p.contacts;

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
    searchText = w: lib.toLower (lib.concatStringsSep " " ([w.title w.role w.period w.description] ++ w.keywords));

    # Three columns — when, what, and why it mattered — so the description uses
    # the width instead of leaving half a page empty beside a narrow measure.
    workRows =
      lib.concatMapStringsSep "" (w: ''
        <li data-search="${esc (searchText w)}">
          <span class="yr">${esc w.period}</span>
          <div class="head">
            <strong>${
          if w.link == ""
          then esc w.title
          else ''<a href="${w.link}" data-event="out:work">${esc w.title}</a>''
        }</strong>
            <span class="org">${esc w.role}</span>
          </div>
          <div class="body">
            <p>${esc w.description}</p>
            ${
          if w ? caseStudy
          # Cloudflare Pages serves `work/x.html` at `work/x` and 308-redirects
          # the .html form, so every link and canonical is the served URL.
          then ''<a class="more" href="work/${w.caseStudy}">${esc ui.caseLabel}</a>''
          else ""
        }
          </div>
        </li>
      '')
      work;

    projectRows =
      lib.concatMapStringsSep "" (e: ''
        <li data-search="${esc (lib.toLower (lib.concatStringsSep " " ([e.name e.entity e.type e.summary] ++ e.keywords)))}">
          <span class="yr">${esc (yearPeriod nowLabel e.start e.end)}</span>
          <div class="head">
            <strong>${esc e.name}</strong>
            <span class="meta"><span class="kind">${esc (lib.replaceStrings ["_"] [" "] e.type)}</span>${
          if e.entity == ""
          then ""
          else " · ${esc e.entity}"
        }</span>
          </div>
          <div class="body">
            <p>${esc e.summary}</p>
            <ul class="kw">${lib.concatMapStringsSep "" (k: "<li>${esc k}</li>") e.keywords}</ul>
          </div>
          ${
          if e.url == ""
          then ''<span class="go" aria-hidden="true"></span>''
          else ''<a class="go" href="${e.url}" data-event="out:project" aria-label="${esc e.name}">↗</a>''
        }
        </li>
      '')
      projectRowsData;

    labLinks =
      lib.concatMapStringsSep " · " (l: ''<a href="${l.href}" data-event="out:lab">${esc l.label}</a>'') d.lab.links;

    stackGroups =
      lib.concatMapStringsSep "" (g: ''
        <details>
          <summary><span>${esc g.category}</span><span class="count">${toString (builtins.length g.items)} ${esc ui.items}</span></summary>
          <ul class="tags">${lib.concatMapStringsSep "" (i: "<li>${esc i}</li>") g.items}</ul>
        </details>
      '')
      d.stack;

    # Work authorisation and language level are facts: the first is stated once in
    # the profile, the second only in the resume. Both are appended here rather
    # than repeated inside `hire.wants`.
    wants = lib.concatMapStringsSep "" (w: "<li>${esc w}</li>") ([p.workAuth] ++ d.hire.wants ++ [(languageLine ui)]);

    briefLinks = lib.concatMapStringsSep " · " (s: let
      b =
        if lang == "de"
        then briefsDe.${s}
        else briefs.${s};
    in ''<a href="brief/${s}">${esc b.title}</a>'')
    briefSlugs;

    # Contact links are looked up by label rather than by position, so reordering
    # profile.json cannot point the structured data at the wrong site.
    contactHref = label: (builtins.head (builtins.filter (c: c.label == label) p.contacts)).href;

    sameAs = map (c: c.href) (builtins.filter (c: c.label != "email") p.contacts);

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
        sameAs = sameAs;
        address = {
          "@type" = "PostalAddress";
          addressLocality = "Gutach im Breisgau";
          addressCountry = "DE";
        };
        alumniOf =
          map (e: {
            "@type" = "EducationalOrganization";
            name = e.school;
          })
          education;
      });

    body = ''
      <section id="focus">
        <h2><span>00</span> ${esc ui.headings.focus}</h2>
        <div class="cards">${focusCards}</div>
      </section>

      <section id="work">
        <h2><span>01</span> ${esc ui.headings.work}</h2>
        <div data-filter-group>
          <div class="filterbar" data-filter-bar data-of="${esc ui.filterOf}" hidden>
            <label for="work-filter">${esc ui.filterLabel}</label>
            <input id="work-filter" type="search" data-filter-input placeholder="${esc ui.filterPlaceholder}" autocomplete="off" spellcheck="false">
            <p class="fcount" data-filter-count aria-live="polite"></p>
          </div>
          <p class="fempty" data-filter-none hidden>${esc ui.filterNone}</p>
          <ol class="work" data-filter-list>${workRows}</ol>
        </div>
      </section>

      <section id="projects">
        <h2><span>02</span> ${esc ui.headings.projects}</h2>
        <p class="note">${esc ui.archiveNote}</p>
        <div data-filter-group>
          <div class="filterbar" data-filter-bar data-of="${esc ui.filterOf}" hidden>
            <label for="project-filter">${esc ui.projectsFilterLabel}</label>
            <input id="project-filter" type="search" data-filter-input placeholder="${esc ui.projectsFilterPlaceholder}" autocomplete="off" spellcheck="false">
            <p class="fcount" data-filter-count aria-live="polite"></p>
          </div>
          <p class="fempty" data-filter-none hidden>${esc ui.projectsFilterNone}</p>
          <ul class="archive" data-filter-list>${projectRows}</ul>
        </div>
      </section>

      <section id="lab">
        <h2><span>03</span> ${esc d.lab.title}</h2>
        <div class="lab">
          <p>${esc d.lab.body}</p>
          <p class="tools">${labLinks}</p>
        </div>
      </section>

      <section id="stack">
        <h2><span>04</span> ${esc ui.headings.stack}</h2>
        ${stackGroups}
      </section>

      <section id="hire">
        <h2><span>05</span> ${esc d.hire.title}</h2>
        <div class="hire">
          <p>${esc d.hire.body}</p>
          <ul>${wants}</ul>
          <p class="briefs">${esc d.hire.briefsNote} ${briefLinks}</p>
          <a class="cta" href="${d.hire.cta.href}" data-event="out:email">${esc d.hire.cta.label}</a>
        </div>
      </section>
    '';

    langSwitch =
      if lang == "de"
      then ''<a href="${root}" hreflang="en" lang="en">EN</a><span class="sep" aria-hidden="true">/</span><span aria-current="page">DE</span>''
      else ''<span aria-current="page">EN</span><span class="sep" aria-hidden="true">/</span><a href="${root}de/" hreflang="de" lang="de">DE</a>'';
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
      inherit (ui) cvLabel;
      cvHref = "${root}${
        if lang == "de"
        then "cv-de.pdf"
        else "cv.pdf"
      }";
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
      footer = "${privacy ui d.analytics} ${ui.footer}";
      analytics = mkAnalytics d.analytics;
    };

  # A case study and a brief are the same page with different data: one article
  # template, so a heading or a fact table cannot drift between the two.
  mkArticle = {
    lang,
    slug,
    kind,
  }: let
    d =
      if lang == "de"
      then dataDe
      else data;
    p = d.profile;
    ui = d.ui;
    dir =
      if kind == "case"
      then "work"
      else "brief";
    pageRoot =
      if lang == "de"
      then "../../"
      else "../";
    # A case study or brief sits two directories below the origin, so its link
    # back into the German home has to name `de/`; `../../` alone lands on the
    # English page and the locale is silently lost.
    localeRoot =
      if lang == "de"
      then "../../de/"
      else "../";
    dataSet =
      if kind == "case"
      then
        (
          if lang == "de"
          then casesDe
          else cases
        )
      else
        (
          if lang == "de"
          then briefsDe
          else briefs
        );
    c = dataSet.${slug};
    url = "${siteUrl}/${
      if lang == "de"
      then "de/"
      else ""
    }${dir}/${slug}";

    facts = lib.concatMapStringsSep "" (f: ''<div><dt>${esc f.label}</dt><dd>${esc f.value}</dd></div>'') (c.facts or []);
    factsBlock =
      if facts == ""
      then ""
      else ''
        <dl class="facts">${facts}</dl>
      '';

    body =
      lib.concatMapStringsSep "" (s: ''
        <section>
          <h2>${esc s.heading}</h2>
          ${lib.concatMapStringsSep "" (x: "<p>${esc x}</p>") s.body}
        </section>
      '')
      c.sections;

    langSwitch =
      if lang == "de"
      then ''<a href="../../${dir}/${slug}" hreflang="en" lang="en">EN</a><span class="sep" aria-hidden="true">/</span><span aria-current="page">DE</span>''
      else ''<span aria-current="page">EN</span><span class="sep" aria-hidden="true">/</span><a href="../de/${dir}/${slug}" hreflang="de" lang="de">DE</a>'';
  in
    render ./matt/article.html {
      inherit lang;
      title = "${c.title} — ${p.name}";
      description = c.standfirst;
      inherit url;
      locale =
        if lang == "de"
        then "de_DE"
        else "en_US";
      ogImage = "${siteUrl}/${
        if lang == "de"
        then "og-de.png"
        else "og.png"
      }";
      ogImageAlt = c.standfirst;
      altEn = "${siteUrl}/${dir}/${slug}";
      altDe = "${siteUrl}/de/${dir}/${slug}";
      kicker =
        if kind == "case"
        then ui.caseKicker
        else c.kicker;
      headline = c.title;
      standfirst = c.standfirst;
      byline =
        if kind == "case"
        then "${c.period} · ${c.role}"
        else ui.briefsLabel;
      facts = factsBlock;
      sections = body;
      backHref = "${localeRoot}#${
        if kind == "case"
        then "work"
        else "hire"
      }";
      backLabel =
        if kind == "case"
        then ui.nav.work
        else ui.nav.hire;
      homeHref = localeRoot;
      inherit (p) name;
      inherit (ui) skip;
      inherit (ui) theme;
      inherit (ui) themeAria;
      inherit (ui) langLabel;
      inherit langSwitch;
      cssHref = "${pageRoot}style.css";
      footer = "${privacy ui d.analytics} ${ui.footer}";
      analytics = mkAnalytics d.analytics;
    };

  en = mkLocale "en";
  de = mkLocale "de";

  page = name: content: pkgs.writeText name content;
  cssFile = pkgs.writeText "matt-style.css" css;

  # The closed label set the CV template reads. A heading is part of the
  # document's language, so it lives with the other localized strings rather than
  # in a second template.
  cvLabels = {
    en = {
      cv = "CV";
      experience = "Experience";
      projects = "Selected projects";
      education = "Education";
      tools = "Tools";
      languages = "Languages and authorisation";
      page = "page";
      of = "of";
    };
    de = {
      cv = "Lebenslauf";
      experience = "Berufserfahrung";
      projects = "Ausgewählte Projekte";
      education = "Ausbildung";
      tools = "Werkzeuge";
      languages = "Sprachen und Arbeitserlaubnis";
      page = "Seite";
      of = "von";
    };
  };

  # The CV is compiled from the same data the page reads, so a role that appears
  # or disappears in the resume appears or disappears in the PDF. Typst runs in
  # the sandbox with its own fonts; nothing is fetched. One template, two
  # compiles over each locale's prose, so the languages cannot drift.
  cvData = lang: let
    d =
      if lang == "de"
      then dataDe
      else data;
    nowLabel =
      if lang == "de"
      then "heute"
      else "now";
    # A German page titles a project in German: the translated corpus keys each
    # entry by the English name, so the archive's English title never reaches the
    # German CV. A project the German corpus has not translated fails the build
    # rather than shipping a half-English page, the same rule education follows.
    deProjects = lib.listToAttrs (
      map (p: lib.nameValuePair (p.resumeName or p.name) p) (
        builtins.filter (p: (p.resumeName or "") != "") lebenslaufProjects
      )
    );
    # The shared key is the resume name: the archive is free to title a project
    # its own way ("Risk calculation engine"), which the German corpus does not.
    untranslated =
      if lang == "de"
      then builtins.filter (e: !(builtins.hasAttr (e.resumeName or e.name) deProjects)) joinProjects
      else [];
  in
    d
    // {
      inherit lang;
      # The full CV has always been two pages; the build now proves it instead of
      # leaving the second page to be noticed by whoever opens the file.
      pages = 2;
      labels = cvLabels.${lang};
      profile =
        d.profile
        // {
          languages = languageLine d.ui;
        };
      education =
        if lang == "de"
        then deEducation
        else education;
      work = joinWork d nowLabel;
      projects =
        if untranslated != []
        then throw "matt-site: no German project title for: ${lib.concatStringsSep ", " (map (e: e.name) untranslated)}"
        else
          map (
            e:
              e
              // {
                name =
                  if lang == "de"
                  then deProjects.${e.resumeName or e.name}.name
                  else e.name;
                summary =
                  if lang == "de"
                  then e.summaryDe or e.summary
                  else e.summary;
                period = yearPeriod nowLabel e.start e.end;
              }
          )
          joinProjects;
    };

  # A tailored CV is a projection of the corpus for its language: the variant
  # names roles, highlights and projects by their own strings and the build fails
  # on anything the corpus does not say. It can select and order; it cannot invent.
  cvEnergyJson = builtins.fromJSON (builtins.readFile ./matt/cv-energy.json);
  cvEnergyDeJson = builtins.fromJSON (builtins.readFile ./matt/cv-energy.de.json);

  cvVariantData = json: lang: let
    corpusWork =
      if lang == "de"
      then lebenslaufWork
      else resumeWork;
    prose =
      if lang == "de"
      then dataDe
      else data;
    nowLabel =
      if lang == "de"
      then "heute"
      else "now";
    # Keyed by the resume name, not the archive's display name: the variant names
    # resume facts, and the archive is allowed to title the same project differently.
    byProject = lib.listToAttrs (
      map (p: lib.nameValuePair (p.resumeName or p.name) p) (
        builtins.filter (p: (p.resumeName or "") != "") joinProjects
      )
    );
    deProject = lib.listToAttrs (
      map (p: lib.nameValuePair (p.resumeName or p.name) p) (
        builtins.filter (p: (p.resumeName or "") != "") lebenslaufProjects
      )
    );
    byRole = lib.listToAttrs (
      map (w: lib.nameValuePair w.org w) (
        builtins.filter (w: (w.org or "") != "") (joinWork prose nowLabel)
      )
    );
    knownRoles = map (w: w.name) corpusWork;
    named = map (w: w.name) json.work;
    highlightsOf = n: (lib.findFirst (w: w.name == n) {highlights = [];} corpusWork).highlights or [];
    unknownRoles = builtins.filter (n: !(builtins.elem n knownRoles)) named;
    omittedRoles = builtins.filter (n: !(builtins.elem n named)) knownRoles;
    invented =
      lib.concatMap (
        w: map (h: "${w.name}: ${h}") (builtins.filter (h: !(builtins.elem h (highlightsOf w.name))) (w.highlights or []))
      )
      json.work;
    unknownProjects =
      builtins.filter (
        n: !(builtins.hasAttr n byProject) || (lang == "de" && !(builtins.hasAttr n deProject))
      )
      json.projects;
  in
    if json.lang != lang
    then throw "cv-variant: the ${lang} CV carries a ${json.lang} variant"
    else if unknownRoles != []
    then throw "cv-variant: not a ${lang} corpus role: ${lib.concatStringsSep ", " unknownRoles}"
    else if omittedRoles != []
    then throw "cv-variant: ${lang} role(s) missing from the variant: ${lib.concatStringsSep ", " omittedRoles}"
    else if invented != []
    then throw "cv-variant: not in the ${lang} corpus: ${lib.concatStringsSep " | " invented}"
    else if unknownProjects != []
    then throw "cv-variant: not a ${lang} corpus project: ${lib.concatStringsSep ", " unknownProjects}"
    else {
      inherit lang;
      # A tailored CV earns its one page the hard way: the build fails if it spills.
      pages = json.pages or 1;
      labels = cvLabels.${lang} // (json.labels or {});
      profile =
        prose.profile
        // {
          title = json.title;
          bio = json.bio;
          languages = languageLine prose.ui;
        };
      education =
        if lang == "de"
        then deEducation
        else education;
      # The tailored CV says its piece in bullets: the site's one-line framing for
      # a role repeats what they state, and on paper it pushed the tools block onto
      # a second page with two lines on it.
      work =
        map (
          w:
            byRole.${w.name}
            // {
              description = "";
              highlights = w.highlights or [];
            }
        )
        json.work;
      # A German CV titles its projects in German, so the title and the summary come
      # from the translated corpus; the dates stay with the archive entry.
      projects =
        map (
          n: let
            e =
              if lang == "de"
              then
                byProject.${n}
                // {
                  name = deProject.${n}.name;
                  summary = deProject.${n}.description;
                }
              else byProject.${n};
          in
            e
            // {
              period = yearPeriod nowLabel e.start e.end;
            }
        )
        json.projects;
      stack = json.stack;
    };

  cvPdf = name: cvJson:
    pkgs.runCommand "matt-cv-${name}" {nativeBuildInputs = [pkgs.typst pkgs.jq];} ''
      mkdir -p $out work
      cp ${./matt/cv.typ} work/cv.typ
      cp ${pkgs.writeText "cv.json" (builtins.toJSON cvJson)} work/cv.json
      typst compile --root work work/cv.typ $out/cv.pdf
      ${typeset.check {
        source = "work/cv.typ";
        budget = cvJson.pages;
        doc = "cv-${name}.pdf";
      }}
    '';

  cv = cvPdf "en" (cvData "en");
  cvDe = cvPdf "de" (cvData "de");
  cvEnergy = cvPdf "energy" (cvVariantData cvEnergyJson "en");
  cvEnergyDe = cvPdf "energy-de" (cvVariantData cvEnergyDeJson "de");

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
    ++ map (s: {
      loc = "${siteUrl}/work/${s}";
      en = "${siteUrl}/work/${s}";
      de = "${siteUrl}/de/work/${s}";
    })
    caseSlugs
    ++ map (s: {
      loc = "${siteUrl}/brief/${s}";
      en = "${siteUrl}/brief/${s}";
      de = "${siteUrl}/de/brief/${s}";
    })
    briefSlugs;

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
  pkgs.runCommand "matt-site" {} ''
    mkdir -p $out/de $out/work $out/de/work $out/brief $out/de/brief
    install -m 0644 ${cssFile} $out/style.css
    install -m 0644 ${card}/og.png $out/og.png
    install -m 0644 ${card}/og-de.png $out/og-de.png
    install -m 0644 ${cv}/cv.pdf $out/cv.pdf
    install -m 0644 ${cvDe}/cv.pdf $out/cv-de.pdf
    install -m 0644 ${cvEnergy}/cv.pdf $out/cv-energy.pdf
    install -m 0644 ${cvEnergyDe}/cv.pdf $out/cv-energy-de.pdf
    install -m 0644 ${page "index.html" en} $out/index.html
    install -m 0644 ${page "de-index.html" de} $out/de/index.html
    ${lib.concatMapStringsSep "\n" (s: ''
        install -m 0644 ${page "work-${s}.html" (mkArticle {
          lang = "en";
          slug = s;
          kind = "case";
        })} $out/work/${s}.html
        install -m 0644 ${page "de-work-${s}.html" (mkArticle {
          lang = "de";
          slug = s;
          kind = "case";
        })} $out/de/work/${s}.html
      '')
      caseSlugs}
    ${lib.concatMapStringsSep "\n" (s: ''
        install -m 0644 ${page "brief-${s}.html" (mkArticle {
          lang = "en";
          slug = s;
          kind = "brief";
        })} $out/brief/${s}.html
        install -m 0644 ${page "de-brief-${s}.html" (mkArticle {
          lang = "de";
          slug = s;
          kind = "brief";
        })} $out/de/brief/${s}.html
      '')
      briefSlugs}
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
    <h1>404</h1><p>No such page.</p><p><a href="/">matt.bountystash.com</a></p>
    EOF
    echo "matt-site: $(find $out -type f | wc -l) files, $(du -sb $out | cut -f1) bytes"
  ''
