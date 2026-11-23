// Smoke test for vercel/api/*.js — exercised directly by run.sh via node.
// Prints "ok <case>" / "FAIL <case>"; exit 1 on any failure, 2 on bad env.
import { TARGETS, probe, default as check } from "../../vercel/api/check.js";

let fail = 0;
const ok = (cond, name) => {
  if (cond) console.log(`ok ${name}`);
  else { console.log(`FAIL ${name}`); fail = 1; }
};
const mkRes = () => ({
  _s: 0, _h: {}, _b: undefined,
  status(c) { this._s = c; return this; },
  setHeader(k, v) { this._h[k.toLowerCase()] = v; return this; },
  json(b) { this._b = b; return this; },
});

// --- check.js --------------------------------------------------------------
ok(Object.keys(TARGETS).length >= 5, "targets: at least five public surfaces");
ok(Object.values(TARGETS).every((t) => t.url.startsWith("https://")), "targets: all https");

{
  const res = mkRes();
  await check({ method: "GET", query: { name: "bogus" }, headers: {} }, res);
  ok(res._s === 400, "check: unknown name refused with 400 (no fetch made)");
}
{
  const res = mkRes();
  await check({ method: "POST", query: {}, headers: {} }, res);
  ok(res._s === 405, "check: POST refused with 405");
}
{
  // Loopback refusal: closed port answers fast, proves {ok:false} shape
  // without touching the network.
  const r = await probe("http://127.0.0.1:1/");
  ok(r.ok === false && r.status === 0 && r.ms >= 0, "probe: dead endpoint reports down, not thrown");
}

// --- no private data may ship ----------------------------------------------
import { readFileSync, existsSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
const root = join(dirname(fileURLToPath(import.meta.url)), "../../vercel");
ok(!existsSync(join(root, "api/ops.js")), "no /api/ops handler (token path removed)");
ok(!existsSync(join(root, "ops.html")), "no ops page shipping private data");
const pub = readFileSync(join(root, "index.html"), "utf8");
ok(!/edge.?config|vercel_token|ops_basic/i.test(pub), "index.html references no gated store/token");

process.exit(fail);
