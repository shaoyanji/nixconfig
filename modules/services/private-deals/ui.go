package main

import "net/http"

const uiPage = `<!doctype html>
<html><head><meta charset="utf-8"><title>private-deals</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
 body{font:15px/1.45 system-ui;margin:2rem auto;max-width:60rem;padding:0 1rem;background:#14181d;color:#dde}
 input,button{font:inherit;padding:.35rem .5rem;background:#1e262e;color:#dde;border:1px solid #3a4652;border-radius:4px}
 input{width:20rem}
 table{border-collapse:collapse;width:100%;margin-top:1rem}
 td,th{padding:.3rem .5rem;border-bottom:1px solid #2a343e;text-align:left}
 a{color:#7db8ff}
 .price{white-space:nowrap;text-align:right}
 form{margin:.4rem 0}
 h1{font-size:1.3rem}
</style></head><body>
<h1>private-deals</h1>
<form id="search"><input name="q" placeholder="search deals (FTS5)" autofocus>
<button>search</button> <a href="/">reset</a></form>
<form id="add"><input name="title" placeholder="add deal: title" style="width:14rem">
<input name="url" placeholder="url" style="width:14rem">
<input name="price" placeholder="price e.g. 49,99" style="width:9rem">
<button>add</button></form>
<table id="out"><tr><th>title</th><th>price</th><th>source</th><th>last seen</th></tr></table>
<script>
const fmt = c => c ? (c/100).toFixed(2) + " €" : "";
async function load(q){
  const r = await fetch("/api/deals" + (q ? "?q=" + encodeURIComponent(q) : ""));
  const j = await r.json();
  const t = document.getElementById("out");
  t.innerHTML = "<tr><th>title</th><th>price</th><th>source</th><th>last seen</th></tr>";
  for (const d of j.deals){
    const tr = t.insertRow();
    const a = d.url ? '<a href="'+d.url+'">'+d.title+"</a>" : d.title;
    tr.insertCell().innerHTML = a;
    tr.insertCell().textContent = fmt(d.price_cents);
    tr.insertCell().textContent = d.source;
    tr.insertCell().textContent = (d.last_seen||"").slice(0,10);
  }
}
document.getElementById("search").onsubmit = e => { e.preventDefault(); load(e.target.q.value); };
document.getElementById("add").onsubmit = async e => {
  e.preventDefault();
  const f = e.target;
  const cents = Math.round(parseFloat((f.price.value||"0").replace(",","."))*100) || 0;
  await fetch("/api/deals", {method:"POST", body: JSON.stringify({title: f.title.value, url: f.url.value, price_cents: cents})});
  f.reset(); load();
};
load((new URLSearchParams(location.search)).get("q") || "");
</script></body></html>`

func (s *server) handleUI(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.Write([]byte(uiPage))
}
