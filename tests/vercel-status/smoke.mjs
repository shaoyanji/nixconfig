// Smoke test for vercel/api/*.js — exercised directly by run.sh via node.
// Prints "ok <case>" / "FAIL <case>"; exit 1 on any failure, 2 on bad env.
import { TARGETS, probe, default as check } from "../../vercel/api/check.js";
import { authorized, default as ops } from "../../vercel/api/ops.js";

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
const basic = (s) => "Basic " + Buffer.from(s).toString("base64");

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

// --- ops.js: the gate must fail closed -------------------------------------
ok(authorized(basic("u:p"), "u:p") === true, "auth: matching creds pass");
ok(authorized(basic("u:wrong"), "u:p") === false, "auth: wrong pass refused");
ok(authorized("Bearer x", "u:p") === false, "auth: non-basic scheme refused");
ok(authorized(undefined, "u:p") === false, "auth: missing header refused");

{
  delete process.env.OPS_BASIC_AUTH;
  delete process.env.EDGE_CONFIG;
  const res = mkRes();
  await ops({ method: "GET", headers: { authorization: basic("u:p") } }, res);
  ok(res._s === 503, "ops: unconfigured env fails closed with 503");
}
{
  process.env.OPS_BASIC_AUTH = "u:p";
  process.env.EDGE_CONFIG = "https://127.0.0.1:1/ecfg_x";
  let res = mkRes();
  await ops({ method: "GET", headers: {} }, res);
  ok(res._s === 401 && "www-authenticate" in res._h, "ops: missing creds get 401 + challenge");
  res = mkRes();
  await ops({ method: "GET", headers: { authorization: basic("u:no") } }, res);
  ok(res._s === 401, "ops: wrong creds get 401");
  res = mkRes();
  await ops({ method: "GET", headers: { authorization: basic("u:p") } }, res);
  ok(res._s === 502, "ops: right creds reach the store read (dead store → 502)");
  res = mkRes();
  await ops({ method: "POST", headers: {} }, res);
  ok(res._s === 405, "ops: POST refused with 405");
}

process.exit(fail);
