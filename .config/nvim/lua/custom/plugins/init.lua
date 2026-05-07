-- You can add your own plugins here or in other files in this directory!
--  I promise not to create any merge conflicts in this directory :)
--
-- See the kickstart.nvim README for more information
return {
	require("custom.plugins.avante"), -- comment this out and run :Copilot setup to setup copilot
	require("custom.plugins.nvim-cmp"),
	require("custom.plugins.colorschemes"),
	require("custom.plugins.conform"), -- Autoformat
	require("custom.plugins.copilot"),
	require("custom.plugins.diffview"),
	require("custom.plugins.fzf-lua"),
	require("custom.plugins.gitsigns"),
	require("custom.plugins.img-clip"),
	require("custom.plugins.leetcode"),
	require("custom.plugins.mini"),
	require("custom.plugins.neotest"),
	require("custom.plugins.noice"),
	require("custom.plugins.nvim-coverage"),
	require("custom.plugins.nvim-dap-virtual-text"),
	require("custom.plugins.nvim-jdtls"),
	require("custom.plugins.nvim-treesitter"),
	require("custom.plugins.plenary"),
	require("custom.plugins.rustaceanvim"),
	require("custom.plugins.smear-cursor"),
	require("custom.plugins.smooth-cursor"),
	require("custom.plugins.typescript-tools"),
	require("custom.plugins.which-key"),
}
