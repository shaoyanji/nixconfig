/*
 * The netbook's accessibility layer: this keyboard lost P and most of the
 * punctuation cluster to a broken ribbon connector, so these entries borrow
 * keys that still work.
 *
 * Not a header and not included — profiles.dwlDesktop splices this text in at
 * config.h's @EXTRA_KEYBINDS@ marker, which sits FIRST in keys[]. dwl takes the
 * first match, so an entry here shadows the fleet binding for the same chord.
 * Two fleet bindings are shadowed, both on purpose: Mod+S (the region
 * screenshot) and Mod+Space (the spotlight, which this session has no DMS for —
 * the symbol menu takes its place). The screenshot keeps a chord at the bottom
 * of this file rather than being lost.
 *
 * Two rules, because the alternative is a pile of one-off bindings:
 *
 *   1. One mechanism per meaning. TYPED() is the only place that knows how a
 *      dead character reaches a window: it copies first, so a client that
 *      refuses synthetic input still leaves the character pasteable.
 *   2. Chords live here; bodies live with alice. Every command below is a name
 *      on the session PATH — `environment.localBinInPath` puts ~/.local/bin
 *      there, and the dotfiles and ~/mako-suite installers fill it. The HUD
 *      cards are that same rule: they are her six scripts, and they speak
 *      fnott (the session's notifier) since the 2026-10-27 port.
 */

/* Chord -> character. The macro writes the quoting once, so a character is
 * spelled once instead of three times, and adding one is a single table row. */
#define TYPED(key, mods, ch) \
	{mods, XKB_KEY_##key, spawn, SHCMD("printf '" ch "' | wl-copy; wtype -- '" ch "'")}

/* The punctuation cluster, on letters that still send events. */
TYPED(s, MODKEY, "/"),
TYPED(s, MODKEY | WLR_MODIFIER_SHIFT, "?"),
TYPED(n, MODKEY, "-"),
TYPED(n, MODKEY | WLR_MODIFIER_SHIFT, "_"),
TYPED(z, MODKEY, "0"),
TYPED(m, MODKEY, ";"),
TYPED(m, MODKEY | WLR_MODIFIER_SHIFT, ":"),
TYPED(b, MODKEY, "\\\\"),

/* Her own tools, by name: the symbol menu on Mod+Space, the QR transfer on
 * Mod+Shift+Space, dictation on Caps_Lock alone and on Mod+grave, the agent on
 * Mod+Caps_Lock. */
{MODKEY, XKB_KEY_space, spawn, SHCMD("quick-keys.sh")},
{MODKEY | WLR_MODIFIER_SHIFT, XKB_KEY_space, spawn, SHCMD("qr-sync")},
{0, XKB_KEY_Caps_Lock, spawn, SHCMD("voice-dictate.sh")},
{MODKEY, XKB_KEY_grave, spawn, SHCMD("voice-dictate")},
{MODKEY, XKB_KEY_Caps_Lock, spawn, SHCMD("voice-agent.sh")},

/* The HUD cards, one per BackSpace modifier — the same five chords niri had. */
{MODKEY, XKB_KEY_BackSpace, spawn, SHCMD("makotop")},
{MODKEY | WLR_MODIFIER_SHIFT, XKB_KEY_BackSpace, spawn, SHCMD("makofetch")},
{MODKEY | WLR_MODIFIER_CTRL, XKB_KEY_BackSpace, spawn, SHCMD("makodf")},
{MODKEY | WLR_MODIFIER_ALT, XKB_KEY_BackSpace, spawn, SHCMD("makokill")},
{MODKEY | WLR_MODIFIER_CTRL | WLR_MODIFIER_SHIFT, XKB_KEY_BackSpace, spawn, SHCMD("makonet")},

/* niri habits worth keeping: the second launcher chord (the fleet keymap binds
 * Mod+A), Alt+Tab through the window stack, and Super+Alt+L to lock. */
{MODKEY, XKB_KEY_d, spawn, {.v = menucmd}},
{WLR_MODIFIER_ALT, XKB_KEY_Tab, focusstack, {.i = +1}},
{WLR_MODIFIER_ALT | WLR_MODIFIER_SHIFT, XKB_KEY_Tab, focusstack, {.i = -1}},
{MODKEY | WLR_MODIFIER_ALT, XKB_KEY_l, spawn, SHCMD("waylock")},

/* Mod+S types '/', so the fleet's region screenshot moves one modifier over
 * instead of disappearing. Full-screen is still the fleet's Mod+Print. */
{MODKEY | WLR_MODIFIER_ALT, XKB_KEY_s, spawn, SHCMD("grim -g \"$(slurp)\" - | wl-copy")},
