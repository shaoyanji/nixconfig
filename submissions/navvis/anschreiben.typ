// NavVis — Senior Linux Platform Engineer. Native English letter, reproducing the submitted text.
#set page(paper: "a4", margin: (x: 2.3cm, y: 1.9cm))
#set text(font: "DejaVu Sans", size: 9.6pt, fill: rgb("#191919"), lang: "en")
#set par(justify: true, leading: 0.62em)
#let muted = rgb("#5c6b7a")

#align(right)[
  #text(weight: "bold", size: 10.4pt)[Matt Ji]
  #linebreak()
  #text(size: 9pt)[Am Burgerhof 4 · 79261 Gutach im Breisgau, Germany]
  #linebreak()
  #text(size: 9pt)[matt\@bountystash.com · +49 1733281570]
]

#v(0.4cm)
#text(size: 8.6pt, fill: muted)[21 November 2026]
#v(0.4cm)
NavVis #linebreak() System Software, Mapping and Perception

#v(0.5cm)
#text(weight: "bold", size: 10.1pt)[Application: Senior Linux Platform Engineer (F/M/D)]
#v(0.4cm)

Dear NavVis team,

I build and ship Linux platforms the way your System Software team does, one layer below the application: a host is a declarative
feature list, the image is built reproducibly from that list, every service is a systemd unit with explicit failure behaviour,
and a generation rolls back in one command when an update goes wrong. The same per-host gate CI runs is what a machine passes
before it switches, which is the discipline behind shipping device software several times a quarter without a manual checklist.

The closest I have to your sensor and device boundary is the CUDA node that serves models here and the microVM sandbox beside
it. On the GPU node I pin driver and userspace versions together, patch around library behaviour when a newer stack breaks a
model, and measure latency and queue depth rather than trusting a green service. The sandbox is a small image that boots capped,
mounts read-only and fails closed, which is the same shape as a device image even though the hardware is a server.

What I have not done is the device-specific half of this role: I have not owned Debian or Ubuntu images, written production C++
beyond an earlier lab-equipment application, or worked with ROS, V4L2, LiDAR or an ARM device fleet. I would be learning that
from your Embedded Software team, and I would rather say so than let the first month say it for me. The parts that transfer are
the OS lifecycle, systemd, packaging, reproducible builds and a CI gate that proves a machine before it ships.

One practical point, since the role asks for three days on site: I am based in Gutach im Breisgau, so Munich is a relocation
decision rather than a commute, and I would want that settled early rather than at offer stage.

Kind regards,
#v(0.45cm)
Matt Ji
