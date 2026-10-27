/*
 * The netbook's accessibility layer: this keyboard lost P and most of the
 * punctuation cluster to a broken ribbon connector, so these binds are how
 * those characters still get typed.
 *
 * Not a header and not included — profiles.dwlDesktop splices this text in at
 * config.h's @EXTRA_KEYBINDS@ marker, which sits FIRST in keys[]. dwl takes the
 * first match, so an entry here shadows the fleet binding for the same key:
 * Mod+S types a slash below, it does not take a region screenshot. Mod+Print
 * (full-screen shot) is still the fleet's.
 *
 * The commands are named, not pathed: the session inherits the login shell's
 * PATH, which home-manager puts ~/.local/bin first on. Their bodies are in the
 * dotfiles repo (quick-keys.sh, qr-sync, voice-*.sh) and in ~/mako-suite.
 */

/* Mod+Space — the symbol menu: wmenu lists the dead characters and wtypes the
 * chosen one into the focused window. Caps_Lock alone dictates. */
{MODKEY, XKB_KEY_space, spawn, SHCMD("quick-keys.sh")},
{MODKEY | WLR_MODIFIER_SHIFT, XKB_KEY_space, spawn, SHCMD("qr-sync")},
{0, XKB_KEY_Caps_Lock, spawn, SHCMD("voice-dictate.sh")},
{MODKEY, XKB_KEY_grave, spawn, SHCMD("voice-dictate")},
{MODKEY, XKB_KEY_Caps_Lock, spawn, SHCMD("voice-agent.sh")},

/* One character each, into whatever has focus. It goes to the clipboard first
 * so that a wtype that cannot reach the window still leaves it pasteable. */
{MODKEY, XKB_KEY_s, spawn, SHCMD("printf '/' | wl-copy; sleep 0.05; wtype -- '/'")},
{MODKEY | WLR_MODIFIER_SHIFT, XKB_KEY_s, spawn, SHCMD("printf '?' | wl-copy; sleep 0.05; wtype -- '?'")},
{MODKEY, XKB_KEY_n, spawn, SHCMD("printf '-' | wl-copy; sleep 0.05; wtype -- '-'")},
{MODKEY | WLR_MODIFIER_SHIFT, XKB_KEY_n, spawn, SHCMD("printf '_' | wl-copy; sleep 0.05; wtype -- '_'")},
{MODKEY, XKB_KEY_z, spawn, SHCMD("printf '0' | wl-copy; sleep 0.05; wtype -- '0'")},
{MODKEY, XKB_KEY_m, spawn, SHCMD("printf ';' | wl-copy; sleep 0.05; wtype -- ';'")},
{MODKEY | WLR_MODIFIER_SHIFT, XKB_KEY_m, spawn, SHCMD("printf ':' | wl-copy; sleep 0.05; wtype -- ':'")},
{MODKEY, XKB_KEY_b, spawn, SHCMD("printf '\\\\' | wl-copy; sleep 0.05; wtype -- '\\\\'")},

/* The HUD cards, one per BackSpace modifier — the same five Mod+BackSpace
 * chords niri had. */
{MODKEY, XKB_KEY_BackSpace, spawn, SHCMD("makotop")},
{MODKEY | WLR_MODIFIER_SHIFT, XKB_KEY_BackSpace, spawn, SHCMD("makofetch")},
{MODKEY | WLR_MODIFIER_CTRL, XKB_KEY_BackSpace, spawn, SHCMD("makodf")},
{MODKEY | WLR_MODIFIER_ALT, XKB_KEY_BackSpace, spawn, SHCMD("makokill")},
{MODKEY | WLR_MODIFIER_CTRL | WLR_MODIFIER_SHIFT, XKB_KEY_BackSpace, spawn, SHCMD("makonet")},

/* Both of niri's launcher chords: the fleet keymap binds Mod+A, and the rice was
 * in the habit of Mod+D too. */
{MODKEY, XKB_KEY_d, spawn, {.v = menucmd}},

/* Alt+Tab walks the window stack, as niri's next/previous-window did. */
{WLR_MODIFIER_ALT, XKB_KEY_Tab, focusstack, {.i = +1}},
{WLR_MODIFIER_ALT | WLR_MODIFIER_SHIFT, XKB_KEY_Tab, focusstack, {.i = -1}},

/* Super+Alt+L locks. niri also powered the monitors off in the same chord; dwl
 * has no such primitive, so this is waylock and nothing else. */
{MODKEY | WLR_MODIFIER_ALT, XKB_KEY_l, spawn, SHCMD("waylock")},
