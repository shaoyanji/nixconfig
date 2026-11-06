// The log is a wheel, not a document: the ends of the list wrap into each
// other, so a reader never reaches a scrollbar or a dead stop.
const log = document.getElementById("log");
const EDGE = 4;

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
