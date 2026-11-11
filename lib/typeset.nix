# lib/typeset.nix — the typesetting rules a PDF build has to satisfy.
#
# WHY THIS EXISTS: a CV that spills two lines onto a second page compiles cleanly
# and is only visible if someone opens the file, which is how a page carrying one
# line once shipped. The templates end with a `<typeset>` report — the page count
# and how much content the last page carries — and the build reads it back and
# fails. Both builders use this file, so the site's CVs and the appflow packets
# answer to the same rule.
#
# Why typst answers and a PDF does not: a PDF's text bounding boxes include the
# footer, which sits at the bottom of every page and would make every last page look
# full. `here().position().y` is where the content actually stopped.
#
# Why millimetres and not a percent of the page: tested against this repo's own
# documents, a percent floor punished a final page that carries a real section (the
# German CV's languages block, 71 mm) while a two-line spillover measured 22 mm.
# The defect is "almost nothing on that page", so the floor is an amount of content.
#
# `task apps:audit` in the retired workflow checkout asks a related question about
# dist/ after the fact; that directory is not an input to any build, so it cannot
# refuse one.
{pkgs}: {
  # check — the shell to run in the same derivation, after `typst compile`.
  #
  #   source       the .typ the compile used, as typst was given it (--root work)
  #   budget       the exact number of pages the document is allowed to make
  #   minLastPage  millimetres of content a final page must carry once there is a
  #                second page; below this it is a spillover, not a page
  #   doc          what the failure message should call the document
  #
  # Needs typst and jq on PATH.
  check = {
    source,
    budget,
    minLastPage ? 40,
    doc ? "document",
  }: ''
    # `typst eval`, not `typst query`: query is deprecated in the pinned typst and
    # answers the same element as JSON.
    _report=$(typst eval --root work --in ${source} --format json 'query(<typeset>).first().value') || {
      echo "typeset: ${doc} has no <typeset> report — the template must end with one" >&2
      exit 1
    }
    _pages=$(printf '%s' "$_report" | ${pkgs.jq}/bin/jq -r .pages)
    _last=$(printf '%s' "$_report" | ${pkgs.jq}/bin/jq -r .last)

    # The measurement goes into the log either way: it is what says a budget is
    # about to break before the build that breaks it.
    printf 'typeset: %s: %s page(s), budget %s, %smm on the last page\n' \
      "${doc}" "$_pages" "${toString budget}" "$_last" >&2

    if [ "$_pages" != "${toString budget}" ]; then
      echo "typeset: ${doc} made $_pages page(s), the budget is ${toString budget} — tighten the copy, or change the budget deliberately" >&2
      exit 1
    fi
    if [ "$_pages" -gt 1 ] && [ "$_last" -lt "${toString minLastPage}" ]; then
      echo "typeset: ${doc} ends with $_last mm of content on its last page (floor ${toString minLastPage} mm) — that is a spillover, not a page" >&2
      exit 1
    fi
  '';
}
