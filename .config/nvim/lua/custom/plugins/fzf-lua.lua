return {
	{
		"ibhagwan/fzf-lua",
		-- optional for icon support
		dependencies = { "nvim-tree/nvim-web-devicons" },
		-- or if using mini.icons/mini.nvim
		-- dependencies = { "echasnovski/mini.icons" },
		opts = {
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
