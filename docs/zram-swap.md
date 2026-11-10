# zram swap on workstations

Hosts importing `base-node` carry 16-64 GB of RAM, and a build plus a browser
can cross it. zram keeps swap in zstd-compressed RAM pages instead of on disk,
which avoids an SSD swap partition or file that thrashes wear leveling. The
profile raises the NixOS default `memoryPercent` from 25 to 50 and sets
`priority=100`, so the kernel prefers the compressed-RAM pages over any physical
swap device.
