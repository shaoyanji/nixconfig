#!/usr/bin/env python3
"""jevdecide runner: classify inbox from envelope metadata; delete only DELETE>=0.8;
escalate to message body only when the metadata call is uncertain.

Usage: jev_inbox.py [--limit N] [--apply]
  default = report only; --apply moves confirmed DELETE ids to [Gmail]/Trash.
"""
import json, os, re, subprocess, sys, html as _html

sys.path  # no-op

def load_env():
    env = dict(os.environ)
    hp = os.path.expanduser("~/.config/hermes/hermes.env")
    if os.path.exists(hp):
        for line in open(hp, encoding="utf-8", errors="replace"):
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                k, v = line.split("=", 1)
                env.setdefault(k.strip(), v.strip().strip('"').strip("'"))
    env["TYPESAFE_API_KEY"] = env.get("TYPESAFE_API_KEY") or env.get("TYPESAFEAI_API_KEY", "")
    return env

ENV = load_env()
CRIT = "/tmp/jev_inbox_criteria.json"
CRITERIA = {
    "KEEP": "personal or human correspondence; security alerts and sign-in notices; financial statements, broker/order alerts, tax; legal or terms changes tied to a real account; receipts and shipping for goods actually ordered; job-application, recruiter, interview or ATS mail; government and admin notices; anything time-sensitive or requiring a reply",
    "DELETE": "marketing, promotional, newsletters, digests, retail sales, loyalty/hotel rewards, event or conference promo, webinar invites, job-board blasts and bulk match notifications, vendor product updates, social-media digests, breaking-news alerts",
    "REVIEW": "unclear from subject and sender alone",
}
with open(CRIT, "w", encoding="utf-8") as f:
    json.dump(CRITERIA, f, ensure_ascii=False)

# Never delete on a metadata-only DELETE if the sender/subject clearly signals critical mail.
GUARD = ["fidelity", "schwab", "sofi", "capital one", "security alert", "bewerbung",
         "application", "aptar", "join.com", "kleinanzeigen", "systemtec", "marketbridge",
         "innocharge", "trumpf", "dean&david", "rechnung", "invoice", "statement", "bank",
         "finanzamt", "deutsche bahn", "vhs", "google voice", "run failed", "verify your email"]

def run(cmd, timeout=30):
    return subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8",
                          errors="replace", env=ENV, timeout=timeout)

def jload(s):
    i = s.find("{")
    return json.loads(s[i:]) if i != -1 else {}

def classify(text):
    p = run(["jev-decide", "classify", "--provider", "typesafe", "--text", text,
             "--criteria", CRIT, "--min-probability", "0.8", "--review-label", "REVIEW"], timeout=60)
    try:
        d = jload(p.stdout)["decisions"]["category"]
        return d.get("value", "?"), float(d.get("probability") or 0)
    except Exception:
        return "ERROR", 0.0

def body_text(eid):
    try:
        j = jload(run(["himalaya", "message", "read", str(eid), "--json"], timeout=30).stdout)
        parts = j.get("parts") or []
        chunks = []
        for e in j.get("text_body") or []:
            part = parts[e] if isinstance(e, int) and 0 <= e < len(parts) else (e if isinstance(e, dict) else None)
            if isinstance(part, dict):
                b = part.get("body")
                t = (b.get("Text") or b.get("Html") or "") if isinstance(b, dict) else (b if isinstance(b, str) else "")
                if t:
                    chunks.append(t)
        t = "\n".join(chunks)
        if "<" in t and ">" in t:
            t = re.sub(r"<[^>]+>", " ", t)
        return _html.unescape(t)[:2000]
    except Exception:
        return ""

def main():
    limit = 150
    apply = False
    a = sys.argv[1:]
    if "--limit" in a:
        limit = int(a[a.index("--limit") + 1])
    apply = "--apply" in a

    out = run(["himalaya", "--json", "envelope", "list", "-s", str(limit)], timeout=60).stdout
    envs = jload(out).get("envelopes", [])

    to_delete, kept, guarded = [], [], []
    for e in envs:
        eid = e.get("id")
        subj = e.get("subject", "") or ""
        frm = e.get("from") or []
        f0 = frm[0] if frm else {}
        name = f0.get("name", "") or ""
        em = f0.get("email", "") or ""
        low = f"{subj} {name} {em}".lower()
        val, prob = classify(f"{subj} — from {name} <{em}>")
        used_body = False
        if not (val == "DELETE" and prob >= 0.8):
            b = body_text(eid)
            if b.strip():
                used_body = True
                val, prob = classify(f"{subj} — from {name} <{em}>\n\n{b}")
        if val == "DELETE" and prob >= 0.8:
            if any(g in low for g in GUARD):
                guarded.append((str(eid), subj, name, prob))
            else:
                to_delete.append((str(eid), subj, name, prob, used_body))
        else:
            kept.append((str(eid), subj, name, val, round(prob, 2), used_body))

    print(json.dumps({"scanned": len(envs), "delete": len(to_delete),
                      "guarded_kept": len(guarded), "kept_or_review": len(kept)}, indent=2))
    print("\n== DELETE ==")
    for r in to_delete:
        print(f"  {r[0]}  p={r[3]:.2f}  body={r[4]}  {r[2]} :: {r[1][:70]}")
    print("\n== GUARDED (kept despite DELETE) ==")
    for r in guarded:
        print(f"  {r[0]}  p={r[3]:.2f}  {r[2]} :: {r[1][:70]}")
    print("\n== KEPT/REVIEW ==")
    for r in kept:
        print(f"  {r[0]}  {r[3]} p={r[4]}  body={r[5]}  {r[2]} :: {r[1][:60]}")

    if apply and to_delete:
        ids = [r[0] for r in to_delete]
        p = run(["himalaya", "message", "move", "--to", "[Gmail]/Trash"] + ids, timeout=120)
        print("\nMOVE:", (p.stdout + p.stderr).strip()[-200:])

if __name__ == "__main__":
    main()
