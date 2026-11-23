// Gated ops feed. The sentinel status.json snapshots live in an Edge Config
// store (items keyed `status:<host>`), pushed by scripts/task/vercel-publish.sh
// on frieren. Two env vars, both required — an unset gate fails closed:
//
//   OPS_BASIC_AUTH  "user:pass" — the credentials a viewer must present
//   EDGE_CONFIG     the store's connection string (Vercel sets it when an
//                   Edge Config is linked to the project)
//
// The page shell at /ops is intentionally public — it carries no data. All
// private material crosses exactly this function, behind the basic-auth check.
const REALM = 'Basic realm="fleet-ops", charset="UTF-8"';

function credentials(header) {
  if (typeof header !== "string" || !header.startsWith("Basic ")) return null;
  try {
    return atob(header.slice(6));
  } catch {
    return null;
  }
}

export function authorized(header, expected) {
  const got = credentials(header);
  return got !== null && got === expected;
}

export default async function handler(req, res) {
  if (req.method !== "GET") {
    res.status(405).json({ error: "method not allowed" });
    return;
  }
  const expected = process.env.OPS_BASIC_AUTH;
  const edgeConfig = process.env.EDGE_CONFIG;
  if (!expected || !edgeConfig) {
    res.status(503).json({ error: "ops feed not configured" });
    return;
  }
  if (!authorized(req.headers?.authorization, expected)) {
    res.setHeader("WWW-Authenticate", REALM);
    res.status(401).json({ error: "authentication required" });
    return;
  }
  try {
    const r = await fetch(`${edgeConfig}/items`, { signal: AbortSignal.timeout(5000) });
    if (!r.ok) throw new Error(`edge config ${r.status}`);
    const items = await r.json();
    const hosts = {};
    for (const item of items) {
      if (typeof item.key === "string" && item.key.startsWith("status:")) {
        hosts[item.key.slice(7)] = item.value;
      }
    }
    res.status(200).json({ ts: new Date().toISOString(), hosts });
  } catch (e) {
    res.status(502).json({ error: `edge config read failed: ${e.message}` });
  }
}
