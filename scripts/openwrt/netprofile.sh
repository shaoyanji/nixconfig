#!/bin/sh
# netprofile — switch the FRITZ!Box 7320 (OpenWrt 24.10, ath9k) between roles.
#
# Canonical copy: scripts/openwrt/netprofile.sh. Installed to the box by
# `openwrt install` (nix develop .#openwrt) — never edited on the device.
# Only the radio changes; wired LAN access (192.168.1.1) is never touched.
CONF=/etc/netprofile.conf
[ -f "$CONF" ] && . "$CONF"
CHANNEL=${CHANNEL:-6}
SSID=${SSID:-pentest-7320}
# TXPOWER is in dBm; empty leaves the driver/regulatory default (20 dBm here).
TXPOWER=${TXPOWER:-}

save() { cp /etc/config/wireless /root/net-profiles/wireless.before 2>/dev/null; }
mon_del() { iw dev mon0 del 2>/dev/null; }
mon_add() {
	mon_del
	iw phy phy0 interface add mon0 type monitor 2>/dev/null || { echo "mon0: cannot add (phy busy?)"; return 1; }
	ip link set mon0 up
	iw dev mon0 set channel "$CHANNEL" 2>/dev/null
	sleep 1
	iw dev mon0 info 2>/dev/null | grep -q "type monitor" || { echo "mon0: not in monitor mode"; return 1; }
	echo "mon0: monitor on channel $CHANNEL"
}
ap_up() {
	uci set wireless.radio0.disabled='0'
	uci set wireless.radio0.channel="$CHANNEL"
	[ -n "$TXPOWER" ] && uci set wireless.radio0.txpower="$TXPOWER"
	uci set wireless.default_radio0.disabled='0'
	uci set wireless.default_radio0.mode='ap'
	uci set wireless.default_radio0.ssid="$SSID"
	uci set wireless.default_radio0.encryption='psk2'
	uci set wireless.default_radio0.key="$PSK"
	uci set wireless.default_radio0.network='lan'
	uci commit wireless
	# `wifi reload` does not restart a radio that `wifi down` stopped, so a
	# switch from baseline to ap would silently leave radio0 up=false.
	wifi up
	sleep 3
}
radio_off() {
	mon_del
	uci set wireless.default_radio0.disabled='1'
	uci set wireless.radio0.disabled='1'
	uci commit wireless
	# `wifi down` is the only thing that actually stops hostapd and removes the
	# interface; a reload can leave the AP vif beaconing for seconds after.
	wifi down
	sleep 2
}
apply() {
	case "$1" in
	baseline) radio_off ;;
	monitor)
		uci set wireless.default_radio0.disabled='1'
		uci set wireless.radio0.disabled='0'
		uci set wireless.radio0.channel="$CHANNEL"
		[ -n "$TXPOWER" ] && uci set wireless.radio0.txpower="$TXPOWER"
		uci commit wireless
		wifi up; sleep 2
		mon_add ;;
	ap) mon_del; ap_up ;;
	ap-monitor) ap_up; mon_add ;;
	*) echo "unknown profile: $1"; return 2 ;;
	esac
}

[ "$1" = "--boot" ] && { [ -f /etc/netprofile ] && apply "$(cat /etc/netprofile)"; exit $?; }

case "$1" in
baseline|monitor|ap|ap-monitor)
	save
	apply "$1" || exit $?
	echo "$1" > /etc/netprofile
	echo "profile: $1 (persisted)" ;;
status)
	echo "profile: $(cat /etc/netprofile 2>/dev/null || echo baseline)"
	if command -v ubus >/dev/null 2>&1; then
		ubus call network.wireless status 2>/dev/null | grep -o '"radio0".*' >/dev/null 2>&1
		up=$(ubus call network.wireless status 2>/dev/null | awk '/"up"/{print $2; exit}' | tr -d ',')
		[ -n "$up" ] && echo "radio0: up=$up"
	fi
	iw dev 2>/dev/null | sed -n 's/^\s*Interface \(\w*\)/\1/p' | while read -r i; do
		printf "  %s: %s channel %s\n" "$i" "$(iw dev "$i" info | sed -n 's/^\s*type //p')" "$(iw dev "$i" info | awk '/channel/{print $2}')"
	done ;;
capture)
	shift
	exec tcpdump -i mon0 -U -n -w - "$@" ;;
*)
	echo "usage: netprofile {baseline|monitor|ap|ap-monitor|status|capture [tcpdump args]}" >&2
	exit 2 ;;
esac
