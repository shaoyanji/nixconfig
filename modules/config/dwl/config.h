#define COLOR(hex)    { ((hex >> 24) & 0xFF) / 255.0f, \
                        ((hex >> 16) & 0xFF) / 255.0f, \
                        ((hex >> 8) & 0xFF) / 255.0f, \
                        (hex & 0xFF) / 255.0f }

/* Appearance - Catppuccin Mocha */
static const int sloppyfocus               = 1;
static const int bypass_surface_visibility = 0;
static const unsigned int borderpx         = 2;
static const unsigned int snap             = 32;
static const float rootcolor[]             = COLOR(0x1e1e2eff);
static const float bordercolor[]           = COLOR(0x313244ff);
static const float focuscolor[]            = COLOR(0xcba6f7ff);
static const float urgentcolor[]           = COLOR(0xf38ba8ff);
static const float fullscreen_bg[]         = {0.1f, 0.1f, 0.15f, 1.0f};

/* Tagging */
#define TAGCOUNT (9)
static int log_level = WLR_ERROR;

static const Rule rules[] = {
	/* app_id     title       tags mask     isfloating   monitor */
	{ "foot",     NULL,       0,            0,           -1 },
};

/* Layouts */
static const Layout layouts[] = {
	/* symbol     arrange function */
	{ "[]=",      tile },
	{ "><>",      NULL },
	{ "[M]",      monocle },
};

/* Monitors */
static const MonitorRule monrules[] = {
	{ NULL,       0.55f, 1,      1,    &layouts[0], WL_OUTPUT_TRANSFORM_NORMAL,   -1,  -1 },
};

/* Keyboard */
static const struct xkb_rule_names xkb_rules = {
	.options = NULL,
};

static const int repeat_rate = 25;
static const int repeat_delay = 600;

/* Trackpad */
static const int tap_to_click = 1;
static const int tap_and_drag = 1;
static const int drag_lock = 1;
static const int natural_scrolling = 1;
static const int disable_while_typing = 1;
static const int left_handed = 0;
static const int middle_button_emulation = 0;
static const enum libinput_config_scroll_method scroll_method = LIBINPUT_CONFIG_SCROLL_2FG;
static const enum libinput_config_click_method click_method = LIBINPUT_CONFIG_CLICK_METHOD_BUTTON_AREAS;
static const uint32_t send_events_mode = LIBINPUT_CONFIG_SEND_EVENTS_ENABLED;
static const enum libinput_config_accel_profile accel_profile = LIBINPUT_CONFIG_ACCEL_PROFILE_ADAPTIVE;
static const double accel_speed = 0.0;
static const enum libinput_config_tap_button_map button_map = LIBINPUT_CONFIG_TAP_MAP_LRM;

/* Modkey: Super (Windows logo key) */
#define MODKEY WLR_MODIFIER_LOGO

/* niri's tag row: Mod+N focuses workspace N, Mod+Ctrl+N sends the window there */
#define TAGKEYS(KEY,TAG) \
	{ MODKEY,                    KEY,            view,            {.ui = 1 << TAG} }, \
	{ MODKEY|WLR_MODIFIER_CTRL,  KEY,            tag,             {.ui = 1 << TAG} }

#define SHCMD(cmd) { .v = (const char*[]){ "/bin/sh", "-c", cmd, NULL } }

/*
 * ---- niri-parity helpers ------------------------------------------------
 * The keymap follows ~/.config/niri (modules/user/desktop/niri.nix) so muscle
 * memory carries over. dwl has no "next/previous tag" and no "reorder
 * column" primitive, but both are a few lines against the structures dwl.c
 * already declares before it includes this file (selmon, clients, tagset).
 */

/* niri Mod+J / Mod+K (focus-workspace-down/up): tags are a bitmask, so the
 * neighbouring workspace is a rotate of the current one. */
static void
viewdir(const Arg *arg)
{
	Arg a;
	uint32_t cur;

	if (!selmon)
		return;
	cur = selmon->tagset[selmon->seltags] & TAGMASK;
	if (!cur)
		return;
	if (arg->i > 0) {
		a.ui = (cur << 1) & TAGMASK;
		if (!a.ui)
			a.ui = 1;
	} else {
		a.ui = cur >> 1;
		if (!a.ui)
			a.ui = 1u << (TAGCOUNT - 1);
	}
	view(&a);
}

/* niri Mod+0 / Mod+I (focus-workspace-previous). view() parks the tagset you
 * came from in the other slot, so this is a read rather than a history. */
static void
viewlast(const Arg *arg)
{
	Arg a;

	(void)arg;
	if (!selmon)
		return;
	a.ui = selmon->tagset[selmon->seltags ^ 1] & TAGMASK;
	if (!a.ui)
		return;
	view(&a);
}

/* niri Mod+Ctrl+H / Mod+Ctrl+L (move-column-left/right): reorder the window
 * in the tiling list. */
static void
movestack(const Arg *arg)
{
	Client *c = focustop(selmon);
	struct wl_list *a, *b;

	if (!c)
		return;
	a = &c->link;
	if (arg->i > 0) {
		b = a->next;
		if (b == &clients)
			return;
		wl_list_remove(a);
		wl_list_insert(b->next, a);
	} else {
		b = a->prev;
		if (b == &clients)
			return;
		wl_list_remove(a);
		wl_list_insert(b, a);
	}
	arrange(selmon);
}

/* niri Mod+Ctrl+J / Mod+Ctrl+K (move-column-to-workspace-down/up): send the
 * focused window a tag along and follow it, which is what niri does. */
static void
movetotag(const Arg *arg)
{
	Arg a;
	Client *c = focustop(selmon);
	uint32_t cur;

	if (!c)
		return;
	cur = c->tags & TAGMASK;
	if (!cur)
		return;
	if (arg->i > 0) {
		a.ui = (cur << 1) & TAGMASK;
		if (!a.ui)
			a.ui = 1;
	} else {
		a.ui = cur >> 1;
		if (!a.ui)
			a.ui = 1u << (TAGCOUNT - 1);
	}
	c->tags = a.ui;
	view(&a);
	arrange(selmon);
}

static const char *termcmd[] = { "foot", NULL };
/* fleet-menu: XDG desktop entries AND $PATH binaries in one menu. It exists
 * because j4-dmenu-desktop lists only .desktop files and wmenu-run only $PATH,
 * so the merged list has to be built before the menu runs — see
 * modules/scripts/fleet-menu.sh. */
static const char *menucmd[] = { "fleet-menu", NULL };

/* niri Mod+Space opened DMS spotlight; this is the nearest intent. */
static const char *spotlight[] = { "fleet-menu", NULL };

/* Media keys are bound in the keymap here because scratch runs no DMS daemon
 * to own them; niri binds the same XF86 keys explicitly. */
static const char *volup[] = { "wpctl", "set-volume", "-l", "1.0", "@DEFAULT_AUDIO_SINK@", "5%+", NULL };
static const char *voldown[] = { "wpctl", "set-volume", "-l", "1.0", "@DEFAULT_AUDIO_SINK@", "5%-", NULL };
static const char *volmute[] = { "wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle", NULL };
static const char *micmute[] = { "wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle", NULL };
static const char *playpause[] = { "playerctl", "play-pause", NULL };
static const char *stopcmd[] = { "playerctl", "stop", NULL };
static const char *nextcmd[] = { "playerctl", "next", NULL };
static const char *prevcmd[] = { "playerctl", "previous", NULL };
static const char *brightup[] = { "brightnessctl", "set", "+5%", NULL };
static const char *brightdown[] = { "brightnessctl", "set", "5%-", NULL };

static const Key keys[] = {
	/*
	 * niri -> dwl. Reference: modules/user/desktop/niri.nix.
	 *
	 *   niri action            dwl binding      niri action         dwl binding
	 *   ---------------------  ---------------  ------------------  -----------------
	 *   Mod+A launcher         wmenu-run        Mod+T terminal      foot
	 *   Mod+Q close            killclient       Mod+W float         togglefloating
	 *   Mod+H / Mod+L focus    focusstack -1/+1 Mod+J / Mod+K       viewdir +1/-1
	 *   Mod+Shift+H/L monitor  focusmon L/R     Mod+Shift+J/K       viewdir (+1/-1)
	 *   Mod+Ctrl+H/L reorder   movestack -1/+1  Mod+Ctrl+J/K send   movetotag +1/-1
	 *   Mod+Ctrl+Shift+H/L     tagmon L/R       Mod+1..9            view tag N
	 *   Mod+Ctrl+1..9          tag (send)       Mod+0, Mod+I        viewlast
	 *   Mod+F maximize         togglefullscreen Mod+Shift+F         togglefullscreen
	 *   Mod+Return overview    zoom             Mod+R / Shift+R     setmfact +/-0.05
	 *   Mod+S region shot      grim + slurp     Mod+Print screen    grim
	 *   XF86 audio/mic/media   wpctl, playerctl XF86 brightness     brightnessctl
	 *
	 * Two niri keys have no dwl meaning and are mapped to the nearest intent:
	 * Mod+F is "maximize-column" in niri and Mod+Return is the overview; dwl
	 * has neither, so Mod+F is fullscreen (the effect the operator wants) and
	 * Mod+Return promotes the focused window to master.
	 *
	 * Deliberately unbound, because dwl has no primitive for them: Mod+E
	 * (niri switches focus between the floating and tiling layers), Mod+[
	 * and Mod+] (consume/expel into a column), Mod+U (previous monitor), and
	 * the DMS/kando/zen keys — Mod+Y P V N M B Shift+B Z C, Ctrl+Space,
	 * Mod+MouseMiddle — whose programs are not installed here. Mod+Space is
	 * bound (spotlight[]). Mod+Shift+E stays as an escape hatch; niri has no
	 * equivalent.
	 */
	/* Host keybinds, spliced here by modules/profiles/dwl-desktop.nix from a
	 * host's `profiles.dwlDesktop.extraKeybinds`. They sit FIRST because dwl
	 * takes the first match, so a host entry deliberately shadows the fleet
	 * binding for the same key. */
	/* @EXTRA_KEYBINDS@ */

	/* modifier                    key                  function          argument */
	/* niri: Mod+A launcher, Mod+T terminal (kitty) */
	{ MODKEY,                      XKB_KEY_a,           spawn,            {.v = menucmd} },
	{ MODKEY,                      XKB_KEY_t,           spawn,            {.v = termcmd} },
	{ MODKEY|WLR_MODIFIER_SHIFT,   XKB_KEY_Return,      spawn,            {.v = termcmd} },

	/* niri: Mod+Q close, Mod+W float, Mod+F fullscreen. In niri Mod+F gives
	 * the focused column the screen and Mod+Shift+F is the explicit
	 * fullscreen; dwl has one fullscreen state, so both land on it. Mod+E is
	 * left free instead of being overloaded with togglefloating. */
	{ MODKEY,                      XKB_KEY_q,           killclient,       {0} },
	{ MODKEY,                      XKB_KEY_w,           togglefloating,   {0} },
	{ MODKEY,                      XKB_KEY_f,           togglefullscreen, {0} },
	{ MODKEY|WLR_MODIFIER_SHIFT,   XKB_KEY_f,           togglefullscreen, {0} },
	{ MODKEY,                      XKB_KEY_Return,      zoom,             {0} },

	/* niri: Mod+H/L focus column, Mod+J/K workspace down/up */
	{ MODKEY,                      XKB_KEY_h,           focusstack,       {.i = -1} },
	{ MODKEY,                      XKB_KEY_l,           focusstack,       {.i = +1} },
	{ MODKEY,                      XKB_KEY_j,           viewdir,          {.i = +1} },
	{ MODKEY,                      XKB_KEY_k,           viewdir,          {.i = -1} },
	{ MODKEY|WLR_MODIFIER_SHIFT,   XKB_KEY_j,           viewdir,          {.i = +1} },
	{ MODKEY|WLR_MODIFIER_SHIFT,   XKB_KEY_k,           viewdir,          {.i = -1} },
	{ MODKEY,                      XKB_KEY_i,           viewlast,         {0} },
	{ MODKEY,                      XKB_KEY_0,           viewlast,         {0} },

	/* niri: Mod+Shift+H/L focus the neighbouring monitor */
	{ MODKEY|WLR_MODIFIER_SHIFT,   XKB_KEY_h,           focusmon,         {.i = WLR_DIRECTION_LEFT} },
	{ MODKEY|WLR_MODIFIER_SHIFT,   XKB_KEY_l,           focusmon,         {.i = WLR_DIRECTION_RIGHT} },

	/* niri: Mod+Ctrl+H/L move the column, Mod+Ctrl+J/K move it to the next
	 * workspace, Mod+Ctrl+Shift+H/L move it to another monitor. */
	{ MODKEY|WLR_MODIFIER_CTRL,    XKB_KEY_h,           movestack,        {.i = -1} },
	{ MODKEY|WLR_MODIFIER_CTRL,    XKB_KEY_l,           movestack,        {.i = +1} },
	{ MODKEY|WLR_MODIFIER_CTRL,    XKB_KEY_j,           movetotag,        {.i = +1} },
	{ MODKEY|WLR_MODIFIER_CTRL,    XKB_KEY_k,           movetotag,        {.i = -1} },
	{ MODKEY|WLR_MODIFIER_CTRL|WLR_MODIFIER_SHIFT, XKB_KEY_h, tagmon,    {.i = WLR_DIRECTION_LEFT} },
	{ MODKEY|WLR_MODIFIER_CTRL|WLR_MODIFIER_SHIFT, XKB_KEY_l, tagmon,    {.i = WLR_DIRECTION_RIGHT} },
	{ MODKEY|WLR_MODIFIER_CTRL|WLR_MODIFIER_SHIFT, XKB_KEY_j, movetotag, {.i = +1} },
	{ MODKEY|WLR_MODIFIER_CTRL|WLR_MODIFIER_SHIFT, XKB_KEY_k, movetotag, {.i = -1} },

	/* niri: Mod+R switches the column width — here it widens, Shift narrows */
	{ MODKEY,                      XKB_KEY_r,           setmfact,         {.f = +0.05f} },
	{ MODKEY|WLR_MODIFIER_SHIFT,   XKB_KEY_r,           setmfact,         {.f = -0.05f} },
	/* niri: Mod+Space opens the DMS spotlight bar (see spotlight[]) */
	{ MODKEY,                      XKB_KEY_space,       spawn,            {.v = spotlight} },

	/* niri: Mod+S region screenshot, Mod+Print full screen (into the clipboard) */
	{ MODKEY,                      XKB_KEY_s,           spawn,            SHCMD("grim -g \"$(slurp)\" - | wl-copy") },
	{ MODKEY,                      XKB_KEY_Print,       spawn,            SHCMD("grim - | wl-copy") },

	/* media keys, as niri binds them */
	{ 0, XKB_KEY_XF86AudioRaiseVolume, spawn,           {.v = volup} },
	{ 0, XKB_KEY_XF86AudioLowerVolume, spawn,           {.v = voldown} },
	{ 0, XKB_KEY_XF86AudioMute,        spawn,           {.v = volmute} },
	{ 0, XKB_KEY_XF86AudioMicMute,     spawn,           {.v = micmute} },
	{ 0, XKB_KEY_XF86AudioPlay,        spawn,           {.v = playpause} },
	{ 0, XKB_KEY_XF86AudioStop,        spawn,           {.v = stopcmd} },
	{ 0, XKB_KEY_XF86AudioNext,        spawn,           {.v = nextcmd} },
	{ 0, XKB_KEY_XF86AudioPrev,        spawn,           {.v = prevcmd} },
	{ 0, XKB_KEY_XF86MonBrightnessUp,  spawn,           {.v = brightup} },
	{ 0, XKB_KEY_XF86MonBrightnessDown, spawn,          {.v = brightdown} },
	TAGKEYS(                     XKB_KEY_1,           0),
	TAGKEYS(                     XKB_KEY_2,           1),
	TAGKEYS(                     XKB_KEY_3,           2),
	TAGKEYS(                     XKB_KEY_4,           3),
	TAGKEYS(                     XKB_KEY_5,           4),
	TAGKEYS(                     XKB_KEY_6,           5),
	TAGKEYS(                     XKB_KEY_7,           6),
	TAGKEYS(                     XKB_KEY_8,           7),
	TAGKEYS(                     XKB_KEY_9,           8),
	{ MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_e,           quit,             {0} },
	{ WLR_MODIFIER_CTRL|WLR_MODIFIER_ALT,XKB_KEY_BackSpace, quit, {0} },
};

/* niri drags windows with the modkey held; no middle-click action exists there
 * (its Mod+MouseMiddle opens kando, which is not installed). */
static const Button buttons[] = {
	{ MODKEY, BTN_LEFT,   moveresize,     {.ui = CurMove} },
	{ MODKEY, BTN_RIGHT,  moveresize,     {.ui = CurResize} },
};

/* niri: Mod+wheel changes workspace, Mod+Ctrl+wheel moves the column */
static const Axis axes[] = {
	{ MODKEY,                    AxisUp,   viewdir,  {.i = -1} },
	{ MODKEY,                    AxisDown, viewdir,  {.i = +1} },
	{ MODKEY|WLR_MODIFIER_CTRL,  AxisUp,   movetotag, {.i = -1} },
	{ MODKEY|WLR_MODIFIER_CTRL,  AxisDown, movetotag, {.i = +1} },
};
