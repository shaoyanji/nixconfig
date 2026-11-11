/*
 * The netbook's dead-key layer: this keyboard's ribbon connector is broken, so
 * `p`, `0` and the right-hand punctuation never reach the compositor. Every
 * entry below rents a key that still works.
 *
 * Not a header and not included — profiles.dwlDesktop splices this text in at
 * config.h's @EXTRA_KEYBINDS@ marker, which sits FIRST in keys[]. dwl takes the
 * first match, so an entry here shadows the fleet binding for the same chord.
 * Nothing is shadowed any more: the rent is the bottom row plus three free keys,
 * and no fleet chord lives on any of them — so Mod+S is the region screenshot
 * again and Mod+Space the spotlight. Nothing below needs an escape hatch.
 *
 * One rule, so this is a thing to learn rather than twenty things:
 *
 *   Mod+<key>        types the dead key's plain character
 *   Mod+Shift+<key>  types its shifted character
 *
 * The rent is one row and one reason: the bottom row is the only stretch of the
 * keyboard no fleet chord borders, so aiming for a dead key and missing lands
 * on another dead key. Left to right: z 0, x backquote, c [, v ], b \, n -,
 * m ;, comma =, period /. Then u ', o p, p ( — the free keys left over, with
 * `/` on `period` because that is the key beside the one the ribbon lost. Vim's
 * `:wq` is Mod+Shift+m, then w, then q. Mod+Shift+grave puts the whole table on
 * screen, because a mapping nobody can look up is just the menu this replaced.
 *
 * The rows are not written out here. `hosts/netbook/dead-keys.toml` is the one
 * list, and the build projects it three times: into the rows at @DEAD_KEYS@
 * below, into the text of that card, and into `netbook-keys --json`, which is
 * the contract a consumer reads instead of parsing a keymap. A new character is
 * one entry there, and it becomes typable, documented and consumable together.
 *
 * There is no menu. The layer this replaced opened wmenu, sent a fnott card,
 * copied the character to the clipboard twice and slept before typing — so a
 * `:` in a vim command was three keystrokes and a stall — and its list carried
 * neither parenthesis. Here the body is one `wtype -- <char>`: the character
 * lands at once, and the clipboard is left alone.
 *
 * Her own tools stay names on the session PATH (`environment.localBinInPath`):
 * the six mako-suite HUD cards, dictation, the agent and the QR transfer. Their
 * bodies live with alice; this file only names them.
 */

/* Chord -> character. The argument is a shell-quoted word, so the quoting lives
 * once in the list that generates these rows instead of in every row. */
#define TYPED(key, mods, lit) \
	{mods, XKB_KEY_##key, spawn, SHCMD("wtype -- " lit)}

/* The characters the connector lost, generated from `deadKeys`. */
/* @DEAD_KEYS@ */

/* Her own tools, by name: the QR transfer on Mod+Shift+Space, dictation on
 * Caps_Lock alone and on Mod+grave, the agent on Mod+Caps_Lock. */
{MODKEY | WLR_MODIFIER_SHIFT, XKB_KEY_space, spawn, SHCMD("qr-sync")},
{0, XKB_KEY_Caps_Lock, spawn, SHCMD("voice-dictate.sh")},
{MODKEY, XKB_KEY_grave, spawn, SHCMD("voice-dictate")},
{MODKEY, XKB_KEY_Caps_Lock, spawn, SHCMD("voice-agent.sh")},

/* The same table as a fnott card, and `netbook-keys --text` in a shell. */
{MODKEY | WLR_MODIFIER_SHIFT, XKB_KEY_grave, spawn, SHCMD("netbook-keys")},

/* The HUD cards, one per BackSpace modifier — the same five chords niri had. */
{MODKEY, XKB_KEY_BackSpace, spawn, SHCMD("makotop")},
{MODKEY | WLR_MODIFIER_SHIFT, XKB_KEY_BackSpace, spawn, SHCMD("makofetch")},
{MODKEY | WLR_MODIFIER_CTRL, XKB_KEY_BackSpace, spawn, SHCMD("makodf")},
{MODKEY | WLR_MODIFIER_ALT, XKB_KEY_BackSpace, spawn, SHCMD("makokill")},
{MODKEY | WLR_MODIFIER_CTRL | WLR_MODIFIER_SHIFT, XKB_KEY_BackSpace, spawn, SHCMD("makonet")},

/* niri habits worth keeping: Alt+Tab through the window stack, and Super+Alt+L
 * to lock. The launcher has one chord on the fleet keymap now (Mod+Space), so
 * the second one this file used to add is gone. */
{WLR_MODIFIER_ALT, XKB_KEY_Tab, focusstack, {.i = +1}},
{WLR_MODIFIER_ALT | WLR_MODIFIER_SHIFT, XKB_KEY_Tab, focusstack, {.i = -1}},
{MODKEY | WLR_MODIFIER_ALT, XKB_KEY_l, spawn, SHCMD("waylock")},
