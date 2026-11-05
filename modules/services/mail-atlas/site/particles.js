// The qi field. WebAssembly simulates; this file only paints — and it is the
// one place the search reaches into the field: `react()` raises the current,
// turns it gold when the query comes back empty, and sends a ripple through it
// from wherever the query was typed.
//
// The offsets mirror particles.wat: 64 = x, 4160 = y, 8256 = vx, 12352 = vy,
// and index 0 of the Float32 view is the count. If the WAT layout changes, both
// sides change together — that is the whole coupling.
const X = 16; // 64 bytes / 4
const Y = 1040; // 4160 / 4
const VX = 2064; // 8256 / 4
const VY = 3088; // 12352 / 4

const JADE = [46, 230, 214];
const GOLD = [232, 192, 122];

const mix = (a, b, t) => [
  Math.round(a[0] + (b[0] - a[0]) * t),
  Math.round(a[1] + (b[1] - a[1]) * t),
  Math.round(a[2] + (b[2] - a[2]) * t),
];

export async function startQiField(canvas) {
  const ctx = canvas.getContext("2d", { alpha: true });
  const still = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  const noop = { burst() {}, inhale() {}, react() {}, caret() {} };
  if (!ctx) return noop;

  let sim = null;
  let view = null;
  let count = 0;
  let width = 0;
  let height = 0;
  let last = performance.now();
  let elapsed = 0;
  let running = true;
  const dpr = Math.min(window.devicePixelRatio || 1, 1.75);

  // The three channels the page writes, and the simulation feels.
  let amp = 1;
  let ampTarget = 1;
  let swirl = 0;
  let swirlTarget = 0;
  let tint = 0;
  let tintTarget = 0;
  let state = "idle";
  const rings = [];

  try {
    const response = await fetch("/particles.wasm");
    if (!response.ok) throw new Error(`wasm ${response.status}`);
    const { instance } = await WebAssembly.instantiate(await response.arrayBuffer(), {});
    sim = instance.exports;
    view = new Float32Array(sim.memory.buffer);
  } catch (err) {
    // No WASM, no field. The page is still a working archive.
    console.warn("qi field unavailable:", err);
    canvas.style.display = "none";
    return noop;
  }

  function resize() {
    width = window.innerWidth;
    height = window.innerHeight;
    canvas.width = Math.floor(width * dpr);
    canvas.height = Math.floor(height * dpr);
    canvas.style.width = `${width}px`;
    canvas.style.height = `${height}px`;
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    const target = Math.max(180, Math.min(1024, Math.round((width * height) / 1700)));
    count = target;
    sim.init(target, (Date.now() & 0x7fffffff) || 1, width, height);
    view = new Float32Array(sim.memory.buffer);
    draw();
  }

  function note(value) {
    state = value;
    canvas.dataset.state = value;
  }

  // One path per colour/alpha bucket instead of one per particle: the field
  // stays cheap enough to sit behind a page someone is reading mail on.
  function draw() {
    ctx.clearRect(0, 0, width, height);
    const breath = 0.86 + 0.14 * Math.sin(elapsed * 0.7);
    const gold = mix(JADE, GOLD, tint);
    const buckets = new Map();

    for (let i = 0; i < count; i++) {
      const x = view[X + i];
      const y = view[Y + i];
      const vx = view[VX + i];
      const vy = view[VY + i];
      const speed = Math.min(Math.hypot(vx, vy), 3.2);
      const veil = 1 - 0.36 * (y / Math.max(height, 1));
      const hot = (i * 7) % 17 === 0;
      const hue = hot ? mix(gold, GOLD, 0.65) : gold;
      const a = Math.min(0.9, (0.26 + speed * 0.65) * veil * breath) * (hot ? 1.45 : 1);
      const key = `${hue.join(",")}|${Math.round(a * 14)}`;
      let bucket = buckets.get(key);
      if (!bucket) {
        bucket = { hue, alpha: Math.min(0.92, a), streak: [], motes: [] };
        buckets.set(key, bucket);
      }
      // The tail is a fraction of a second of travel, capped: a frame count
      // that grows with speed turns a fast particle into a line across the
      // page, which is what a 6 px/frame velocity did to this field.
      const tail = Math.min(12, 6 + speed * 6);
      (hot ? bucket.motes : bucket.streak).push([x, y, vx, vy, tail]);
    }

    ctx.globalCompositeOperation = "lighter";
    for (const bucket of buckets.values()) {
      const [r, g, b] = bucket.hue;
      ctx.strokeStyle = `rgba(${r}, ${g}, ${b}, ${bucket.alpha.toFixed(3)})`;
      ctx.lineWidth = 1.05;
      ctx.beginPath();
      for (const [x, y, vx, vy, tail] of bucket.streak) {
        ctx.moveTo(x - vx * tail, y - vy * tail);
        ctx.lineTo(x, y);
      }
      ctx.stroke();

      if (bucket.motes.length) {
        ctx.shadowColor = `rgba(${r}, ${g}, ${b}, 0.8)`;
        ctx.shadowBlur = 8;
        ctx.fillStyle = `rgba(${r}, ${g}, ${b}, ${Math.min(0.9, bucket.alpha * 1.2).toFixed(3)})`;
        for (const [x, y] of bucket.motes) {
          ctx.beginPath();
          ctx.arc(x, y, 1.45, 0, 6.283185);
          ctx.fill();
        }
        ctx.shadowBlur = 0;
      }
    }

    // The ripple a query leaves: three rings that widen and fade. Painted here
    // rather than in the simulation because they are light, not matter.
    for (let i = rings.length - 1; i >= 0; i--) {
      const ring = rings[i];
      const age = (performance.now() - ring.at) / 1000;
      if (age > 1.6) {
        rings.splice(i, 1);
        continue;
      }
      const radius = 8 + age * 420;
      const alpha = Math.max(0, 0.3 * (1 - age / 1.6));
      ctx.strokeStyle = `rgba(${gold[0]}, ${gold[1]}, ${gold[2]}, ${alpha.toFixed(3)})`;
      ctx.lineWidth = 1.1;
      ctx.beginPath();
      ctx.arc(ring.x, ring.y, radius, 0, 6.283185);
      ctx.stroke();
    }
    ctx.globalCompositeOperation = "source-over";
  }

  function frame(now) {
    const dt = Math.min((now - last) / 1000, 0.05);
    last = now;
    elapsed += dt;

    // Decay toward rest, and paint what the simulation did.
    ampTarget += (1 - ampTarget) * Math.min(1, dt * 0.9);
    swirlTarget += (0 - swirlTarget) * Math.min(1, dt * 0.7);
    tintTarget += (0 - tintTarget) * Math.min(1, dt * 0.5);
    amp += (ampTarget - amp) * Math.min(1, dt * 7);
    swirl += (swirlTarget - swirl) * Math.min(1, dt * 5);
    tint += (tintTarget - tint) * Math.min(1, dt * 3);
    sim.mood(amp, swirl);
    sim.step(dt, elapsed, width, height);
    draw();

    if (running && !still) requestAnimationFrame(frame);
    else if (still) running = false;
  }

  resize();
  window.addEventListener("resize", () => {
    resize();
  });
  document.addEventListener("visibilitychange", () => {
    running = !document.hidden;
    if (running && !still) {
      last = performance.now();
      requestAnimationFrame(frame);
    }
  });
  note("idle");
  if (still) {
    // Reduced motion: one still field, no loop, no ripples.
    sim.step(0.016, 1, width, height);
    draw();
  } else {
    requestAnimationFrame(frame);
  }

  return {
    burst(x, y, strength = 9000) {
      if (sim) sim.burst(x, y, strength);
    },
    // The inhale: a query landed, so the sea draws toward it, then releases.
    inhale(x, y) {
      if (!sim) return;
      sim.burst(x, y, -26000);
      rings.push({ x, y, at: performance.now() });
      setTimeout(() => sim && sim.burst(x, y, 13000), 220);
      note("listening");
    },
    // Every keystroke: a light ripple, no state change.
    caret(x, y) {
      if (!sim) return;
      sim.burst(x, y, 2400);
    },
    // The search result, as a feeling: more hits, more current; no hits, gold
    // and slow. `hits` is null while a query is in flight.
    react({ hits = 0, ms = 0 } = {}) {
      if (!sim) return;
      if (hits == null) {
        ampTarget = 1.6;
        swirlTarget = 0.012;
        tintTarget = 0.25;
        note("seeking");
        return;
      }
      const energy = Math.log2(1 + hits) / 5.4;
      ampTarget = 1 + Math.min(2.4, energy * 2.4);
      swirlTarget = Math.min(0.03, energy * 0.05) * (ms > 40 ? -1 : 1);
      tintTarget = hits === 0 ? 0.9 : Math.max(0, 0.5 - hits / 40);
      note(hits === 0 ? "void" : "found");
      canvas.dataset.hits = String(hits);
    },
  };
}
