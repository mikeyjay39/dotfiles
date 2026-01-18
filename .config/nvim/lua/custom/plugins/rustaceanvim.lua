return {
	{
		"mrcjkb/rustaceanvim",
		version = "^6", -- Recommended
		lazy = false, -- This plugin is already lazy
		init = function()
			vim.g.rustaceanvim = {
				server = {
					settings = {
						["rust-analyzer"] = {
							diagnostics = {
								disabled = { "unlinked-file" },
							},
						},
					},
				},
			}
		end,
	},
}
