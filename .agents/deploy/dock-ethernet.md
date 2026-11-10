# Dock Ethernet (CDC-NCM)

The USB dock's RJ45 is a `cdc_ncm` device. NetworkManager's auto-generated
"Wired connection N" mints a new profile on every dock or replug and takes a
fresh DHCP lease (observed .60, then .253), which the router then recycles to the
next device. That duplicate-address window is how poseidon's .74 answered from
two MACs.

`profiles.dell-dock` owns the shared behaviour: one matched profile with a pinned
interface name and `route-metric 600`, so Wi-Fi stays primary and the dock is the
fallback. `manageUsbEthernet` decides whether the port is managed at all. Hosts
where the port is spare (frieren) leave it unmanaged, because no lease beats a
stale third default route.

Measured on fern 2026-11-01: dock 6.2 MB/s against Wi-Fi 2.6 MB/s at 5 GHz and
1.8 MB/s at 2.4 GHz. The AP above that desk is a mesh point, so the radio, not
the powerline backbone (225/319 Mbps link rate), is the ceiling.

Three failure modes are closed for this knob (AGENTS.nix note
`poseidon-tpm-luks-dock`): the pinned name stops a second UUID-named profile, the
static address stops the hostname-keyed lease trading places with Wi-Fi, and the
ARP sysctls stop the two NICs answering for each other's address. On poseidon the
cable terminates on the parent 192.168.3.0/24 (lease .3, Wi-Fi .2), not behind a
cascaded node, so it does not put two subnets on one host, which is the trap
commit 661397fa reverted.
