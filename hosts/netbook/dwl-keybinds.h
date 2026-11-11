/*
 * The netbook's dead-key layer: this keyboard's ribbon connector is broken, so
 * `p`, `0` and the right-hand punctuation never reach the compositor. Every
 * entry below rents a key that still works.
 *
 * Not a header and not included — profiles.dwlDesktop splices this text in at
 * config.h's @EXTRA_KEYBINDS@ marker, which sits FIRST in keys[]. dwl takes the
 * first match, so an entry here shadows the fleet binding for the same chord.
 * One fleet binding is shadowed, on purpose: Mod+S types `/`, so the region
 * screenshot keeps Mod+Alt+S at the bottom of this file. Mod+Space is not bound
 * here, so the fleet spotlight answers it again.
 *
 * One rule, so this is a thing to learn rather than twenty things:
 *
 *   Mod+<key>        types the dead key's plain character
 *   Mod+Shift+<key>  types its shifted character
 *
 * The rented key sits as close to the lost one as the layout allows: z for 0,
 * m for ;, n for -, u for =, c for [, o for ], b for \, s for /, x for ', v for
 * the backquote, and g for the parenthesis pair. Vim's `:wq` is Mod+Shift+m,
 * then w, then q.
 *
 * There is no menu. The layer this replaces opened wmenu, sent a fnott card,
 * copied the character to the clipboard twice and slept before typing — so a
 * `:` in a vim command was three keystrokes and a stall — and its list carried
 * neither parenthesis. Here the body is one `wtype -- '<char>'`: the character
 * lands at once, and the clipboard is left alone.
 *
 * Her own tools stay names on the session PATH (`environment.localBinInPath`):
 * the six mako-suite HUD cards, dictation, the agent and the QR transfer. Their
 * bodies live with alice; this file only names them.
 */

/* Chord -> character. The macro writes the quoting once, so a character is
 * spelled once per row instead of three times (`printf`, `wl-copy`, `wtype`),
 * and adding one is a single row. */
#define TYPED(key, mods, ch) \
	{mods, XKB_KEY_##key, spawn, SHCMD("wtype -- '" ch "'")}

/* The punctuation the connector lost: plain on Mod, shifted on Mod+Shift, the
 * way the original key carried its pair. */
TYPED(s, MODKEY, "/"),
TYPED(s, MODKEY | WLR_MODIFIER_SHIFT, "?"),
TYPED(n, MODKEY, "-"),
TYPED(n, MODKEY | WLR_MODIFIER_SHIFT, "_"),
TYPED(z, MODKEY, "0"),
TYPED(z, MODKEY | WLR_MODIFIER_SHIFT, ")"),
TYPED(m, MODKEY, ";"),
TYPED(m, MODKEY | WLR_MODIFIER_SHIFT, ":"),
TYPED(b, MODKEY, "\\"),
TYPED(b, MODKEY | WLR_MODIFIER_SHIFT, "|"),
TYPED(u, MODKEY, "="),
TYPED(u, MODKEY | WLR_MODIFIER_SHIFT, "+"),
TYPED(c, MODKEY, "["),
TYPED(c, MODKEY | WLR_MODIFIER_SHIFT, "{"),
TYPED(o, MODKEY, "]"),
TYPED(o, MODKEY | WLR_MODIFIER_SHIFT, "}"),
TYPED(g, MODKEY, "("),
TYPED(g, MODKEY | WLR_MODIFIER_SHIFT, ")"),
TYPED(v, MODKEY, "`"),
TYPED(v, MODKEY | WLR_MODIFIER_SHIFT, "~"),
TYPED(y, MODKEY, "p"),
TYPED(y, MODKEY | WLR_MODIFIER_SHIFT, "P"),
/* The apostrophe half of that pair cannot go through the macro: a single quote
 * inside a single-quoted shell word has no escape, so this row is written out. */
{MODKEY, XKB_KEY_x, spawn, SHCMD("wtype -- \"'\"")},
TYPED(x, MODKEY | WLR_MODIFIER_SHIFT, "\""),

/* Her own tools, by name: the QR transfer on Mod+Shift+Space, dictation on
 * Caps_Lock alone and on Mod+grave, the agent on Mod+Caps_Lock. */
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
