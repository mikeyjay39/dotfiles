-- Keeps Session.vim current so tmux-resurrect can restore buffers with `nvim -S`
return {
	{
		"tpope/vim-obsession",
		lazy = false,
		config = function()
			vim.api.nvim_create_autocmd("VimEnter", {
				group = vim.api.nvim_create_augroup("auto-obsess", { clear = true }),
				desc = "Load or start session tracking in the current directory",
				-- Nested so the restored buffers fire BufRead/FileType (syntax, LSP)
				nested = true,
				callback = function()
					-- Skip `nvim <file>` (e.g. git commit) and special buffers such as man pages.
					-- A loaded Session.vim already resumes tracking by itself.
					if vim.fn.argc() > 0 or vim.api.nvim_buf_get_name(0) ~= "" or vim.v.this_session ~= "" then
						return
					end
					-- Load an existing session; starting a new one would overwrite it with an empty one
					if vim.fn.filereadable("Session.vim") == 1 then
						vim.cmd("source Session.vim")
						return
					end
					vim.cmd("Obsess")
				end,
			})
		end,
	},
}
