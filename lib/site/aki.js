(() => {
  function pollTelemetry() {
    // A background tab has no reader: poll on return instead of every 30 s.
    if (document.hidden) return;
    fetch('data/live.json', {cache: 'no-store'})
      .then(r => r.json())
      .then(d => {
        const el = document.getElementById('live-status-badge');
        if (el && d.uptime) {
          // textContent: the badge shows telemetry, and a hostname is data.
          el.textContent = "🟢 " + d.hostname + ": " + d.uptime + " (Gen " + d.generation + ", load " + d.load + ")";
        }
      })
      .catch(() => {});
  }

  document.addEventListener('DOMContentLoaded', pollTelemetry);
  document.addEventListener('visibilitychange', () => { if (!document.hidden) pollTelemetry(); });
  setInterval(pollTelemetry, 30000);

  document.addEventListener('click', (e) => {
    const el = e.target.closest('[url][fn="onclick"], [url]:not([fn])');
    if (!el) return;
    const url = el.getAttribute('url');
    if (!url) return;
    e.preventDefault();
    document.querySelectorAll('.nav-active').forEach(n => n.classList.remove('nav-active'));
    el.classList.add('nav-active');
    // Slices are regenerated per deploy; a cached copy would show the last build.
    fetch(url, {cache: 'no-store'})
      .then(r => r.json())
      .then(data => {
        Object.entries(data).forEach(([sel, props]) => {
          const target = document.querySelector(sel);
          if (target) Object.assign(target, props);
        });
        pollTelemetry();
        // Slices that own imperative widgets (the knowledge-graph canvas)
        // rebuild their DOM here, so they subscribe to this instead of
        // having Aki know about canvas internals.
        document.dispatchEvent(new CustomEvent('aki:applied', {detail: data}));
      })
      .catch(err => console.error("Aki transition failed:", err));
  });
})();
