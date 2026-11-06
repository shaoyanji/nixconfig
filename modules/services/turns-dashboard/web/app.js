// The live log: one EventSource, one tiny frame parser, no framework. The
// server speaks a text protocol it also prints in its own source, so the client
// and the writer cannot drift without one of them reading wrong.

const log = document.getElementById("log");
const EDGE = 4;

// --- wire ------------------------------------------------------------------
// A frame is `selector <css>`, `mode <inner|outer|prepend|append|remove>` and
// zero or more `elements <html>` lines; the frame ends with a blank line.
function frameFrom(block) {
  const data = {mode: "inner", elements: ""};
  const elements = [];
  for (const line of block.split("\n")) {
    if (!line || line.startsWith(":")) continue;
    const colon = line.indexOf(":");
    if (colon < 0) continue;
    const field = line.slice(0, colon);
    let value = line.slice(colon + 1);
    if (value.startsWith(" ")) value = value.slice(1);
    if (field !== "data") continue;
    const space = value.indexOf(" ");
    const key = space < 0 ? value : value.slice(0, space);
    const rest = space < 0 ? "" : value.slice(space + 1);
    if (key === "elements") elements.push(rest);
    else data[key] = rest;
  }
  if (elements.length) data.elements = elements.join("\n");
  return data;
}

function applyPatch(data) {
  if (!data.selector) return;
  const target = document.querySelector(data.selector);
  if (!target) return;
  if (data.mode === "remove") {
    target.remove();
    return;
  }
  const tpl = document.createElement("template");
  tpl.innerHTML = data.elements;
  const nodes = tpl.content;
  if (data.mode === "inner") target.replaceChildren(nodes);
  else if (data.mode === "outer" || data.mode === "replace") target.replaceWith(nodes);
  else if (data.mode === "prepend") target.prepend(nodes);
  else target.append(nodes);
}

// A fetch body and an EventSource carry the same frames, so one reader serves
// the log stream and a prompt's answer.
function reader(onFrame) {
  let buffer = "";
  return (chunk) => {
    buffer += chunk;
    let cut;
    while ((cut = buffer.indexOf("\n\n")) >= 0) {
      onFrame(frameFrom(buffer.slice(0, cut)));
      buffer = buffer.slice(cut + 2);
    }
  };
}

const es = new EventSource("/api/stream");
es.onmessage = (event) => applyPatch(frameFrom(event.data));
es.addEventListener("patch", (event) => applyPatch(frameFrom(event.data)));
es.onerror = () => {
  log.dataset.state = "retrying";
};

// --- prompts ---------------------------------------------------------------
async function ask(row, prompt) {
  const box = document.getElementById(`req-${row}`);
  if (box) box.textContent = "▸ dispatched";
  const res = await fetch("/api/prompt", {
    method: "POST",
    headers: {"Content-Type": "application/json"},
    body: JSON.stringify({row, prompt}),
  });
  if (!res.ok || !res.body) {
    if (box) box.textContent = await res.text();
    return;
  }
  const read = reader(applyPatch);
  const decoder = new TextDecoder();
  for await (const chunk of res.body) read(decoder.decode(chunk, {stream: true}));
}

log.addEventListener("click", (event) => {
  const button = event.target.closest("button[data-prompt-for]");
  if (!button) return;
  const row = button.dataset.promptFor;
  const field = document.getElementById(`p-${row}`);
  const prompt = field ? field.value.trim() : "";
  if (!prompt) return;
  field.value = "";
  field.style.height = "auto";
  ask(row, prompt);
});

log.addEventListener("keydown", (event) => {
  if (event.key !== "Enter" || !(event.metaKey || event.ctrlKey)) return;
  const field = event.target;
  if (field.tagName !== "TEXTAREA") return;
  const row = field.id.replace(/^p-/, "");
  const prompt = field.value.trim();
  if (!prompt) return;
  field.value = "";
  field.style.height = "auto";
  ask(row, prompt);
});

// --- reading ---------------------------------------------------------------
// The log is a wheel, not a document: the ends of the list wrap into each
// other, so a reader never reaches a scrollbar or a dead stop.
log.addEventListener(
  "wheel",
  (event) => {
    const atBottom = log.scrollTop + log.clientHeight >= log.scrollHeight - EDGE;
    const atTop = log.scrollTop <= EDGE;
    const out = (event.deltaY > 0 && atBottom) || (event.deltaY < 0 && atTop);
    if (!out) return;
    event.preventDefault();
    log.scrollTo({top: event.deltaY > 0 ? 0 : log.scrollHeight, behavior: "auto"});
  },
  {passive: false},
);

addEventListener("keydown", (event) => {
  const typing = /^(INPUT|TEXTAREA)$/.test(document.activeElement?.tagName ?? "");
  if (typing) return;
  if (event.key === "/" || event.key === "Home") {
    event.preventDefault();
    log.scrollTo({top: 0, behavior: "smooth"});
  }
});

// A textarea is one line until it has something to say.
log.addEventListener("input", (event) => {
  const el = event.target;
  if (el.tagName !== "TEXTAREA") return;
  el.style.height = "auto";
  el.style.height = `${Math.min(el.scrollHeight, 112)}px`;
});
