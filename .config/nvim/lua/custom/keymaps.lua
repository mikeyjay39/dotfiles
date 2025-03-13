-- Keybinds to make split navigation easier.
--  Use CTRL+<hjkl> to switch between windows
--
--  See `:help wincmd` for a list of all window commands
vim.keymap.set("n", "<C-h>", "<C-w><C-h>", { desc = "Move focus to the left window" })
vim.keymap.set("n", "<C-l>", "<C-w><C-l>", { desc = "Move focus to the right window" })
vim.keymap.set("n", "<C-j>", "<C-w><C-j>", { desc = "Move focus to the lower window" })
vim.keymap.set("n", "<C-k>", "<C-w><C-k>", { desc = "Move focus to the upper window" })

-- nvim-coverage bindings
vim.api.nvim_create_user_command("CoverageLoad", function()
	require("coverage").load()
end, { desc = "Load coverage data" })

vim.api.nvim_create_user_command("CoverageShow", function()
	require("coverage").show()
end, { desc = "Show coverage highlights" })

vim.api.nvim_create_user_command("CoverageHide", function()
	require("coverage").hide()
end, { desc = "Hide coverage highlights" })

vim.api.nvim_create_user_command("CoverageToggle", function()
	require("coverage").toggle()
end, { desc = "Toggle coverage highlights" })

vim.api.nvim_create_user_command("CoverageSummary", function()
	require("coverage").summary()
end, { desc = "Toggle coverage summary" })

-- Keybinding to load coverage data
vim.api.nvim_set_keymap(
	"n", -- Normal mode
	"<leader>Cl", -- Keybinding: <leader>cl (Coverage Load)
	":CoverageLoad<CR>", -- Command to execute
	{ noremap = true, silent = true } -- Options: non-recursive and silent
)

-- Keybinding to show coverage highlights
vim.api.nvim_set_keymap(
	"n",
	"<leader>Cs", -- Keybinding: <leader>cs (Coverage Show)
	":CoverageShow<CR>",
	{ noremap = true, silent = true }
)

-- Keybinding to hide coverage highlights
vim.api.nvim_set_keymap(
	"n",
	"<leader>Ch", -- Keybinding: <leader>ch (Coverage Hide)
	":CoverageHide<CR>",
	{ noremap = true, silent = true }
)

-- Keybinding to toggle coverage highlights
vim.api.nvim_set_keymap(
	"n",
	"<leader>Ct", -- Keybinding: <leader>ct (Coverage Toggle)
	":CoverageToggle<CR>",
	{ noremap = true, silent = true }
)

-- Keybinding to toggle coverage highlights
vim.api.nvim_set_keymap(
	"n",
	"<leader>CS", -- Keybinding: <leader>CS (Coverage Summary)
	":CoverageSummary<CR>",
	{ noremap = true, silent = true }
)

-- diffview bindings

vim.keymap.set("n", "<leader>go", ":DiffviewOpen <CR>", { desc = "[G]it diffview[O]pen" })
vim.keymap.set("n", "<leader>gc", ":DiffviewClose <CR>", { desc = "[G]it diffview[C]lose" })
vim.keymap.set("n", "<leader>gh", ":DiffviewFileHistory %<CR>", { desc = "[G]it diffview[H]istory" })
