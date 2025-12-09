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
vim.keymap.set("n", "<leader>gm", ":DiffviewOpen origin/main <CR>", { desc = "[G]it diffview [M]ain" })
vim.keymap.set("n", "<leader>gc", ":DiffviewClose <CR>", { desc = "[G]it diffview[C]lose" })
vim.keymap.set("n", "<leader>gh", ":DiffviewFileHistory %<CR>", { desc = "[G]it diffview[H]istory" })

-- copilot bindings
vim.keymap.set("n", "<leader>Lo", ":CopilotChatOpen<CR>", { desc = "[L]LM [O]pen" })
vim.keymap.set("n", "<leader>Lr", ":CopilotChatReset<CR>", { desc = "[L]LM CopilotChat[R]eset" })

-- noice bindings
vim.keymap.set("n", "<leader>nd", ":NoiceDismiss<CR>", { desc = "[N]oice [D]ismiss" })
vim.keymap.set("n", "<leader>nh", ":NoiceHistory<CR>", { desc = "[N]oice [H]istory" })
vim.keymap.set("n", "<leader>nt", ":NoiceTelescope<CR>", { desc = "[N]oice [T]elescope" })
vim.keymap.set("n", "<leader>ne", ":NoiceErrors<CR>", { desc = "[N]oice [E]rrors" })

-- fzf lua bindings
vim.api.nvim_set_keymap("n", "<F4>", ":FzfLua dap_commands<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<F5>", ":FzfLua dap_configurations<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<F6>", ":FzfLua dap_frames<CR>", { noremap = true, silent = true })
vim.keymap.set("n", "<leader>sh", ":FzfLua help_tags<CR>", { desc = "[S]earch [H]elp" })
vim.keymap.set("n", "<leader>sk", ":FzfLua keymaps<CR>", { desc = "[S]earch [K]eymaps" })
vim.keymap.set("n", "<leader>sf", ":FzfLua files<CR>", { desc = "[S]earch [F]iles" })
vim.keymap.set("n", "<leader>ss", ":FzfLua builtin<CR>", { desc = "[S]earch [S]elect Telescope" })
vim.keymap.set("n", "<leader>sw", ":FzfLua grep_cword<CR>", { desc = "[S]earch current [W]ord" })
vim.keymap.set(
	"n",
	"<leader>sg",
	":lua require('fzf-lua').live_grep({ cmd = 'rg --line-number --column --color=always --hidden'})<CR>",
	{ desc = "[S]earch by [G]rep" }
)
-- vim.keymap.set("n", "<leader>sg", ":FzfLua live_grep_glob<CR>", { desc = "[S]earch by [G]rep" })
vim.keymap.set("n", "<leader>sd", ":FzfLua diagnostics_document<CR>", { desc = "[S]earch [D]iagnostics" })
vim.keymap.set("n", "<leader>sc", ":FzfLua colorschemes<CR>", { desc = "[S]earch [C]olorschemes" })
vim.keymap.set("n", "<leader>sr", ":FzfLua resume<CR>", { desc = "[S]earch [R]esume" })
vim.keymap.set("n", "<leader>s.", ":FzfLua oldfiles<CR>", { desc = '[S]earch Recent Files ("." for repeat)' })
vim.keymap.set("n", "<leader><leader>", ":FzfLua buffers<CR>", { desc = "[ ] Find existing buffers" })
vim.keymap.set("n", "<leader>/", ":FzfLua lines<CR>", { desc = "[/] Fuzzily search in current buffer" })

vim.keymap.set(
	"n",
	"<leader>sn",
	":FzfLua files cwd=" .. vim.fn.stdpath("config") .. "<CR>",
	{ desc = "[S]earch [N]eovim files" }
)

vim.keymap.set("n", "gd", ":FzfLua lsp_definitions<CR>", { desc = "[G]oto [D]efinition" })
vim.keymap.set("n", "gr", ":FzfLua lsp_references<CR>", { desc = "[G]oto [R]eferences" })
vim.keymap.set("n", "ds", ":FzfLua lsp_document_symbols<CR>", { desc = "[D]ocument [S]ymbols" })
vim.keymap.set("n", "ws", ":FzfLua lsp_live_workspace_symbols<CR>", { desc = "[W]orkplace [S]ymbols" })

-- custom
-- Insert timestamp in the current buffer
vim.keymap.set("n", "<leader>ct", function()
	local timestamp = os.date("%Y-%m-%d %H:%M:%S")
	vim.api.nvim_put({ timestamp }, "c", true, true)
end, { desc = "[C] [T]timestamp" })

-- vim.keymap.set("n", "<leader>ec", function()
-- 	vim.api.nvim_put({ "✔" }, "c", true, true)
-- end, { desc = "[E]moji [C]heckmark" })

-- Show diagnostics for the current line in a floating window
vim.keymap.set("n", "<leader>e", vim.diagnostic.open_float, { desc = "Show LSP error popup" })

-- keymap that toggles between tokyonight and onedark themes
vim.keymap.set("n", "<leader>Tt", function()
	local current_theme = vim.g.colors_name
	if current_theme == "tokyonight-day" then
		vim.cmd("colorscheme onedark")
	else
		vim.cmd("colorscheme tokyonight")
	end
end, { desc = "[T]oggle [T]heme" })
