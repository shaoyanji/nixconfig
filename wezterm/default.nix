{ config, pkgs, ... }:

{
   #currentltly dotfiles need hardlinking ln modules/mappings.lua ~/.config/wezterm/modules/mappings.lua
   home.packages = with pkgs; [
      wezterm
   ];
   home.file = {
    # # Building this configuration will create a copy of 'dotfiles/screenrc' in
    # # the Nix store. Activating the configuration will then make '~/.screenrc' a
    # # symlink to the Nix store copy.
    ".wezterm.lua".text = ''
      local wezterm = require("wezterm")
local mappings = require("modules.mappings")
-- Show which key table is active in the status area
wezterm.on("update-right-status", function(window, pane)
	local name = window:active_key_table()
	if name then
		name = "TABLE: " .. name
	end
	window:set_right_status(name or "")
end)

return {
	--	default_prog = { "C:\\Users\\Jisifu\\scoop\\shims\\nu" },
	front_end = "WebGpu",
	default_cursor_style = "BlinkingBlock",
	color_scheme = "Poimandres",
	colors = {
		cursor_bg = "#A6ACCD",
		cursor_border = "#A6ACCD",
		cursor_fg = "#1B1E28",
	},
	-- font
	font = wezterm.font("JetBrainsMono Nerd Font", { weight = "Medium" }),
	font_size = 12,
	line_height = 1.2,
	window_background_opacity = 0.98,
	-- tab bar
	use_fancy_tab_bar = false,
	tab_bar_at_bottom = true,
	hide_tab_bar_if_only_one_tab = true,
	tab_max_width = 999999,
	window_padding = {
		left = 30,
		right = 30,
		top = 30,
		bottom = 30,
	},
	window_decorations = "RESIZE",
	inactive_pane_hsb = {
		brightness = 0.7,
	},
	send_composed_key_when_left_alt_is_pressed = false,
	send_composed_key_when_right_alt_is_pressed = true,
	-- key bindings
	leader = mappings.leader,
	keys = mappings.keys,
	key_tables = mappings.key_tables,
}
    '';
    
    ".config/wezterm/modules/mappings.lua".text = ''
local wezterm = require("wezterm")
local act = wezterm.action

return {
	leader = { key = "Space", mods = "SHIFT" },

	keys = {
		{
			key = "w",
			mods = "LEADER",
			action = act.CloseCurrentPane({ confirm = false }),
		},

		-- activate resize mode
		{
			key = "r",
			mods = "LEADER",
			action = act.ActivateKeyTable({
				name = "resize_pane",
				one_shot = false,
			}),
		},

		-- focus panes
		{
			key = "h",
			mods = "LEADER",
			action = act.ActivatePaneDirection("Left"),
		},
		{
			key = "l",
			mods = "LEADER",
			action = act.ActivatePaneDirection("Right"),
		},
		{
			key = "k",
			mods = "LEADER",
			action = act.ActivatePaneDirection("Up"),
		},
		{
			key = "j",
			mods = "LEADER",
			action = act.ActivatePaneDirection("Down"),
		},

		-- add new panes
		{
			key = "s",
			mods = "LEADER",
			action = act.SplitVertical({ domain = "CurrentPaneDomain" }),
		},
		{
			key = "d",
			mods = "LEADER",
			action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }),
		},
	},

	key_tables = {
		resize_pane = {
			{ key = "LeftArrow", action = act.AdjustPaneSize({ "Left", 5 }) },
			{ key = "h", action = act.AdjustPaneSize({ "Left", 5 }) },

			{ key = "RightArrow", action = act.AdjustPaneSize({ "Right", 5 }) },
			{ key = "l", action = act.AdjustPaneSize({ "Right", 5 }) },

			{ key = "UpArrow", action = act.AdjustPaneSize({ "Up", 2 }) },
			{ key = "k", action = act.AdjustPaneSize({ "Up", 2 }) },

			{ key = "DownArrow", action = act.AdjustPaneSize({ "Down", 2 }) },
			{ key = "j", action = act.AdjustPaneSize({ "Down", 2 }) },

			{ key = "Escape", action = "PopKeyTable" },
		},
	},
}
    '';
      # # You can also set the file content immediately.
    # ".gradle/gradle.properties".text = ''
    #   org.gradle.console=verbose
    #   org.gradle.daemon.idletimeout=3600000
    # '';
      #".wezterm.lua" = {
      #	  source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.wezterm.lua";
      #};
  };

}
