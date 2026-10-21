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

#define TAGKEYS(KEY,TAG) \
	{ MODKEY,                    KEY,            view,            {.ui = 1 << TAG} }, \
	{ MODKEY|WLR_MODIFIER_CTRL,  KEY,            toggleview,      {.ui = 1 << TAG} }, \
	{ MODKEY|WLR_MODIFIER_SHIFT, KEY,            tag,             {.ui = 1 << TAG} }, \
	{ MODKEY|WLR_MODIFIER_CTRL|WLR_MODIFIER_SHIFT,KEY,toggletag,  {.ui = 1 << TAG} }

#define SHCMD(cmd) { .v = (const char*[]){ "/bin/sh", "-c", cmd, NULL } }

/* Commands with Catppuccin Mocha themed wmenu */
static const char *termcmd[] = { "foot", NULL };
static const char *menucmd[] = { "wmenu-run", "-f", "JetBrainsMono Nerd Font 11", "-N", "1e1e2e", "-n", "cdd6f4", "-M", "313244", "-m", "cdd6f4", "-S", "cba6f7", "-s", "11111b", NULL };

static const Key keys[] = {
	/* modifier                  key                  function          argument */
	{ MODKEY,                    XKB_KEY_p,           spawn,            {.v = menucmd} },
	{ MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_Return,      spawn,            {.v = termcmd} },
	{ MODKEY,                    XKB_KEY_Return,      spawn,            {.v = termcmd} },
	{ MODKEY,                    XKB_KEY_j,           focusstack,       {.i = +1} },
	{ MODKEY,                    XKB_KEY_k,           focusstack,       {.i = -1} },
	{ MODKEY,                    XKB_KEY_i,           incnmaster,       {.i = +1} },
	{ MODKEY,                    XKB_KEY_d,           incnmaster,       {.i = -1} },
	{ MODKEY,                    XKB_KEY_h,           setmfact,         {.f = -0.05f} },
	{ MODKEY,                    XKB_KEY_l,           setmfact,         {.f = +0.05f} },
	{ MODKEY,                    XKB_KEY_Tab,         view,             {0} },
	{ MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_c,           killclient,       {0} },
	{ MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_q,           killclient,       {0} },
	{ MODKEY,                    XKB_KEY_t,           setlayout,        {.v = &layouts[0]} },
	{ MODKEY,                    XKB_KEY_f,           setlayout,        {.v = &layouts[1]} },
	{ MODKEY,                    XKB_KEY_m,           setlayout,        {.v = &layouts[2]} },
	{ MODKEY,                    XKB_KEY_space,       setlayout,        {0} },
	{ MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_space,       togglefloating,   {0} },
	{ MODKEY,                    XKB_KEY_e,           togglefullscreen, {0} },
	{ MODKEY,                    XKB_KEY_0,           view,             {.ui = ~0} },
	{ MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_0,           tag,              {.ui = ~0} },
	{ MODKEY,                    XKB_KEY_comma,       focusmon,         {.i = WLR_DIRECTION_LEFT} },
	{ MODKEY,                    XKB_KEY_period,      focusmon,         {.i = WLR_DIRECTION_RIGHT} },
	{ MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_comma,       tagmon,           {.i = WLR_DIRECTION_LEFT} },
	{ MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_period,      tagmon,           {.i = WLR_DIRECTION_RIGHT} },
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

static const Button buttons[] = {
	{ MODKEY, BTN_LEFT,   moveresize,     {.ui = CurMove} },
	{ MODKEY, BTN_MIDDLE, togglefloating, {0} },
	{ MODKEY, BTN_RIGHT,  moveresize,     {.ui = CurResize} },
};

/* Trackpad / mouse wheel: Super+scroll adjusts the PipeWire default sink */
static const Axis axes[] = {
	{ MODKEY, AxisUp,     spawn, SHCMD("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+") },
	{ MODKEY, AxisDown,   spawn, SHCMD("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-") },
};
