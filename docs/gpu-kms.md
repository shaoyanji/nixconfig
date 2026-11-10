# NVIDIA KMS on Kepler cards

The proprietary driver's `nvidia_drm` module defaults to `modeset=0` and
`fbdev=0`, so `/dev/dri/card0` exposes no KMS node, or seatd cannot enumerate
the seat as graphics-capable. A wlroots compositor then falls back to its
headless backend:

```
wlserver [backend/headless/backend.c:67] Creating headless backend
```

`boot.kernelParams` sets `nvidia_drm.modeset=1` on ares and kellerbench, and
`fbdev=1` on the legacy Kepler (sm_30) cards, where the driver prefers fbdev for
legacy framebuffer paths.
