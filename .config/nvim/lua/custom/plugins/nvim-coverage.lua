return {
	{
		"andythigpen/nvim-coverage",
		requires = { "nvim-lua/plenary.nvim" },
		config = function()
			require("coverage").setup({
				highlights = {
					covered = { fg = "LightGreen" }, -- supports style, fg, bg, sp (see :h highlight-gui)
					uncovered = { fg = "DarkRed" },
					partial = { fg = "Blue" },
				},
				lang = {
					typescript = {
						coverage_file = "coverage/coverage-final.json",
					},
				},
			})
		end,
	},
}
