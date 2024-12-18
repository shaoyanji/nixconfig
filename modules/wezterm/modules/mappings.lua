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
