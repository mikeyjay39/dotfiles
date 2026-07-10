return {
	{
		"pmizio/typescript-tools.nvim",
		dependencies = { "nvim-lua/plenary.nvim", "neovim/nvim-lspconfig" },
		opts = {
			settings = {
				tsserver_logs = "verbose",
			},
			root_dir = function(bufnr, on_dir)
				local path = vim.api.nvim_buf_get_name(bufnr)
				-- Prefer monorepo root (pnpm/nx) over per-package tsconfig.json.
				-- Important for git worktrees and nested libs/* projects.
				local root = vim.fs.root(path, { "pnpm-workspace.yaml", "nx.json", "package.json" })
				on_dir(root or vim.fn.getcwd())
			end,
		},
	},
}
