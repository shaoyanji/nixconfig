package main

import "net/http"

const uiPage = `<!doctype html>
<html><head><meta charset="utf-8"><title>inventory-site</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
 body{font:15px/1.45 system-ui;margin:2rem auto;max-width:64rem;padding:0 1rem;background:#14181d;color:#dde}
 input,select,button{font:inherit;padding:.35rem .5rem;background:#1e262e;color:#dde;border:1px solid #3a4652;border-radius:4px}
 table{border-collapse:collapse;width:100%;margin-top:1rem}
 td,th{padding:.3rem .5rem;border-bottom:1px solid #2a343e;text-align:left}
 a{color:#7db8ff}
 form{margin:.4rem 0}
 h1{font-size:1.3rem}
 .tag{background:#233242;border-radius:3px;padding:0 .3rem;margin-right:.25rem;font-size:.85em}
 .bar{display:flex;gap:.5rem;flex-wrap:wrap;align-items:center}
</style></head><body>
<h1>inventory-site</h1>
<div class="bar">
 <form id="search"><input name="q" placeholder="search (FTS5)" autofocus><button>search</button></form>
 <select id="floc"><option value="">location…</option></select>
 <select id="fcat"><option value="">category…</option></select>
 <select id="ftag"><option value="">tag…</option></select>
 <a href="/">reset</a> ·
 <a href="/api/export/json">json</a> · <a href="/api/export/csv">csv</a>
</div>
<form id="add" class="bar">
 <input name="name" placeholder="name" required>
 <input name="location" placeholder="location">
 <input name="category" placeholder="category">
 <input name="serial" placeholder="serial">
 <input name="value" placeholder="value 49,99" style="width:7rem">
 <input name="tags" placeholder="tags a,b">
 <button>add</button>
</form>
<table id="out"><tr><th>name</th><th>location</th><th>category</th><th>serial</th><th>value</th><th>warranty</th><th>tags</th></tr></table>
<script>
const fmt = c => c ? (c/100).toFixed(2) + " €" : "";
function params(){
  const p = new URLSearchParams();
  const q = document.querySelector("#search input").value;
  const l = document.getElementById("floc").value, c = document.getElementById("fcat").value, t = document.getElementById("ftag").value;
  if (q) p.set("q", q); if (l) p.set("location", l); if (c) p.set("category", c); if (t) p.set("tag", t);
  return p.toString();
}
async function load(){
  const r = await fetch("/api/items?" + params());
  const j = await r.json();
  const t = document.getElementById("out");
  t.innerHTML = "<tr><th>name</th><th>location</th><th>category</th><th>serial</th><th>value</th><th>warranty</th><th>tags</th></tr>";
  for (const it of j.items){
    const tr = t.insertRow();
    tr.insertCell().textContent = it.name;
    tr.insertCell().textContent = it.location;
    tr.insertCell().textContent = it.category;
    tr.insertCell().textContent = it.serial;
    tr.insertCell().textContent = fmt(it.value_cents);
    tr.insertCell().textContent = (it.warranty_until||"").slice(0,10);
    tr.insertCell().innerHTML = (it.tags||[]).map(x=>'<span class="tag">'+x+'</span>').join("");
  }
}
async function loadFacets(){
  const j = await (await fetch("/api/facets")).json();
  const fill = (id, xs) => { const s = document.getElementById(id); for (const x of xs){ const o = document.createElement("option"); o.value = o.textContent = x; s.appendChild(o); } };
  fill("floc", j.locations); fill("fcat", j.categories); fill("ftag", j.tags);
}
document.getElementById("search").onsubmit = e => { e.preventDefault(); load(); };
for (const id of ["floc","fcat","ftag"]) document.getElementById(id).onchange = load;
document.getElementById("add").onsubmit = async e => {
  e.preventDefault();
  const f = e.target;
  const cents = Math.round(parseFloat((f.value.value||"0").replace(",","."))*100) || 0;
  const tags = f.tags.value ? f.tags.value.split(",").map(x=>x.trim()).filter(Boolean) : [];
  await fetch("/api/items", {method:"POST", body: JSON.stringify({name: f.name.value, location: f.location.value, category: f.category.value, serial: f.serial.value, value_cents: cents, tags})});
  f.reset(); load(); loadFacets();
};
load(); loadFacets();
</script></body></html>`

func (s *server) handleUI(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.Write([]byte(uiPage))
}
