package main

import "net/http"

const uiPage = `<!doctype html>
<html><head><meta charset="utf-8"><title>job-db-scraper</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
 body{font:15px/1.45 system-ui;margin:2rem auto;max-width:64rem;padding:0 1rem;background:#14181d;color:#dde}
 input,select,button{font:inherit;padding:.35rem .5rem;background:#1e262e;color:#dde;border:1px solid #3a4652;border-radius:4px}
 table{border-collapse:collapse;width:100%;margin-top:1rem}
 td,th{padding:.3rem .5rem;border-bottom:1px solid #2a343e;text-align:left}
 a{color:#7db8ff}
 form{margin:.4rem 0}
 h1{font-size:1.3rem}
 .bar{display:flex;gap:.5rem;flex-wrap:wrap;align-items:center}
 .score{font-weight:600;text-align:right}
 .in{color:#7fe0a0}.out{color:#e07f7f}.unclear{color:#c8b96a}
 .reasons{color:#8a97a5;font-size:.85em}
</style></head><body>
<h1>job-db-scraper</h1>
<div class="bar">
 <form id="search"><input name="q" placeholder="search (FTS5)" autofocus><button>search</button></form>
 <select id="flane"><option value="">lane…</option><option>in</option><option>unclear</option><option>out</option></select>
 <select id="fscore"><option value="0">min score…</option><option value="60">60+</option><option value="70">70+</option><option value="80">80+</option><option value="90">90+</option></select>
 <a href="/">reset</a> · <span id="stats"></span>
</div>
<table id="out"><tr><th>score</th><th>lane</th><th>title</th><th>employer</th><th>location</th><th>source</th><th>last seen</th></tr></table>
<script>
function params(){
  const p = new URLSearchParams();
  const q = document.querySelector("#search input").value;
  const l = document.getElementById("flane").value, ms = document.getElementById("fscore").value;
  if (q) p.set("q", q); if (l) p.set("lane", l); if (ms && ms !== "0") p.set("min_score", ms);
  return p.toString();
}
async function load(){
  const r = await fetch("/api/postings?" + params());
  const j = await r.json();
  const t = document.getElementById("out");
  t.innerHTML = "<tr><th>score</th><th>lane</th><th>title</th><th>employer</th><th>location</th><th>source</th><th>last seen</th></tr>";
  for (const p of j.postings){
    const tr = t.insertRow();
    const sc = tr.insertCell(); sc.textContent = p.score; sc.className = "score";
    const ln = tr.insertCell(); ln.textContent = p.lane; ln.className = p.lane;
    const ti = tr.insertCell();
    ti.innerHTML = (p.url ? '<a href="'+p.url+'">'+p.title+"</a>" : p.title) +
      '<div class="reasons">'+(p.reasons||[]).join(" ")+"</div>";
    tr.insertCell().textContent = p.employer;
    tr.insertCell().textContent = p.location;
    tr.insertCell().textContent = p.source;
    tr.insertCell().textContent = (p.last_seen||"").slice(0,10);
  }
}
async function stats(){
  const j = await (await fetch("/api/stats")).json();
  document.getElementById("stats").textContent =
    Object.entries(j.lanes).map(([k,v]) => k+": "+v).join(" · ");
}
document.getElementById("search").onsubmit = e => { e.preventDefault(); load(); };
for (const id of ["flane","fscore"]) document.getElementById(id).onchange = load;
load(); stats();
</script></body></html>`

func (s *server) handleUI(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.Write([]byte(uiPage))
}
