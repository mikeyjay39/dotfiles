return {
	-- { -- You can easily change to a different colorscheme.
	-- 	-- Change the name of the colorscheme plugin below, and then
	-- 	-- change the command in the config to whatever the name of that colorscheme is.
	-- 	--
	-- 	-- If you want to see what colorschemes are already installed, you can use `:Telescope colorscheme`.
	-- 	"folke/tokyonight.nvim",
	-- 	priority = 1000, -- Make sure to load this before all the other start plugins.
	-- 	init = function()
	-- 		-- Load the colorscheme here.
	-- 		-- Like many other themes, this one has different styles, and you could load
	-- 		-- any other, such as 'tokyonight-storm', 'tokyonight-moon', or 'tokyonight-day'.
	-- 		vim.cmd.colorscheme("tokyonight-night")
	-- 		-- vim.cmd.colorscheme("tokyonight-day")
	--
	-- 		-- You can configure highlights by doing something like:
	-- 		vim.cmd.hi("Comment gui=none")
	-- 	end,
	-- 	opts = {
	-- 		transparent = true,
	-- 		styles = {
	-- 			sidebars = "transparent",
	-- 			floats = "transparent",
	-- 		},
	-- 	},
	-- },
	-- {
	-- 	"sonph/onehalf",
	-- 	lazy = false,
	-- 	priority = 1000,
	-- 	config = function()
	-- 		vim.cmd("set runtimepath+=~/.local/share/nvim/lazy/onehalf/vim") -- Add to runtime path
	-- 		vim.cmd("colorscheme onehalfdark")
	-- 		-- vim.cmd("colorscheme onehalflight")
	-- 		-- Set transparent background
	-- 		vim.cmd([[
	--      highlight Normal     ctermbg=none guibg=none
	--      highlight NormalNC   ctermbg=none guibg=none
	--      highlight SignColumn ctermbg=none guibg=none
	--      highlight VertSplit  ctermbg=none guibg=none
	--      highlight StatusLine ctermbg=none guibg=none
	--    ]])
	-- 	end,
	-- },
	-- {
	-- 	"catppuccin/nvim",
	-- 	name = "catppuccin",
	-- 	priority = 1000,
	-- 	config = function()
	-- 		require("catppuccin").setup({
	-- 			flavour = "latte", -- Set the variant to 'latte'
	-- 			transparent_background = true, -- Enable transparency
	-- 		})
	-- 		vim.cmd("colorscheme catppuccin")
	-- 	end,
	-- },
	-- {
	-- 	"EdenEast/nightfox.nvim",
	-- 	lazy = false,
	-- 	priority = 1000,
	-- 	config = function()
	-- 		require("nightfox").setup({
	-- 			options = {
	-- 				transparent = true, -- Enable transparent background
	-- 				colorblind = {
	-- 					enable = true, -- Enable colorblind mode
	-- 					simulate_only = false,
	-- 					severity = {
	-- 						protan = 0.0, -- Red weakness
	-- 						deutan = 0.0, -- Green weakness
	-- 						tritan = 1.0, -- Blue weakness
	-- 					},
	-- 				},
	-- 				styles = {
	-- 					comments = "italic",
	-- 					keywords = "bold",
	-- 					types = "italic,bold",
	-- 				},
	-- 			},
	-- 		})
	-- 		vim.cmd("colorscheme nightfox") -- Apply the colorscheme
	-- 	end,
	-- },
	-- {
	-- 	-- ATOM
	-- 	"olimorris/onedarkpro.nvim",
	-- 	priority = 1000, -- Ensure it loads first
	--
	-- 	config = function()
	-- 		require("onedarkpro").setup({
	-- 			options = {
	-- 				transparency = true,
	-- 			},
	-- 		})
	-- 		vim.cmd("colorscheme onedark")
	-- 	end,
	-- },
	-- {
	-- 	-- ATOM LIGHT
	-- 	"navarasu/onedark.nvim",
	-- 	priority = 1000, -- Ensure it loads first
	--
	-- 	config = function()
	-- 		require("onedark").setup({
	-- 			style = "light", -- Default theme style. Choose between 'dark', 'darker', 'cool', 'deep', 'warm', 'warmer' and 'light'
	-- 			transparent = true, -- show/hide background
	-- 		})
	-- 		require("onedark").load()
	-- 	end,
	-- },
	{
		"projekt0n/github-nvim-theme",
		name = "github-theme",
		lazy = false, -- make sure we load this during startup if it is your main colorscheme
		priority = 1000, -- make sure to load this before all the other start plugins
		config = function()
			require("github-theme").setup({
				options = {
					transparent = true,
				},
				-- palettes = {
				-- 	all = {
				-- 		Visual = { bg = "#000000", guibg = "#000000", sel1 = "#000000" }, -- Change to your preferred selection color
				-- 	},
				-- },
			})
			vim.cmd("colorscheme github_light_colorblind")
			vim.api.nvim_set_hl(0, "CursorLine", { bg = "#d9d2e9" }) -- Change color here
			vim.api.nvim_set_hl(0, "Visual", { bg = "#7eb6e1" }) -- Change color here
		end,
	},
}
