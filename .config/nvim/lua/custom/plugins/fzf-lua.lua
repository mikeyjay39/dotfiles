return {
	{
		"ibhagwan/fzf-lua",
		-- optional for icon support
		dependencies = { "nvim-tree/nvim-web-devicons" },
		-- or if using mini.icons/mini.nvim
		-- dependencies = { "echasnovski/mini.icons" },
		opts = {
			winopts = {
				fullscreen = true,
				preview = {
					layout = "vertical",
					vertical = "down:60%", -- preview below the file list (adjust % to taste)
				},
			},
			previewers = {
				builtin = {
					render_markdown = {
						enabled = false,
					},
				},
			},
			fzf_opts = {
				-- A footer, not a header, because fzf-lua writes its own per-picker hints to the header.
				["--footer"] = "tab/s-tab: mark row | alt-q: marked to quickfix | ctrl-q: all to quickfix | ctrl-a: toggle all",
			},
			keymap = {
				fzf = {
					-- This line maps Ctrl+Q to select all results and then accept them,
					-- which automatically sends them to the quickfix list.
					["ctrl-q"] = "select-all+accept",
					-- You can also ensure the default Ctrl+A is available if needed:
					["ctrl-a"] = "toggle-all",
				},
			},
		},
	},
}
