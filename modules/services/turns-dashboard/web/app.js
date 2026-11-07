// The live log: one EventSource, one tiny frame parser, no framework. The
// server speaks a text protocol it also prints in its own source, so the client
// and the writer cannot drift without one of them reading wrong.

const log = document.getElementById("log");
const EDGE = 4;

// --- wire ------------------------------------------------------------------
// A frame is `selector <css>`, `mode <inner|outer|prepend|append|remove>` and
// zero or more `elements <html>` lines. Over EventSource the browser has
// already stripped the `data:` prefixes and hands over the payload; a fetch
// body still has them, so `sseData` does that one job for the prompt reader.
function fields(payload) {
  const data = {mode: "inner", elements: ""};
  const elements = [];
  for (const line of payload.split("\n")) {
    if (!line || line.startsWith(":")) continue;
    const space = line.indexOf(" ");
    const key = space < 0 ? line : line.slice(0, space);
    const value = space < 0 ? "" : line.slice(space + 1);
    if (key === "elements") elements.push(value);
    else if (key === "selector" || key === "mode") data[key] = value;
  }
  if (elements.length) data.elements = elements.join("\n");
  return data;
}

function sseData(block) {
  const lines = [];
  for (const line of block.split("\n")) {
    if (!line.startsWith("data:")) continue;
    let value = line.slice(5);
    if (value.startsWith(" ")) value = value.slice(1);
    lines.push(value);
  }
  return lines.join("\n");
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

// One reader for both carriers: the log stream and a prompt's answer body.
function reader(onPayload) {
  let buffer = "";
  return (chunk) => {
    buffer += chunk;
    let cut;
    while ((cut = buffer.indexOf("\n\n")) >= 0) {
      onPayload(sseData(buffer.slice(0, cut)));
      buffer = buffer.slice(cut + 2);
    }
  };
}

// --- stream ----------------------------------------------------------------
// The header's dot is the stream's own state, not a decoration: a reader can
// tell a quiet log from a disconnected one without opening a console.
const pulse = document.querySelector(".pulse");
function streamState(state) {
  document.body.dataset.stream = state;
  if (pulse) pulse.dataset.state = state;
}

streamState("connecting");
// Relative on purpose: the same files are served at `/` on the tailnet mount and
// at `/turns/` on the public one, and an absolute `/api/stream` would leave the
// public page streaming from the site root instead of the dashboard.
const es = new EventSource("api/stream");
es.onopen = () => streamState("live");
const onPayload = (payload) => {
  streamState("live");
  applyPatch(fields(payload));
};
es.onmessage = (event) => onPayload(event.data);
es.addEventListener("patch", (event) => onPayload(event.data));
es.onerror = () => streamState("retrying");

// --- prompts ---------------------------------------------------------------
async function ask(row, prompt) {
  const box = document.getElementById(`req-${row}`);
  if (box) box.textContent = "▸ dispatched";
  const res = await fetch("api/prompt", {
    method: "POST",
    headers: {"Content-Type": "application/json"},
    body: JSON.stringify({row, prompt}),
  });
  if (!res.ok || !res.body) {
    if (box) box.textContent = await res.text();
    return;
  }
  const read = reader((payload) => applyPatch(fields(payload)));
  const decoder = new TextDecoder();
  for await (const chunk of res.body) read(decoder.decode(chunk, {stream: true}));
}

function send(row) {
  const field = document.getElementById(`p-${row}`);
  const prompt = field ? field.value.trim() : "";
  if (!prompt) return;
  field.value = "";
  field.style.height = "auto";
  ask(row, prompt);
}

log.addEventListener("click", (event) => {
  const button = event.target.closest("button[data-prompt-for]");
  if (button) send(button.dataset.promptFor);
});

log.addEventListener("keydown", (event) => {
  if (event.key !== "Enter" || !(event.metaKey || event.ctrlKey)) return;
  if (event.target.tagName !== "TEXTAREA") return;
  send(event.target.id.replace(/^p-/, ""));
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
