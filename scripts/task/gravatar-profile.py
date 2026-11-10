#!/usr/bin/env python3
"""Reconcile the live Gravatar profile with modules/config/gravatar.toml.

Only scalars are writable through the public API (PATCH /v3/me/profile). Links,
interests, languages and timezone have no write endpoint, so they are compared
for drift and reported as manual work at gravatar.com rather than silently
skipped.
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import time
import tomllib
import urllib.error
import urllib.request

PROFILE_URL = "https://api.gravatar.com/v3/me/profile"
WRITABLE = (
    "first_name",
    "last_name",
    "display_name",
    "description",
    "pronunciation",
    "pronouns",
    "location",
    "job_title",
    "company",
    "cell_phone",
    "contact_email",
)
# The contact section is nested in the read model and flat in the write model:
# PATCH takes `cell_phone` and `contact_email`, GET returns
# `contact_info.{cell_phone,email}`, and calendar/contact_form exist only on the
# read side.
CONTACT = {
    "cell_phone": "cell_phone",
    "contact_email": "email",
    "calendar": "calendar",
    "contact_form": "contact_form",
}
SCALARS = WRITABLE + ("timezone", "calendar", "contact_form")

ROOT = subprocess.check_output(["git", "rev-parse", "--show-toplevel"], text=True).strip()
DATA = os.path.join(ROOT, "modules", "config", "gravatar.toml")
def _secrets_path() -> str:
    """The canonical sops file, resolved by scripts/task/lib/paths.sh so this
    script never spells where it lives."""
    helper = os.path.join(ROOT, "scripts", "task", "lib", "paths.sh")
    out = subprocess.run([helper, "secrets"], capture_output=True, text=True)
    path = out.stdout.strip()
    if out.returncode != 0 or not path:
        raise SystemExit("gravatar-profile: paths.sh could not resolve a secrets.yaml (submodule checked out?)")
    return path


SECRETS = _secrets_path()


def token():
    return subprocess.check_output(
        ["sops", "-d", "--extract", '["gravatar_oauth_token"]', SECRETS], text=True
    ).strip()


def desired():
    with open(DATA, "rb") as handle:
        return tomllib.load(handle)


def live():
    request = urllib.request.Request(
        PROFILE_URL,
        headers={"Authorization": "Bearer " + token(), "User-Agent": "nixconfig-gravatar-sync"},
    )
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            return json.load(response)
    except urllib.error.HTTPError as error:
        sys.exit("gravatar: read failed (%s) — run `task gravatar:token`" % error.code)
    except urllib.error.URLError as error:
        sys.exit("gravatar: read failed (%s)" % error.reason)


def live_value(have, key):
    if key in CONTACT:
        return (have.get("contact_info") or {}).get(CONTACT[key]) or ""
    return have.get(key, "")


def diffs(want, have):
    found = []
    for key in SCALARS:
        wanted = want.get(key, "")
        actual = live_value(have, key)
        if wanted != actual:
            found.append((key, wanted, actual, key in WRITABLE))
    wanted_languages = list(want.get("languages", []))
    actual_languages = [
        item["code"] for item in sorted(have.get("languages", []), key=lambda item: item.get("order", 0))
    ]
    if wanted_languages != actual_languages:
        found.append(("languages", wanted_languages, actual_languages, False))
    wanted_interests = list(want.get("interests", []))
    actual_interests = [item["name"] for item in have.get("interests", [])]
    if sorted(wanted_interests) != sorted(actual_interests):
        found.append(("interests", wanted_interests, actual_interests, False))
    wanted_links = [(link["label"], link["url"]) for link in want.get("links", [])]
    actual_links = [(link["label"], link["url"]) for link in have.get("links", [])]
    if wanted_links != actual_links:
        found.append(("links", wanted_links, actual_links, False))
    return found


def show(found):
    for key, wanted, actual, writable in found:
        print("drift: %s (%s)" % (key, "writable" if writable else "manual"))
        print("  want: %s" % (wanted,))
        print("  live: %s" % (actual,))


def apply(found):
    body = {key: wanted for key, wanted, _, writable in found if writable}
    if not body:
        return []
    request = urllib.request.Request(
        PROFILE_URL,
        data=json.dumps(body).encode(),
        method="PATCH",
        headers={
            "Authorization": "Bearer " + token(),
            "Content-Type": "application/json",
            "User-Agent": "nixconfig-gravatar-sync",
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            json.load(response)
    except urllib.error.HTTPError as error:
        sys.exit("gravatar: patch failed (%s): %s" % (error.code, error.read().decode("utf-8", "replace")))
    return sorted(body)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true", help="PATCH the writable fields that drift")
    args = parser.parse_args()

    found = diffs(desired(), live())
    if not found:
        print("gravatar: in sync with %s" % os.path.relpath(DATA, ROOT))
        return 0
    show(found)
    if not args.apply:
        print("\nrun `task gravatar:sync` for the writable fields")
        return 1
    written = apply(found)
    if written:
        print("\napplied: %s" % ", ".join(written))
    # The profile read lags the write: a GET issued right after a 200 PATCH can
    # still return the old scalars (measured 2026-11-09 on pronouns, location and
    # company, which a later read showed written). Re-read until no writable
    # drift is left, then report whatever remains.
    remaining = diffs(desired(), live())
    for _ in range(4):
        if not any(item[3] for item in remaining):
            break
        time.sleep(1.5)
        remaining = diffs(desired(), live())
    if remaining:
        show(remaining)
        print("\ngravatar: %d field(s) need https://gravatar.com/jisifu" % len(remaining))
        return 1
    print("gravatar: in sync after apply")
    return 0


if __name__ == "__main__":
    sys.exit(main())
