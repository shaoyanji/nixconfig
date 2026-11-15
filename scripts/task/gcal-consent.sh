#!/usr/bin/env bash
# Drive a Google OAuth consent screen to completion with no human and no paste.
#
# `vdirsyncer discover` keeps its callback server alive only while it runs, so the
# consent has to happen inside that window and the redirect has to reach
# 127.0.0.1:<port> *on this host*. A real browser on a laptop cannot do that, and a
# paste is a human. This runs Chromium where the listener is: under xvfb with CDP
# over node's built-in WebSocket, so the redirect is fetched locally.
#
#   gcal-consent.sh <consent-url> <callback-port> [passkey-file]
#
# Filling the login needs up to three inputs, all optional and all skipped when
# absent: CAL_GOOGLE_EMAIL, CAL_GOOGLE_PASSWORD_FILE (a file, never a value on a
# command line - it would land in the process table), and CAL_TOTP_CMD (a command
# whose last output line is the code, e.g. `cloak view google`).
#
# The browser profile is the Google session. Keep it on disk (not /tmp) and a
# re-consent skips the password entirely; lose it and the login pages appear, which
# is where the optional passkey matters: the file is a credential extracted from the
# vault ({rpId, credentialId base64url, privateKey base64}) and it is installed into
# a CDP virtual authenticator, so Google sees a local, already-verified authenticator
# and never offers the "sign in with your phone" prompt. scripts/task/passkey-probe.sh
# proves that import path without touching Google.
set -euo pipefail

url="${1:?usage: gcal-consent.sh <consent-url> <callback-port> [passkey-file]}"
port="${2:?usage: gcal-consent.sh <consent-url> <callback-port> [passkey-file]}"
passkey="${3:-}"
profile="${CAL_PROFILE:-${XDG_STATE_HOME:-$HOME/.local/state}/cdp-prof-headed}"
deadline="${CAL_DEADLINE:-240}"

chromium="${CHROMIUM:-$(command -v chromium || command -v chromium-browser || true)}"
# Not every host exposes chromium on PATH, and a flake input's store path is the
# same binary; naming it here keeps the caller from having to know that.
if [ -z "$chromium" ]; then
  chromium="$(ls -d /nix/store/*-chromium-*/bin/chromium 2>/dev/null | tail -1 || true)"
fi
[ -n "$chromium" ] || {
  echo "gcal-consent: no chromium found (set CHROMIUM=.../bin/chromium)" >&2
  exit 3
}
for tool in node python3 curl; do
  command -v "$tool" >/dev/null 2>&1 || {
    echo "gcal-consent: $tool is not on PATH" >&2
    exit 3
  }
done
if [ -n "$passkey" ] && [ ! -s "$passkey" ]; then
  echo "gcal-consent: passkey file $passkey is missing; continuing without it" >&2
  passkey=""
fi

work="$(mktemp -d)"
pick_port() {
  python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1]); s.close()'
}
cdp_port="$(pick_port)"
trap 'kill "${browser:-}" 2>/dev/null || true; rm -rf "$work"' EXIT

cat >"$work/drive.mjs" <<'JS'
import fs from "node:fs";
import { execSync } from "node:child_process";

const [port, target, passkeyFile, deadline, email, passwordFile, totpCmd] = process.argv.slice(2);
const password = passwordFile ? fs.readFileSync(passwordFile, "utf8").trim() : "";
// Called per attempt: a code captured at start is dead by the time a form asks.
const totp = () => {
  if (!totpCmd) return "";
  try {
    return execSync(totpCmd, { encoding: "utf8", timeout: 10000 }).trim().split("\n").pop();
  } catch {
    return "";
  }
};
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function pageTarget() {
  for (let i = 0; i < 200; i++) {
    try {
      const list = await (await fetch(`http://127.0.0.1:${port}/json/list`)).json();
      const page = list.find((t) => t.type === "page" && t.webSocketDebuggerUrl);
      if (page) return page;
    } catch {}
    await sleep(150);
  }
  throw new Error("no page target on the debugging port");
}

const page = await pageTarget();
const ws = new WebSocket(page.webSocketDebuggerUrl);
await new Promise((res, rej) => {
  ws.onopen = res;
  ws.onerror = rej;
});

let id = 0;
const waiters = new Map();
ws.onmessage = (ev) => {
  const msg = JSON.parse(ev.data);
  if (msg.id && waiters.has(msg.id)) {
    const { res, rej } = waiters.get(msg.id);
    waiters.delete(msg.id);
    msg.error ? rej(new Error(JSON.stringify(msg.error))) : res(msg.result);
  }
};
const send = (method, params = {}) =>
  new Promise((res, rej) => {
    const n = ++id;
    waiters.set(n, { res, rej });
    ws.send(JSON.stringify({ id: n, method, params }));
  });
const evaluate = async (expression) => {
  const r = await send("Runtime.evaluate", {
    expression,
    awaitPromise: true,
    returnByValue: true,
  });
  if (r.exceptionDetails) return { error: JSON.stringify(r.exceptionDetails) };
  return { value: r.result.value };
};

await send("Page.enable");
await send("Runtime.enable");

let authenticator = null;
if (passkeyFile) {
  const v = JSON.parse(fs.readFileSync(passkeyFile, "utf8"));
  await send("WebAuthn.enable", { enableUI: false });
  const { authenticatorId } = await send("WebAuthn.addVirtualAuthenticator", {
    options: {
      protocol: "ctap2",
      ctap2Version: "ctap2_1",
      transport: "internal",
      hasResidentKey: true,
      hasUserVerification: true,
      isUserVerified: true,
      automaticPresenceSimulation: true,
    },
  });
  authenticator = authenticatorId;
  await send("WebAuthn.addCredential", {
    authenticatorId,
    credential: {
      // Vault: base64url. CDP: standard base64, or it refuses the parameter.
      credentialId: Buffer.from(v.credentialId, "base64url").toString("base64"),
      privateKey: v.privateKey,
      rpId: v.rpId,
      userHandle: v.userHandle ?? "cHJvYmU=",
      isResidentCredential: true,
      signCount: 0,
    },
  });
  console.log(`  passkey installed for rp ${v.rpId} (user verification pre-satisfied)`);
}

await send("Page.navigate", { url: target });

// One decision per tick, in the order Google asks: identify, prove, consent.
// Values go through the prototype setter and a bubbling input event, because
// Google's fields ignore a plain assignment and the Next button then submits an
// empty form - which is what an automated run looks like when it "does nothing".
const actionExpr = () => `(() => {
  const visible = (e) => !!(e.offsetWidth || e.offsetHeight || e.getClientRects().length);
  const text = (e) => (e.innerText || e.textContent || "").replace(/\\s+/g, " ").trim();
  const setVal = (el, v) => {
    const d = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, "value");
    d.set.call(el, v);
    el.dispatchEvent(new Event("input", { bubbles: true }));
    el.dispatchEvent(new Event("change", { bubbles: true }));
    el.focus();
  };
  const email = ${JSON.stringify(email)};
  const password = ${JSON.stringify(password)};
  const totp = ${JSON.stringify(totp())};
  const pick = (sel) => [...document.querySelectorAll(sel)].filter(visible)[0];
  const idField = pick('input[type=email], input[name="identifier"], input[autocomplete="username"]');
  if (idField && !idField.value && email) { setVal(idField, email); return "filled: email"; }
  const pwField = pick('input[type=password]');
  if (pwField && !pwField.value && password) { setVal(pwField, password); return "filled: password"; }
  const otpField = pick('input[name="totpPin"], input[id="totpPin"], input[autocomplete="one-time-code"], input[type="tel"]');
  if (otpField && totp && !otpField.value) { setVal(otpField, totp); return "filled: totp"; }
  const els = [...document.querySelectorAll('button, div[role=button], a[role=button], span[role=button], input[type=submit]')].filter(visible);
  // This account answers a login with a passkey challenge. Without an
  // authenticator it lands on /challenge/pk/error, so never take the "Continue"
  // on a challenge page: walk to the password path, which is the one a TOTP can
  // finish. A passkey installed via CAL_PASSKEY_FILE makes Google skip this
  // entirely, which is why the alternative is tried before it.
  if (/\\/challenge\\//.test(location.href)) {
    // A challenge page that already offers a password field IS the password page:
    // clicking "try another way" there walks back to the chooser and returns, in
    // a circle that looks like a hang. Submit instead.
    const alt = pwField ? undefined : els.find((e) => /try another way|use another|other way/i.test(text(e)));
    if (alt) { alt.click(); return "clicked: " + text(alt); }
    if (pwField) {
      const next = els.find((e) => /^(next|continue)$/i.test(text(e)));
      if (next) { next.click(); return "submitted: " + text(next); }
      return "waiting";
    }
    // The method list is role=radio rows, not buttons: a button query reports
    // "waiting" forever on a page that is offering the choice, which reads like
    // a hang instead of a wrong selector.
    const wide = [...document.querySelectorAll('[role="radio"], [role="link"], li, div')].filter(
      (e) => visible(e) && text(e).length < 90,
    );
    const rows = wide.filter((e) => !wide.some((o) => o !== e && e.contains(o)));
    const pw = rows.find((e) => /password/i.test(text(e)));
    if (pw) {
      (pw.closest('[role="radio"], [role="link"], li, button, a') || pw).click();
      return "chosen: " + text(pw).slice(0, 60);
    }
    const offered = rows.map((e) => text(e)).filter((t) => t && t.length < 70).slice(0, 6).join(" | ");
    if (offered) return "selection: " + offered;
  }
  const exact = els.find((e) => /^(continue|allow|next|agree|accept|verify)$/i.test(text(e)));
  if (exact) { exact.click(); return "clicked: " + text(exact); }
  const cont = els.find((e) => /continue|allow|agree|next/i.test(text(e)));
  if (cont) { cont.click(); return "clicked: " + text(cont); }
  const account = els.find((e) => /@/.test(text(e)));
  if (account) { account.click(); return "account: " + text(account); }
  if (pwField) return "stuck: password page and no password supplied (CAL_GOOGLE_PASSWORD_FILE)";
  if (otpField) return "stuck: code page and no TOTP command (CAL_TOTP_CMD)";
  return "waiting";
})()`;

const started = Date.now();
let last = "";
let clicks = 0;
const limit = Number(deadline || 240) * 1000;
while (Date.now() - started < limit) {
  await sleep(1200);
  const href = await evaluate("location.href");
  const here = href.value || "";
  if (/^http:\/\/127\.0\.0\.1:/.test(here)) {
    console.log(`  redirect captured after ${Math.round((Date.now() - started) / 1000)}s, ${clicks} click(s)`);
    console.log(here);
    ws.close();
    process.exit(0);
  }
  const r = await evaluate(actionExpr());
  if (r.value && r.value !== last) {
    if (String(r.value).startsWith("clicked") || String(r.value).startsWith("account")) clicks++;
    console.log(`  ${r.value}  <- ${here.slice(0, 70)}`);
    last = r.value;
  }
  if (String(r.value).startsWith("stuck")) {
    console.error(`gcal-consent: ${r.value}`);
    ws.close();
    process.exit(4);
  }
}
// Say what the page says, not just that nothing happened: "wrong password"
// and "this value was not accepted by the field" need different fixes, and from
// the outside both look like a page that never moves.
const said = await evaluate("document.body.innerText.replace(/\\s+/g,' ').slice(0,300)");
if (said.value) console.error(`gcal-consent: page says: ${said.value}`);
console.error(`gcal-consent: no redirect within ${deadline}s (last page ${last || "unknown"})`);
ws.close();
process.exit(5);
JS

# A killed browser leaves SingletonLock behind and the next launch dies in the
# zygote before CDP ever exists ("Failed sending zygote boot message"). Clear it
# only when the process that owned it is gone.
if [ -L "$profile/SingletonLock" ]; then
  owner="$(readlink "$profile/SingletonLock" | sed 's/.*-//')"
  if [ -n "$owner" ] && ! kill -0 "$owner" 2>/dev/null; then
    rm -f "$profile/SingletonLock" "$profile/SingletonSocket" "$profile/SingletonCookie"
    echo "gcal-consent: cleared a stale profile lock (pid $owner is gone)" >&2
  fi
fi

if command -v xvfb-run >/dev/null 2>&1; then
  launch=(xvfb-run -a "$chromium")
else
  launch=(nix shell --option builders "" nixpkgs#xvfb-run -c xvfb-run -a "$chromium")
fi

echo "gcal-consent: chromium under xvfb, profile $profile, cdp :$cdp_port"
"${launch[@]}" \
  --user-data-dir="$profile" \
  --no-first-run --no-default-browser-check --disable-gpu --disable-sync \
  --remote-debugging-address=127.0.0.1 --remote-debugging-port="$cdp_port" \
  about:blank >"$work/chrome.log" 2>&1 &
browser=$!
sleep 2

redirect="$(node "$work/drive.mjs" "$cdp_port" "$url" "$passkey" "$deadline" \
  "${CAL_GOOGLE_EMAIL:-}" "${CAL_GOOGLE_PASSWORD_FILE:-}" "${CAL_TOTP_CMD:-}" \
  2>"$work/drive.err" | tee /dev/stderr | tail -1)" || rc=$?
if [ "${rc:-0}" -ne 0 ] || [ -z "${redirect:-}" ]; then
  echo "gcal-consent: FAIL $(tail -2 "$work/drive.err" 2>/dev/null | tr '\n' ' ')" >&2
  echo "  chrome said: $(tail -2 "$work/chrome.log" 2>/dev/null | tr '\n' ' ')" >&2
  exit 1
fi

# Hand the redirect to vdirsyncer's own listener: that request is what makes it
# write the token file, and it only exists on this host.
code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 "$redirect" || echo 000)"
echo "gcal-consent: callback answered $code"
case "$code" in
200 | 302 | 404) exit 0 ;;
*) echo "gcal-consent: FAIL the callback at 127.0.0.1:$port did not take the redirect" >&2; exit 1 ;;
esac
