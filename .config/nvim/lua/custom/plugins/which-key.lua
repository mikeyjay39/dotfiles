return {
	-- NOTE: Plugins can also be configured to run Lua code when they are loaded.
	--
	-- This is often very useful to both group configuration, as well as handle
	-- lazy loading plugins that don't need to be loaded immediately at startup.
	--
	-- For example, in the following configuration, we use:
	--  event = 'VimEnter'
	--
	-- which loads which-key before all the UI elements are loaded. Events can be
	-- normal autocommands events (`:help autocmd-events`).
	--
	-- Then, because we use the `config` key, the configuration only runs
	-- after the plugin has been loaded:
	--  config = function() ... end

	{ -- Useful plugin to show you pending keybinds.
		"folke/which-key.nvim",
		event = "VimEnter", -- Sets the loading event to 'VimEnter'
		opts = {
			icons = {
				-- set icon mappings to true if you have a Nerd Font
				mappings = vim.g.have_nerd_font,
				-- If you are using a Nerd Font: set icons.keys to an empty table which will use the
				-- default whick-key.nvim defined Nerd Font icons, otherwise define a string table
				keys = vim.g.have_nerd_font and {} or {
					Up = "<Up> ",
					Down = "<Down> ",
					Left = "<Left> ",
					Right = "<Right> ",
					C = "<C-…> ",
					M = "<M-…> ",
					D = "<D-…> ",
					S = "<S-…> ",
					CR = "<CR> ",
					Esc = "<Esc> ",
					ScrollWheelDown = "<ScrollWheelDown> ",
					ScrollWheelUp = "<ScrollWheelUp> ",
					NL = "<NL> ",
					BS = "<BS> ",
					Space = "<Space> ",
					Tab = "<Tab> ",
					F1 = "<F1>",
					F2 = "<F2>",
					F3 = "<F3>",
					F4 = "<F4>",
					F5 = "<F5>",
					F6 = "<F6>",
					F7 = "<F7>",
					F8 = "<F8>",
					F9 = "<F9>",
					F10 = "<F10>",
					F11 = "<F11>",
					F12 = "<F12>",
				},
			},

			-- Document existing key chains
			spec = {
				{ "<leader>a", group = "[A]vante", mode = { "n", "v" }, icon = { icon = "🤖" } },
				{ "<leader>c", group = "[C]ode", mode = { "n", "x" }, icon = { icon = "</>" } },
				{ "<leader>d", group = "[D]ocument" },
				{ "<leader>g", group = "[G]it diffview", icon = { icon = "" } },
				{ "<leader>l", group = "[L]SP" },
				{ "<leader>L", group = "[L]LM", icon = { icon = "" } },
				{ "<leader>n", group = "[N]oice", icon = { icon = "💥" } },
				{ "<leader>p", group = "[P]roject" },
				{ "<leader>q", group = "[Q]uickfix" },
				{ "<leader>r", group = "[R]ename" },
				{ "<leader>s", group = "[S]earch", icon = { icon = "🔍" } },
				{ "<leader>w", group = "[W]orkspace" },
				{ "<leader>T", group = "[T]oggle" },
				{ "<leader>h", group = "Git [H]unk", mode = { "n", "v" } },
				{ "<leader>C", group = "[C]Code Coverage" },
				{ "<leader>ct", group = "[C] [T]imestamp", icon = { icon = "🕒" } },
			},
		},
	},
}
