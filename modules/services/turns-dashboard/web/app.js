// The live log: one EventSource, one tiny frame parser, no framework. The
// server speaks a text protocol it also prints in its own source, so the client
// and the writer cannot drift without one of them reading wrong.

const log = document.getElementById("log");
const find = document.getElementById("find");
const count = document.getElementById("count");
const nomatch = document.getElementById("nomatch");
const toasts = document.getElementById("toasts");
// The history frame is `mode inner` on #log, which replaces every child —
// including this anchor. It is held here so the jump-to-top link keeps a real,
// native anchor target (`href="#top"`) after the first frame arrives.
const topAnchor = document.getElementById("top");
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

// --- cards -----------------------------------------------------------------
// The server owns the markup; these helpers only read it.
const cards = () => [...log.querySelectorAll("article.turn")];
const visible = () => cards().filter((c) => !c.hidden);

function haystack(card) {
  const parts = [".out", ".src", ".when", ".subject", ".action", ".why", ".meta"].map(
    (sel) => card.querySelector(sel)?.textContent ?? "",
  );
  return parts.join(" ").replace(/\s+/g, " ").toLowerCase();
}

// Every token has to land inside one word: an exact run first, then a
// subsequence ("trn" finds "turn") for tokens long enough to mean something.
// A subsequence across the WHOLE card is not a finder — "umami" matches any
// turn whose prose happens to contain u, m, a, m, i in order, which is most of
// them (measured: 40/40). Returns -1 for no match, 0 for an empty needle.
function subsequence(needle, word) {
  let i = 0;
  let run = 0;
  let score = 0;
  for (let h = 0; h < word.length && i < needle.length; h++) {
    if (word[h] !== needle[i]) {
      run = 0;
      continue;
    }
    score += 2 + run * 2;
    i += 1;
    run += 1;
  }
  return i === needle.length ? score : -1;
}

function fuzzy(needle, hay) {
  const tokens = needle.trim().split(/\s+/).filter(Boolean);
  if (!tokens.length) return 0;
  const words = hay.split(/[^a-z0-9]+/).filter(Boolean);
  let score = 0;
  for (const token of tokens) {
    let best = -1;
    for (const word of words) {
      const at = word.indexOf(token);
      if (at >= 0) {
        best = Math.max(best, 60 - Math.min(at, 40) + token.length * 4);
        continue;
      }
      if (token.length >= 3) best = Math.max(best, subsequence(token, word));
    }
    if (best < 0) return -1;
    score += best;
  }
  return score;
}

function applyFilter() {
  const q = find.value.trim().toLowerCase();
  const all = cards();
  let shown = 0;
  for (const card of all) {
    const hit = !q || fuzzy(q, (card.dataset.hay ||= haystack(card))) >= 0;
    card.hidden = !hit;
    if (hit) shown += 1;
  }
  nomatch.hidden = !(q && shown === 0);
  count.textContent = q ? `${shown}/${all.length}` : "";
  document.body.classList.toggle("filtering", Boolean(q));
}

function mark(card) {
  for (const c of cards()) c.removeAttribute("data-current");
  if (card) card.dataset.current = "1";
}

function focusCard(card) {
  card.scrollIntoView({block: "center", behavior: "smooth"});
  mark(card);
}

// Where the reader is: the last visible card whose top is above the middle of
// the viewport. A wheel that lands between two cards still has one answer.
function cursor() {
  const list = visible();
  if (!list.length) return {list, i: 0};
  const mid = log.scrollTop + log.clientHeight * 0.5;
  let i = 0;
  for (let k = 0; k < list.length; k++) if (list[k].offsetTop <= mid) i = k;
  return {list, i};
}

function jump(delta) {
  const {list, i} = cursor();
  if (!list.length) return;
  focusCard(list[Math.min(list.length - 1, Math.max(0, i + delta))]);
}

// --- toasts ----------------------------------------------------------------
// A new turn while the reader is deep in the log must not be invisible, and must
// not yank the scroll position either: announce it, let a click travel there.
function announce(card) {
  if (!toasts || !card) return;
  const node = document.createElement("button");
  node.type = "button";
  node.className = `toast ${card.querySelector(".out")?.className.split(" ").pop() ?? "done"}`;
  const src = document.createElement("span");
  src.className = "t-src";
  src.textContent = card.querySelector(".src")?.textContent ?? "";
  const subject = document.createElement("span");
  subject.className = "t-sub";
  subject.textContent = card.querySelector(".subject")?.textContent ?? "";
  const action = document.createElement("span");
  action.className = "t-act";
  action.textContent = (card.querySelector(".action")?.textContent ?? "").slice(0, 140);
  node.append(src, subject, action);

  let timer;
  const dismiss = () => {
    clearTimeout(timer);
    node.classList.add("out");
    setTimeout(() => node.remove(), 220);
  };
  const hold = () => {
    clearTimeout(timer);
    timer = setTimeout(dismiss, 7000);
  };
  node.addEventListener("click", () => {
    dismiss();
    focusCard(card);
  });
  node.addEventListener("mouseenter", () => clearTimeout(timer));
  node.addEventListener("mouseleave", hold);

  toasts.prepend(node);
  while (toasts.children.length > 3) toasts.lastElementChild.remove();
  hold();
}

// --- patches ---------------------------------------------------------------
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
  if (data.mode === "inner") {
    // `replaceChildren(array)` stringifies the array — the children have to be
    // spread, and the anchor is re-attached as a node rather than as text.
    if (topAnchor && target === log) target.replaceChildren(topAnchor, ...nodes.childNodes);
    else target.replaceChildren(nodes);
    return;
  }
  if (data.mode === "outer" || data.mode === "replace") {
    target.replaceWith(nodes);
    return;
  }
  if (data.mode === "prepend") {
    // Newest on top, but `#top` stays first so the header link keeps a native
    // anchor target. A prepend also shifts what the reader is looking at, so the
    // scroll position is carried over by the height that was inserted.
    const before = log.scrollHeight;
    const prev = log.scrollTop;
    const fresh = [...nodes.querySelectorAll("article.turn")];
    target.insertBefore(nodes, topAnchor ? topAnchor.nextSibling : target.firstChild);
    if (prev > EDGE) log.scrollTop = prev + (log.scrollHeight - before);
    for (const card of fresh) announce(card);
    applyFilter();
    return;
  }
  target.append(nodes);
  applyFilter();
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
const es = new EventSource("api/stream");
es.onopen = () => streamState("live");
const onPayload = (payload) => {
  streamState("live");
  applyPatch(fields(payload));
};
es.onmessage = (event) => onPayload(event.data);
es.addEventListener("patch", (event) => onPayload(event.data));
es.onerror = () => streamState("retrying");

// --- finder ----------------------------------------------------------------
function clearFind() {
  find.value = "";
  applyFilter();
  find.blur();
  mark(visible()[0] ?? null);
}

find.addEventListener("input", applyFilter);
find.addEventListener("keydown", (event) => {
  if (event.key === "Escape") {
    event.stopPropagation();
    clearFind();
  }
  if (event.key === "Enter") {
    const hit = visible()[0];
    if (hit) {
      event.preventDefault();
      focusCard(hit);
      find.blur();
    }
  }
});

// Instant, not smooth: a reader who asks for the top of a 40-card log wants the
// top, not a four-second tour through every snap point on the way.
document.getElementById("totop").addEventListener("click", (event) => {
  event.preventDefault();
  log.scrollTo({top: 0, behavior: "auto"});
  mark(cards()[0] ?? null);
});

// --- movement --------------------------------------------------------------
const typing = (el) =>
  el && (el.tagName === "TEXTAREA" || el.tagName === "INPUT" || el.isContentEditable);

addEventListener("keydown", (event) => {
  if (event.metaKey || event.ctrlKey || event.altKey) return;
  const el = document.activeElement;
  if (typing(el)) {
    if (event.key === "Escape" && el.tagName === "TEXTAREA") el.blur();
    return;
  }
  switch (event.key) {
    case "j":
      event.preventDefault();
      jump(1);
      break;
    case "k":
      event.preventDefault();
      jump(-1);
      break;
    case "g":
      event.preventDefault();
      log.scrollTo({top: 0, behavior: "auto"});
      mark(cards()[0] ?? null);
      break;
    case "G":
      event.preventDefault();
      log.scrollTo({top: log.scrollHeight, behavior: "auto"});
      break;
    case "/":
      event.preventDefault();
      find.focus();
      find.select();
      break;
    case "Escape":
      if (find.value) {
        event.preventDefault();
        clearFind();
      }
      break;
    case "ArrowDown":
      if (event.shiftKey) {
        event.preventDefault();
        jump(1);
      }
      break;
    case "ArrowUp":
      if (event.shiftKey) {
        event.preventDefault();
        jump(-1);
      }
      break;
    default:
      break;
  }
});

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

// A textarea is one line until it has something to say.
log.addEventListener("input", (event) => {
  const el = event.target;
  if (el.tagName !== "TEXTAREA") return;
  el.style.height = "auto";
  el.style.height = `${Math.min(el.scrollHeight, 112)}px`;
});
