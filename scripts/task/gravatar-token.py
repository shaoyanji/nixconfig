#!/usr/bin/env python3
"""Mint, renew, or check the Gravatar OAuth token stored in sops.

The flow is the implicit grant against app 152602, whose registered redirect is
the Gravatar developer console. When a logged-in Firefox profile exists on this
host the consent form is submitted headlessly; elsewhere the authorize URL is
printed and the redirected URL (or the bare token) is read from stdin.
"""

from __future__ import annotations

import argparse
import html
import json
import os
import re
import shutil
import sqlite3
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request

CLIENT_ID = os.environ.get("GRAVATAR_CLIENT_ID", "152602")
REDIRECT = "https://gravatar.com/developers/console"
SCOPES = ("auth", "gravatar-profile:read", "gravatar-profile:manage")
TOKEN_KEY = "gravatar_oauth_token"
EXPIRES_KEY = "gravatar_oauth_expires"
TTL_SECONDS = 14 * 24 * 3600
PROFILE_ENDPOINT = "https://api.gravatar.com/v3/me/profile"
UA = "Mozilla/5.0 (X11; Linux x86_64; rv:158.0) Gecko/20100101 Firefox/158.0"
COOKIE_HOSTS = ("%gravatar%", "%wordpress.com%", "%wp.com%")


def repo_root() -> str:
    return subprocess.check_output(["git", "rev-parse", "--show-toplevel"], text=True).strip()


def _secrets_path() -> str:
    """The canonical sops file, resolved by scripts/task/lib/paths.sh so this
    script never spells where it lives."""
    helper = os.path.join(repo_root(), "scripts", "task", "lib", "paths.sh")
    out = subprocess.run([helper, "secrets"], capture_output=True, text=True)
    path = out.stdout.strip()
    if out.returncode != 0 or not path:
        raise SystemExit("gravatar-token: paths.sh could not resolve a secrets.yaml (submodule checked out?)")
    return path


SECRETS = _secrets_path()


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs):
        return None


OPENER = urllib.request.build_opener(NoRedirect)


def http(url, cookie=None, data=None, referer=None):
    headers = {"User-Agent": UA, "Accept": "text/html,application/xhtml+xml"}
    if cookie:
        headers["Cookie"] = cookie
    if data is not None:
        headers["Content-Type"] = "application/x-www-form-urlencoded"
    if referer:
        headers["Referer"] = referer
    request = urllib.request.Request(url, data=data, headers=headers)
    try:
        with OPENER.open(request, timeout=30) as response:
            return response.status, response.headers.get("Location") or "", response.read().decode("utf-8", "replace")
    except urllib.error.HTTPError as error:
        return error.code, error.headers.get("Location") or "", error.read().decode("utf-8", "replace")


def authorize_url(state="task"):
    query = urllib.parse.urlencode(
        {
            "response_type": "token",
            "client_id": CLIENT_ID,
            "redirect_uri": REDIRECT,
            "scope": " ".join(SCOPES),
            "state": state,
        },
        quote_via=urllib.parse.quote,
    )
    return "https://public-api.wordpress.com/oauth2/authorize?" + query


def profile_dirs():
    home = os.path.expanduser("~")
    roots = (
        os.path.join(home, ".config/mozilla/firefox"),
        os.path.join(home, ".mozilla/firefox"),
        os.path.join(home, ".config/librewolf/librewolf"),
    )
    for root in roots:
        if not os.path.isdir(root):
            continue
        for name in sorted(os.listdir(root)):
            profile = os.path.join(root, name)
            if os.path.isfile(os.path.join(profile, "cookies.sqlite")):
                yield profile


def cookie_header():
    for profile in profile_dirs():
        handle, temp = tempfile.mkstemp(suffix=".sqlite")
        os.close(handle)
        try:
            shutil.copy(os.path.join(profile, "cookies.sqlite"), temp)
            connection = sqlite3.connect(temp)
            where = " or ".join("host like ?" for _ in COOKIE_HOSTS)
            rows = connection.execute(
                "select host,name,value from moz_cookies where " + where, COOKIE_HOSTS
            ).fetchall()
        except Exception:
            continue
        finally:
            try:
                os.unlink(temp)
            except OSError:
                pass
        if rows:
            return "; ".join("%s=%s" % (name, value) for _, name, value in rows)
    return None


def token_from_location(location):
    match = re.search(r"access_token=([^&]+)", location or "")
    return urllib.parse.unquote(match.group(1)) if match else None


def approve(url, cookie):
    status, _, body = http(url, cookie=cookie)
    if status != 200:
        return None
    form = re.search(r"<form\b.*?</form>", body, re.S | re.I)
    if not form:
        return None
    form = form.group(0)
    action = re.search(r'action="([^"]*)"', form, re.I)
    if not action:
        return None
    action = html.unescape(action.group(1))
    fields = {}
    for control in re.findall(r"<input\b[^>]*>", form, re.I):
        name = re.search(r'name="([^"]*)"', control)
        value = re.search(r'value="([^"]*)"', control)
        if name:
            fields[name.group(1)] = html.unescape(value.group(1)) if value else ""
    target = action + ("&" if "?" in action else "?") + urllib.parse.urlencode(fields)
    _, location, _ = http(target, cookie=cookie, referer=url)
    return token_from_location(location)


def consent_token(cookie):
    url = authorize_url()
    status, location, _ = http(url, cookie=cookie)
    token = token_from_location(location)
    if token:
        return token
    if status == 200:
        return approve(url, cookie)
    return None


def verify(token):
    request = urllib.request.Request(
        PROFILE_ENDPOINT, headers={"Authorization": "Bearer " + token, "User-Agent": UA}
    )
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            return response.status, json.load(response)
    except urllib.error.HTTPError as error:
        return error.code, {}


def sops_get(key):
    result = subprocess.run(
        ["sops", "-d", "--extract", json.dumps([key]), SECRETS], capture_output=True, text=True
    )
    return result.stdout.strip() if result.returncode == 0 else None


def sops_set(key, value):
    subprocess.run(
        ["sops", "set", SECRETS, json.dumps([key]), "--value-stdin"],
        input=json.dumps(value).encode(),
        check=True,
    )


def store(token, sync=True):
    expires = time.strftime("%Y-%m-%dT%H:%MZ", time.gmtime(time.time() + TTL_SECONDS))
    sops_set(TOKEN_KEY, token)
    sops_set(EXPIRES_KEY, expires)
    if sync:
        synced = subprocess.run(
            ["task", "infra:secrets:sync"], cwd=repo_root(), capture_output=True, text=True
        )
        if synced.returncode != 0:
            print("gravatar: stored in the canonical file, but infra:secrets:sync failed", file=sys.stderr)
    return expires


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--status", action="store_true", help="check the stored token and exit")
    parser.add_argument("--token", default=os.environ.get("GRAVATAR_TOKEN"), help="token or redirected URL")
    parser.add_argument("--token-file", help="file holding the token or the redirected URL")
    parser.add_argument("--no-sync", action="store_true", help="leave the mirrored secrets file alone")
    args = parser.parse_args()

    if args.status:
        token = sops_get(TOKEN_KEY)
        if not token:
            print("gravatar: no token stored — run `task gravatar:token`")
            return 1
        status, profile = verify(token)
        expires = sops_get(EXPIRES_KEY) or "not recorded (renew to record it)"
        if status == 200:
            print("gravatar: ok | %s | expires %s" % (profile.get("display_name"), expires))
            return 0
        print("gravatar: token rejected (%s) | expires %s — run `task gravatar:token`" % (status, expires))
        return 1

    token = args.token
    if args.token_file:
        with open(args.token_file, encoding="utf-8") as handle:
            token = handle.read().strip()
    if not token:
        cookie = cookie_header()
        if cookie:
            print("gravatar: using the logged-in browser session on this host")
            token = consent_token(cookie)
        if not token:
            print("gravatar: no usable browser session here.")
            print("  open this, approve, then paste the redirected URL or the token:\n")
            print(authorize_url() + "\n")
            try:
                token = input("token: ").strip()
            except EOFError:
                token = ""
    token = token_from_location(token) or (token or "").strip()
    if not token:
        print("gravatar: no token given", file=sys.stderr)
        return 1
    status, profile = verify(token)
    if status != 200:
        print("gravatar: token rejected (%s) — nothing stored" % status, file=sys.stderr)
        return 1
    expires = store(token, sync=not args.no_sync)
    print("gravatar: stored | %s | expires %s" % (profile.get("display_name"), expires))
    return 0


if __name__ == "__main__":
    sys.exit(main())
