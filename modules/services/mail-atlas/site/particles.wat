;; The qi field: a particle system simulated in WebAssembly, painted by a 2D
;; canvas. The simulation is genuinely here (positions, velocities, a flow field
;; and a ripple impulse), not in JavaScript — the page only reads the shared
;; buffer and draws.
;;
;; Memory is one page and the array offsets are constants, so the JS side needs
;; no negotiation: 64 = x, 4160 = y, 8256 = vx, 12352 = vy, 1024 particles max.
;; Address 0 holds the particle count.
;;
;; `mood(amp, swirl)` is the coupling to the search: the page raises the field's
;; amplitude and twist when a query lands, and lets it decay. The simulation
;; never learns what the query was — it only feels how much the sea is moving.
;;
;; Core WASM has no sin/cos, so a Bhaskara-style polynomial with range reduction
;; is the flow field's whole transcendental cost.
(module
  (memory (export "memory") 1)
  (global $seed (mut i32) (i32.const 1))
  (global $n (mut i32) (i32.const 0))
  (global $amp (mut f32) (f32.const 1.0))
  (global $swirl (mut f32) (f32.const 0.0))

  (func $rand (result f32)
    (global.set $seed
      (i32.add
        (i32.mul (global.get $seed) (i32.const 1664525))
        (i32.const 1013904223)))
    (f32.div
      (f32.convert_i32_u (i32.shr_u (global.get $seed) (i32.const 8)))
      (f32.const 16777216.0)))

  (func $sin (param $x f32) (result f32)
    (local $r f32)
    (local $r2 f32)
    (local.set $r
      (f32.sub
        (local.get $x)
        (f32.mul
          (f32.const 6.2831853)
          (f32.nearest (f32.div (local.get $x) (f32.const 6.2831853))))))
    (local.set $r2 (f32.mul (local.get $r) (local.get $r)))
    (f32.mul
      (local.get $r)
      (f32.add
        (f32.const 1.0)
        (f32.add
          (f32.mul (local.get $r2) (f32.const -0.16666667))
          (f32.mul
            (f32.mul (local.get $r2) (local.get $r2))
            (f32.const 0.008333333))))))

  (func $cos (param $x f32) (result f32)
    (call $sin (f32.add (local.get $x) (f32.const 1.5707964))))

  (func (export "init") (param $n i32) (param $seed i32) (param $w f32) (param $h f32)
    (local $i i32)
    (local $a i32)
    (if (i32.gt_u (local.get $n) (i32.const 1024))
      (then (local.set $n (i32.const 1024))))
    (global.set $n (local.get $n))
    (global.set $seed (local.get $seed))
    (i32.store (i32.const 0) (local.get $n))
    (block $done
      (loop $loop
        (br_if $done (i32.ge_u (local.get $i) (global.get $n)))
        (local.set $a (i32.mul (local.get $i) (i32.const 4)))
        (f32.store
          (i32.add (i32.const 64) (local.get $a))
          (f32.mul (call $rand) (local.get $w)))
        (f32.store
          (i32.add (i32.const 4160) (local.get $a))
          (f32.mul (call $rand) (local.get $h)))
        (f32.store
          (i32.add (i32.const 8256) (local.get $a))
          (f32.mul (f32.sub (call $rand) (f32.const 0.5)) (f32.const 0.6)))
        (f32.store
          (i32.add (i32.const 12352) (local.get $a))
          (f32.mul (f32.sub (call $rand) (f32.const 0.5)) (f32.const 0.6)))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $loop))))

  ;; The only channel from the page into the simulation: how hard the current
  ;; pushes and how much it twists. Clamped, because a runaway amp turns the
  ;; field into noise and a runaway swirl into a blender.
  (func (export "mood") (param $amp f32) (param $swirl f32)
    (global.set $amp (f32.max (f32.const 0.25) (f32.min (f32.const 4.0) (local.get $amp))))
    (global.set $swirl (f32.max (f32.const -0.05) (f32.min (f32.const 0.05) (local.get $swirl)))))

  (func (export "step") (param $dt f32) (param $t f32) (param $w f32) (param $h f32)
    (local $i i32)
    (local $a i32)
    (local $x f32)
    (local $y f32)
    (local $vx f32)
    (local $vy f32)
    (local $vx0 f32)
    (local $k f32)
    (local $push f32)
    (local $twist f32)
    (local.set $k (f32.mul (f32.min (local.get $dt) (f32.const 0.05)) (f32.const 60.0)))
    ;; The equilibrium speed is push/(1-0.988) times mean|sin| = 2/pi, so this
    ;; constant *is* the field's drift: ~0.55 px per frame at rest (~33 px/s)
    ;; and ~1.9 under a query. The 0.075 it once held moved particles six pixels
    ;; per frame — a blur, and every tail drawn from a frame count became a
    ;; scratch 300-1000 px long across the whole page.
    (local.set $push (f32.mul (f32.mul (local.get $k) (f32.const 0.0105)) (global.get $amp)))
    (local.set $twist (f32.mul (global.get $swirl) (local.get $k)))
    (block $done
      (loop $loop
        (br_if $done (i32.ge_u (local.get $i) (global.get $n)))
        (local.set $a (i32.mul (local.get $i) (i32.const 4)))
        (local.set $x (f32.load (i32.add (i32.const 64) (local.get $a))))
        (local.set $y (f32.load (i32.add (i32.const 4160) (local.get $a))))
        (local.set $vx (f32.load (i32.add (i32.const 8256) (local.get $a))))
        (local.set $vy (f32.load (i32.add (i32.const 12352) (local.get $a))))
        (local.set $vx0 (local.get $vx))
        (local.set $vx
          (f32.mul
            (f32.add
              (local.get $vx)
              (f32.add
                (f32.mul
                  (call $sin
                    (f32.add
                      (f32.mul (local.get $y) (f32.const 0.0045))
                      (f32.mul (local.get $t) (f32.const 0.35))))
                  (local.get $push))
                (f32.mul (f32.neg (local.get $vy)) (local.get $twist))))
            (f32.const 0.988)))
        (local.set $vy
          (f32.mul
            (f32.add
              (local.get $vy)
              (f32.add
                (f32.mul
                  (call $cos
                    (f32.sub
                      (f32.mul (local.get $x) (f32.const 0.0045))
                      (f32.mul (local.get $t) (f32.const 0.28))))
                  (local.get $push))
                (f32.mul (local.get $vx0) (local.get $twist))))
            (f32.const 0.988)))
        (local.set $x (f32.add (local.get $x) (f32.mul (local.get $vx) (local.get $k))))
        (local.set $y (f32.add (local.get $y) (f32.mul (local.get $vy) (local.get $k))))
        (if (f32.lt (local.get $x) (f32.const 0.0))
          (then (local.set $x (f32.add (local.get $x) (local.get $w)))))
        (if (f32.gt (local.get $x) (local.get $w))
          (then (local.set $x (f32.sub (local.get $x) (local.get $w)))))
        (if (f32.lt (local.get $y) (f32.const 0.0))
          (then (local.set $y (f32.add (local.get $y) (local.get $h)))))
        (if (f32.gt (local.get $y) (local.get $h))
          (then (local.set $y (f32.sub (local.get $y) (local.get $h)))))
        (f32.store (i32.add (i32.const 64) (local.get $a)) (local.get $x))
        (f32.store (i32.add (i32.const 4160) (local.get $a)) (local.get $y))
        (f32.store (i32.add (i32.const 8256) (local.get $a)) (local.get $vx))
        (f32.store (i32.add (i32.const 12352) (local.get $a)) (local.get $vy))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $loop))))

  ;; One impulse at a point: positive pushes the sea away (a pebble), negative
  ;; draws it in (the inhale when a query lands). The page schedules these, the
  ;; simulation only integrates them.
  (func (export "burst") (param $cx f32) (param $cy f32) (param $s f32)
    (local $i i32)
    (local $a i32)
    (local $dx f32)
    (local $dy f32)
    (local $d2 f32)
    (local $f f32)
    (block $done
      (loop $loop
        (br_if $done (i32.ge_u (local.get $i) (global.get $n)))
        (local.set $a (i32.mul (local.get $i) (i32.const 4)))
        (local.set $dx
          (f32.sub
            (f32.load (i32.add (i32.const 64) (local.get $a)))
            (local.get $cx)))
        (local.set $dy
          (f32.sub
            (f32.load (i32.add (i32.const 4160) (local.get $a)))
            (local.get $cy)))
        (local.set $d2
          (f32.add
            (f32.add
              (f32.mul (local.get $dx) (local.get $dx))
              (f32.mul (local.get $dy) (local.get $dy)))
            (f32.const 900.0)))
        (local.set $f (f32.div (local.get $s) (local.get $d2)))
        (f32.store
          (i32.add (i32.const 8256) (local.get $a))
          (f32.add
            (f32.load (i32.add (i32.const 8256) (local.get $a)))
            (f32.mul (f32.div (local.get $dx) (f32.sqrt (local.get $d2))) (local.get $f))))
        (f32.store
          (i32.add (i32.const 12352) (local.get $a))
          (f32.add
            (f32.load (i32.add (i32.const 12352) (local.get $a)))
            (f32.mul (f32.div (local.get $dy) (f32.sqrt (local.get $d2))) (local.get $f))))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $loop))))

  (func (export "count") (result i32)
    (global.get $n)))
