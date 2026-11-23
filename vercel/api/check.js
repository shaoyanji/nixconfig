// Public-surface probe. GET /api/check → every target; GET /api/check?name=<id>
// → one. The allowlist is the privacy boundary: no caller-chosen URLs, so this
// cannot be turned into an open proxy.
export const TARGETS = {
  cv: { label: "matt.bountystash.com", url: "https://matt.bountystash.com/" },
  mockup: { label: "concept.bountystash.com", url: "https://concept.bountystash.com/" },
  gallery: { label: "bountystash-assets", url: "https://bountystash-assets.pages.dev/manifest.json" },
  docs: { label: "docs (github pages)", url: "https://shaoyanji.github.io/nixconfig/" },
  dragoncourt: { label: "dragoncourt.alwaysdata.net", url: "https://dragoncourt.alwaysdata.net/" },
  neocities: { label: "dragoncourt.neocities.org", url: "https://dragoncourt.neocities.org/" },
  envs: { label: "jisifu.envs.net", url: "https://jisifu.envs.net/" },
};

export async function probe(url) {
  const t0 = Date.now();
  try {
    const res = await fetch(url, {
      method: "GET",
      redirect: "follow",
      signal: AbortSignal.timeout(6000),
      headers: { "user-agent": "fleet-status-probe/1" },
    });
    return { ok: res.status < 400, status: res.status, ms: Date.now() - t0 };
  } catch {
    return { ok: false, status: 0, ms: Date.now() - t0 };
  }
}

export default async function handler(req, res) {
  if (req.method !== "GET") {
    res.status(405).json({ error: "method not allowed" });
    return;
  }
  const name = req.query?.name;
  if (name !== undefined && name !== null && !(name in TARGETS)) {
    res.status(400).json({ error: "unknown target", targets: Object.keys(TARGETS) });
    return;
  }
  const picked = name ? { [name]: TARGETS[name] } : TARGETS;
  const rows = await Promise.all(
    Object.entries(picked).map(async ([id, t]) => ({
      id,
      label: t.label,
      url: t.url,
      ...(await probe(t.url)),
    })),
  );
  res.status(200).json({ ts: new Date().toISOString(), rows });
}
