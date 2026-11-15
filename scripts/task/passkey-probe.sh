#!/usr/bin/env bash
# Prove the one primitive a headless passkey login needs, without touching Google.
#
# A passkey cannot be *typed* the way a TOTP code can, so the automation question
# is whether a browser can sign a WebAuthn assertion with a key it did not
# generate. That is exactly what Chrome's CDP virtual authenticator does: a key
# exported from the vault is installed with WebAuthn.addCredential, and the site's
# own ceremony signs with it. No phone, no fingerprint, no browser extension.
#
# This registers a credential in a throwaway authenticator, exports the private
# key, installs it into a *second* empty authenticator, and asserts with the
# imported copy. Passing means the vault -> browser half of a passkey login is
# wired; what is left is the site's own login page and a vault client that can
# read fido2Credentials (bw/rbw — `cloak` is TOTP only).
#
#   scripts/task/passkey-probe.sh                     # self-test on 127.0.0.1
#   scripts/task/passkey-probe.sh --from-vault FILE   # import a vault credential
#
# --from-vault takes {"rpId": "...", "credentialId": "<b64url>", "privateKey": "<base64 PKCS8>"}
# as extracted from a Bitwarden item's fido2Credentials; the self-test writes the
# same shape to /tmp/passkey-probe-credential.json so the import path is visible.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

vault_file=""
while [ $# -gt 0 ]; do
  case "$1" in
  --from-vault)
    vault_file="${2:?--from-vault needs a file}"
    shift 2
    ;;
  *)
    echo "passkey-probe: unknown argument $1" >&2
    exit 2
    ;;
  esac
done

chromium="${CHROMIUM:-$(command -v chromium || command -v chromium-browser || true)}"
if [ -z "$chromium" ]; then
  echo "passkey-probe: no chromium on PATH (set CHROMIUM=/nix/store/.../bin/chromium)" >&2
  exit 3
fi
for tool in node python3; do
  command -v "$tool" >/dev/null 2>&1 || {
    echo "passkey-probe: $tool is not on PATH" >&2
    exit 3
  }
done
# Node before 22 has no global WebSocket; the client below needs one.
if ! node -e 'process.exit(typeof WebSocket === "function" ? 0 : 1)'; then
  echo "passkey-probe: node $(node -v) has no global WebSocket (needs 22+)" >&2
  exit 3
fi

work="$(mktemp -d)"
pick_port() {
  python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1]); s.close()'
}
# Two ports, never one: the page must be served while Chrome also needs a
# debugging socket, and a collision leaves no /json/list to connect to at all.
srv_port="$(pick_port)"
cdp_port="$(pick_port)"
[ "$srv_port" = "$cdp_port" ] && cdp_port="$(pick_port)"
trap 'kill "${srv:-}" "${browser:-}" 2>/dev/null || true; rm -rf "$work"' EXIT

cat >"$work/index.html" <<'HTML'
<!doctype html><meta charset=utf-8><title>passkey probe</title>
<script>
const b64 = (b) => btoa(String.fromCharCode(...new Uint8Array(b)));
const unb64 = (s) => Uint8Array.from(atob(s), (c) => c.charCodeAt(0));
const rpId = location.hostname;
window.doCreate = async () => {
  const c = await navigator.credentials.create({publicKey: {
    rp: {id: rpId, name: "passkey probe"},
    user: {id: unb64("cHJvYmU"), name: "probe@localhost", displayName: "probe"},
    challenge: crypto.getRandomValues(new Uint8Array(32)),
    pubKeyCredParams: [{type: "public-key", alg: -7}],
    authenticatorSelection: {residentKey: "required", userVerification: "required"},
    timeout: 20000,
  }});
  return b64(c.rawId);
};
window.doGet = async (idB64) => {
  const a = await navigator.credentials.get({publicKey: {
    challenge: crypto.getRandomValues(new Uint8Array(32)),
    rpId,
    allowCredentials: [{type: "public-key", id: unb64(idB64)}],
    userVerification: "required",
    timeout: 20000,
  }});
  return b64(a.response.signature);
};
</script>
HTML

cat >"$work/cdp.mjs" <<'JS'
import fs from "node:fs";

const [port, vaultFile] = process.argv.slice(2);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function pageTarget() {
  for (let i = 0; i < 100; i++) {
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
  if (r.exceptionDetails) throw new Error(JSON.stringify(r.exceptionDetails));
  return r.result.value;
};

const opts = {
  protocol: "ctap2",
  ctap2Version: "ctap2_1",
  transport: "internal",
  hasResidentKey: true,
  hasUserVerification: true,
  isUserVerified: true,
  automaticPresenceSimulation: true,
};

// The target exists before its document has run: evaluating doCreate() too early
// is a ReferenceError, not a WebAuthn failure, and it looks random (it is), so
// wait for the page to say it is ready.
await send("Page.enable");
let pageReady = false;
for (let i = 0; i < 150; i++) {
  pageReady = await evaluate(`document.readyState === "complete" && typeof doCreate === "function"`);
  if (pageReady) break;
  await sleep(100);
}
if (!pageReady) throw new Error("the probe page never finished loading");

await send("WebAuthn.enable", { enableUI: false });
const first = await send("WebAuthn.addVirtualAuthenticator", { options: opts });
const authId = first.authenticatorId;

let credential;
if (vaultFile) {
  const v = JSON.parse(fs.readFileSync(vaultFile, "utf8"));
  credential = {
    // A vault stores base64url; CDP's WebAuthn domain wants standard base64 and
    // rejects the other with "invalid base64 string at position 94".
    credentialId: Buffer.from(v.credentialId, "base64url").toString("base64"),
    privateKey: v.privateKey,
    rpId: v.rpId,
    userHandle: v.userHandle ?? "cHJvYmU=",
    isResidentCredential: true,
    signCount: 0,
  };
} else {
  const rawId = await evaluate("doCreate()");
  if (!rawId) throw new Error("registration returned no credential id");
  const { credentials } = await send("WebAuthn.getCredentials", { authenticatorId: authId });
  if (!credentials?.length) throw new Error("the authenticator exported no credential");
  credential = credentials[0];
  console.log(`  registered and exported ${credential.credentialId} for rp ${credential.rpId}`);
  console.log(`  private key: ${Buffer.from(credential.privateKey, "base64").length} bytes (PKCS8)`);
  fs.writeFileSync("/tmp/passkey-probe-credential.json", JSON.stringify({
    rpId: credential.rpId,
    credentialId: Buffer.from(credential.credentialId, "base64").toString("base64url"),
    privateKey: credential.privateKey,
    userHandle: credential.userHandle,
  }, null, 2));
  console.log("  vault-shaped dump: /tmp/passkey-probe-credential.json");
}

// A second, empty authenticator: nothing it holds came from this browser.
await send("WebAuthn.removeVirtualAuthenticator", { authenticatorId: authId });
const second = await send("WebAuthn.addVirtualAuthenticator", { options: opts });
await send("WebAuthn.addCredential", {
  authenticatorId: second.authenticatorId,
  credential,
});
const assertion = await evaluate(`doGet(${JSON.stringify(credential.credentialId)})`);
if (!assertion) throw new Error("the imported credential signed nothing");

console.log(`  assertion signed by the imported key: ${Buffer.from(assertion, "base64").length} bytes`);
ws.close();
process.exit(0);
JS

echo "passkey-probe: chromium $(basename "$chromium"), node $(node -v), page :$srv_port, cdp :$cdp_port"
python3 -m http.server "$srv_port" --bind 127.0.0.1 --directory "$work" >/dev/null 2>&1 &
srv=$!
sleep 1

if command -v xvfb-run >/dev/null 2>&1; then
  launch=(xvfb-run -a "$chromium")
else
  echo "passkey-probe: xvfb-run is not on PATH; using a nix shell" >&2
  launch=(nix shell --option builders "" nixpkgs#xvfb-run -c xvfb-run -a "$chromium")
fi

# Headed under a virtual display, because Google disowns headless Chrome and the
# virtual authenticator is a page-level capability either way.
"${launch[@]}" \
  --user-data-dir="$work/profile" \
  --no-first-run --no-default-browser-check --disable-gpu \
  --remote-debugging-address=127.0.0.1 --remote-debugging-port="$cdp_port" \
  "http://localhost:$srv_port/index.html" >"$work/chrome.log" 2>&1 &
browser=$!

args=("$cdp_port")
[ -n "$vault_file" ] && args+=("$vault_file")
node "$work/cdp.mjs" "${args[@]}"
rc=$?
if [ "$rc" -ne 0 ]; then
  echo "passkey-probe: FAIL the virtual authenticator round trip broke" >&2
  echo "  chrome said: $(tail -3 "$work/chrome.log" 2>/dev/null | tr '\n' ' ')" >&2
  exit 1
fi
echo "passkey-probe: ok — a credential was imported into a blank authenticator and signed with"
echo "  what a headless login still needs: a vault client that reads fido2Credentials (bw/rbw;"
echo "  cloak is TOTP only) and a passkey for the site stored in Vaultwarden."
